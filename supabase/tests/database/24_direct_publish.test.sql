-- MOBILE-BE-DIRECT-PUBLISH-20261124 — TEAM-DEC-013: النشر المباشر دون اعتماد إداري
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

-- a معلن، b متابع، s مدير.
insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002');
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test');
update public.profiles set display_name = 'معلن الاختبار', region_id = 1
  where id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b');
insert into public.policy_consents (user_id, document_id)
  select u.id, d.id from private.current_policy_documents() d,
    (values ('00000000-0000-0000-0000-00000000000a'::uuid), ('00000000-0000-0000-0000-00000000000b'::uuid)) u(id);
select private.bootstrap_first_admin('00000000-0000-0000-0000-0000000000a1');

create function pg_temp.login(p_user uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

create temp table ids (k text primary key, v uuid);
create temp table vals (k text primary key, v text);
grant all on ids, vals to authenticated, anon;

-- مسودة مكتملة بثلاث صور؛ p_submit يرسلها فتنشر. تعيد معرف الإعلان في ids.
create function pg_temp.mk(p_key text, p_title text, p_submit boolean)
returns void language plpgsql as $$
declare
  v_listing uuid;
  v_media uuid[] := array[]::uuid[];
  v_m uuid;
begin
  perform pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
  v_listing := (public.create_listing_draft(gen_random_uuid()) #>> '{listing,id}')::uuid;
  perform public.save_listing_draft(v_listing, jsonb_build_object(
    'title', p_title, 'description', 'وصف كاف لاجتياز الحد الأدنى للطول المطلوب',
    'breed_id', (select id from public.breeds where not requires_note order by id limit 1),
    'sex', 'FEMALE', 'age_months', 48, 'region_id', 1,
    'city_id', (select id from public.cities where region_id = 1 order by id limit 1),
    'health_notes', 'لا توجد عيوب معروفة', 'owner_declaration', true,
    'offer_type', 'FIXED_PRICE', 'price', 25000, 'contact_phone', '0500000009'));
  insert into ids values (p_key, v_listing);
  for i in 1..3 loop
    v_m := (public.add_listing_media(v_listing, 'IMAGE', 'image/jpeg', 1000) ->> 'media_id')::uuid;
    perform public.finalize_listing_media(v_m, 'image/jpeg', 1000, 800, 600);
    v_media := v_media || v_m;
  end loop;
  perform public.arrange_listing_media(v_listing, v_media, v_media[1]);
  if p_submit then
    perform public.submit_listing(v_listing, gen_random_uuid());
  end if;
end;
$$;

create function pg_temp.keys(p jsonb) returns text language sql as $$
  select coalesce(string_agg(k, ',' order by n), '') from (
    select (select i.k from ids i where i.v = (e ->> 'listing_id')::uuid) as k, n
    from jsonb_array_elements(p -> 'items') with ordinality t(e, n)) s;
$$;
grant execute on function pg_temp.keys(jsonb) to anon, authenticated;

-- b يتابع المعلن مسبقًا
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select public.follow_seller('00000000-0000-0000-0000-00000000000a');
reset role;

------------------------------------------------------------------------------
-- نشر مباشر لمسودة
------------------------------------------------------------------------------
select pg_temp.mk('l1', 'ناقة مجاهيم للبيع', false);
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is(
  (select count(*)::integer from public.my_listings where status = 'DRAFT'), 1, 'قبل الإرسال مسودة');
create temp table res (j jsonb);
grant all on res to authenticated;
insert into res select public.submit_listing((select v from ids where k = 'l1'), 'bbbbbbbb-0000-0000-0000-000000000001');
select is((select j #>> '{listing,status}' from res), 'PUBLISHED', 'submit_listing يعيد PUBLISHED');
select is((select j #>> '{version,status}' from res), 'APPROVED', 'النسخة المعادة APPROVED');
select ok((select (j #>> '{listing,published_version_id}') = (j #>> '{listing,current_version_id}')
    and (j #>> '{listing,has_draft}')::boolean = false
    and j #>> '{listing,first_published_at}' is not null
    and j #>> '{listing,last_published_at}' is not null
    and j #>> '{listing,next_bump_at}' is not null
    and j #>> '{version,decided_at}' is not null from res),
  'مؤشرات النشر في رد الإرسال');
select lives_ok(
  $$select public.submit_listing((select v from ids where k = 'l1'), 'bbbbbbbb-0000-0000-0000-000000000001')$$,
  'إعادة الطلب بالمعرف نفسه آمنة');
reset role;

insert into vals select 'first_pub', first_published_at::text from public.listings where id = (select v from ids where k = 'l1');
insert into vals select 'vis', visibility_updated_at::text from public.listings where id = (select v from ids where k = 'l1');
insert into vals select 'last_pub', last_published_at::text from public.listings where id = (select v from ids where k = 'l1');
update public.listings set first_published_at = first_published_at - interval '2 hours',
    visibility_updated_at = visibility_updated_at - interval '2 hours',
    last_published_at = last_published_at - interval '2 hours'
  where id = (select v from ids where k = 'l1');
update vals set v = (select first_published_at::text from public.listings where id = (select v from ids where k = 'l1')) where k = 'first_pub';
update vals set v = (select visibility_updated_at::text from public.listings where id = (select v from ids where k = 'l1')) where k = 'vis';
update vals set v = (select last_published_at::text from public.listings where id = (select v from ids where k = 'l1')) where k = 'last_pub';

select set_config('request.jwt.claims', '', true);
set local role anon;
select is((select count(*)::integer from public.public_listing_cards), 1, 'الإعلان ظاهر للعامة فور الإرسال');
select is((select count(*)::integer from public.public_listing_media), 3, 'ووسائطه');
select is(pg_temp.keys(public.search_listings()), 'l1', 'ويظهر في البحث');
reset role;

select is((select decision::text || ':' || reason_text from public.reviews), 'APPROVED:AUTO_PUBLISH', 'حدث النشر التلقائي في السجل');
select is((select count(*)::integer from public.audit_log where action like 'listing.%'), 0, 'لا سجل إجراء موظف');

-- لا إشعار «اعتمد» للمعلن، وتنبيه أول نشر للمتابع مرة واحدة
select is((select count(*)::integer from public.notifications where recipient_id = '00000000-0000-0000-0000-00000000000a'), 0,
  'لا إشعار للمعلن عن النشر المباشر');
select is(
  (select count(*)::integer from public.notifications
    where event = 'follow.new_listing' and recipient_id = '00000000-0000-0000-0000-00000000000b'),
  1, 'المتابع يُنبَّه عند النشر المباشر الأول');

-- المالك لا يقرأ سجل reviews
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is((select count(*)::integer from public.reviews), 0, 'المعلن لا يقرأ سجل القرارات');
reset role;

------------------------------------------------------------------------------
-- تعديل المنشور: يسري فورًا دون اختفاء، ولا يرفع الترتيب
------------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is(public.start_listing_edit((select v from ids where k = 'l1')) #>> '{listing,status}', 'PUBLISHED', 'يبقى منشورًا أثناء التعديل');
select lives_ok(
  $$select public.save_listing_draft((select v from ids where k = 'l1'), '{"title": "ناقة مجاهيم معدلة", "price": 30000}')$$,
  'تعديل المسودة الخاصة');
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
select is((select title from public.public_listing_cards), 'ناقة مجاهيم للبيع', 'العامة ترى النص السابق أثناء التحرير');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is(
  public.submit_listing((select v from ids where k = 'l1'), 'bbbbbbbb-0000-0000-0000-000000000002') #>> '{listing,status}',
  'PUBLISHED', 'إرسال التعديل يعيد PUBLISHED');
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
select is((select count(*)::integer from public.public_listing_cards), 1, 'لا يختفي الإعلان عند التعديل');
select is((select title from public.public_listing_cards), 'ناقة مجاهيم معدلة', 'التعديل ظاهر فورًا');
select is((select price from public.public_listing_details), 30000.00::numeric, 'السعر الجديد ظاهر فورًا');
reset role;
select is(
  (select l.published_version_id from public.listings l where l.id = (select v from ids where k = 'l1')),
  (select v.id from public.listing_versions v where v.version_no = 2),
  'النسخة الجديدة هي المنشورة');
select ok(
  (select l.first_published_at::text = (select v from vals where k = 'first_pub')
     and l.visibility_updated_at::text = (select v from vals where k = 'vis')
     and l.last_published_at::text = (select v from vals where k = 'last_pub')
     and l.published_version_at > l.first_published_at
   from public.listings l where l.id = (select v from ids where k = 'l1')),
  'التعديل لا يرفع الترتيب ولا يغير first/last_published_at');
select is(
  (select count(*)::integer from public.notifications where event = 'follow.new_listing'), 1,
  'التعديل لا يطلق تنبيه إعلان جديد');
select is((select count(*)::integer from public.listing_versions v where v.status = 'APPROVED'), 2, 'نسختان معتمدتان');

------------------------------------------------------------------------------
-- حد 5 إعلانات جديدة كل 24 ساعة
------------------------------------------------------------------------------
select pg_temp.mk('x2', 'إعلان اثنين للاختبار', true);
select pg_temp.mk('x3', 'إعلان ثلاثة للاختبار', true);
select pg_temp.mk('x4', 'إعلان أربعة للاختبار', true);
select pg_temp.mk('x5', 'إعلان خمسة للاختبار', true);
select pg_temp.mk('x6', 'إعلان ستة للاختبار', false);
set local role authenticated;
select throws_ok(
  $$select public.submit_listing((select v from ids where k = 'x6'), gen_random_uuid())$$,
  'P0001', 'RATE_LIMITED', 'السادس خلال 24 ساعة مرفوض');
select is((select status::text from public.my_listings where listing_id = (select v from ids where k = 'x6')),
  'DRAFT', 'المرفوض بالحد يبقى مسودة (ذري)');
-- تعديل منشور لا يحسب من الحد
select lives_ok($$select public.start_listing_edit((select v from ids where k = 'l1'))$$, 'بدء تعديل بعد بلوغ الحد');
select lives_ok($$select public.save_listing_draft((select v from ids where k = 'l1'), '{"price": 31000}')$$, 'حفظ');
select is(
  public.submit_listing((select v from ids where k = 'l1'), gen_random_uuid()) #>> '{listing,status}',
  'PUBLISHED', 'تعديل المنشور لا يخضع للحد اليومي');
reset role;
select is((select count(*)::integer from public.listings where status = 'PUBLISHED'), 5, 'خمسة منشورة');

-- نقص الاكتمال يمنع النشر
select pg_temp.mk('inc', 'إعلان ناقص للاختبار', false);
update public.listing_versions set description = null
  where listing_id = (select v from ids where k = 'inc');
set local role authenticated;
select throws_ok(
  $$select public.submit_listing((select v from ids where k = 'inc'), gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', 'لا نشر لإعلان ناقص');
reset role;
select is((select status::text from public.listings where id = (select v from ids where k = 'inc')), 'DRAFT', 'يبقى مسودة');

------------------------------------------------------------------------------
-- الأرشيف والمرفوض القديم ينشران مباشرة بعد التعديل
------------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is(public.archive_listing((select v from ids where k = 'x2')) #>> '{listing,status}', 'ARCHIVED', 'أرشفة');
select is(public.start_listing_edit((select v from ids where k = 'x2')) #>> '{listing,status}', 'DRAFT', 'المؤرشف يعود مسودة');
select is(
  public.submit_listing((select v from ids where k = 'x2'), gen_random_uuid()) #>> '{listing,status}',
  'PUBLISHED', 'المؤرشف المعدل ينشر مباشرة');
reset role;

-- REJECTED قديم (بيانات سابقة)
update public.listings set status = 'REJECTED' where id = (select v from ids where k = 'x3');
set local role authenticated;
select is(public.start_listing_edit((select v from ids where k = 'x3')) #>> '{listing,status}', 'DRAFT', 'المرفوض القديم يعود مسودة');
select is(
  public.submit_listing((select v from ids where k = 'x3'), gen_random_uuid()) #>> '{listing,status}',
  'PUBLISHED', 'المرفوض القديم المعدل ينشر مباشرة');
reset role;

------------------------------------------------------------------------------
-- الإخفاء الإداري
------------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;
select throws_ok(
  $$select public.admin_hide_listing((select v from ids where k = 'l1'), null)$$,
  'P0001', 'REASON_REQUIRED', 'الإخفاء يستلزم سببًا');
select is(jsonb_array_length(public.admin_list_listings('PUBLISHED')), 5, 'قائمة الإدارة: خمسة منشورة');
select is(public.admin_list_listings('PUBLISHED') #>> '{0,title}' is not null, true, 'عنوان في القائمة');
select is(
  public.admin_hide_listing((select v from ids where k = 'l1'), 'BAD_MEDIA', 'صور غير مناسبة') ->> 'status',
  'HIDDEN', 'إخفاء منشور');
select is(jsonb_array_length(public.admin_list_listings('HIDDEN')), 1, 'التصفية بالمخفي');
select is(public.admin_list_listings('HIDDEN') #>> '{0,hide_reason_code}', 'BAD_MEDIA', 'سبب الإخفاء في القائمة');
select is(public.admin_list_listings('HIDDEN') #>> '{0,title}', 'ناقة مجاهيم معدلة', 'المخفي يعرض نسخته المنشورة');
select is(jsonb_array_length(public.admin_list_listings('PUBLISHED')), 4, 'أربعة منشورة بعد الإخفاء');
select is(jsonb_array_length(public.admin_list_listings(null, 'اثنين')), 1, 'البحث بالعنوان');
select is(
  jsonb_array_length(public.admin_get_listing_review((select v from ids where k = 'l1')) -> 'media'), 3,
  'تفاصيل الإعلان المخفي للإدارة');
reset role;

select set_config('request.jwt.claims', '', true);
set local role anon;
select is(
  (select count(*)::integer from public.public_listing_cards where listing_id = (select v from ids where k = 'l1'))
  + (select count(*)::integer from public.public_listing_details where listing_id = (select v from ids where k = 'l1'))
  + (select count(*)::integer from public.public_listing_media where listing_id = (select v from ids where k = 'l1')),
  0, 'المخفي يختفي من الـviews العامة');
select is(pg_temp.keys(public.search_listings()) like '%l1%', false, 'والمخفي خارج البحث');
reset role;

-- المعلن لا يتجاوز الإخفاء
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select throws_ok(
  $$select public.submit_listing((select v from ids where k = 'l1'), gen_random_uuid())$$,
  'P0001', 'INVALID_STATE', 'المخفي لا ينشره المعلن بالإرسال');
select throws_ok(
  $$select public.start_listing_edit((select v from ids where k = 'l1'))$$,
  'P0001', 'INVALID_STATE', 'ولا يعدله');
select throws_ok(
  $$select public.archive_listing((select v from ids where k = 'l1'))$$,
  'P0001', 'INVALID_STATE', 'ولا يؤرشفه');
select is(
  (select reason_code || ':' || reason_text from public.my_listings where listing_id = (select v from ids where k = 'l1')),
  'BAD_MEDIA:صور غير مناسبة', 'سبب الإخفاء يظهر لصاحبه');
reset role;
select is(
  (select payload ->> 'reason_text' from public.notifications
   where event = 'listing.hidden' and recipient_id = '00000000-0000-0000-0000-00000000000a'),
  'صور غير مناسبة', 'إشعار الإخفاء بسببه');

select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;
select is(public.admin_unhide_listing((select v from ids where k = 'l1'), 'تم التصحيح') ->> 'status', 'PUBLISHED', 'إعادة الإظهار');
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
select is(pg_temp.keys(public.search_listings()) like '%l1%', true, 'يعود للبحث');
reset role;
select is(
  (select count(*)::integer from public.notifications
    where event = 'follow.new_listing' and recipient_id = '00000000-0000-0000-0000-00000000000b'
      and resource_id = (select v::text from ids where k = 'l1')),
  1, 'إعادة الإظهار لا تعيد تنبيه المتابعين');

------------------------------------------------------------------------------
-- الاعتماد والرفض مهملان
------------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;
select throws_ok(
  $$select public.admin_approve_listing_version((select v from ids where k = 'l1'), gen_random_uuid(), 'x')$$,
  'P0001', 'INVALID_STATE', 'الاعتماد يرفع INVALID_STATE');
select throws_ok(
  $$select public.admin_reject_listing_version((select v from ids where k = 'l1'), gen_random_uuid(), 'x', 'MISSING_INFO')$$,
  'P0001', 'INVALID_STATE', 'الرفض يرفع INVALID_STATE');
select throws_ok(
  $$select public.admin_approve_listing_version(gen_random_uuid(), gen_random_uuid(), 'x')$$,
  'P0001', 'NOT_FOUND', 'إعلان غير موجود');
select is(jsonb_array_length(public.admin_review_queue()), 0, 'قائمة المراجعة فارغة');
select is(public.admin_stats() #>> '{listings,under_review_now}', '0', 'under_review_now صفر');
reset role;

------------------------------------------------------------------------------
-- تحويل UNDER_REVIEW القديم (المنطق نفسه الذي يشغله الترحيل)
------------------------------------------------------------------------------
set constraints all immediate;
alter table public.listings drop constraint listings_no_under_review;
insert into public.listings (id, owner_id, create_request_id, status, first_submitted_at) values
  ('10000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-00000000000a', gen_random_uuid(), 'DRAFT', now() - interval '2 days');
insert into public.listing_versions (
    id, listing_id, version_no, status, title, description, breed_id, sex, age_months, region_id, city_id,
    health_notes, owner_declaration_at, offer_type, price, contact_phone, contact_consent_at,
    settings_version, content_hash, submitted_at)
  values (
    '20000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-000000000009', 1, 'SUBMITTED',
    'قيد مراجعة قديم', 'وصف كاف لاجتياز الحد الأدنى للطول',
    (select id from public.breeds order by id limit 1), 'MALE', 36, 1,
    (select id from public.cities where region_id = 1 order by id limit 1),
    'سليم', now(), 'FIXED_PRICE', 9000, '+966500000009', now(), 1, 'hash-legacy', now() - interval '2 days');
update public.listings set status = 'UNDER_REVIEW', current_version_id = '20000000-0000-0000-0000-000000000009'
  where id = '10000000-0000-0000-0000-000000000009';
update public.listing_versions set status = 'APPROVED', decided_at = now()
  where id = '20000000-0000-0000-0000-000000000009';
select private.publish_listing_version('10000000-0000-0000-0000-000000000009', '20000000-0000-0000-0000-000000000009');

select is((select status::text from public.listings where id = '10000000-0000-0000-0000-000000000009'), 'PUBLISHED',
  'القديم قيد المراجعة يصير منشورًا');
select ok(
  (select published_version_id = '20000000-0000-0000-0000-000000000009'
     and first_published_at is not null and last_published_at is not null and visibility_updated_at is not null
   from public.listings where id = '10000000-0000-0000-0000-000000000009'),
  'مؤشرات النشر للقديم');
select set_config('request.jwt.claims', '', true);
set local role anon;
select is(
  (select count(*)::integer from public.public_listing_cards where listing_id = '10000000-0000-0000-0000-000000000009'),
  1, 'القديم المحول ظاهر للعامة');
reset role;
set constraints all immediate;
alter table public.listings add constraint listings_no_under_review check (status <> 'UNDER_REVIEW');
select throws_ok(
  $$update public.listings set status = 'UNDER_REVIEW' where id = (select v from ids where k = 'l1')$$,
  '23514', null, 'القيد يمنع إنتاج UNDER_REVIEW بعد التحويل');

select * from finish();
rollback;
