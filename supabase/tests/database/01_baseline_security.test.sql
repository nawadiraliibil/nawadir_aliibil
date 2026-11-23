-- MOBILE-BE-101 — الترحيل 01 baseline_security
begin;

create extension if not exists pgtap with schema extensions;

select plan(18);

-- مخطط private
select has_schema('private');
select ok(not has_schema_privilege('anon', 'private', 'usage'), 'anon بلا USAGE على private');
select ok(not has_schema_privilege('authenticated', 'private', 'usage'), 'authenticated بلا USAGE على private');
select ok(not has_schema_privilege('anon', 'private', 'create'), 'anon بلا CREATE على private');
select ok(not has_schema_privilege('authenticated', 'public', 'create'), 'authenticated بلا CREATE على public');

-- الامتداد
select has_extension('pg_trgm');

-- الصلاحيات الافتراضية: ما ينشأ في public مغلق أمام أدوار العميل
create table public._t_default_privs (id bigint generated always as identity primary key);
create function public._f_default_privs() returns integer language sql set search_path = '' as 'select 1';

select table_privs_are('public', '_t_default_privs', 'anon', array[]::text[], 'جدول جديد: لا صلاحيات لـanon');
select table_privs_are('public', '_t_default_privs', 'authenticated', array[]::text[], 'جدول جديد: لا صلاحيات لـauthenticated');
select sequence_privs_are('public', '_t_default_privs_id_seq', 'anon', array[]::text[], 'تسلسل جديد: لا صلاحيات لـanon');
select sequence_privs_are('public', '_t_default_privs_id_seq', 'authenticated', array[]::text[], 'تسلسل جديد: لا صلاحيات لـauthenticated');
select function_privs_are('public', '_f_default_privs', array[]::text[], 'anon', array[]::text[], 'دالة جديدة: لا EXECUTE لـanon');
select function_privs_are('public', '_f_default_privs', array[]::text[], 'authenticated', array[]::text[], 'دالة جديدة: لا EXECUTE لـauthenticated');
select function_privs_are('public', '_f_default_privs', array[]::text[], 'service_role', array['EXECUTE'], 'دالة جديدة: service_role يحتفظ بـEXECUTE');

drop function public._f_default_privs();
drop table public._t_default_privs;

-- دالة رفع الأخطاء
select has_function('private', 'raise_error', array['text', 'jsonb']);

select throws_ok(
  $$select private.raise_error('INVALID_STATE', '{"field":"status"}')$$,
  'P0001', 'INVALID_STATE', 'الرمز في message'
);

create function pg_temp.error_detail() returns jsonb language plpgsql as $$
declare
  v_detail text;
begin
  perform private.raise_error('VALIDATION_FAILED', '{"fields":["title"]}');
  return null;
exception when sqlstate 'P0001' then
  get stacked diagnostics v_detail = pg_exception_detail;
  return v_detail::jsonb;
end;
$$;

select is(pg_temp.error_detail(), '{"fields":["title"]}'::jsonb, 'التفاصيل JSON في detail');

select throws_ok(
  $$select private.raise_error('not a code')$$,
  'P0001', 'INTERNAL_ERROR', 'رمز غير صالح يرفع INTERNAL_ERROR'
);

-- العميل لا يصل إلى private
set local role anon;
select throws_ok(
  $$select private.raise_error('INVALID_STATE')$$,
  '42501', null, 'anon لا يستدعي دوال private'
);
reset role;

select * from finish();
rollback;
