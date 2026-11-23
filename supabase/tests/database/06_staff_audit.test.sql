-- MOBILE-BE-104 — الترحيل 06 staff_audit
begin;

create extension if not exists pgtap with schema extensions;

select plan(34);

-- حسابات وهمية: a مدير، m مشرف، s موظف بلا دور، u مستخدم هاتف.
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'moderator@example.test'),
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'staff@example.test');
insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001');

insert into public.breeds (name_ar, is_active) values ('سلالة معطلة للاختبار', false);

create function pg_temp.login(p_user uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

-- تهيئة أول مدير
select throws_ok(
  $$select private.bootstrap_first_admin('00000000-0000-0000-0000-0000000000b1')$$,
  'P0001', 'VALIDATION_FAILED', 'حساب هاتف لا يصير مديرًا');
select lives_ok(
  $$select private.bootstrap_first_admin('00000000-0000-0000-0000-0000000000a1')$$,
  'تهيئة أول مدير');
select throws_ok(
  $$select private.bootstrap_first_admin('00000000-0000-0000-0000-0000000000a3')$$,
  'P0001', 'INVALID_STATE', 'التهيئة ترفض عند وجود مدير فعال');
select is((select action from public.audit_log order by id desc limit 1),
  'staff.bootstrap_admin', 'التهيئة مسجلة في سجل الإجراءات');

-- مستخدم عادي
select pg_temp.login('00000000-0000-0000-0000-0000000000b1', 'aal1');
set local role authenticated;
select throws_ok($$select public.admin_whoami()$$, 'P0001', 'FORBIDDEN', 'المستخدم العادي يرفض');
select throws_ok(
  $$select public.admin_grant_role('00000000-0000-0000-0000-0000000000a3', 'ADMIN')$$,
  'P0001', 'FORBIDDEN', 'المستخدم العادي لا يمنح دورًا');
select is(public.has_staff_capability('lookups.manage'), false, 'المستخدم العادي بلا قدرات');
select is((select count(*)::integer from public.admin_roles), 0, 'المستخدم العادي لا يقرأ الأدوار');
select is((select count(*)::integer from public.breeds where not is_active), 0, 'المستخدم العادي لا يرى قيمة معطلة');
reset role;

-- المدير دون aal2
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal1');
set local role authenticated;
select throws_ok($$select public.admin_whoami()$$, 'P0001', 'MFA_REQUIRED', 'جلسة دون aal2 ترفض');
select is((select count(*)::integer from public.audit_log), 0, 'لا قراءة للسجل دون aal2');
reset role;

-- المدير بـaal2
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;
select is(public.admin_whoami() ->> 'role', 'ADMIN', 'whoami: مدير');
select is(jsonb_array_length(public.admin_whoami() -> 'capabilities'), 12, 'المدير له كل القدرات');

select throws_ok(
  $$select public.admin_grant_role('00000000-0000-0000-0000-0000000000a1', 'MODERATOR')$$,
  'P0001', 'CANNOT_MODIFY_SELF', 'لا يغير الموظف دوره');
select throws_ok(
  $$select public.admin_revoke_role('00000000-0000-0000-0000-0000000000a1')$$,
  'P0001', 'CANNOT_MODIFY_SELF', 'لا يسحب الموظف دوره');
select throws_ok(
  $$select public.admin_grant_role('00000000-0000-0000-0000-0000000000a2', 'MODERATOR', array['staff.manage'])$$,
  'P0001', 'VALIDATION_FAILED', 'قدرة خاصة بالمدير لا تمنح لمشرف');
select throws_ok(
  $$select public.admin_grant_role('00000000-0000-0000-0000-0000000000a2', 'MODERATOR', array['unknown.cap'])$$,
  'P0001', 'VALIDATION_FAILED', 'قدرة غير معرفة مرفوضة');
select throws_ok(
  $$select public.admin_grant_role('00000000-0000-0000-0000-0000000000b1', 'MODERATOR', array['listings.review'])$$,
  'P0001', 'VALIDATION_FAILED', 'حساب مستخدم لا يمنح دور موظف');
select lives_ok(
  $$select public.admin_grant_role('00000000-0000-0000-0000-0000000000a2', 'MODERATOR',
      array['lookups.manage', 'listings.review', 'listings.review'])$$,
  'منح دور مشرف');
select throws_ok(
  $$insert into public.audit_log (action, resource_type) values ('x.y', 'z')$$,
  '42501', null, 'لا كتابة مباشرة في السجل');
select throws_ok(
  $$update public.admin_roles set role = 'ADMIN'$$,
  '42501', null, 'لا تعديل مباشر للأدوار');
reset role;

-- المشرف
select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal2');
set local role authenticated;
select is(public.admin_whoami() -> 'capabilities', '["listings.review", "lookups.manage"]'::jsonb,
  'whoami: قدرات المشرف دون تكرار');
select throws_ok(
  $$select public.admin_grant_role('00000000-0000-0000-0000-0000000000a3', 'MODERATOR')$$,
  'P0001', 'FORBIDDEN', 'مشرف دون staff.manage لا يمنح دورًا');
select is(public.has_staff_capability('settings.manage'), false, 'قدرة غير ممنوحة');
select is((select count(*)::integer from public.breeds where not is_active), 1, 'مدير القوائم يرى القيمة المعطلة');
select is((select count(*)::integer from public.settings_versions), 0, 'دون settings.manage لا يقرأ الإعدادات');
select is((select count(*)::integer from public.admin_roles), 1, 'المشرف يقرأ دوره فقط');
select is((select count(*)::integer from public.audit_log), 0, 'المشرف لا يقرأ السجل');
reset role;

-- سحب الدور يسري في الاستدعاء التالي
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;
select lives_ok(
  $$select public.admin_revoke_role('00000000-0000-0000-0000-0000000000a2', 'انتهاء التكليف')$$,
  'سحب دور المشرف');
select throws_ok(
  $$select public.admin_revoke_role('00000000-0000-0000-0000-0000000000a2')$$,
  'P0001', 'INVALID_STATE', 'سحب دور مسحوب مرفوض');
select is((select count(*)::integer from public.audit_log), 3, 'المدير يقرأ السجل: تهيئة ومنح وسحب');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal2');
set local role authenticated;
select throws_ok($$select public.admin_whoami()$$, 'P0001', 'FORBIDDEN', 'الدور المسحوب يرفض في الاستدعاء التالي');
select is((select count(*)::integer from public.breeds where not is_active), 0, 'القراءة الإدارية تتوقف بعد السحب');
reset role;

-- السجل إضافة فقط حتى لمالك القاعدة
select throws_ok(
  $$delete from public.audit_log$$,
  'P0001', 'APPEND_ONLY', 'السجل لا يحذف منه');

select * from finish();
rollback;
