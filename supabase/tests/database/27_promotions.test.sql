-- MOBILE-PROMO-20261126 — الترحيل 29 promotions (TEAM-DEC-017، INT-010)
-- لا يعتمد على bootstrap_first_admin حتى يعمل على قاعدة فيها مدير فعلي (يمنح الدور مباشرة).
-- دوال الإدارة تفحص الهوية من JWT (auth.uid وaal)؛ استدعاءات pg_temp تجري بالدور الافتراضي مع
-- ضبط الـclaims، وفحوص الأدوار (anon/authenticated) تجري بـset local role دون pg_temp.
begin;

create extension if not exists pgtap with schema extensions;

select plan(65);

-- مستخدم هاتف (له ملف شخصي)، ومدير، ومشرف بالقدرة، ومشرف بدونها.
insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966599990001');
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'promo-admin@example.test'),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'promo-mod@example.test'),
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'promo-other@example.test');
insert into public.admin_roles (user_id, role, capabilities) values
  ('00000000-0000-0000-0000-0000000000d1', 'ADMIN', array[]::text[]),
  ('00000000-0000-0000-0000-0000000000d2', 'MODERATOR', array['promotions.manage']),
  ('00000000-0000-0000-0000-0000000000d3', 'MODERATOR', array['reports.handle']);

