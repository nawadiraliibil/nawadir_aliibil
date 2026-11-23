-- MOBILE-BE-304 — الترحيل 19 follows
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

-- a معلن، b يتابع المعلن ويحفظ بحثًا مطابقًا، c يحفظ بحثًا مطابقًا فقط،
-- e يحفظ بحثًا غير مطابق، s مدير.
insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002'),
  ('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000003'),
  ('00000000-0000-0000-0000-00000000000e', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000005');
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test');
update public.profiles set display_name = 'معلن الاختبار', region_id = 1 where id = '00000000-0000-0000-0000-00000000000a';
update public.profiles set display_name = 'متابع', region_id = 1 where id = '00000000-0000-0000-0000-00000000000b';
update public.profiles set display_name = 'باحث', region_id = 1 where id = '00000000-0000-0000-0000-00000000000c';
update public.profiles set display_name = 'آخر', region_id = 1 where id = '00000000-0000-0000-0000-00000000000e';
insert into public.policy_consents (user_id, document_id)
  select u.id, d.id from private.current_policy_documents() d,
    (values ('00000000-0000-0000-0000-00000000000a'::uuid),
            ('00000000-0000-0000-0000-00000000000b'::uuid),
            ('00000000-0000-0000-0000-00000000000c'::uuid),
            ('00000000-0000-0000-0000-00000000000e'::uuid)) u(id);
select private.bootstrap_first_admin('00000000-0000-0000-0000-0000000000a1');

create function pg_temp.login(p_user uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated, anon;

create function pg_temp.publish(p_key text, p_title text, p_region integer) returns void language plpgsql as $$
declare
  v_listing uuid;
  v_media uuid[] := array[]::uuid[];
  v_m uuid;
  v_ver uuid;
  v_hash text;
begin
  perform pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
  v_listing := (public.create_listing_draft(gen_random_uuid()) #>> '{listing,id}')::uuid;
  perform public.save_listing_draft(v_listing, jsonb_build_object(
    'title', p_title, 'description', 'وصف كاف لاجتياز الحد الأدنى للطول المطلوب في الاختبار',
    'breed_id', (select id from public.breeds where not requires_note order by id limit 1),
    'sex', 'FEMALE', 'age_months', 48, 'region_id', p_region,
    'city_id', (select id from public.cities where region_id = p_region order by id limit 1),
    'health_notes', 'لا توجد عيوب معروفة', 'owner_declaration', true,
    'offer_type', 'FIXED_PRICE', 'price', 25000, 'contact_phone', '0500000009',
    'contact_call_enabled', true));
  insert into ids values (p_key, v_listing);
  for i in 1..3 loop
    v_m := (public.add_listing_media(v_listing, 'IMAGE', 'image/jpeg', 1000) ->> 'media_id')::uuid;
    perform public.finalize_listing_media(v_m, 'image/jpeg', 1000, 800, 600);
    v_media := v_media || v_m;
  end loop;
  perform public.arrange_listing_media(v_listing, v_media, v_media[1]);
  perform public.submit_listing(v_listing, gen_random_uuid());
  perform pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
  v_ver := (public.admin_get_listing_review(v_listing) #>> '{version,id}')::uuid;
  v_hash := public.admin_get_listing_review(v_listing) #>> '{version,content_hash}';
  perform public.admin_approve_listing_version(v_listing, v_ver, v_hash);
end;
$$;

select columns_are('public', 'saved_searches', array['id', 'user_id', 'name', 'filters', 'filters_hash', 'created_at']);
select columns_are('public', 'follows', array['follower_id', 'seller_id', 'created_at']);
select columns_are('public', 'my_saved_searches', array['id', 'name', 'filters', 'created_at']);
select columns_are('public', 'my_follows', array[
  'user_id', 'display_name', 'region_id', 'region_name_ar', 'followed_at', 'published_listings_count']);

-- الزائر
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok($$select public.follow_seller('00000000-0000-0000-0000-00000000000a')$$, '42501', null, 'الزائر لا يتابع');
select throws_ok($$select public.save_search('{"region_id": 1}')$$, '42501', null, 'الزائر لا يحفظ بحثًا');
reset role;

-- التحقق من المدخلات
select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
set local role authenticated;
select throws_ok($$select public.save_search('{}')$$, 'P0001', 'VALIDATION_FAILED', 'بحث بلا مرشحات');
select throws_ok($$select public.save_search('{"query": "  "}')$$, 'P0001', 'VALIDATION_FAILED', 'نص فارغ فقط');
select throws_ok($$select public.save_search('{"foo": 1}')$$, 'P0001', 'VALIDATION_FAILED', 'مفتاح غير معروف');
select throws_ok($$select public.save_search('{"sex": "X"}')$$, 'P0001', 'VALIDATION_FAILED', 'جنس غير معروف');
select throws_ok($$select public.save_search('{"age_min": 60, "age_max": 30}')$$, 'P0001', 'VALIDATION_FAILED', 'عمر معكوس');
select throws_ok($$select public.save_search('{"price_min": 500, "price_max": 100}')$$, 'P0001', 'VALIDATION_FAILED', 'سعر معكوس');
select throws_ok($$select public.save_search('{"price_min": 100, "offer_type": "IN_PERSON_AUCTION"}')$$, 'P0001',
  'VALIDATION_FAILED', 'سعر مع مزاد');
select throws_ok($$select public.save_search('{"price_min": -5}')$$, 'P0001', 'VALIDATION_FAILED', 'سعر سالب');
select throws_ok(
  $$select public.save_search(jsonb_build_object('region_id', 1, 'city_id', (select id from public.cities where region_id = 2 limit 1)))$$,
  'P0001', 'VALIDATION_FAILED', 'مدينة لا تتبع المنطقة');
select throws_ok($$select public.save_search('{"query": "x"}', repeat('أ', 81))$$, 'P0001', 'VALIDATION_FAILED', 'اسم طويل');
select throws_ok($$select public.save_search('[1]')$$, 'P0001', 'VALIDATION_FAILED', 'ليس كائنًا');
select throws_ok($$select public.follow_seller(auth.uid())$$, 'P0001', 'VALIDATION_FAILED', 'لا متابعة للنفس');
select throws_ok($$select public.follow_seller('00000000-0000-0000-0000-000000000099')$$, 'P0001', 'NOT_FOUND', 'معلن غير موجود');
reset role;

-- الاشتراكات
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is(public.follow_seller('00000000-0000-0000-0000-00000000000a') ->> 'created', 'true', 'متابعة معلن');
select is(public.follow_seller('00000000-0000-0000-0000-00000000000a') ->> 'created', 'false', 'المتابعة المكررة آمنة');
select is((select count(*)::integer from public.follows), 1, 'صف واحد');
-- ويحفظ بحثًا مطابقًا أيضًا: ينبه مرة واحدة
select is(public.save_search('{"query": "ناقة", "region_id": 1}', 'نوق الرياض') ->> 'created', 'true', 'حفظ بحث');
select is(public.save_search('{"region_id": 1, "query": " ناقة "}') ->> 'created', 'false', 'نفس المرشحات بترتيب آخر لا يتكرر');
select is((select filters::text from public.my_saved_searches), '{"query": "ناقة", "region_id": 1}', 'المرشحات المنظمة');
select throws_ok(
  $$insert into public.follows (follower_id, seller_id) values (auth.uid(), '00000000-0000-0000-0000-00000000000c')$$,
  '42501', null, 'لا كتابة مباشرة في المتابعات');
select throws_ok($$delete from public.saved_searches$$, '42501', null, 'ولا في البحوث المحفوظة');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
set local role authenticated;
select public.save_search('{"query": "ناقة", "region_id": 1}');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000e', 'aal1');
set local role authenticated;
select public.save_search('{"region_id": 2}');
select is((select count(*)::integer from public.my_saved_searches), 1, 'كل مستخدم يرى بحثه فقط');
select is((select count(*)::integer from public.my_follows), 0, 'ولا يرى متابعات غيره');
reset role;

-- أول نشر
select pg_temp.publish('p1', 'ناقة مجاهيم للبيع', 1);

select is((select count(*)::integer from public.notifications where event = 'follow.new_listing'), 2,
  'متابع المعلن والباحث المطابق فقط');
select is(
  (select payload ->> 'source' from public.notifications
   where event = 'follow.new_listing' and recipient_id = '00000000-0000-0000-0000-00000000000b'),
  'SELLER', 'من تطابق عنده الاشتراكان: إشعار واحد بمصدر المتابعة');
select is(
  (select payload ->> 'source' from public.notifications
   where event = 'follow.new_listing' and recipient_id = '00000000-0000-0000-0000-00000000000c'),
  'SEARCH', 'البحث المطابق');
select is(
  (select count(*)::integer from public.notifications
   where event = 'follow.new_listing' and recipient_id in
     ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000e')), 0,
  'المعلن نفسه وغير المطابق لا ينبهان');
select is(
  (select (payload ? 'body') or (payload ? 'description') from public.notifications where event = 'follow.new_listing' limit 1),
  false, 'لا تفاصيل خاصة في الحمولة');

-- الإخفاء وإعادة الإظهار والتجديد لا تنبه
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
select public.admin_hide_listing((select v from ids where k = 'p1'), 'OTHER', 'اختبار');
select public.admin_unhide_listing((select v from ids where k = 'p1'), 'إعادة');
select is((select count(*)::integer from public.notifications where event = 'follow.new_listing'), 2,
  'الإخفاء وإعادة الإظهار لا ينبهان');
update public.listings set last_bumped_at = now(), visibility_updated_at = now()
  where id = (select v from ids where k = 'p1');
select is((select count(*)::integer from public.notifications where event = 'follow.new_listing'), 2,
  'التجديد لا ينبه');

-- إعلان آخر في منطقة أخرى: يطابق e فقط والمتابعين
select pg_temp.publish('p2', 'حاشي من المنطقة الثانية', 2);
select is(
  (select array_agg(recipient_id::text order by recipient_id::text) from public.notifications
   where event = 'follow.new_listing' and resource_id = (select v::text from ids where k = 'p2')),
  array['00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000e'],
  'المتابع والباحث بالمنطقة الثانية');

-- بعد إلغاء المتابعة لا تنبيه
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is(public.unfollow_seller('00000000-0000-0000-0000-00000000000a') ->> 'following', 'false', 'إلغاء المتابعة');
select lives_ok($$select public.unfollow_seller('00000000-0000-0000-0000-00000000000a')$$, 'الإلغاء المتكرر آمن');
select is((select count(*)::integer from public.my_follows), 0, 'القائمة فارغة');
select is(public.delete_saved_search((select id from public.my_saved_searches limit 1)) ->> 'deleted', 'true',
  'إلغاء متابعة بحث');
select is(public.delete_saved_search('00000000-0000-0000-0000-000000000099') ->> 'deleted', 'false', 'إلغاء غير موجود آمن');
reset role;
select pg_temp.publish('p3', 'ناقة ثانية للبيع اليوم', 1);
select is(
  (select count(*)::integer from public.notifications
   where event = 'follow.new_listing' and recipient_id = '00000000-0000-0000-0000-00000000000b'
     and resource_id = (select v::text from ids where k = 'p3')), 0,
  'بعد الإلغاء لا تنبيه');
select is(
  (select count(*)::integer from public.notifications
   where event = 'follow.new_listing' and recipient_id = '00000000-0000-0000-0000-00000000000c'
     and resource_id = (select v::text from ids where k = 'p3')), 1,
  'الاشتراك الباقي ينبه');

-- الحظر يمنع التنبيه
select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
set local role authenticated;
select public.block_user('00000000-0000-0000-0000-00000000000a');
reset role;
select pg_temp.publish('p4', 'ناقة ثالثة للبيع اليوم', 1);
select is(
  (select count(*)::integer from public.notifications
   where event = 'follow.new_listing' and recipient_id = '00000000-0000-0000-0000-00000000000c'
     and resource_id = (select v::text from ids where k = 'p4')), 0,
  'المحظور لا ينبه الحاظر');

-- حد البحوث المحفوظة: 20
select pg_temp.login('00000000-0000-0000-0000-00000000000e', 'aal1');
set local role authenticated;
select lives_ok(format($$select public.save_search('{"age_min": %s}')$$, i), 'بحث ' || i)
  from generate_series(1, 19) i;
select throws_ok($$select public.save_search('{"age_min": 100}')$$, 'P0001', 'FOLLOW_LIMIT_REACHED', 'بلوغ حد البحوث');
select is(public.save_search('{"age_min": 5}') ->> 'created', 'false', 'المكرر يعمل عند بلوغ الحد');
reset role;

select * from finish();
rollback;
