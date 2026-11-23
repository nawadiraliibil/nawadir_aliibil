-- 06 staff_audit — MOBILE-BE-104
-- الموظفون وأدوارهم وسجل الإجراءات: AD-FR-017، AD-FR-021، TEAM-DEC-011 البند 6.
-- الدور يفحص من admin_roles في كل استدعاء (لا JWT claim) مع اشتراط مستوى aal2،
-- فيسري سحب الدور في الاستدعاء التالي.

-- القدرات المعرفة. المصدر: ADMIN-HANDOFF-20261122.md القسم 3.
create function private.all_capabilities()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array[
    'listings.review', 'listings.hide', 'accounts.manage', 'reports.handle',
    'evidence.read', 'comments.moderate', 'ratings.moderate', 'lookups.manage',
    'settings.manage', 'staff.manage', 'audit.read', 'stats.read'
  ]::text[]
$$;

-- قدرات مدير المنصة وحده (SRS القسم 2): لا تمنح لمشرف.
create function private.admin_only_capabilities()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['staff.manage', 'audit.read', 'stats.read']::text[]
$$;

-- دور واحد لكل موظف. السحب تعطيل (is_active) لا حذف.
create table public.admin_roles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  role public.staff_role not null,
  -- قدرات المشرف. تهمل للمدير: له كل القدرات.
  capabilities text[] not null default array[]::text[],
  is_active boolean not null default true,
  granted_by uuid,
  granted_at timestamptz not null default now(),
  revoked_by uuid,
  revoked_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint admin_roles_capabilities_known
    check (capabilities <@ private.all_capabilities()),
  constraint admin_roles_moderator_capabilities
    check (role = 'ADMIN' or not (capabilities && private.admin_only_capabilities()))
);

create trigger admin_roles_set_updated_at before update on public.admin_roles
  for each row execute function private.set_updated_at();

-- سجل الإجراءات الإدارية: إضافة فقط، تكتبه الدوال نفسها.
create table public.audit_log (
  id bigint generated always as identity primary key,
  -- الفاعل؛ NULL لإجراء النظام (سكربت التهيئة).
  actor_id uuid,
  action text not null check (action ~ '^[a-z_]+(\.[a-z_]+)+$'),
  resource_type text not null,
  resource_id text,
  reason_code text,
  reason_text text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index audit_log_created_at_idx on public.audit_log (created_at desc);
create index audit_log_resource_idx on public.audit_log (resource_type, resource_id);
create index audit_log_actor_id_idx on public.audit_log (actor_id);

create trigger audit_log_append_only
  before update or delete on public.audit_log
  for each row execute function private.forbid_change();

create function private.audit(
  p_actor uuid,
  p_action text,
  p_resource_type text,
  p_resource_id text,
  p_details jsonb default '{}'::jsonb,
  p_reason_code text default null,
  p_reason_text text default null
)
returns void
language sql
set search_path = ''
as $$
  insert into public.audit_log
    (actor_id, action, resource_type, resource_id, details, reason_code, reason_text)
  values
    (p_actor, p_action, p_resource_type, p_resource_id,
     coalesce(p_details, '{}'::jsonb), p_reason_code, p_reason_text)
$$;

-- هل صاحب الجلسة موظف فعال بمستوى aal2 ويملك القدرة؟ تستخدمها سياسات القراءة.
-- في public لأن سياسات RLS تنفذ بصلاحيات المستعلم، ومخطط private مغلق أمامه.
-- لا تكشف شيئًا عن غير صاحب الجلسة.
create function public.has_staff_capability(p_capability text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select auth.jwt()) ->> 'aal', '') = 'aal2'
    and exists (
      select 1 from public.admin_roles r
      where r.user_id = (select auth.uid())
        and r.is_active
        and (r.role = 'ADMIN' or p_capability = any (r.capabilities))
    )
$$;

comment on function public.has_staff_capability(text) is
  'هل صاحب الجلسة موظف فعال بمستوى aal2 ويملك القدرة المذكورة.';