create function pg_temp.login(p_user uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

create function pg_temp.payload(p_over jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object(
    'title', '  أعلاف   الصحراء ',
    'body', 'خصم 15٪ على الأعلاف',
    'advertiser_name', 'مؤسسة الصحراء',
    'image_path', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/cover.webp',
    'action_type', 'URL',
    'action_value', 'https://example.com/offer?x=1',
    'placements', jsonb_build_array('HOME_FEED'),
    'region_ids', null,
    'starts_at', (now() - interval '1 day')::text,
    'ends_at', (now() + interval '10 days')::text,
    'priority', 50) || p_over
$$;

-- رمز الخطأ والحقول المرفوضة عند الحفظ بحمولة معدلة.
create function pg_temp.save_error(p_over jsonb) returns jsonb language plpgsql as $$
declare
  v_detail text;
begin
  perform public.admin_save_promotion(null, pg_temp.payload(p_over));
  return null;
exception when others then
  get stacked diagnostics v_detail = pg_exception_detail;
  return jsonb_build_object('code', sqlerrm, 'fields', (v_detail::jsonb) -> 'fields');
end;
$$;

create function pg_temp.region(p_n integer) returns integer language sql as $$
  select id from public.regions where is_active order by id offset p_n - 1 limit 1
$$;

select ok('promotions.manage' = any (private.all_capabilities()), 'القدرة الجديدة معرفة');
select is((select public from storage.buckets where id = 'promotions'), true, 'bucket الدعايات عام');
select is((select feed_interval from public.promotion_settings), 8, 'الفاصل الافتراضي 8');

------------------------------------------------------------------------------
-- الصلاحيات
------------------------------------------------------------------------------

select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok($$select public.admin_list_promotions()$$, '42501', null, 'الزائر لا يستدعي دوال الإدارة');
select throws_ok($$select * from public.promotions$$, '42501', null, 'لا قراءة مباشرة للجدول للزائر');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000c1', 'aal2');
set local role authenticated;
select throws_ok($$select public.admin_list_promotions()$$, 'P0001', 'FORBIDDEN', 'المستخدم العادي مرفوض');
select throws_ok($$select * from public.promotions$$, '42501', null, 'لا قراءة مباشرة للجدول للمستخدم');
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('promotions', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaab/x.webp')$$,
  '42501', null, 'المستخدم لا يرفع صور الدعايات');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000d3', 'aal2');
set local role authenticated;
select throws_ok($$select public.admin_list_promotions()$$, 'P0001', 'FORBIDDEN', 'مشرف دون القدرة مرفوض');
select throws_ok($$select public.admin_update_promotion_settings(true, 8)$$, 'P0001', 'FORBIDDEN', 'مشرف دون القدرة لا يغير الإعدادات');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000d2', 'aal1');
set local role authenticated;
select throws_ok($$select public.admin_list_promotions()$$, 'P0001', 'MFA_REQUIRED', 'يشترط aal2');
reset role;

------------------------------------------------------------------------------
-- الرفع والتحقق من الحقول (المشرف ذو القدرة)
------------------------------------------------------------------------------

select pg_temp.login('00000000-0000-0000-0000-0000000000d2', 'aal2');
set local role authenticated;
select lives_ok(
  $$insert into storage.objects (bucket_id, name) values ('promotions', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/cover.webp')$$,
  'المشرف ذو القدرة يرفع صورة');
select is(public.admin_list_promotions(), '[]'::jsonb, 'قائمة فارغة في البداية');
select throws_ok($$select public.admin_save_promotion(null, '{}'::jsonb)$$, 'P0001', 'VALIDATION_FAILED', 'حمولة فارغة مرفوضة');
reset role;

select is(pg_temp.save_error('{"title": " ا "}'), '{"code": "VALIDATION_FAILED", "fields": ["title"]}', 'عنوان قصير');
select is(pg_temp.save_error(jsonb_build_object('body', repeat('ن', 141))) -> 'fields', '["body"]', 'نص أطول من 140');
select is(pg_temp.save_error('{"advertiser_name": ""}') -> 'fields', '["advertiser_name"]', 'اسم المعلن مطلوب');
select is(pg_temp.save_error('{"image_path": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/missing.webp"}') -> 'fields', '["image_path"]', 'صورة غير مرفوعة');
select is(pg_temp.save_error('{"action_value": "http://example.com"}') -> 'fields', '["action_value"]', 'الرابط https فقط');
select is(pg_temp.save_error('{"action_value": "https://localhost/x"}') -> 'fields', '["action_value"]', 'مضيف بلا نطاق مرفوض');
select is(pg_temp.save_error('{"action_type": "WHATSAPP", "action_value": "0112345678"}') -> 'fields', '["action_value"]', 'واتساب برقم جوال سعودي فقط');
select is(pg_temp.save_error('{"action_type": "SMS"}') -> 'fields', '["action_type"]', 'نوع إجراء غير معروف');
select is(pg_temp.save_error('{"placements": []}') -> 'fields', '["placements"]', 'موضع واحد على الأقل');
select is(pg_temp.save_error('{"placements": ["DETAILS"]}') -> 'fields', '["placements"]', 'موضع غير معروف');
select is(pg_temp.save_error('{"region_ids": []}') -> 'fields', '["region_ids"]', 'قائمة مناطق فارغة مرفوضة');
select is(pg_temp.save_error('{"region_ids": [999999]}') -> 'fields', '["region_ids"]', 'منطقة غير موجودة');
select is(pg_temp.save_error(jsonb_build_object('ends_at', (now() - interval '2 days')::text)) -> 'fields', '["ends_at"]', 'النهاية قبل البداية');
select is(pg_temp.save_error('{"starts_at": "غدًا"}') -> 'fields', '["starts_at"]', 'تاريخ بداية غير صالح');
select is(pg_temp.save_error('{"priority": 101}') -> 'fields', '["priority"]', 'الأولوية حتى 100');
select is(pg_temp.save_error('{"priority": "5"}') -> 'fields', '["priority"]', 'الأولوية رقم لا نص');

------------------------------------------------------------------------------
-- الإنشاء والتعديل والحالة
------------------------------------------------------------------------------

-- A: جارية في الرئيسية لكل المناطق (أولوية 40).
select set_config('promo.a', public.admin_save_promotion(null, pg_temp.payload('{"priority": 40}')) ->> 'id', true);
select is((public.admin_get_promotion(current_setting('promo.a')::uuid) ->> 'title'), 'أعلاف الصحراء', 'تنظيف مسافات العنوان');
select is((public.admin_get_promotion(current_setting('promo.a')::uuid) ->> 'status'), 'ACTIVE', 'الإنشاء ACTIVE');
select is((public.admin_get_promotion(current_setting('promo.a')::uuid) ->> 'created_by'), '00000000-0000-0000-0000-0000000000d2', 'من أنشأ');
select is((select count(*)::integer from public.audit_log where action = 'promotion.created' and resource_id = current_setting('promo.a')),
  1, 'سجل الإنشاء');

-- B: واتساب، الموضعان، محصورة بمنطقة، أولوية 90.
select set_config('promo.b', public.admin_save_promotion(null, pg_temp.payload(jsonb_build_object(
  'action_type', 'WHATSAPP', 'action_value', '055 123 4567',
  'placements', jsonb_build_array('SEARCH_RESULTS', 'HOME_FEED', 'HOME_FEED'),
  'region_ids', jsonb_build_array(pg_temp.region(1)), 'priority', 90))) ->> 'id', true);
select is(public.admin_get_promotion(current_setting('promo.b')::uuid) ->> 'action_value', '+966551234567', 'توحيد رقم الجوال');
select is(public.admin_get_promotion(current_setting('promo.b')::uuid) -> 'placements', '["HOME_FEED", "SEARCH_RESULTS"]', 'المواضع بلا تكرار');

-- C: عرض فقط، تقبل قيمة الإجراء وتهملها، ثم توقف. D: مجدولة لاحقًا.
select set_config('promo.c', public.admin_save_promotion(null, pg_temp.payload('{"action_type": "NONE", "action_value": "x", "ends_at": null}')) ->> 'id', true);
select is(public.admin_get_promotion(current_setting('promo.c')::uuid) -> 'action_value', 'null', 'NONE بلا قيمة');
select is(public.admin_get_promotion(current_setting('promo.c')::uuid) -> 'ends_at', 'null', 'بلا نهاية');
select set_config('promo.d', public.admin_save_promotion(null, pg_temp.payload(jsonb_build_object(
  'starts_at', (now() + interval '2 days')::text, 'ends_at', null))) ->> 'id', true);

select is(jsonb_array_length(public.admin_list_promotions()), 4, 'أربع دعايات في القائمة');
select is(jsonb_array_length(public.admin_list_promotions('ACTIVE', 2)), 2, 'الحد والمرشح');
select throws_ok($$select public.admin_list_promotions('LIVE')$$, 'P0001', 'VALIDATION_FAILED', 'حالة مرشح غير معروفة');
select throws_ok($$select public.admin_get_promotion(gen_random_uuid())$$, 'P0001', 'NOT_FOUND', 'دعاية غير موجودة');

select is(public.admin_save_promotion(current_setting('promo.a')::uuid, pg_temp.payload('{"title": "أعلاف الصحراء الجديدة", "priority": 40}')) ->> 'title',
  'أعلاف الصحراء الجديدة', 'التعديل');
select is((select count(*)::integer from public.audit_log where action = 'promotion.updated' and resource_id = current_setting('promo.a')),
  1, 'سجل التعديل');

select is(public.admin_set_promotion_status(current_setting('promo.c')::uuid, 'PAUSED', 'طلب المعلن') ->> 'status', 'PAUSED', 'الإيقاف');
select is((select reason_text from public.audit_log where action = 'promotion.status_changed' and resource_id = current_setting('promo.c')),
  'طلب المعلن', 'سجل تغيير الحالة بالملاحظة');
select throws_ok(format($$select public.admin_set_promotion_status(%L, 'DELETED')$$, current_setting('promo.c')),
  'P0001', 'VALIDATION_FAILED', 'حالة غير معروفة');

select throws_ok($$select public.admin_update_promotion_settings(true, 3)$$, 'P0001', 'VALIDATION_FAILED', 'الفاصل من 4 إلى 30');
select is(public.admin_update_promotion_settings(true, 12) ->> 'feed_interval', '12', 'تحديث الفاصل');
select is((select count(*)::integer from public.audit_log where action = 'promotion.settings_updated'
             and actor_id = '00000000-0000-0000-0000-0000000000d2'), 1, 'سجل الإعدادات');

------------------------------------------------------------------------------
-- التطبيق: الدعايات الجارية والأحداث (زائر)
------------------------------------------------------------------------------

-- now() ثابت داخل المعاملة؛ وقت تعديل قديم صراحةً يجعل فحص «الأحداث لا تغيره» ذا معنى.
alter table public.promotions disable trigger promotions_set_updated_at;
update public.promotions set updated_at = '2026-01-01T00:00:00Z' where id = current_setting('promo.a')::uuid;
alter table public.promotions enable trigger promotions_set_updated_at;
select set_config('promo.a_updated', '2026-01-01T00:00:00Z', true);
select set_config('request.jwt.claims', '', true);
set local role anon;

select is(public.list_active_promotions('HOME_FEED') -> 'feed_interval', '12', 'الفاصل مع القائمة');
-- الجارية: B (90) ثم A (40)؛ C موقوفة وD مجدولة.
select is(
  (select jsonb_agg(e ->> 'id') from jsonb_array_elements(public.list_active_promotions('HOME_FEED') -> 'items') e),
  jsonb_build_array(current_setting('promo.b'), current_setting('promo.a')),
  'الجارية بترتيب الأولوية دون الموقوفة والمجدولة');
select is(
  (select jsonb_agg(e ->> 'id') from jsonb_array_elements(public.list_active_promotions('SEARCH_RESULTS') -> 'items') e),
  jsonb_build_array(current_setting('promo.b')),
  'موضع نتائج البحث');
select is(
  (select jsonb_agg(e ->> 'id') from jsonb_array_elements(public.list_active_promotions('HOME_FEED', (select id from public.regions where is_active order by id offset 1 limit 1)) -> 'items') e),
  jsonb_build_array(current_setting('promo.a')),
  'المحصورة بمنطقة لا تظهر لمنطقة أخرى');
select is(
  (select array_agg(k order by k) from jsonb_object_keys(public.list_active_promotions('HOME_FEED') -> 'items' -> 0) k),
  array['action_type', 'action_value', 'advertiser_name', 'body', 'id', 'image_path', 'title'],
  'لا عدادات ولا منشئ في رد التطبيق');
select throws_ok($$select public.list_active_promotions('DETAILS')$$, 'P0001', 'VALIDATION_FAILED', 'موضع غير معروف');

select is(public.record_promotion_event(current_setting('promo.a')::uuid, 'IMPRESSION', '11111111-1111-4111-8111-111111111111'), true, 'أول ظهور يحسب');
select is(public.record_promotion_event(current_setting('promo.a')::uuid, 'IMPRESSION', '11111111-1111-4111-8111-111111111111'), false, 'تكرار الظهور في الساعة لا يحسب');
select is(public.record_promotion_event(current_setting('promo.a')::uuid, 'CLICK', '11111111-1111-4111-8111-111111111111'), true, 'النقر يحسب');
select is(public.record_promotion_event(current_setting('promo.a')::uuid, 'IMPRESSION'), false, 'بلا هوية لا يحسب');
select throws_ok(format($$select public.record_promotion_event(%L, 'IMPRESSION', gen_random_uuid())$$, current_setting('promo.c')),
  'P0001', 'NOT_FOUND', 'الموقوفة لا تسجل أحداثًا');
select throws_ok(format($$select public.record_promotion_event(%L, 'VIEW', gen_random_uuid())$$, current_setting('promo.a')),
  'P0001', 'VALIDATION_FAILED', 'نوع حدث غير معروف');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000d2', 'aal2');
select is(
  (select (p ->> 'impression_count', p ->> 'click_count')::text
     from (select public.admin_get_promotion(current_setting('promo.a')::uuid) p) x),
  '(1,1)', 'العدادات في اللوحة');
select is(
  (select updated_at from public.promotions where id = current_setting('promo.a')::uuid),
  current_setting('promo.a_updated')::timestamptz,
  'الأحداث لا تغير وقت التعديل');

-- إطفاء العرض يفرغ القائمة.
select public.admin_update_promotion_settings(false, 12);
select set_config('request.jwt.claims', '', true);
set local role anon;
select is(public.list_active_promotions('HOME_FEED') -> 'items', '[]'::jsonb, 'الإطفاء يخفي كل الدعايات');
reset role;

select * from finish();
rollback;
