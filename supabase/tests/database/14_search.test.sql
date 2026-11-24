-- MOBILE-BE-201 — الترحيل 14 search
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002');
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test');
update public.profiles set display_name = 'معلن أول', region_id = 1
  where id = '00000000-0000-0000-0000-00000000000a';
update public.profiles set display_name = 'معلن ثان', region_id = 2
  where id = '00000000-0000-0000-0000-00000000000b';
insert into public.policy_consents (user_id, document_id)
  select u.id, d.id from private.current_policy_documents() d,
    (values ('00000000-0000-0000-0000-00000000000a'::uuid), ('00000000-0000-0000-0000-00000000000b'::uuid)) u(id);
select private.bootstrap_first_admin('00000000-0000-0000-0000-0000000000a1');

create function pg_temp.login(p_user uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated, anon;

-- ينشئ إعلانًا كاملًا ويعتمده. يعمل بصلاحية postgres والجلسة من الادعاءات.
create function pg_temp.publish(
  p_key text, p_owner uuid, p_title text, p_sex text, p_age integer, p_offer text,
  p_price numeric, p_region integer, p_city_nth integer default 0
) returns void language plpgsql as $$
declare
  v_listing uuid;
  v_city integer;
  v_patch jsonb;
  v_media uuid[] := array[]::uuid[];
  v_m uuid;
  v_ver uuid;
  v_hash text;
begin
  select c.id into v_city from public.cities c where c.region_id = p_region order by c.id offset p_city_nth limit 1;
  perform pg_temp.login(p_owner, 'aal1');
  v_listing := (public.create_listing_draft(gen_random_uuid()) #>> '{listing,id}')::uuid;
  v_patch := jsonb_build_object(
    'title', p_title, 'description', 'وصف كاف لاجتياز الحد الأدنى للطول المطلوب في الاختبار',
    'breed_id', (select id from public.breeds where not requires_note order by id limit 1),
    'sex', p_sex, 'age_months', p_age, 'region_id', p_region, 'city_id', v_city,
    'health_notes', 'لا توجد عيوب معروفة', 'owner_declaration', true,
    'offer_type', p_offer, 'contact_phone', '0500000009', 'contact_call_enabled', true);
  if p_offer = 'FIXED_PRICE' then
    v_patch := v_patch || jsonb_build_object('price', p_price);
  else
    v_patch := v_patch || jsonb_build_object(
      'auction_region_id', p_region, 'auction_city_id', v_city,
      'auction_lat', 24.713552, 'auction_lng', 46.675297, 'auction_venue', 'ساحة المزاد', 'auction_starts_at', to_char((now() + interval '30 days') at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
  end if;
  perform public.save_listing_draft(v_listing, v_patch);
  for i in 1..3 loop
    v_m := (public.add_listing_media(v_listing, 'IMAGE', 'image/jpeg', 1000) ->> 'media_id')::uuid;
    perform public.finalize_listing_media(v_m, 'image/jpeg', 1000, 800, 600);
    v_media := v_media || v_m;
  end loop;
  perform public.arrange_listing_media(v_listing, v_media, v_media[1]);
  perform public.submit_listing(v_listing, gen_random_uuid());
  perform pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
  insert into ids values (p_key, v_listing);
end;
$$;

-- مجموعة بيانات: أربعة ثابتة السعر ومزادان
select pg_temp.publish('l1', '00000000-0000-0000-0000-00000000000a', 'ناقة مجاهيم للبيع', 'FEMALE', 48, 'FIXED_PRICE', 25000, 1);
select pg_temp.publish('l2', '00000000-0000-0000-0000-00000000000a', 'جمل صفر أصيل', 'MALE', 24, 'FIXED_PRICE', 10000, 1, 1);
select pg_temp.publish('l3', '00000000-0000-0000-0000-00000000000b', 'حاشي 100% نادر', 'FEMALE', 72, 'FIXED_PRICE', 40000, 2);
select pg_temp.publish('l4', '00000000-0000-0000-0000-00000000000b', 'ناقة سباق أصيلة', 'FEMALE', 36, 'FIXED_PRICE', 25000, 2, 1);
select pg_temp.publish('a1', '00000000-0000-0000-0000-00000000000a', 'مزاد ركاب مفتوح', 'MALE', 36, 'IN_PERSON_AUCTION', null, 1);
select pg_temp.publish('a2', '00000000-0000-0000-0000-00000000000b', 'مزاد قديم للإبل', 'MALE', 40, 'IN_PERSON_AUCTION', null, 2);

-- أوقات متمايزة: l1 الأحدث ظهورًا ثم l2، l3، l4، a1، a2؛ وأول نشر بالعكس.
update public.listings set
  visibility_updated_at = timestamptz '2026-11-20 12:00+00' - make_interval(mins => t.n),
  first_published_at = timestamptz '2026-11-19 12:00+00' + make_interval(mins => t.n)
from (values ('l1', 0), ('l2', 10), ('l3', 20), ('l4', 30), ('a1', 40), ('a2', 50)) t(k, n)
where id = (select v from ids where ids.k = t.k);

-- المزاد a2 يمضي موعده بعد نشره (ثبات النسخ يمنع التعديل عبر الدوال).
set local session_replication_role = replica;
update public.listing_versions set auction_starts_at = now() - interval '1 day'
  where listing_id = (select v from ids where k = 'a2') and status = 'APPROVED';
set local session_replication_role = origin;

create function pg_temp.keys(p jsonb) returns text language sql as $$
  select coalesce(string_agg(k, ',' order by n), '') from (
    select (select i.k from ids i where i.v = (e ->> 'listing_id')::uuid) as k, n
    from jsonb_array_elements(p -> 'items') with ordinality t(e, n)) s;
$$;
grant execute on function pg_temp.keys(jsonb) to anon, authenticated;

-- الدفعات: يمر الفرز على كل النتائج مرة واحدة دون تكرار أو فقد
create function pg_temp.walk(p_sort text, p_limit integer) returns text language plpgsql as $$
declare
  v_cursor jsonb := null;
  v_res jsonb;
  v_all text := '';
  v_pages integer := 0;
begin
  loop
    v_res := public.search_listings(p_sort => p_sort, p_limit => p_limit, p_cursor => v_cursor);
    v_all := v_all || case when v_all = '' then '' else ',' end || pg_temp.keys(v_res);
    v_pages := v_pages + 1;
    v_cursor := v_res -> 'next_cursor';
    exit when v_cursor is null or jsonb_typeof(v_cursor) = 'null' or v_pages > 10;
  end loop;
  return v_all || '|' || v_pages;
end;
$$;
grant execute on function pg_temp.walk(text, integer) to anon, authenticated;

select set_config('request.jwt.claims', '', true);
set local role anon;

select is(pg_temp.keys(public.search_listings()), 'l1,l2,l3,l4,a1', 'الافتراضي: الأحدث ظهورًا ويستبعد المزاد الماضي');
select is(pg_temp.keys(public.search_listings(p_sort => 'NEWEST_PUBLISHED')), 'a1,l4,l3,l2,l1',
  'الفرز بالأحدث نشرًا');
select matches(pg_temp.keys(public.search_listings(p_sort => 'PRICE_ASC')), '^l2,(l1,l4|l4,l1),l3,a1$',
  'السعر تصاعديًا والمزاد أخيرًا');
select matches(pg_temp.keys(public.search_listings(p_sort => 'PRICE_DESC')), '^l3,(l1,l4|l4,l1),l2,a1$',
  'السعر تنازليًا والمزاد أخيرًا');

-- المرشحات
select is(pg_temp.keys(public.search_listings(p_region_id => 2)), 'l3,l4', 'التصفية بالمنطقة');
select is(pg_temp.keys(public.search_listings(
  p_region_id => 2, p_city_id => (select city_id from public.public_listing_cards where listing_id = (select v from ids where k = 'l4')))),
  'l4', 'التصفية بالمدينة');
select is(pg_temp.keys(public.search_listings(p_sex => 'MALE')), 'l2,a1', 'التصفية بالجنس');
select is(pg_temp.keys(public.search_listings(p_offer_type => 'IN_PERSON_AUCTION')), 'a1', 'نوع العرض مزاد');
select is(pg_temp.keys(public.search_listings(p_age_min => 30, p_age_max => 50)), 'l1,l4,a1', 'نطاق العمر');
select is(pg_temp.keys(public.search_listings(p_price_min => 20000)), 'l1,l3,l4',
  'نطاق السعر يستبعد المزاد');
select is(pg_temp.keys(public.search_listings(p_price_max => 25000)), 'l1,l2,l4', 'الحد الأعلى للسعر يستبعد المزاد');
select is(pg_temp.keys(public.search_listings(p_sex => 'FEMALE', p_region_id => 2, p_price_max => 30000)), 'l4',
  'مرشحات مجتمعة');
select is(pg_temp.keys(public.search_listings(p_owner_id => '00000000-0000-0000-0000-00000000000b')), 'l3,l4',
  'إعلانات معلن واحد');

-- نص البحث
select is(pg_temp.keys(public.search_listings(p_query => 'ناقة')), 'l1,l4', 'البحث في العنوان');
select is(pg_temp.keys(public.search_listings(p_query => '  ناقة  ')), 'l1,l4', 'البحث يقص الفراغات');
select is(pg_temp.keys(public.search_listings(p_query => '100%')), 'l3', 'علامة % حرفية');
select is(pg_temp.keys(public.search_listings(p_query => '%')), 'l3', 'علامة % وحدها لا تطابق الكل');
select is(pg_temp.keys(public.search_listings(p_query => '_')), '', 'علامة _ حرفية');
select is(pg_temp.keys(public.search_listings(p_query => 'غير موجود')), '', 'بحث بلا نتائج');

-- التحقق
select throws_ok($$select public.search_listings(p_age_min => 60, p_age_max => 30)$$, 'P0001', 'VALIDATION_FAILED',
  'نطاق عمر معكوس');
select throws_ok($$select public.search_listings(p_price_min => 5000, p_price_max => 100)$$, 'P0001', 'VALIDATION_FAILED',
  'نطاق سعر معكوس');
select throws_ok($$select public.search_listings(p_price_min => -1)$$, 'P0001', 'VALIDATION_FAILED', 'سعر سالب');
select throws_ok($$select public.search_listings(p_sex => 'X')$$, 'P0001', 'VALIDATION_FAILED', 'جنس غير معروف');
select throws_ok($$select public.search_listings(p_offer_type => 'X')$$, 'P0001', 'VALIDATION_FAILED', 'نوع عرض غير معروف');
select throws_ok($$select public.search_listings(p_sort => 'X')$$, 'P0001', 'VALIDATION_FAILED', 'فرز غير معروف');
select throws_ok($$select public.search_listings(p_limit => 0)$$, 'P0001', 'VALIDATION_FAILED', 'حد صفر');
select throws_ok($$select public.search_listings(p_limit => 51)$$, 'P0001', 'VALIDATION_FAILED', 'حد فوق 50');
select throws_ok($$select public.search_listings(p_query => repeat('أ', 101))$$, 'P0001', 'VALIDATION_FAILED',
  'نص بحث طويل');
select throws_ok($$select public.search_listings(p_region_id => 1, p_city_id =>
  (select id from public.cities where region_id = 2 order by id limit 1))$$, 'P0001', 'VALIDATION_FAILED',
  'مدينة لا تتبع المنطقة');
select throws_ok($$select public.search_listings(p_cursor => '{"x": 1}')$$, 'P0001', 'VALIDATION_FAILED',
  'مؤشر غير صالح');

select is(pg_temp.walk('NEWEST_VISIBLE', 2), 'l1,l2,l3,l4,a1|3', 'دفعات الأحدث ظهورًا');
select is(pg_temp.walk('NEWEST_PUBLISHED', 2), 'a1,l4,l3,l2,l1|3', 'دفعات الأحدث نشرًا');
select is(pg_temp.walk('PRICE_ASC', 2), regexp_replace(pg_temp.walk('PRICE_ASC', 50), '[|].*', '|3'), 'دفعات السعر تصاعديًا');
select is(pg_temp.walk('PRICE_DESC', 2), regexp_replace(pg_temp.walk('PRICE_DESC', 50), '[|].*', '|3'), 'دفعات السعر تنازليًا');
select is(pg_temp.walk('PRICE_ASC', 1), regexp_replace(pg_temp.walk('PRICE_ASC', 50), '[|].*', '|5'), 'دفعة بحجم واحد');
select is(public.search_listings(p_limit => 50) -> 'next_cursor', 'null'::jsonb, 'لا مؤشر في الصفحة الأخيرة');

-- الأكثر مشاهدة: l3 ثم l1 وl2 بالتعادل (الأحدث معرّفًا أولًا)، ويدفع بالمؤشر دون تكرار
reset role;
insert into public.listing_stats (listing_id, view_count)
  select id, case when id = (select v from ids where k = 'l3') then 50 when id = (select v from ids where k = 'l4') then 10 else 0 end
  from public.listings
  on conflict (listing_id) do update set view_count = excluded.view_count;
select is(
  (select count(*)::integer from jsonb_array_elements(public.search_listings(p_sort => 'MOST_VIEWED', p_limit => 50) -> 'items')),
  5, 'الأكثر مشاهدة يعيد كل الإعلانات النشطة');
select is(left(pg_temp.walk('MOST_VIEWED', 2), 5), 'l3,l4', 'الأعلى مشاهدة أولًا');
select is(pg_temp.walk('MOST_VIEWED', 2), regexp_replace(pg_temp.walk('MOST_VIEWED', 50), '[|].*', '|3'), 'دفعات الأكثر مشاهدة بلا تكرار');

select is(
  (select array_agg(k order by k) from jsonb_object_keys((public.search_listings(p_limit => 1) -> 'items') -> 0) k),
  array['age_months', 'auction_lat', 'auction_lng', 'auction_passed', 'auction_starts_at', 'breed_id', 'breed_name_ar', 'breed_note',
    'city_id', 'city_name_ar', 'cover_bucket', 'cover_path', 'favorite_count', 'first_published_at', 'listing_id', 'offer_type',
    'owner_display_name', 'owner_id', 'price', 'public_ref', 'region_id', 'region_name_ar', 'sex', 'title',
    'view_count', 'visibility_updated_at'],
  'أعمدة عنصر النتيجة');
reset role;

-- الإخفاء يخرج الإعلان من النتائج فورًا
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
select public.admin_hide_listing((select v from ids where k = 'l2'), 'OTHER', 'اختبار');
select set_config('request.jwt.claims', '', true);
set local role anon;
select is(pg_temp.keys(public.search_listings()), 'l1,l3,l4,a1', 'المخفي خارج النتائج');
select is(pg_temp.keys(public.search_listings(p_query => 'جمل')), '', 'المخفي خارج البحث');
reset role;

-- المعرّف العام
select is((select count(*)::integer from public.listings where public_ref ~ '^[a-z2-9]{8}$'), 6, 'صيغة المعرف العام');
select is((select count(distinct public_ref)::integer from public.listings), 6, 'المعرفات فريدة');
set local role anon;
select is(public.resolve_listing_ref((select public_ref from public.public_listing_cards where listing_id = (select v from ids where k = 'l1'))),
  (select v from ids where k = 'l1'), 'ترجمة المعرف إلى الإعلان');
select is(public.resolve_listing_ref(upper((select public_ref from public.public_listing_cards where listing_id = (select v from ids where k = 'l1')))),
  (select v from ids where k = 'l1'), 'الترجمة لا تتأثر بحالة الأحرف');
select throws_ok($$select public.resolve_listing_ref('zzzzzzzz')$$, 'P0001', 'NOT_FOUND', 'معرف غير موجود');
select throws_ok($$select public.resolve_listing_ref(null)$$, 'P0001', 'NOT_FOUND', 'معرف فارغ');
select throws_ok($$select public_ref from public.listings$$, '42501', null, 'الزائر لا يقرأ الجدول');
reset role;
-- رابط المخفي يتوقف
create temp table refs as select public_ref from public.listings where id = (select v from ids where k = 'l2');
grant select on refs to anon;
set local role anon;
select throws_ok($$select public.resolve_listing_ref((select public_ref from refs))$$, 'P0001', 'NOT_FOUND', 'رابط المخفي يتوقف');
reset role;

select * from finish();
rollback;