-- شرط كل دالة إدارية: موظف فعال، جلسة aal2، والقدرة المطلوبة (NULL: أي موظف).
create function private.require_staff(p_capability text)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_role public.admin_roles;
begin
  if v_uid is null then
    perform private.raise_error('AUTH_REQUIRED');
  end if;

  select * into v_role from public.admin_roles r
    where r.user_id = v_uid and r.is_active;
  if not found then
    perform private.raise_error('FORBIDDEN');
  end if;

  if coalesce(auth.jwt() ->> 'aal', '') <> 'aal2' then
    perform private.raise_error('MFA_REQUIRED');
  end if;

  if p_capability is not null
    and v_role.role <> 'ADMIN'
    and not (p_capability = any (v_role.capabilities))
  then
    perform private.raise_error(
      'FORBIDDEN', pg_catalog.jsonb_build_object('capability', p_capability));
  end if;

  return v_uid;
end;
$$;

-- قراءة الموظف
alter table public.admin_roles enable row level security;
alter table public.audit_log enable row level security;

grant select on public.admin_roles, public.audit_log,
  public.settings_versions, public.platform_settings to authenticated;

create policy admin_roles_read_own on public.admin_roles
  for select to authenticated using ((select auth.uid()) = user_id);
create policy admin_roles_read_staff on public.admin_roles
  for select to authenticated using ((select public.has_staff_capability('staff.manage')));
create policy audit_log_read_staff on public.audit_log
  for select to authenticated using ((select public.has_staff_capability('audit.read')));

create policy settings_versions_read_staff on public.settings_versions
  for select to authenticated using ((select public.has_staff_capability('settings.manage')));
create policy platform_settings_read_staff on public.platform_settings
  for select to authenticated using ((select public.has_staff_capability('settings.manage')));

-- القيم المعطلة في القوائم يراها من يديرها.
create policy regions_read_staff on public.regions
  for select to authenticated using ((select public.has_staff_capability('lookups.manage')));
create policy cities_read_staff on public.cities
  for select to authenticated using ((select public.has_staff_capability('lookups.manage')));
create policy breeds_read_staff on public.breeds
  for select to authenticated using ((select public.has_staff_capability('lookups.manage')));

create policy profiles_read_staff on public.profiles
  for select to authenticated using ((select public.has_staff_capability('accounts.manage')));

-- دوال الإدارة

create function public.admin_whoami()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_staff(null);
  v_role public.admin_roles;
begin
  select * into v_role from public.admin_roles r where r.user_id = v_uid;
  return pg_catalog.jsonb_build_object(
    'user_id', v_uid,
    'role', v_role.role,
    'capabilities', pg_catalog.to_jsonb(
      case when v_role.role = 'ADMIN' then private.all_capabilities() else v_role.capabilities end)
  );
end;
$$;

comment on function public.admin_whoami() is
  'دور الموظف صاحب الجلسة وقدراته. لإظهار القوائم في اللوحة فقط؛ الصلاحية تفحص في كل دالة.';

-- حساب الموظف: حساب بريد دون ملف مستخدم (حسابات الموظفين منفصلة).
create function private.is_staff_account(p_user uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from auth.users u where u.id = p_user and u.email is not null)
    and not exists (select 1 from public.profiles p where p.id = p_user)
$$;

create function private.validate_role_input(
  p_user uuid,
  p_role public.staff_role,
  p_capabilities text[]
)
returns text[]
language plpgsql
set search_path = ''
as $$
declare
  v_caps text[] := coalesce(p_capabilities, array[]::text[]);
  v_fields text[] := array[]::text[];
