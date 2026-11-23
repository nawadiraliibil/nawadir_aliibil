-- MOBILE-BE-105 — الترحيل 07 listings_core
begin;

create extension if not exists pgtap with schema extensions;

select plan(31);

insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002');

create function pg_temp.login(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal1')::text, true);
$$;

-- مدينة من منطقة الرياض (1) وأخرى من مكة (2)
create temp table t as
select
  (select id from public.cities where region_id = 1 order by id limit 1) as city_r1,
  (select id from public.cities where region_id = 2 order by id limit 1) as city_r2,
  (select id from public.breeds order by id limit 1) as breed;
grant select on t to authenticated;

insert into public.listings (id, owner_id, create_request_id) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', gen_random_uuid()),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000a', gen_random_uuid());
insert into public.listing_versions (id, listing_id, version_no) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 1),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 1);

-- قيود النسخة
select throws_ok(
  $$insert into public.listing_versions (listing_id, version_no) values ('10000000-0000-0000-0000-000000000001', 2)$$,
  '23505', null, 'مسودة واحدة لكل إعلان');
select throws_ok(
  $$update public.listing_versions set status = 'SUBMITTED' where id = '20000000-0000-0000-0000-000000000001'$$,
  '23514', null, 'نسخة ناقصة لا ترسل');
select throws_ok(
  $$update public.listing_versions set offer_type = 'IN_PERSON_AUCTION', price = 100 where id = '20000000-0000-0000-0000-000000000001'$$,
  '23514', null, 'لا سعر في المزاد الحضوري');
select throws_ok(
  $$update public.listing_versions set offer_type = 'FIXED_PRICE', auction_venue = 'سوق' where id = '20000000-0000-0000-0000-000000000001'$$,
  '23514', null, 'لا حقول مزاد في العرض السعري');
select throws_ok(
  $$update public.listing_versions set offer_type = 'FIXED_PRICE', price = 0 where id = '20000000-0000-0000-0000-000000000001'$$,
  '23514', null, 'السعر موجب');
select throws_ok(
  $$update public.listing_versions set region_id = 1, city_id = (select city_r2 from t) where id = '20000000-0000-0000-0000-000000000001'$$,
  '23503', null, 'مدينة لا تتبع المنطقة مرفوضة');
select throws_ok(
  $$update public.listing_versions set city_id = (select city_r1 from t) where id = '20000000-0000-0000-0000-000000000001'$$,
  '23514', null, 'مدينة دون منطقة مرفوضة');
select throws_ok(
  $$update public.listing_versions set contact_phone = '0500000000' where id = '20000000-0000-0000-0000-000000000001'$$,
  '23514', null, 'رقم تواصل بصيغة غير دولية مرفوض');

-- وسائط المسودة
insert into public.media (id, listing_id, version_id, owner_id, kind, status, bucket, object_path, mime_type, size_bytes, is_cover) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-00000000000a', 'IMAGE', 'READY', 'listing-images', 'a/l1/m1.jpg', 'image/jpeg', 1000, true);
select throws_ok(
  $$insert into public.media (listing_id, version_id, owner_id, kind, bucket, object_path, is_cover) values
    ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-00000000000a', 'IMAGE', 'listing-images', 'a/l1/m2.jpg', true)$$,
  '23505', null, 'غلاف واحد للنسخة');
select throws_ok(
  $$insert into public.media (listing_id, version_id, owner_id, kind, bucket, object_path, is_cover) values
    ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-00000000000a', 'VIDEO', 'listing-videos', 'a/l1/v1.mp4', true)$$,
  '23514', null, 'الغلاف صورة');
insert into public.media (listing_id, version_id, owner_id, kind, bucket, object_path) values
  ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-00000000000a', 'VIDEO', 'listing-videos', 'a/l1/v1.mp4');
select throws_ok(
  $$insert into public.media (listing_id, version_id, owner_id, kind, bucket, object_path) values
    ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-00000000000a', 'VIDEO', 'listing-videos', 'a/l1/v2.mp4')$$,
  '23505', null, 'فيديو واحد للنسخة');
select throws_ok(
  $$insert into public.media (listing_id, version_id, owner_id, kind, bucket, object_path) values
    ('10000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001',
     '00000000-0000-0000-0000-00000000000a', 'IMAGE', 'listing-images', 'a/l2/m1.jpg')$$,
  '23503', null, 'وسيط لنسخة من إعلان آخر مرفوض');

-- إرسال نسخة مكتملة (عرض سعري) ثم ثباتها
select lives_ok(
  $$update public.listing_versions set
      title = 'ناقة مجاهيم للبيع', description = 'وصف كاف لاجتياز الحد الأدنى للطول',
      breed_id = (select breed from t), sex = 'FEMALE', age_months = 48,
      region_id = 1, city_id = (select city_r1 from t),
      health_notes = 'لا توجد عيوب معروفة', owner_declaration_at = now(),
      offer_type = 'FIXED_PRICE', price = 25000.50,
      contact_phone = '+966500000009', contact_call_enabled = true, contact_consent_at = now(),
      settings_version = 1, content_hash = 'hash-1', submitted_at = now(), status = 'SUBMITTED'
    where id = '20000000-0000-0000-0000-000000000001'$$,
  'نسخة سعرية مكتملة ترسل');
