-- 01 baseline_security — MOBILE-BE-101
-- الأساس الأمني: لا يحصل دور عميل على صلاحية لم تمنح له صراحة في ترحيل لاحق.
-- المرجع: AD-NFR-002، TEAM-DEC-007، supabase/README.md «قواعد المخطط».

-- 1) الصلاحيات الافتراضية
-- Supabase يمنح anon وauthenticated كل الصلاحيات على ما ينشئه postgres في public.
-- تسحب هنا، فيصير كل جدول أو تسلسل أو دالة جديدة مغلقة إلى أن يمنحها ترحيلها.
-- service_role يبقى كما هو: يستخدمه الخادم (دوال Edge) ولا يصل إلى العميل.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on functions from anon, authenticated;

-- EXECUTE يمنح لـPUBLIC على كل دالة جديدة افتراضيًا في Postgres. هذا الافتراضي عام
-- (غير مرتبط بمخطط) ولا يلغيه سحب على مستوى المخطط، فيسحب على المستوى العام.
alter default privileges for role postgres
  revoke execute on functions from public;

-- ما قد يكون موجودًا في public قبل هذا الترحيل.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

-- 2) مخطط private: الدوال المساعدة والمنطق الداخلي. غير مكشوف للـAPI
-- (ليس ضمن api.schemas) ولا تملك أدوار العميل USAGE عليه.
create schema private;
revoke all on schema private from public;
grant usage on schema private to service_role;

comment on schema private is
  'دوال مساعدة داخلية تستدعيها دوال public من نوع SECURITY DEFINER. لا صلاحية لأدوار العميل.';

-- 3) الامتدادات
create extension if not exists pg_trgm with schema extensions;

-- 4) رفع الأخطاء بصيغة العقد
-- الرمز الثابت في message، والتفاصيل JSON في detail (يصل العميل عبر PostgREST
-- في الحقلين message وdetails). الرموز تسرد في contracts/api/errors.json.
create function private.raise_error(
  p_code text,
  p_details jsonb default '{}'::jsonb
)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_code is null or p_code !~ '^[A-Z][A-Z0-9_]*$' then
    raise exception using
      errcode = 'P0001',
      message = 'INTERNAL_ERROR',
      detail = pg_catalog.jsonb_build_object('reason', 'invalid error code')::text;
  end if;

  raise exception using
    errcode = 'P0001',
    message = p_code,
    detail = coalesce(p_details, '{}'::jsonb)::text;
end;
$$;

comment on function private.raise_error(text, jsonb) is
  'يرفع خطأ برمز ثابت في message وتفاصيل JSON في detail.';