begin
  if p_user is null or not private.is_staff_account(p_user) then
    v_fields := v_fields || 'user_id'::text;
  end if;
  if p_role is null then
    v_fields := v_fields || 'role'::text;
  end if;

  if p_role = 'ADMIN' then
    v_caps := array[]::text[];
  elsif pg_catalog.array_position(v_caps, null) is not null
    or not (v_caps <@ private.all_capabilities())
    or v_caps && private.admin_only_capabilities()
  then
    v_fields := v_fields || 'capabilities'::text;
  end if;

  if pg_catalog.cardinality(v_fields) > 0 then
    perform private.raise_error(
      'VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.to_jsonb(v_fields)));
  end if;

  return (select coalesce(pg_catalog.array_agg(distinct c order by c), array[]::text[])
          from pg_catalog.unnest(v_caps) as c);
end;
$$;

create function public.admin_grant_role(
  p_user_id uuid,
  p_role public.staff_role,
  p_capabilities text[] default array[]::text[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('staff.manage');
  v_caps text[];
  v_before public.admin_roles;
begin
  if p_user_id = v_actor then
    perform private.raise_error('CANNOT_MODIFY_SELF');
  end if;

  v_caps := private.validate_role_input(p_user_id, p_role, p_capabilities);

  lock table public.admin_roles in share row exclusive mode;

  select * into v_before from public.admin_roles r where r.user_id = p_user_id;

  -- تحويل مدير إلى مشرف لا يترك المنصة دون مدير فعال.
  if v_before.role = 'ADMIN' and v_before.is_active and p_role <> 'ADMIN'
    and not exists (
      select 1 from public.admin_roles r
      where r.role = 'ADMIN' and r.is_active and r.user_id <> p_user_id)
  then
    perform private.raise_error('LAST_ADMIN');
  end if;

  insert into public.admin_roles as r
    (user_id, role, capabilities, is_active, granted_by, granted_at, revoked_by, revoked_at)
  values (p_user_id, p_role, v_caps, true, v_actor, now(), null, null)
  on conflict (user_id) do update
    set role = excluded.role,
        capabilities = excluded.capabilities,
        is_active = true,
        granted_by = excluded.granted_by,
        granted_at = excluded.granted_at,
        revoked_by = null,
        revoked_at = null;

  perform private.audit(
    v_actor, 'staff.role_granted', 'admin_role', p_user_id::text,
    pg_catalog.jsonb_build_object(
      'role', p_role, 'capabilities', pg_catalog.to_jsonb(v_caps),
      'previous_role', v_before.role, 'previous_active', v_before.is_active));

  return pg_catalog.jsonb_build_object(
    'user_id', p_user_id, 'role', p_role,
    'capabilities', pg_catalog.to_jsonb(v_caps), 'is_active', true);
end;
$$;

comment on function public.admin_grant_role(uuid, public.staff_role, text[]) is
  'منح دور لحساب موظف أو تعديله. القدرة: staff.manage.';

create function public.admin_revoke_role(p_user_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('staff.manage');
  v_before public.admin_roles;
begin
  if p_user_id = v_actor then
    perform private.raise_error('CANNOT_MODIFY_SELF');
  end if;

  lock table public.admin_roles in share row exclusive mode;

  select * into v_before from public.admin_roles r where r.user_id = p_user_id;
  if not found or not v_before.is_active then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('reason', 'no_active_role'));
  end if;

  if v_before.role = 'ADMIN' and not exists (
    select 1 from public.admin_roles r
    where r.role = 'ADMIN' and r.is_active and r.user_id <> p_user_id)
  then
    perform private.raise_error('LAST_ADMIN');
  end if;

  update public.admin_roles r
    set is_active = false, revoked_by = v_actor, revoked_at = now()
    where r.user_id = p_user_id;

  perform private.audit(
    v_actor, 'staff.role_revoked', 'admin_role', p_user_id::text,
    pg_catalog.jsonb_build_object('role', v_before.role),
    null, nullif(btrim(coalesce(p_reason, '')), ''));

  return pg_catalog.jsonb_build_object(
    'user_id', p_user_id, 'role', v_before.role, 'is_active', false);
end;
$$;

comment on function public.admin_revoke_role(uuid, text) is
  'سحب دور موظف. يسري في استدعائه التالي. القدرة: staff.manage.';

-- تهيئة أول مدير: تنفذ مرة واحدة من محرر SQL بصلاحية قاعدة البيانات
-- (supabase/scripts/admin/bootstrap_first_admin.sql). ترفض إن وجد مدير فعال.
create function private.bootstrap_first_admin(p_user_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  lock table public.admin_roles in share row exclusive mode;

  if exists (select 1 from public.admin_roles r where r.role = 'ADMIN' and r.is_active) then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('reason', 'admin_exists'));
  end if;
  if p_user_id is null or not private.is_staff_account(p_user_id) then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('user_id')));
  end if;

  insert into public.admin_roles (user_id, role, is_active)
  values (p_user_id, 'ADMIN', true)
  on conflict (user_id) do update
    set role = 'ADMIN', capabilities = array[]::text[], is_active = true,
        granted_by = null, granted_at = now(), revoked_by = null, revoked_at = null;

  perform private.audit(null, 'staff.bootstrap_admin', 'admin_role', p_user_id::text);
end;
$$;

grant execute on function public.has_staff_capability(text) to authenticated;
grant execute on function public.admin_whoami() to authenticated;
grant execute on function public.admin_grant_role(uuid, public.staff_role, text[]) to authenticated;
grant execute on function public.admin_revoke_role(uuid, text) to authenticated;
