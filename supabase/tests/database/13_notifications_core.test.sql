-- MOBILE-BE-109 — الترحيل 13 notifications_core
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002');
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test');
update public.profiles set display_name = 'معلن الاختبار', region_id = 1
  where id = '00000000-0000-0000-0000-00000000000a';
insert into public.policy_consents (user_id, document_id)
  select '00000000-0000-0000-0000-00000000000a', d.id from private.current_policy_documents() d;
select private.bootstrap_first_admin('00000000-0000-0000-0000-0000000000a1');

create function pg_temp.login(p_user uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

create temp table ids (k text primary key, v uuid);
create temp table vals (k text primary key, v text);
grant all on ids, vals to authenticated, anon;

-- إعلان مرسل
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
select lives_ok(
  $$select public.finalize_listing_media(v, 'image/jpeg', 1000, 800, 600) from ids where k in ('m1', 'm2', 'm3')$$,
  'تثبيت الوسائط');
set local role authenticated;
select lives_ok(
  $$select public.arrange_listing_media((select v from ids where k = 'l1'),
      array[(select v from ids where k = 'm1'), (select v from ids where k = 'm2'), (select v from ids where k = 'm3')],
      (select v from ids where k = 'm1'))$$,
  'ترتيب الوسائط');
select lives_ok(
  $$select public.submit_listing((select v from ids where k = 'l1'), 'bbbbbbbb-0000-0000-0000-000000000001')$$,
  'إرسال الإعلان');
select is((select count(*)::integer from public.notifications), 0, 'النشر المباشر لا ينشئ إشعارًا للمعلن');
reset role;

-- الإخفاء ينشئ إشعارًا بسببه؛ الرفض لم يعد ممكنًا ولا ينتج إشعارًا
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;
select throws_ok(
  $$select public.admin_reject_listing_version((select v from ids where k = 'l1'),
      gen_random_uuid(), 'x', 'MISSING_INFO', 'أضف صورًا أوضح')$$,
  'P0001', 'INVALID_STATE', 'الرفض لم يعد متاحًا');
select lives_ok(
  $$select public.admin_hide_listing((select v from ids where k = 'l1'), 'BAD_MEDIA', 'أضف صورًا أوضح')$$,
  'إخفاء الإعلان');
reset role;

select is((select count(*)::integer from public.notifications), 1, 'إشعار واحد بعد الإخفاء (لا إشعار للنشر المباشر)');
select is(
  (select event || '|' || category::text || '|' || resource_type || '|' || (payload ->> 'reason_label_ar')
     || '|' || (payload ->> 'reason_text') || '|' || (payload ->> 'title')
   from public.notifications),
  'listing.hidden|LISTING_STATUS|listing|صور غير واضحة أو لا تخص المعروض|أضف صورًا أوضح|ناقة مجاهيم للبيع',
  'الإشعار يحمل الحدث والسبب وعنوان الإعلان');
select is(
  (select recipient_id from public.notifications), '00000000-0000-0000-0000-00000000000a'::uuid,
  'الإشعار لصاحب الإعلان');
select is((select count(*)::integer from public.notification_outbox where status = 'PENDING'), 1,
  'صف في طابور الدفع لكل إشعار');

-- منع التكرار بالمفتاح
select lives_ok(
  $$select private.notify('00000000-0000-0000-0000-00000000000a', 'LISTING_STATUS', 'listing.hidden',
      'listing', 'x', '{}', (select dedupe_key from public.notifications limit 1))$$,
  'إعادة الحدث بالمفتاح نفسه لا تفشل');
select is((select count(*)::integer from public.notifications), 1, 'الحدث المكرر لا ينشئ إشعارًا ثانيًا');
select is((select count(*)::integer from public.notification_outbox), 1, 'ولا صفًا ثانيًا في الطابور');

-- المعلن لا يتجاوز الإخفاء؛ الإدارة تعيد الإظهار فيصله إشعار
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select throws_ok($$select public.start_listing_edit((select v from ids where k = 'l1'))$$,
  'P0001', 'INVALID_STATE', 'لا تعديل لمخفي');
select throws_ok(
  $$select public.submit_listing((select v from ids where k = 'l1'), 'bbbbbbbb-0000-0000-0000-000000000002')$$,
  'P0001', 'INVALID_STATE', 'لا نشر لمخفي');
reset role;
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;
select lives_ok($$select public.admin_unhide_listing((select v from ids where k = 'l1'))$$, 'إعادة إظهار الإعلان');
reset role;
select is(
  (select array_agg(event order by event) from public.notifications),
  array['listing.hidden', 'listing.unhidden'], 'إشعار لإعادة الإظهار إضافة إلى إشعار الإخفاء');

-- صلاحيات القراءة والكتابة
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is((select count(*)::integer from public.notifications), 2, 'المستلم يقرأ إشعاراته');
select throws_ok(
  $$insert into public.notifications (recipient_id, category, event, resource_type, resource_id, dedupe_key)
    values ('00000000-0000-0000-0000-00000000000a', 'ACCOUNT', 'a.b', 'x', 'y', 'k')$$,
  '42501', null, 'لا إدراج مباشر لإشعار');
select throws_ok(
  $$update public.notifications set read_at = now()$$, '42501', null, 'لا تعديل مباشر للإشعارات');
select throws_ok(
  $$select count(*) from public.notification_outbox$$, '42501', null, 'طابور الدفع مغلق أمام العميل');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is((select count(*)::integer from public.notifications), 0, 'مستخدم آخر لا يقرأ إشعارات غيره');
select is(public.mark_notifications_read(), 0, 'مستخدم آخر لا يعلم إشعارات غيره');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is(
  public.mark_notifications_read(array[(select id from public.notifications where event = 'listing.hidden')]),
  1, 'تعليم إشعار محدد كمقروء');
select is(public.mark_notifications_read(), 1, 'تعليم الباقي كمقروء');
select is((select count(*)::integer from public.notifications where read_at is null), 0, 'لا إشعارات غير مقروءة');
select is(public.mark_notifications_read(), 0, 'التعليم مرة أخرى لا يغير شيئًا');
reset role;

-- تعليق الحساب: إشعار واحد للتعليق دون إشعار إخفاء لكل إعلان
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;
select lives_ok(
  $$select public.admin_suspend_account('00000000-0000-0000-0000-00000000000a', 'OTHER', 'سبب التعليق')$$,
  'تعليق الحساب');
reset role;
select is((select status::text from public.listings where id = (select v from ids where k = 'l1')), 'HIDDEN',
  'التعليق أخفى الإعلان المنشور');
select is(
  (select count(*)::integer from public.notifications where event = 'account.suspended'
     and category = 'ACCOUNT' and payload ->> 'reason_text' = 'سبب التعليق'),
  1, 'إشعار تعليق الحساب بسببه');
select is((select count(*)::integer from public.notifications where event = 'listing.hidden'), 1,
  'لا إشعار إخفاء إضافي للإعلانات المخفاة بسبب التعليق');

select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;
select lives_ok(
  $$select public.admin_reactivate_account('00000000-0000-0000-0000-00000000000a')$$, 'تفعيل الحساب');
select lives_ok(
  $$select public.admin_unhide_listing((select v from ids where k = 'l1'), 'ملاحظة داخلية')$$, 'إعادة إظهار الإعلان');
reset role;
select is((select count(*)::integer from public.notifications where event = 'account.reactivated'), 1,
  'إشعار تفعيل الحساب');
select is(
  (select count(*)::integer from public.notifications
    where event = 'listing.unhidden' and payload ->> 'reason_text' is not null),
  0, 'ملاحظة إعادة الإظهار الداخلية لا تصل المعلن');
select is(
  (select count(*)::integer from public.notifications) ,
  (select count(*)::integer from public.notification_outbox), 'صف طابور لكل إشعار');

-- الزائر
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok($$select count(*) from public.notifications$$, '42501', null, 'الزائر لا يقرأ الإشعارات');
reset role;

select * from finish();
rollback;
