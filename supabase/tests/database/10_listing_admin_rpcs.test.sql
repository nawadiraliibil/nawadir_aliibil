-- MOBILE-BE-107 — الترحيل 10 listing_admin_rpcs
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

-- a معلن، s مدير، m مشرف بقدرة المراجعة فقط.
insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001');
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'moderator@example.test');

update public.profiles set display_name = 'معلن الاختبار', region_id = 1
  where id = '00000000-0000-0000-0000-00000000000a';
insert into public.policy_consents (user_id, document_id)
  select '00000000-0000-0000-0000-00000000000a', d.id from private.current_policy_documents() d;
select private.bootstrap_first_admin('00000000-0000-0000-0000-0000000000a1');
insert into public.admin_roles (user_id, role, capabilities)
  values ('00000000-0000-0000-0000-0000000000a2', 'MODERATOR', array['listings.review']);

create function pg_temp.login(p_user uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

create temp table ids (k text primary key, v uuid);
create temp table vals (k text primary key, v text);
grant all on ids, vals to authenticated;

-- المعلن ينشئ إعلانًا ويرسله بالدوال الفعلية
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
insert into ids select 'l1', (public.create_listing_draft('aaaaaaaa-0000-0000-0000-000000000001') #>> '{listing,id}')::uuid;
select lives_ok(
  $$select public.save_listing_draft((select v from ids where k = 'l1'),
    jsonb_build_object(
      'title', 'ناقة مجاهيم للبيع', 'description', 'وصف كاف لاجتياز الحد الأدنى للطول المطلوب',
      'breed_id', (select id from public.breeds where not requires_note order by id limit 1),
      'sex', 'FEMALE', 'age_months', 48,
      'region_id', 1, 'city_id', (select id from public.cities where region_id = 1 order by id limit 1),
      'health_notes', 'لا توجد عيوب معروفة', 'owner_declaration', true,
      'offer_type', 'FIXED_PRICE', 'price', 25000,
      'contact_phone', '0500000009', 'contact_call_enabled', true))$$,
  'حفظ المسودة');
insert into ids select 'm1', (public.add_listing_media((select v from ids where k = 'l1'), 'IMAGE', 'image/jpeg', 1000) ->> 'media_id')::uuid;
insert into ids select 'm2', (public.add_listing_media((select v from ids where k = 'l1'), 'IMAGE', 'image/jpeg', 1000) ->> 'media_id')::uuid;
insert into ids select 'm3', (public.add_listing_media((select v from ids where k = 'l1'), 'IMAGE', 'image/jpeg', 1000) ->> 'media_id')::uuid;
reset role;
select public.finalize_listing_media(v, 'image/jpeg', 1000, 800, 600) from ids where k in ('m1', 'm2', 'm3');
set local role authenticated;
select lives_ok(
  $$select public.arrange_listing_media((select v from ids where k = 'l1'),
      array[(select v from ids where k = 'm1'), (select v from ids where k = 'm2'), (select v from ids where k = 'm3')],
      (select v from ids where k = 'm1'))$$,
  'ترتيب الوسائط');
select is(
  public.submit_listing((select v from ids where k = 'l1'), 'bbbbbbbb-0000-0000-0000-000000000001') #>> '{listing,status}',
  'PUBLISHED', 'إرسال الإعلان ينشره مباشرة');

-- المستخدم العادي لا يستدعي دوال الإدارة
select throws_ok(
  $$select public.admin_review_queue()$$, 'P0001', 'FORBIDDEN', 'المستخدم العادي لا يقرأ قائمة المراجعة');
select throws_ok(
  $$select public.admin_approve_listing_version((select v from ids where k = 'l1'), gen_random_uuid(), 'x')$$,
  'P0001', 'FORBIDDEN', 'المستخدم العادي لا يعتمد إعلانه');
select throws_ok(
  $$select public.admin_suspend_account('00000000-0000-0000-0000-00000000000a', 'ABUSE')$$,
  'P0001', 'FORBIDDEN', 'المستخدم العادي لا يعلق حسابًا');
reset role;

-- المشرف دون aal2
select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal1');
set local role authenticated;
select throws_ok(
  $$select public.admin_review_queue()$$, 'P0001', 'MFA_REQUIRED', 'المراجعة تشترط aal2');
reset role;

-- المشرف: قائمة المراجعة القديمة فارغة، وإدارة الإعلانات بالقائمة الجديدة
select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal2');
set local role authenticated;
select is(jsonb_array_length(public.admin_review_queue()), 0, 'قائمة المراجعة المهملة فارغة دائمًا');
select is(jsonb_array_length(public.admin_list_listings()), 1, 'إعلان واحد في إدارة الإعلانات');
select is(public.admin_list_listings() #>> '{0,status}', 'PUBLISHED', 'الإعلان منشور');
select is(public.admin_list_listings() #>> '{0,owner_display_name}', 'معلن الاختبار', 'القائمة تعرض اسم المعلن');
select is(jsonb_array_length(public.admin_list_listings('HIDDEN')), 0, 'التصفية بالحالة: لا مخفي');
select is(jsonb_array_length(public.admin_list_listings('PUBLISHED', 'مجاهيم')), 1, 'البحث بجزء من العنوان');
select is(jsonb_array_length(public.admin_list_listings(null, 'اختبار')), 1, 'البحث باسم المعلن');
select is(jsonb_array_length(public.admin_list_listings(null, 'لا يوجد مثله')), 0, 'بحث بلا نتائج');
select is(jsonb_array_length(public.admin_list_listings(null, (select v::text from ids where k = 'l1'))), 1, 'البحث بمعرف الإعلان');
select throws_ok($$select public.admin_list_listings('UNDER_REVIEW')$$, 'P0001', 'VALIDATION_FAILED', 'حالة غير مدعومة');
insert into ids select 'v1', (public.admin_get_listing_review((select v from ids where k = 'l1')) #>> '{version,id}')::uuid;
insert into vals select 'h1', public.admin_get_listing_review((select v from ids where k = 'l1')) #>> '{version,content_hash}';
select is(
  jsonb_array_length(public.admin_get_listing_review((select v from ids where k = 'l1')) -> 'media'),
  3, 'تفاصيل إعلان منشور تضم الوسائط');
select is(
  public.admin_get_listing_review((select v from ids where k = 'l1')) #>> '{reviews,0,reason_text}',
  'AUTO_PUBLISH', 'سجل المراجعة يحوي حدث النشر التلقائي');

select throws_ok(
  $$select public.admin_approve_listing_version((select v from ids where k = 'l1'), (select v from ids where k = 'v1'),
      (select v from vals where k = 'h1'))$$,
  'P0001', 'INVALID_STATE', 'الاعتماد مهمل ويرفع INVALID_STATE');
select throws_ok(
  $$select public.admin_reject_listing_version((select v from ids where k = 'l1'), (select v from ids where k = 'v1'),
      (select v from vals where k = 'h1'), 'MISSING_INFO')$$,
  'P0001', 'INVALID_STATE', 'الرفض مهمل ويرفع INVALID_STATE');
select throws_ok(
  $$select public.admin_hide_listing((select v from ids where k = 'l1'), 'FRAUD')$$,
  'P0001', 'FORBIDDEN', 'مشرف دون listings.hide لا يخفي');
reset role;

select is((select decision::text || ':' || reason_text || ':' || (moderator_id = '00000000-0000-0000-0000-00000000000a')::text
    from public.reviews), 'APPROVED:AUTO_PUBLISH:true', 'النشر التلقائي مسجل بمعرف المعلن');
select is((select count(*)::integer from public.audit_log where action in ('listing.approved', 'listing.rejected')), 0,
  'لا سجل إجراء موظف للنشر');
select is((select status::text from public.listing_versions), 'APPROVED', 'النسخة معتمدة تلقائيًا');
select ok(
  (select published_version_id = (select v from ids where k = 'v1')
     and first_published_at is not null and last_published_at is not null and visibility_updated_at is not null
   from public.listings where id = (select v from ids where k = 'l1')),
  'أوقات النشر والنسخة المنشورة تحفظ');
select is(
  public.storage_object_is_public('listing-images',
    (select object_path from public.media where id = (select v from ids where k = 'm1'))),
  true, 'وسائط المنشور عامة');

-- الإخفاء وإعادة الإظهار (المدير)
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;
select throws_ok(
  $$select public.admin_hide_listing((select v from ids where k = 'l1'), '')$$,
  'P0001', 'REASON_REQUIRED', 'الإخفاء يستلزم سببًا');
select is(
  public.admin_hide_listing((select v from ids where k = 'l1'), 'FRAUD') ->> 'status',
  'HIDDEN', 'إخفاء الإعلان');
select throws_ok(
  $$select public.admin_hide_listing((select v from ids where k = 'l1'), 'FRAUD')$$,
  'P0001', 'INVALID_STATE', 'إخفاء مخفي مرفوض');
reset role;
select is(
  public.storage_object_is_public('listing-images',
    (select object_path from public.media where id = (select v from ids where k = 'm1'))),
  false, 'وسائط المخفي غير عامة');

update public.listings set last_published_at = now() - interval '3 days'
  where id = (select v from ids where k = 'l1');
set local role authenticated;
select is(
  public.admin_unhide_listing((select v from ids where k = 'l1'), 'بعد المراجعة') ->> 'status',
  'PUBLISHED', 'إعادة إظهار الإعلان');
reset role;

-- إعادة النشر لا تتجاوز مهلة التجديد
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select throws_ok(
  $$select public.bump_listing((select v from ids where k = 'l1'))$$,
  'P0001', 'BUMP_TOO_EARLY', 'الإخفاء وإعادة الإظهار لا يتجاوزان مهلة التجديد');
reset role;

-- تعليق الحساب
select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal2');
set local role authenticated;
select throws_ok(
  $$select public.admin_suspend_account('00000000-0000-0000-0000-00000000000a', 'ABUSE')$$,
  'P0001', 'FORBIDDEN', 'مشرف دون accounts.manage لا يعلق حسابًا');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;
select throws_ok(
  $$select public.admin_suspend_account('00000000-0000-0000-0000-00000000000a', null)$$,
  'P0001', 'REASON_REQUIRED', 'التعليق يستلزم سببًا');
select throws_ok(
  $$select public.admin_suspend_account('00000000-0000-0000-0000-00000000000a', 'MISSING_INFO')$$,
  'P0001', 'VALIDATION_FAILED', 'سبب لا ينطبق على التعليق مرفوض');
select is(
  public.admin_suspend_account('00000000-0000-0000-0000-00000000000a', 'ABUSE') ->> 'status',
  'SUSPENDED', 'تعليق الحساب');
select is(
  public.admin_get_account('00000000-0000-0000-0000-00000000000a') #>> '{listing_counts,HIDDEN}',
  '1', 'التعليق يخفي الإعلان المنشور');
select is(
  public.admin_get_account('00000000-0000-0000-0000-00000000000a') ->> 'phone',
  '966500000001', 'تفاصيل الحساب تضم هاتف الدخول');
select throws_ok(
  $$select public.admin_unhide_listing((select v from ids where k = 'l1'))$$,
  'P0001', 'INVALID_STATE', 'لا إعادة إظهار لإعلان حساب معلق');
select is(
  public.admin_reactivate_account('00000000-0000-0000-0000-00000000000a') ->> 'status',
  'ACTIVE', 'تفعيل الحساب');
select is(
  public.admin_get_account('00000000-0000-0000-0000-00000000000a') #>> '{listing_counts,HIDDEN}',
  '1', 'التفعيل لا يعيد نشر الإعلانات');
select throws_ok(
  $$select public.admin_reactivate_account('00000000-0000-0000-0000-00000000000a')$$,
  'P0001', 'INVALID_STATE', 'تفعيل حساب فعال مرفوض');
select is(
  (select count(*)::integer from public.audit_log where action in ('account.suspended', 'account.reactivated')),
  2, 'التعليق والتفعيل في سجل الإجراءات');
reset role;

-- UNDER_REVIEW لم تعد حالة ممكنة
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
select throws_ok(
  $$update public.listings set status = 'UNDER_REVIEW' where id = (select v from ids where k = 'l1')$$,
  '23514', null, 'قيد يمنع إنتاج UNDER_REVIEW');

-- الزائر
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok($$select public.admin_review_queue()$$, '42501', null, 'الزائر لا يستدعي دوال الإدارة');
reset role;

select * from finish();
rollback;
