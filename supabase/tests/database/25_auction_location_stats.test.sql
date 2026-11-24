-- MOBILE-BE-AUCTION-GEO-20261124 — موقع المزاد الدقيق، وعدّاد المشاهدات، وعدد الإعجابات
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002');
update public.profiles set display_name = 'معلن الاختبار', region_id = 1
  where id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b');
insert into public.policy_consents (user_id, document_id)
  select u.id, d.id from private.current_policy_documents() d,
    (values ('00000000-0000-0000-0000-00000000000a'::uuid), ('00000000-0000-0000-0000-00000000000b'::uuid)) u(id);

create function pg_temp.login(p_user uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated, anon;

-- مسودة مزاد مكتملة بثلاث صور، دون إحداثيات.
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
insert into ids values ('a1', (public.create_listing_draft(gen_random_uuid()) #>> '{listing,id}')::uuid);
select public.save_listing_draft((select v from ids where k = 'a1'), jsonb_build_object(
  'title', 'مزاد ركاب مفتوح', 'description', 'وصف كاف لاجتياز الحد الأدنى للطول المطلوب',
  'breed_id', (select id from public.breeds where not requires_note order by id limit 1),
  'sex', 'MALE', 'age_months', 36, 'region_id', 1,
  'city_id', (select id from public.cities where region_id = 1 order by id limit 1),
  'health_notes', 'لا توجد عيوب معروفة', 'owner_declaration', true,
  'offer_type', 'IN_PERSON_AUCTION', 'auction_region_id', 1,
  'auction_city_id', (select id from public.cities where region_id = 1 order by id limit 1),
  'auction_venue', 'ساحة المزاد', 'auction_starts_at', '2099-01-01T16:00:00+03:00',
  'contact_phone', '0500000009'));
do $$
declare
  v_listing uuid := (select v from ids where k = 'a1');
  v_media uuid[] := array[]::uuid[];
  v_m uuid;
begin
  for i in 1..3 loop
    v_m := (public.add_listing_media(v_listing, 'IMAGE', 'image/jpeg', 1000) ->> 'media_id')::uuid;
    perform public.finalize_listing_media(v_m, 'image/jpeg', 1000, 800, 600);
    v_media := v_media || v_m;
  end loop;
  perform public.arrange_listing_media(v_listing, v_media, v_media[1]);
end;
$$;

------------------------------------------------------------------------------
-- الإحداثيات: إلزام عند الإرسال، ونطاق، وزوج
------------------------------------------------------------------------------
select throws_ok(
  $$select public.submit_listing((select v from ids where k = 'a1'), gen_random_uuid())$$,
  'P0001', null, 'مزاد بلا إحداثيات لا يرسل');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'a1'), '{"auction_lat": 91, "auction_lng": 46}')$$,
  'P0001', null, 'خط عرض خارج النطاق يرفض');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'a1'), '{"auction_lat": 24.7, "auction_lng": 181}')$$,
  'P0001', null, 'خط طول خارج النطاق يرفض');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'a1'), '{"auction_lat": "24.7", "auction_lng": 46.6}')$$,
  'P0001', null, 'النص ليس إحداثيًا');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'a1'), '{"auction_lat": 24.7}')$$,
  'P0001', null, 'إحداثي واحد دون الآخر يرفض');
select is(
  public.save_listing_draft((select v from ids where k = 'a1'),
    '{"auction_lat": 24.7135521, "auction_lng": 46.675297}') #>> '{version,auction_lat}',
  '24.713552', 'يحفظ خط العرض بست منازل');

-- التبديل إلى سعر محدد يمسح الإحداثيات
select is(
  public.save_listing_draft((select v from ids where k = 'a1'),
    '{"offer_type": "FIXED_PRICE", "price": 5000}') #>> '{version,auction_lng}',
  null, 'السعر المحدد يمسح الإحداثيات');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'a1'),
    '{"offer_type": "FIXED_PRICE", "auction_lat": 24.7, "auction_lng": 46.6}')$$,
  'P0001', null, 'إحداثيات مع سعر محدد ترفض');
select is(
  public.save_listing_draft((select v from ids where k = 'a1'), jsonb_build_object(
    'offer_type', 'IN_PERSON_AUCTION', 'auction_region_id', 1,
    'auction_city_id', (select id from public.cities where region_id = 1 order by id limit 1),
    'auction_venue', 'ساحة المزاد', 'auction_starts_at', '2099-01-01T16:00:00+03:00',
    'auction_lat', 24.713552, 'auction_lng', 46.675297)) #>> '{version,auction_lng}',
  '46.675297', 'العودة إلى المزاد مع الإحداثيات');

