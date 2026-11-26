-- MOBILE-AVATAR-20261126 — الترحيل 28 profile_avatar
begin;

create extension if not exists pgtap with schema extensions;

select plan(11);

insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002');

create function pg_temp.login(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

select is((select public from storage.buckets where id = 'avatars'), true, 'bucket الصور الرمزية عام');

select pg_temp.login('00000000-0000-0000-0000-00000000000a');
set local role authenticated;

select is(public.get_my_account() -> 'avatar_path', 'null'::jsonb, 'لا صورة في البداية');

-- الرفع في مجلد المالك فقط
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id) values ('avatars',
    '00000000-0000-0000-0000-00000000000a/a1.jpg', '00000000-0000-0000-0000-00000000000a')$$,
  'الرفع إلى مجلد المالك');
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('avatars',
    '00000000-0000-0000-0000-00000000000b/x.jpg')$$,
  '42501', null, 'لا رفع إلى مجلد غيره');

select is(public.set_my_avatar('00000000-0000-0000-0000-00000000000a/a1.jpg') ->> 'avatar_path',
  '00000000-0000-0000-0000-00000000000a/a1.jpg', 'ضبط الصورة');
select is(public.get_my_account() ->> 'avatar_path',
  '00000000-0000-0000-0000-00000000000a/a1.jpg', 'get_my_account يعيد المسار');

select throws_ok(
  $$select public.set_my_avatar('00000000-0000-0000-0000-00000000000b/x.jpg')$$,
  'P0001', 'VALIDATION_FAILED', 'مسار مجلد غيره مرفوض');
select throws_ok(
  $$select public.set_my_avatar('00000000-0000-0000-0000-00000000000a/missing.jpg')$$,
  'P0001', 'VALIDATION_FAILED', 'ملف غير مرفوع مرفوض');
select throws_ok(
  $$select public.set_my_avatar('../x')$$,
  'P0001', 'VALIDATION_FAILED', 'مسار مشوّه مرفوض');

select is(public.set_my_avatar(null) -> 'avatar_path', 'null'::jsonb, 'المسح بـnull');

-- الحذف عبر واجهة التخزين فقط (المشغل يمنع DELETE المباشر)؛ مغطى بفحص التكامل.
reset role;

select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok(
  $$select public.set_my_avatar(null)$$,
  '42501', null, 'الزائر لا يستدعي الدالة');
reset role;

select * from finish();
rollback;
