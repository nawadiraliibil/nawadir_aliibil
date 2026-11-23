-- MOBILE-BE-105 — الترحيل 08 storage
begin;

create extension if not exists pgtap with schema extensions;

select plan(15);

insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002');

create function pg_temp.login(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal1')::text, true);
$$;

insert into public.listings (id, owner_id, create_request_id) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', gen_random_uuid());
insert into public.listing_versions (id, listing_id, version_no) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 1);
insert into public.media (id, listing_id, version_id, owner_id, kind, bucket, object_path, is_cover) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-00000000000a', 'IMAGE', 'listing-images',
   '00000000-0000-0000-0000-00000000000a/10000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001.jpg', true);

select is((select count(*)::integer from storage.buckets
  where id in ('listing-images', 'listing-videos') and not public), 2, 'bucket الصور والفيديو خاصان');

-- الرفع
select pg_temp.login('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('listing-images',
    '00000000-0000-0000-0000-00000000000a/10000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001.jpg')$$,
  '42501', null, 'مستخدم آخر لا يرفع إلى مسار غيره');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('listing-images',
    '00000000-0000-0000-0000-00000000000a/10000000-0000-0000-0000-000000000001/unregistered.jpg')$$,
  '42501', null, 'مسار غير مسجل في media مرفوض');
select lives_ok(
  $$insert into storage.objects (bucket_id, name) values ('listing-images',
    '00000000-0000-0000-0000-00000000000a/10000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001.jpg')$$,
  'المالك يرفع إلى مسار مسجل بانتظار الرفع');
select is((select count(*)::integer from storage.objects where bucket_id = 'listing-images'), 1, 'المالك يقرأ ملفه');
-- سياسة الحذف لا تختبر هنا: التخزين يمنع الحذف المباشر بـSQL (storage.protect_delete)
-- ويشترط واجهة التخزين؛ تختبر من العميل في mobile_app/test_backend.
reset role;

-- قبل النشر: لا يقرؤه غير المالك
select pg_temp.login('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select is((select count(*)::integer from storage.objects where bucket_id = 'listing-images'), 0,
  'مستخدم آخر لا يقرأ وسائط مسودة');
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
select is((select count(*)::integer from storage.objects where bucket_id = 'listing-images'), 0,
  'الزائر لا يقرأ وسائط مسودة');
select is(public.storage_object_is_public('listing-images',
  '00000000-0000-0000-0000-00000000000a/10000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001.jpg'),
  false, 'وسيط المسودة غير عام');
reset role;

-- النشر
update public.media set status = 'READY', mime_type = 'image/jpeg', size_bytes = 1000
  where id = '30000000-0000-0000-0000-000000000001';
update public.listing_versions set
    title = 'ناقة مجاهيم للبيع', description = 'وصف كاف لاجتياز الحد الأدنى للطول',
    breed_id = (select id from public.breeds order by id limit 1), sex = 'FEMALE', age_months = 48,
    region_id = 1, city_id = (select id from public.cities where region_id = 1 order by id limit 1),
    health_notes = 'لا توجد عيوب معروفة', owner_declaration_at = now(),
    offer_type = 'FIXED_PRICE', price = 25000,
    contact_phone = '+966500000009', contact_call_enabled = true, contact_consent_at = now(),
    settings_version = 1, content_hash = 'hash-1', submitted_at = now(), status = 'SUBMITTED'
  where id = '20000000-0000-0000-0000-000000000001';
update public.listing_versions set status = 'APPROVED', decided_at = now()
  where id = '20000000-0000-0000-0000-000000000001';
update public.listings set status = 'PUBLISHED',
    current_version_id = '20000000-0000-0000-0000-000000000001',
    published_version_id = '20000000-0000-0000-0000-000000000001',
    first_submitted_at = now(), first_published_at = now(), published_version_at = now(),
    last_published_at = now(), visibility_updated_at = now()
  where id = '10000000-0000-0000-0000-000000000001';

set local role anon;
select is((select count(*)::integer from storage.objects where bucket_id = 'listing-images'), 1,
  'الزائر يقرأ وسائط إعلان منشور');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select is((select count(*)::integer from storage.objects where bucket_id = 'listing-images'), 1,
  'مستخدم آخر يقرأ وسائط إعلان منشور');
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('listing-images',
    '00000000-0000-0000-0000-00000000000b/x/y.jpg')$$,
  '42501', null, 'لا رفع لمسار غير مسجل حتى في مجلد المستخدم');
reset role;

-- الإخفاء يسري من الطلب التالي
update public.listings set status = 'HIDDEN' where id = '10000000-0000-0000-0000-000000000001';
select set_config('request.jwt.claims', '', true);
set local role anon;
select is((select count(*)::integer from storage.objects where bucket_id = 'listing-images'), 0,
  'الزائر لا يقرأ وسائط إعلان مخفي');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select is((select count(*)::integer from storage.objects where bucket_id = 'listing-images'), 1,
  'المالك يبقى قادرًا على قراءة وسائط إعلانه المخفي');
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('listing-images',
    '00000000-0000-0000-0000-00000000000a/10000000-0000-0000-0000-000000000001/again.jpg')$$,
  '42501', null, 'لا رفع إلى مسار غير مسجل بعد النشر');
reset role;

update public.listings set status = 'ARCHIVED' where id = '10000000-0000-0000-0000-000000000001';
set local role anon;
select is((select count(*)::integer from storage.objects where bucket_id = 'listing-images'), 0,
  'الزائر لا يقرأ وسائط إعلان مؤرشف');
reset role;

select * from finish();
rollback;