select is(public.submit_listing((select v from ids where k = 'a1'), gen_random_uuid()) #>> '{listing,status}',
  'PUBLISHED', 'المزاد بإحداثياته ينشر');
reset role;

------------------------------------------------------------------------------
-- العرض العام والعدّادات
------------------------------------------------------------------------------
select set_config('request.jwt.claims', '', true);
set local role anon;
select is(
  (select (auction_lat::text || ',' || auction_lng::text) from public.public_listing_cards
    where listing_id = (select v from ids where k = 'a1')),
  '24.713552,46.675297', 'البطاقة العامة تحمل الإحداثيات');
select is(
  (select (view_count::text || ',' || favorite_count::text) from public.public_listing_details
    where listing_id = (select v from ids where k = 'a1')),
  '0,0', 'العدّادات تبدأ صفرًا');
select is(
  (public.search_listings() -> 'items' -> 0 ->> 'auction_lat'), '24.713552', 'search_listings يعيد خط العرض');
select is(
  (public.search_listings() -> 'items' -> 0 ->> 'view_count'), '0', 'search_listings يعيد المشاهدات');
select is(public.record_listing_view((select v from ids where k = 'a1')), 0, 'زائر بلا معرف جهاز لا يحسب');
select is(public.record_listing_view((select v from ids where k = 'a1'), '11111111-1111-1111-1111-111111111111'), 1, 'الجهاز يسجل مشاهدة');
select is(public.record_listing_view((select v from ids where k = 'a1'), '11111111-1111-1111-1111-111111111111'), 1, 'والمشاهدة المكررة من الجهاز نفسه لا تزيد');
select is(public.record_listing_view((select v from ids where k = 'a1'), '22222222-2222-2222-2222-222222222222'), 2, 'جهاز آخر يزيد');
select throws_ok(
  $$select public.record_listing_view(gen_random_uuid())$$, 'P0001', null, 'إعلان غير موجود NOT_FOUND');
reset role;

-- مشاهدة المعلن لا تحسب
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is(public.record_listing_view((select v from ids where k = 'a1'), '33333333-3333-3333-3333-333333333333'), 2, 'المعلن لا يزيد العدّاد');

reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is(public.record_listing_view((select v from ids where k = 'a1')), 3, 'مستخدم داخل يحسب مرة');
select is(public.record_listing_view((select v from ids where k = 'a1')), 3, 'ولا يتكرر');
select is((select view_count from public.my_listings where listing_id = (select v from ids where k = 'a1')), null, 'غير المالك لا يرى إعلانات غيره');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is((select view_count from public.my_listings where listing_id = (select v from ids where k = 'a1')), 3, 'إعلاناتي تعرض المشاهدات');
reset role;

-- الإعجابات
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select public.add_favorite((select v from ids where k = 'a1'));
select public.add_favorite((select v from ids where k = 'a1'));
select is(
  (select favorite_count from public.public_listing_cards where listing_id = (select v from ids where k = 'a1')),
  1, 'الإضافة المكررة لا تزيد العدد');
select is(
  (select favorite_count from public.my_favorites where listing_id = (select v from ids where k = 'a1')),
  1, 'my_favorites يحمل العدد');
select public.remove_favorite((select v from ids where k = 'a1'));
select public.remove_favorite((select v from ids where k = 'a1'));
select is(
  (select favorite_count from public.public_listing_cards where listing_id = (select v from ids where k = 'a1')),
  0, 'الإزالة تنقص العدد ولا تنزل عن صفر');
reset role;

-- لا وصول مباشر لجدول العدّادات
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select throws_ok($$select * from public.listing_stats$$, '42501', null, 'لا قراءة مباشرة للعدّادات');
reset role;

------------------------------------------------------------------------------
-- تعديل المنشور ينسخ الإحداثيات
------------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is(
  public.start_listing_edit((select v from ids where k = 'a1')) #>> '{version,auction_lat}',
  '24.713552', 'نسخة التعديل تحمل الإحداثيات');
select is(
  public.save_listing_draft((select v from ids where k = 'a1'), '{"auction_lat": null, "auction_lng": null}')
    #>> '{version,auction_lat}',
  null, 'المسح الصريح للمسودة');
select throws_ok(
  $$select public.submit_listing((select v from ids where k = 'a1'), gen_random_uuid())$$,
  'P0001', null, 'التعديل بلا إحداثيات لا ينشر');
reset role;

select * from finish();
rollback;
