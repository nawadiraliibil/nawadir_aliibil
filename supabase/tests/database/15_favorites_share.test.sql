-- MOBILE-BE-202 — الترحيل 15 favorites_share
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

-- a معلن، b مستخدم يحفظ، c مستخدم آخر، s مدير.
insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002'),
  ('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000003');
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test');
update public.profiles set display_name = 'معلن الاختبار', region_id = 1
  where id = '00000000-0000-0000-0000-00000000000a';
update public.profiles set display_name = 'محب الإبل', region_id = 1
  where id = '00000000-0000-0000-0000-00000000000b';
insert into public.policy_consents (user_id, document_id)
  select '00000000-0000-0000-0000-00000000000a', d.id from private.current_policy_documents() d;
select private.bootstrap_first_admin('00000000-0000-0000-0000-0000000000a1');

create function pg_temp.login(p_user uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated, anon;

create function pg_temp.publish(p_key text, p_title text, p_approve boolean) returns void language plpgsql as $$
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
    'sex', 'FEMALE', 'age_months', 48, 'region_id', 1,
    'city_id', (select id from public.cities where region_id = 1 order by id limit 1),
    'health_notes', 'لا توجد عيوب معروفة', 'owner_declaration', true,
    'offer_type', 'FIXED_PRICE', 'price', 25000, 'contact_phone', '0500000009',
    'contact_call_enabled', true, 'contact_whatsapp_enabled', true));
  insert into ids values (p_key, v_listing);
  if not p_approve then return; end if;
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

select pg_temp.publish('p1', 'ناقة مجاهيم للبيع', true);
select pg_temp.publish('p2', 'ناقة ثانية منشورة', true);
select pg_temp.publish('d1', 'مسودة لم ترسل بعد', false);

-- أعمدة العقد
select columns_are('public', 'my_favorites', array[
  'listing_id', 'saved_at', 'available', 'owner_id', 'owner_display_name', 'title', 'offer_type', 'price',
  'auction_starts_at', 'auction_passed', 'breed_id', 'breed_name_ar', 'breed_note', 'sex', 'age_months',
  'region_id', 'region_name_ar', 'city_id', 'city_name_ar', 'cover_bucket', 'cover_path', 'public_ref']);
select columns_are('public', 'favorites', array['user_id', 'listing_id', 'created_at']);

-- الزائر
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok(
  $$select public.add_favorite((select v from ids where k = 'p1'))$$, '42501', null, 'الزائر لا يحفظ');
select throws_ok($$select count(*) from public.my_favorites$$, '42501', null, 'الزائر لا يقرأ المفضلة');
select throws_ok($$select count(*) from public.favorites$$, '42501', null, 'الزائر لا يقرأ الجدول');
select is(
  (public.get_listing((select v from ids where k = 'p1')) -> 'is_favorite'), 'false'::jsonb,
  'الزائر: لا مفضلة');
