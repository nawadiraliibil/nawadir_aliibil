-- MOBILE-BE-109 — الترحيل 12 public_surface
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

-- a معلن مكتمل الملف، b مستخدم بلا اسم عرض، s مدير.
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

-- أعمدة الـviews جزء من العقد
select columns_are('public', 'public_profiles', array[
  'id', 'display_name', 'region_id', 'region_name_ar', 'joined_at', 'published_listings_count',
  'rating_avg', 'rating_count']);
select columns_are('public', 'public_listing_cards', array[
  'listing_id', 'owner_id', 'owner_display_name', 'title', 'offer_type', 'price',
  'auction_starts_at', 'auction_passed', 'breed_id', 'breed_name_ar', 'breed_note', 'sex',
  'age_months', 'region_id', 'region_name_ar', 'city_id', 'city_name_ar',
  'cover_bucket', 'cover_path', 'first_published_at', 'visibility_updated_at', 'public_ref']);
select columns_are('public', 'public_listing_details', array[
  'listing_id', 'owner_id', 'owner_display_name', 'owner_joined_at', 'title', 'description',
  'offer_type', 'price', 'auction_region_id', 'auction_region_name_ar', 'auction_city_id',
  'auction_city_name_ar', 'auction_venue', 'auction_starts_at', 'auction_passed',
  'breed_id', 'breed_name_ar', 'breed_note', 'sex', 'age_months', 'color', 'health_notes',
  'region_id', 'region_name_ar', 'city_id', 'city_name_ar',
  'contact_phone', 'contact_call_enabled', 'contact_whatsapp_enabled',
  'first_published_at', 'published_version_at', 'visibility_updated_at', 'public_ref', 'comments_closed']);
select columns_are('public', 'public_listing_media', array[
  'listing_id', 'media_id', 'kind', 'bucket', 'object_path', 'mime_type',
  'width', 'height', 'duration_seconds', 'sort_order', 'is_cover']);
select columns_are('public', 'my_listings', array[
  'listing_id', 'status', 'current_version_id', 'published_version_id', 'has_draft',
  'version_no', 'version_status', 'title', 'offer_type', 'price', 'auction_starts_at',
  'auction_passed', 'cover_bucket', 'cover_path', 'reason_code', 'reason_label_ar',
  'reason_text', 'reason_decided_at', 'first_submitted_at', 'first_published_at',
  'last_published_at', 'last_bumped_at', 'next_bump_at', 'status_changed_at',
  'created_at', 'updated_at']);

-- المعلن: إعلان مرسل ومسودة ثانية
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
insert into ids select 'l1', (public.create_listing_draft('aaaaaaaa-0000-0000-0000-000000000001') #>> '{listing,id}')::uuid;
insert into ids select 'l2', (public.create_listing_draft('aaaaaaaa-0000-0000-0000-000000000002') #>> '{listing,id}')::uuid;
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
select lives_ok(
  $$select public.save_listing_draft((select v from ids where k = 'l2'), '{"title": "مسودة خاصة لا تظهر للعامة"}')$$,
  'حفظ مسودة ثانية');
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
reset role;

-- قبل الاعتماد: لا شيء للعامة
select set_config('request.jwt.claims', '', true);
set local role anon;
select is((select count(*)::integer from public.public_listing_cards), 0, 'قيد المراجعة لا يظهر للعامة');
select is((select count(*)::integer from public.public_listing_media), 0, 'وسائط قيد المراجعة لا تظهر');
reset role;

-- الاعتماد
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;
insert into ids select 'v1', (public.admin_get_listing_review((select v from ids where k = 'l1')) #>> '{version,id}')::uuid;
insert into vals select 'h1', public.admin_get_listing_review((select v from ids where k = 'l1')) #>> '{version,content_hash}';
select lives_ok(
  $$select public.admin_approve_listing_version((select v from ids where k = 'l1'),
      (select v from ids where k = 'v1'), (select v from vals where k = 'h1'))$$,
  'اعتماد الإعلان');
reset role;

-- الزائر
select set_config('request.jwt.claims', '', true);
set local role anon;
select is((select count(*)::integer from public.public_listing_cards), 1, 'الزائر يرى المنشور فقط');
select is((select title from public.public_listing_cards), 'ناقة مجاهيم للبيع', 'البطاقة من النسخة المعتمدة');
select isnt((select cover_path from public.public_listing_cards), null, 'البطاقة تحمل مسار الغلاف');
select is((select region_name_ar from public.public_listing_cards), 'الرياض', 'اسم المنطقة في البطاقة');
select is((select contact_phone from public.public_listing_details), '+966500000009', 'التفاصيل تعرض رقم التواصل المنشور');
select is((select count(*)::integer from public.public_listing_media), 3, 'وسائط المنشور الثلاث');
select is(
  (select count(*)::integer from public.public_listing_details where listing_id = (select v from ids where k = 'l2')),
  0, 'طلب تفاصيل مسودة مباشرة لا يعيد شيئًا');
select is((select published_listings_count from public.public_profiles
  where id = '00000000-0000-0000-0000-00000000000a'), 1, 'الملف العام يعد المنشور');
select is((select count(*)::integer from public.public_profiles
  where id = '00000000-0000-0000-0000-00000000000b'), 0, 'حساب بلا اسم عرض لا ملف عام له');
select throws_ok($$select count(*) from public.my_listings$$, '42501', null, 'الزائر لا يقرأ «إعلاناتي»');
select throws_ok($$select count(*) from public.listing_versions$$, '42501', null, 'الزائر لا يقرأ جدول النسخ');
select throws_ok(
  $$update public.public_listing_cards set title = 'x'$$, '55000', null, 'الـviews غير قابلة للكتابة');
reset role;

-- «إعلاناتي»
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is((select count(*)::integer from public.my_listings), 2, 'المعلن يرى إعلانيه');
select is(
  (select status::text from public.my_listings where listing_id = (select v from ids where k = 'l2')),
  'DRAFT', 'المسودة ظاهرة لصاحبها');
select isnt(
  (select next_bump_at from public.my_listings where listing_id = (select v from ids where k = 'l1')),
  null, 'موعد التجديد التالي للمنشور');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is((select count(*)::integer from public.my_listings), 0, 'مستخدم آخر لا يرى إعلانات غيره');
select is((select count(*)::integer from public.public_listing_cards), 1, 'المستخدم يرى المنشور كالزائر');
reset role;

-- الإخفاء يسري على القراءة العامة فورًا، وسببه يظهر لصاحبه
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;
select lives_ok(
  $$select public.admin_hide_listing((select v from ids where k = 'l1'), 'OTHER', 'سبب يراه المعلن')$$,
  'إخفاء الإعلان');
reset role;

select set_config('request.jwt.claims', '', true);
set local role anon;
select is(
  (select count(*)::integer from public.public_listing_cards)
  + (select count(*)::integer from public.public_listing_details)
  + (select count(*)::integer from public.public_listing_media),
  0, 'المخفي يختفي من البطاقات والتفاصيل والوسائط');
select is((select published_listings_count from public.public_profiles
  where id = '00000000-0000-0000-0000-00000000000a'), 0, 'عدد المنشور في الملف العام ينقص');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is(
  (select reason_code || ':' || reason_label_ar || ':' || reason_text from public.my_listings
    where listing_id = (select v from ids where k = 'l1')),
  'OTHER:أخرى:سبب يراه المعلن', 'سبب الإخفاء يظهر لصاحب الإعلان');
reset role;

select * from finish();
rollback;