select throws_ok(
  $$update public.listing_versions set title = 'عنوان آخر' where id = '20000000-0000-0000-0000-000000000001'$$,
  'P0001', 'VERSION_IMMUTABLE', 'نسخة مرسلة لا يتغير محتواها');
select throws_ok(
  $$update public.listing_versions set status = 'DRAFT' where id = '20000000-0000-0000-0000-000000000001'$$,
  'P0001', 'VERSION_IMMUTABLE', 'نسخة مرسلة لا تعود مسودة');
select throws_ok(
  $$update public.media set sort_order = 5 where id = '30000000-0000-0000-0000-000000000001'$$,
  'P0001', 'VERSION_IMMUTABLE', 'وسائط نسخة مرسلة لا تتغير');
select throws_ok(
  $$delete from public.media where id = '30000000-0000-0000-0000-000000000001'$$,
  'P0001', 'VERSION_IMMUTABLE', 'وسائط نسخة مرسلة لا تحذف');
select lives_ok(
  $$update public.listing_versions set status = 'APPROVED', decided_at = now() where id = '20000000-0000-0000-0000-000000000001'$$,
  'قرار الاعتماد يغير الحالة فقط');
select throws_ok(
  $$update public.listing_versions set status = 'REJECTED' where id = '20000000-0000-0000-0000-000000000001'$$,
  'P0001', 'VERSION_IMMUTABLE', 'نسخة معتمدة لا يتغير قرارها');

-- مزاد حضوري: المكان والموعد إلزاميان، ولا سعر
select throws_ok(
  $$update public.listing_versions set
      title = 'مزاد', description = 'وصف كاف لاجتياز الحد الأدنى للطول',
      breed_id = (select breed from t), sex = 'MALE', age_months = 36,
      region_id = 1, city_id = (select city_r1 from t),
      health_notes = 'سليم', owner_declaration_at = now(),
      offer_type = 'IN_PERSON_AUCTION',
      contact_phone = '+966500000009', contact_whatsapp_enabled = true, contact_consent_at = now(),
      settings_version = 1, content_hash = 'hash-2', submitted_at = now(), status = 'SUBMITTED'
    where id = '20000000-0000-0000-0000-000000000002'$$,
  '23514', null, 'مزاد دون مكان وموعد لا يرسل');

-- رأس الإعلان
select throws_ok(
  $$update public.listings set status = 'PUBLISHED' where id = '10000000-0000-0000-0000-000000000002'$$,
  '23514', null, 'منشور دون نسخة معتمدة مرفوض');
select throws_ok(
  $$insert into public.listings (owner_id, create_request_id)
    select owner_id, create_request_id from public.listings where id = '10000000-0000-0000-0000-000000000001'$$,
  '23505', null, 'معرف طلب الإنشاء لا يتكرر للمالك');

-- سجل القرارات
select throws_ok(
  $$insert into public.reviews (listing_id, version_id, decision, moderator_id) values
    ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'REJECTED', gen_random_uuid())$$,
  '23514', null, 'الرفض يستلزم سببًا');
insert into public.reviews (listing_id, version_id, decision, moderator_id) values
  ('10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 'APPROVED', gen_random_uuid());
select throws_ok(
  $$update public.reviews set decision = 'REJECTED', reason_code = 'OTHER'$$,
  'P0001', 'APPEND_ONLY', 'سجل القرارات لا يعدل');
select throws_ok(
  $$delete from public.listings where id = '10000000-0000-0000-0000-000000000001'$$,
  '23503', null, 'إعلان له سجل مراجعة لا يحذف نهائيًا');

-- صلاحيات القراءة
select pg_temp.login('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select is((select count(*)::integer from public.listings), 2, 'المالك يقرأ إعلاناته');
select is((select count(*)::integer from public.reviews), 0, 'المالك لا يقرأ سجل القرارات');
select is((select count(*)::integer from public.moderation_reasons), 12, 'أسباب الإشراف الفعالة مقروءة للمستخدم');
select throws_ok(
  $$insert into public.listings (owner_id, create_request_id) values ('00000000-0000-0000-0000-00000000000a', gen_random_uuid())$$,
  '42501', null, 'لا إدراج مباشر لإعلان');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select is(
  (select count(*)::integer from public.listings)
  + (select count(*)::integer from public.listing_versions)
  + (select count(*)::integer from public.media),
  0, 'مستخدم آخر لا يقرأ إعلانات غيره ولا نسخها ولا وسائطها');
reset role;

set local role anon;
select throws_ok($$select count(*) from public.listings$$, '42501', null, 'الزائر لا يقرأ جدول الإعلانات');
reset role;

select * from finish();
rollback;