select is(
  (public.get_listing((select v from ids where k = 'p1')) #>> '{listing,title}'), 'ناقة مجاهيم للبيع',
  'تفاصيل الإعلان للزائر');
select is(
  jsonb_array_length(public.get_listing((select v from ids where k = 'p1')) -> 'media'), 3, 'وسائط التفاصيل');
select is(
  (public.get_listing((select v from ids where k = 'p1')) #>> '{media,0,is_cover}')::boolean, true,
  'الغلاف أولًا');
select is(
  (public.get_listing((select v from ids where k = 'p1')) #>> '{listing,contact_whatsapp_enabled}')::boolean, true,
  'قنوات التواصل المفعلة');
select throws_ok($$select public.get_listing((select v from ids where k = 'd1'))$$, 'P0001', 'NOT_FOUND',
  'مسودة: غير متاح');
select throws_ok($$select public.get_listing('00000000-0000-0000-0000-000000000099')$$, 'P0001', 'NOT_FOUND',
  'غير موجود: الرد نفسه');
reset role;

-- المستخدم b يحفظ
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is(
  (public.add_favorite((select v from ids where k = 'p1')) ->> 'listing_id')::uuid,
  (select v from ids where k = 'p1'), 'حفظ إعلان منشور');
create temp table first_saved as
  select (public.add_favorite((select v from ids where k = 'p1')) ->> 'saved_at') as at;
grant all on first_saved to authenticated;
select is((select count(*)::integer from public.favorites), 1, 'التكرار لا ينشئ صفًا ثانيًا');
select is(
  public.add_favorite((select v from ids where k = 'p1')) ->> 'saved_at',
  (select at from first_saved), 'تاريخ الحفظ الأول لا يتغير');
select public.add_favorite((select v from ids where k = 'p2'));
select throws_ok($$select public.add_favorite((select v from ids where k = 'd1'))$$, 'P0001', 'NOT_FOUND',
  'حفظ مسودة مرفوض');
select throws_ok($$select public.add_favorite('00000000-0000-0000-0000-000000000099')$$, 'P0001', 'NOT_FOUND',
  'حفظ غير موجود مرفوض');
select is((select count(*)::integer from public.my_favorites where available), 2, 'قائمة المفضلة');
select is((select title from public.my_favorites where listing_id = (select v from ids where k = 'p1')),
  'ناقة مجاهيم للبيع', 'محتوى المنشور');
select is(public.get_listing((select v from ids where k = 'p1')) -> 'is_favorite', 'true'::jsonb,
  'التفاصيل تعرف أنه محفوظ');
select is(public.get_listing((select v from ids where k = 'p2')) -> 'is_favorite', 'true'::jsonb, 'محفوظ ثان');
select throws_ok(
  $$insert into public.favorites (user_id, listing_id) values (auth.uid(), (select v from ids where k = 'p1'))$$,
  '42501', null, 'لا كتابة مباشرة');
select throws_ok($$delete from public.favorites$$, '42501', null, 'لا حذف مباشر');
reset role;

-- مستخدم آخر لا يرى قائمة غيره
select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
set local role authenticated;
select is((select count(*)::integer from public.my_favorites), 0, 'لا يطلع غير المالك على القائمة');
select is((select count(*)::integer from public.favorites), 0, 'ولا على الجدول');
select is(public.get_listing((select v from ids where k = 'p1')) -> 'is_favorite', 'false'::jsonb,
  'غير محفوظ عنده');
reset role;

-- الإخفاء: يبقى صف المفضلة «غير متاح» بلا محتوى
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
select public.admin_hide_listing((select v from ids where k = 'p1'), 'OTHER', 'سبب الإخفاء');
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is((select count(*)::integer from public.my_favorites), 2, 'الصف يبقى بعد الإخفاء');
select is((select available from public.my_favorites where listing_id = (select v from ids where k = 'p1')),
  false, 'المخفي غير متاح');
select is(
  (select (title, price, cover_path, owner_id, region_name_ar, public_ref)::text
   from public.my_favorites where listing_id = (select v from ids where k = 'p1')),
  '(,,,,,)', 'لا محتوى ولا وسائط ولا مرجع للمخفي');
select throws_ok($$select public.get_listing((select v from ids where k = 'p1'))$$, 'P0001', 'NOT_FOUND',
  'تفاصيل المخفي غير متاحة حتى للمحفوظ');
select is((select count(*)::integer from public.my_favorites where available), 1, 'المنشور فقط متاح');

-- الإزالة
select is(public.remove_favorite((select v from ids where k = 'p1')) -> 'removed', 'true'::jsonb,
  'إزالة المخفي من القائمة');
select is(public.remove_favorite((select v from ids where k = 'p1')) -> 'removed', 'false'::jsonb,
  'الإزالة المتكررة آمنة');
select is(public.remove_favorite('00000000-0000-0000-0000-000000000099') -> 'removed', 'false'::jsonb,
  'إزالة ما لم يحفظ');
select is((select count(*)::integer from public.my_favorites), 1, 'بقي واحد');
reset role;

-- إعادة الإظهار: يعود الإعلان للحفظ إن كان محفوظًا (هنا أزيل فلا يعود)
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
select public.admin_unhide_listing((select v from ids where k = 'p1'), 'إعادة');
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is((select count(*)::integer from public.my_favorites where listing_id = (select v from ids where k = 'p1')),
  0, 'المزال لا يعود بإعادة الإظهار');
select public.add_favorite((select v from ids where k = 'p1'));
select is((select available from public.my_favorites where listing_id = (select v from ids where k = 'p1')),
  true, 'حفظ من جديد بعد إعادة الإظهار');
reset role;

-- حساب موقوف لا يحفظ، ويزيل ما حفظ
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
select public.admin_suspend_account('00000000-0000-0000-0000-00000000000b', 'OTHER', 'اختبار');
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select throws_ok($$select public.add_favorite((select v from ids where k = 'p2'))$$, 'P0001', 'ACCOUNT_SUSPENDED',
  'الموقوف لا يحفظ');
select lives_ok($$select public.remove_favorite((select v from ids where k = 'p2'))$$, 'الموقوف يزيل');
reset role;

select * from finish();
rollback;
