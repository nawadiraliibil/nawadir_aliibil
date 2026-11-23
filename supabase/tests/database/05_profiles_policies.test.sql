-- MOBILE-BE-103 — الترحيل 05 profiles_policies
begin;

create extension if not exists pgtap with schema extensions;

select plan(27);

-- حسابات اختبار وهمية: مستخدمان بالهاتف وحساب بريد (موظف) دون ملف شخصي.
insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002');
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'staff@example.test');

create function pg_temp.login(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
$$;

select is((select count(*)::integer from public.profiles
  where id in ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b')),
  2, 'ملف شخصي ينشأ تلقائيًا لحساب الهاتف');
select is((select count(*)::integer from public.profiles where id = '00000000-0000-0000-0000-00000000000c'),
  0, 'لا ملف شخصي لحساب البريد');

select table_privs_are('public', 'profiles', 'authenticated', array['SELECT'], 'authenticated: SELECT فقط على profiles');
select table_privs_are('public', 'profiles', 'anon', array[]::text[], 'anon بلا صلاحية على profiles');
select table_privs_are('public', 'policy_documents', 'authenticated', array[]::text[], 'policy_documents مغلق؛ القراءة بالدالة');

-- شرط النشر قبل الإكمال
select throws_ok(
  $$select private.assert_can_publish('00000000-0000-0000-0000-00000000000a')$$,
  'P0001', 'PROFILE_INCOMPLETE', 'لا نشر قبل إكمال البيانات');

-- المستخدم أ
select pg_temp.login('00000000-0000-0000-0000-00000000000a');
set local role authenticated;

select is((select count(*)::integer from public.profiles), 1, 'المستخدم يرى ملفه فقط');
select is((public.get_my_account() ->> 'profile_complete')::boolean, false, 'الملف غير مكتمل في البداية');
select is(jsonb_array_length(public.get_my_account() -> 'pending_policies'), 2, 'نصان بانتظار الموافقة');
select is((public.get_my_account() ->> 'can_publish')::boolean, false, 'لا أهلية للنشر في البداية');

select throws_ok(
  $$update public.profiles set display_name = 'x'$$,
  '42501', null, 'لا تعديل مباشر للملف');
select throws_ok(
  $$insert into public.policy_consents (user_id, document_id) values ('00000000-0000-0000-0000-00000000000a', 1)$$,
  '42501', null, 'لا إدراج مباشر للموافقة');

select throws_ok(
  $$select public.update_my_profile('أ', 1)$$,
  'P0001', 'VALIDATION_FAILED', 'اسم قصير مرفوض');
select throws_ok(
  $$select public.update_my_profile('اسم صالح', 999)$$,
  'P0001', 'VALIDATION_FAILED', 'منطقة غير موجودة مرفوضة');

select is(
  public.update_my_profile('  أبو   محمد  ', 1) ->> 'display_name',
  'أبو محمد', 'اسم العرض يحفظ بعد توحيد الفراغات');
select is((public.get_my_account() ->> 'profile_complete')::boolean, true, 'الملف مكتمل بعد الحفظ');
select is((public.get_my_account() ->> 'can_publish')::boolean, false, 'لا نشر قبل الموافقة');

select throws_ok(
  $$select public.accept_policies(array[999999])$$,
  'P0001', 'VALIDATION_FAILED', 'موافقة على نص غير سارٍ مرفوضة');

select is(
  jsonb_array_length(public.accept_policies(
    (select array_agg((d ->> 'id')::integer) from jsonb_array_elements(public.get_current_policies()) d)
  ) -> 'pending_policies'),
  0, 'لا نصوص معلقة بعد الموافقة');
select is((public.get_my_account() ->> 'can_publish')::boolean, true, 'أهلية النشر بعد الإكمال والموافقة');
select lives_ok(
  $$select public.accept_policies(
    (select array_agg((d ->> 'id')::integer) from jsonb_array_elements(public.get_current_policies()) d))$$,
  'تكرار الموافقة لا يفشل');

reset role;
select is((select count(*)::integer from public.policy_consents
  where user_id = '00000000-0000-0000-0000-00000000000a'), 2, 'موافقتان فقط بعد التكرار');

-- نص جديد يعيد طلب الموافقة
insert into public.policy_documents (kind, version, title, body) values ('TERMS', 2, 'شروط الاختبار', 'نص');
select throws_ok(
  $$select private.assert_can_publish('00000000-0000-0000-0000-00000000000a')$$,
  'P0001', 'POLICIES_NOT_ACCEPTED', 'إصدار جديد من الشروط يوقف النشر حتى الموافقة');

-- حساب معلق
update public.profiles set status = 'SUSPENDED' where id = '00000000-0000-0000-0000-00000000000a';
set local role authenticated;
select throws_ok(
  $$select public.update_my_profile('اسم آخر', 1)$$,
  'P0001', 'ACCOUNT_SUSPENDED', 'الحساب المعلق لا يعدل ملفه');
reset role;

-- حساب البريد لا ملف له
select pg_temp.login('00000000-0000-0000-0000-00000000000c');
set local role authenticated;
select throws_ok(
  $$select public.get_my_account()$$,
  'P0001', 'FORBIDDEN', 'حساب بلا ملف شخصي مرفوض');
reset role;

-- الزائر
select set_config('request.jwt.claims', '', true);
set local role anon;
select is(jsonb_array_length(public.get_current_policies()), 2, 'الزائر يقرأ النصوص السارية');
select throws_ok(
  $$select public.get_my_account()$$,
  '42501', null, 'الزائر لا يستدعي دوال الحساب');
reset role;

select * from finish();
rollback;
