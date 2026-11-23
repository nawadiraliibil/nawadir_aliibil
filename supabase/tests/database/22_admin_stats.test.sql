-- MOBILE-BE-402 — الترحيل 22 admin_stats
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002');
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mod@example.test');
select private.bootstrap_first_admin('00000000-0000-0000-0000-0000000000a1');
insert into public.admin_roles (user_id, role, capabilities)
  values ('00000000-0000-0000-0000-0000000000a2', 'MODERATOR', array['reports.handle', 'listings.review']);

create function pg_temp.login(p_user uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

update public.profiles set display_name = 'معلن', region_id = 1 where id = '00000000-0000-0000-0000-00000000000a';
update public.profiles set display_name = 'متابع', region_id = 1 where id = '00000000-0000-0000-0000-00000000000b';
insert into public.follows (follower_id, seller_id)
  values ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a');

select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok($$select public.admin_stats()$$, '42501', null, 'الزائر لا يقرأ التقارير');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal2');
set local role authenticated;
select throws_ok($$select public.admin_stats()$$, 'P0001', 'FORBIDDEN', 'المستخدم العادي مرفوض');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal2');
set local role authenticated;
select throws_ok($$select public.admin_stats()$$, 'P0001', 'FORBIDDEN', 'المشرف دون stats.read مرفوض');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal1');
set local role authenticated;
select throws_ok($$select public.admin_stats()$$, 'P0001', 'MFA_REQUIRED', 'يشترط aal2');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;
select is((public.admin_stats() -> 'accounts' ->> 'created')::integer, 2, 'الحسابات المنشأة في الفترة الافتراضية');
select is((public.admin_stats() -> 'accounts' ->> 'total')::integer, 2, 'إجمالي الحسابات');
select is((public.admin_stats() -> 'follows' ->> 'sellers_followed')::integer, 1, 'المتابعات');
select isnt(public.admin_stats() ->> 'generated_at', null, 'وقت التحديث');
select is(
  (public.admin_stats() #>> '{period,from}')::timestamptz < (public.admin_stats() #>> '{period,to}')::timestamptz,
  true, 'تعريف الفترة');
select is(
  (public.admin_stats(now() - interval '10 days', now() - interval '5 days') -> 'accounts' ->> 'created')::integer, 0,
  'فترة سابقة بلا نشاط');
select is(
  (public.admin_stats(now() - interval '1 day', now() + interval '1 day') -> 'accounts' ->> 'created')::integer, 2,
  'فترة تشمل اليوم');
select throws_ok($$select public.admin_stats(now(), now() - interval '1 day')$$, 'P0001', 'VALIDATION_FAILED',
  'نطاق معكوس');
select throws_ok($$select public.admin_stats(now() - interval '400 days', now())$$, 'P0001', 'VALIDATION_FAILED',
  'فترة أطول من سنة');
select is(public.admin_stats()::text ~ '(body|phone|display_name|user_id)', false, 'أعداد فقط');
reset role;

select * from finish();
rollback;
