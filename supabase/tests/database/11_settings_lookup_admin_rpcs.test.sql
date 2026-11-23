-- MOBILE-BE-108 — الترحيل 11 settings_lookup_admin_rpcs
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

-- s مدير، m مشرف بقدرة القوائم فقط، u مستخدم عادي.
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'moderator@example.test');
insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001');
select private.bootstrap_first_admin('00000000-0000-0000-0000-0000000000a1');
insert into public.admin_roles (user_id, role, capabilities)
  values ('00000000-0000-0000-0000-0000000000a2', 'MODERATOR', array['lookups.manage']);

create function pg_temp.login(p_user uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

create temp table ids (k text primary key, v integer);
grant all on ids to authenticated;

------------------------------------------------------------------------------
-- غير المخول
------------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select throws_ok(
  $$select public.admin_upsert_breed(null, 'سلالة')$$, 'P0001', 'FORBIDDEN', 'المستخدم العادي لا يضيف سلالة');
select throws_ok(
  $$select public.admin_publish_settings()$$, 'P0001', 'FORBIDDEN', 'المستخدم العادي لا ينشر إعدادات');
reset role;

------------------------------------------------------------------------------
-- القوائم (المشرف بقدرة lookups.manage)
------------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal2');
set local role authenticated;

insert into ids select 'breed', (public.admin_upsert_breed(null, '  سلالة   اختبار ') ->> 'id')::integer;
select is((select name_ar from public.breeds where id = (select v from ids where k = 'breed')),
  'سلالة اختبار', 'إضافة سلالة باسم منظف');
select throws_ok(
  $$select public.admin_upsert_breed(null, 'سلالة اختبار')$$,
  'P0001', 'VALIDATION_FAILED', 'اسم سلالة مكرر مرفوض');
select throws_ok(
  $$select public.admin_upsert_breed(null, '   ')$$,
  'P0001', 'VALIDATION_FAILED', 'اسم فارغ مرفوض');
select is(
  public.admin_upsert_breed((select v from ids where k = 'breed'), 'سلالة معدلة') ->> 'name_ar',
  'سلالة معدلة', 'تعديل سلالة');
select throws_ok(
  $$select public.admin_upsert_breed(999999, 'لا شيء')$$,
  'P0001', 'NOT_FOUND', 'تعديل سلالة غير موجودة');

insert into ids select 'city', (public.admin_upsert_city(null, 1, 'مدينة اختبار') ->> 'id')::integer;
select is((select region_id from public.cities where id = (select v from ids where k = 'city')), 1, 'إضافة مدينة تابعة لمنطقة');
select throws_ok(
  $$select public.admin_upsert_city(null, 999, 'مدينة')$$,
  'P0001', 'VALIDATION_FAILED', 'مدينة لمنطقة غير موجودة مرفوضة');
select throws_ok(
  $$select public.admin_upsert_city(null, 1, 'مدينة اختبار')$$,
  'P0001', 'VALIDATION_FAILED', 'مدينة مكررة في المنطقة مرفوضة');

insert into ids select 'region', (public.admin_upsert_region(null, 'منطقة اختبار') ->> 'id')::integer;
select ok((select v from ids where k = 'region') > 13, 'المنطقة الجديدة تأخذ معرفًا بعد الثابتة');

select is(
  public.admin_upsert_moderation_reason('TEST_REASON', 'سبب اختبار', array['LISTING_REJECT', 'LISTING_REJECT']) -> 'applies_to',
  '["LISTING_REJECT"]'::jsonb, 'إضافة سبب إشراف دون تكرار');
select throws_ok(
  $$select public.admin_upsert_moderation_reason('bad code', 'سبب', array['LISTING_REJECT'])$$,
  'P0001', 'VALIDATION_FAILED', 'رمز سبب غير صالح');
select throws_ok(
  $$select public.admin_upsert_moderation_reason('TEST_TWO', 'سبب', array['UNKNOWN'])$$,
  'P0001', 'VALIDATION_FAILED', 'إجراء غير معرف مرفوض');

-- التعطيل: لا حذف، ولا تظهر للعميل
select is(
  (public.admin_set_lookup_active('breed', (select v::text from ids where k = 'breed'), false) ->> 'is_active')::boolean,
  false, 'تعطيل سلالة');
select throws_ok(
  $$select public.admin_set_lookup_active('unknown', '1', false)$$,
  'P0001', 'VALIDATION_FAILED', 'نوع قائمة غير معروف');
select throws_ok(
  $$select public.admin_set_lookup_active('breed', '999999', false)$$,
  'P0001', 'NOT_FOUND', 'تعطيل قيمة غير موجودة');
select is(
  (public.admin_set_lookup_active('moderation_reason', 'TEST_REASON', false) ->> 'is_active')::boolean,
  false, 'تعطيل سبب إشراف');

-- الترتيب
select is(
  (public.admin_reorder_lookup('region', array['3', '1', '2']) ->> 'updated')::integer, 3, 'ترتيب ثلاث مناطق');
select is(
  (select array_agg(id order by sort_order, id) from public.regions where id in (1, 2, 3)),
  array[3, 1, 2], 'الترتيب الجديد محفوظ');
select throws_ok(
  $$select public.admin_reorder_lookup('region', array['1', '999999'])$$,
  'P0001', 'NOT_FOUND', 'معرف غير موجود يلغي الترتيب');
select throws_ok(
  $$select public.admin_reorder_lookup('breed', array['1', '1'])$$,
  'P0001', 'VALIDATION_FAILED', 'معرف مكرر في الترتيب مرفوض');

-- مشرف القوائم لا يدير الإعدادات
select throws_ok(
  $$select public.admin_get_settings()$$, 'P0001', 'FORBIDDEN', 'دون settings.manage لا يقرأ الإعدادات');
reset role;

-- أثر التعطيل على العميل
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is(
  (select count(*)::integer from jsonb_array_elements(public.get_published_settings() #> '{lookups,breeds}') b
    where (b ->> 'id')::integer = (select v from ids where k = 'breed')),
  0, 'السلالة المعطلة لا تظهر في القوائم المنشورة');
select is(
  (select count(*)::integer from jsonb_array_elements(public.get_published_settings() #> '{lookups,cities}') c
    where (c ->> 'id')::integer = (select v from ids where k = 'city')),
  1, 'المدينة الجديدة تظهر فورًا');
reset role;

select is((select count(*)::integer from public.breeds where id = (select v from ids where k = 'breed')), 1,
  'القيمة المعطلة باقية في الجدول');
select ok(
  (select count(*) from public.audit_log where action like 'lookup.%') >= 7, 'إجراءات القوائم في سجل الإجراءات');

------------------------------------------------------------------------------
-- الإعدادات (المدير)
------------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;

select is((public.admin_get_settings() ->> 'published_version')::integer, 1, 'الإصدار المنشور 1');
select throws_ok(
  $$select public.admin_publish_settings()$$, 'P0001', 'INVALID_STATE', 'لا نشر دون مسودة');

select throws_ok(
  $$select public.admin_update_settings_draft(
      jsonb_set(public.admin_get_settings() -> 'published', '{bump,interval_hours}', '12'))$$,
  'P0001', 'BELOW_HARD_MINIMUM', 'تجديد أقل من 24 ساعة مرفوض');
select throws_ok(
  $$select public.admin_update_settings_draft(
      jsonb_set(public.admin_get_settings() -> 'published', '{listing,title_max}', '5'))$$,
  'P0001', 'VALIDATION_FAILED', 'حد أعلى أقل من الأدنى مرفوض');
select throws_ok(
  $$select public.admin_update_settings_draft((public.admin_get_settings() -> 'published') #- '{media,image_mime_types}')$$,
  'P0001', 'VALIDATION_FAILED', 'مسودة ناقصة مرفوضة');
select throws_ok(
  $$select public.admin_update_settings_draft('[1]'::jsonb)$$,
  'P0001', 'VALIDATION_FAILED', 'مسودة ليست كائنًا مرفوضة');

select lives_ok(
  $$select public.admin_update_settings_draft(public.admin_get_settings() -> 'published')$$,
  'مسودة مطابقة للمنشور تحفظ');
select throws_ok(
  $$select public.admin_publish_settings()$$, 'P0001', 'INVALID_STATE', 'لا نشر دون تغيير');

select is(
  public.admin_update_settings_draft(
    jsonb_set(jsonb_set(
      (public.admin_get_settings() -> 'published') || '{"unknown_section": {"x": 1}}',
      '{listing,title_max}', '100'),
      '{media,image_max_bytes}', '5242880')) #>> '{draft,unknown_section}',
  null, 'مفاتيح غير معرفة تهمل من المسودة');
select is((public.get_published_settings() #>> '{settings,listing,title_max}')::integer, 80,
  'المسودة لا تغير المنشور');

select is(
  (public.admin_publish_settings('رفع حد العنوان') ->> 'published_version')::integer, 2, 'النشر ينشئ الإصدار 2');
select is(public.admin_get_settings() ->> 'draft', null, 'المسودة تفرغ بعد النشر');
reset role;

select is((public.get_published_settings() #>> '{settings,listing,title_max}')::integer, 100,
  'العميل يقرأ الإصدار الجديد');
select is((select file_size_limit from storage.buckets where id = 'listing-images'), 5242880::bigint,
  'حد حجم الصورة في التخزين يتبع الإصدار المنشور');
select is((select published_by from public.settings_versions where version = 2),
  '00000000-0000-0000-0000-0000000000a1'::uuid, 'الناشر محفوظ في الإصدار');

-- التراجع
set local role authenticated;
select throws_ok(
  $$select public.admin_rollback_settings(2)$$, 'P0001', 'INVALID_STATE', 'لا تراجع إلى الإصدار المنشور نفسه');
select throws_ok(
  $$select public.admin_rollback_settings(99)$$, 'P0001', 'NOT_FOUND', 'تراجع إلى إصدار غير موجود');
select is(
  (public.admin_rollback_settings(1, 'تراجع') ->> 'published_version')::integer, 3,
  'التراجع ينشر إصدارًا جديدًا');
reset role;

select is((select restored_from_version from public.settings_versions where version = 3), 1,
  'الإصدار 3 يشير إلى مصدره');
select is((public.get_published_settings() #>> '{settings,listing,title_max}')::integer, 80,
  'المحتوى يعود إلى قيم الإصدار 1');
select is((select file_size_limit from storage.buckets where id = 'listing-images'), 10485760::bigint,
  'حد التخزين يعود مع التراجع');
select is((select count(*)::integer from public.settings_versions), 3, 'الإصدارات الثلاثة محفوظة');
select is(
  (select array_agg(action order by id) from public.audit_log where action like 'settings.%'),
  array['settings.published', 'settings.rolled_back'], 'النشر والتراجع في سجل الإجراءات');

-- الزائر
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok($$select public.admin_get_settings()$$, '42501', null, 'الزائر لا يستدعي دوال الإعدادات');
reset role;

select * from finish();
rollback;
