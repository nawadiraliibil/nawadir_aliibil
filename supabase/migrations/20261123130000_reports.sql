-- 18 reports — MOBILE-BE-303
-- البلاغات وإدارتها والوصول المقيد للأدلة: AD-FR-015، AD-FR-019، AD-FR-036،
-- AD-AC-008، AD-AC-020. البلاغ خاص: لا يراه المبلغ عنه ولا يكشف مقدمه.
-- لا وصول عام للمحادثات: رسالة مبلّغ عنها وسياقها المحدود عبر دالة مسجلة.

create sequence public.report_ref_seq start 1001;

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  -- رقم مرجعي يراه المبلغ ويذكره للدعم.
  ref text not null unique default ('R-' || nextval('public.report_ref_seq')::text),
  reporter_id uuid not null references public.profiles (id),
  target_type text not null check (target_type in ('LISTING', 'ACCOUNT', 'MESSAGE', 'COMMENT')),
  target_id uuid not null,
  -- صاحب المحتوى المبلغ عنه، لتجميع بلاغات الشخص نفسه.
  target_user_id uuid not null references public.profiles (id),
  -- الإعلان المتصل بالهدف إن وجد (إعلان، رد، محادثة).
  listing_id uuid references public.listings (id),
  reason text not null check (reason in
    ('SPAM', 'FRAUD', 'ABUSE', 'MISLEADING', 'PROHIBITED_CONTENT', 'OTHER')),
  description text check (description is null or char_length(description) <= 2000),
  -- معرف طلب الإرسال لمنع التكرار (AD-NFR-005).
  request_id uuid not null,
  status text not null default 'OPEN' check (status in ('OPEN', 'IN_REVIEW', 'CLOSED')),
  assigned_to uuid references auth.users (id),
  -- الإغلاق: السبب والرد الذي يراه المبلغ، وملاحظة داخلية منفصلة.
  close_reason text check (close_reason in ('ACTION_TAKEN', 'NO_VIOLATION', 'DUPLICATE', 'INVALID')),
  response_text text check (response_text is null or char_length(response_text) <= 1000),
  internal_note text check (internal_note is null or char_length(internal_note) <= 2000),
  closed_by uuid references auth.users (id),
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (reporter_id, request_id),
  constraint reports_closed_complete check (
    (status = 'CLOSED') = (close_reason is not null and closed_by is not null and closed_at is not null)),
  constraint reports_not_self check (reporter_id <> target_user_id)
);

create trigger reports_set_updated_at before update on public.reports
  for each row execute function private.set_updated_at();

-- بلاغ مفتوح واحد لكل مبلغ وهدف.
create unique index reports_one_open_per_target_idx
  on public.reports (reporter_id, target_type, target_id) where status <> 'CLOSED';
create index reports_queue_idx on public.reports (status, created_at, id);
create index reports_target_user_idx on public.reports (target_user_id);
create index reports_reporter_day_idx on public.reports (reporter_id, created_at desc);

-- سجل الاطلاع على الأدلة: إضافة فقط.
create table public.report_evidence_access (
  id bigint generated always as identity primary key,
  report_id uuid not null references public.reports (id),
  actor_id uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create trigger report_evidence_access_append_only
  before update or delete on public.report_evidence_access
  for each row execute function private.forbid_change();

alter table public.reports enable row level security;
alter table public.report_evidence_access enable row level security;

-- الموظف بقدرة البلاغات يقرأ البلاغات. المبلغ والمبلغ عنه لا يقرآن الجدول.
create policy reports_read_staff on public.reports
  for select to authenticated using ((select public.has_staff_capability('reports.handle')));

create policy report_evidence_access_read_audit on public.report_evidence_access
  for select to authenticated using ((select public.has_staff_capability('audit.read')));

grant select on public.reports to authenticated;
grant select on public.report_evidence_access to authenticated;

------------------------------------------------------------------------------
-- إرسال بلاغ
------------------------------------------------------------------------------

-- p_target_type: LISTING | ACCOUNT | MESSAGE | COMMENT. لا إبلاغ عن شيء لا يملك
-- المبلغ حق الاطلاع عليه (رسالة في محادثة لا يشارك فيها، أو إعلان غير منشور).
-- التكرار بمعرف الطلب يعيد البلاغ الأول؛ بلاغ مفتوح لهدف أبلغ عنه سابقًا يعيده
-- (duplicate=true) دون إنشاء ثانٍ.
create function public.submit_report(
  p_target_type text,
  p_target_id uuid,
  p_reason text,
  p_description text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_desc text := nullif(pg_catalog.btrim(coalesce(p_description, '')), '');
  v_limit integer := (private.published_settings() #>> '{rate_limits,reports_per_day}')::integer;
  v_existing public.reports;
  v_target_user uuid;
  v_listing uuid;
  v_report public.reports;
  v_recent integer;
begin
  if p_request_id is null or p_target_id is null
     or p_target_type is null or p_target_type not in ('LISTING', 'ACCOUNT', 'MESSAGE', 'COMMENT')
     or p_reason is null
     or p_reason not in ('SPAM', 'FRAUD', 'ABUSE', 'MISLEADING', 'PROHIBITED_CONTENT', 'OTHER')
     or pg_catalog.char_length(v_desc) > 2000
     or (p_reason = 'OTHER' and v_desc is null) then
    perform private.raise_error('VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', (
      select pg_catalog.jsonb_agg(f) from (
        select 'request_id' as f where p_request_id is null
        union all select 'p_target_id' where p_target_id is null
        union all select 'p_target_type' where p_target_type is null
          or p_target_type not in ('LISTING', 'ACCOUNT', 'MESSAGE', 'COMMENT')
        union all select 'p_reason' where p_reason is null
          or p_reason not in ('SPAM', 'FRAUD', 'ABUSE', 'MISLEADING', 'PROHIBITED_CONTENT', 'OTHER')
        union all select 'p_description' where pg_catalog.char_length(v_desc) > 2000
          or (p_reason = 'OTHER' and v_desc is null)) x)));
  end if;

  -- إعادة الطلب نفسه.
  select * into v_existing from public.reports r
    where r.reporter_id = v_uid and r.request_id = p_request_id;
  if found then
    return pg_catalog.jsonb_build_object(
      'report_id', v_existing.id, 'ref', v_existing.ref, 'status', v_existing.status,
      'created', false, 'duplicate', false);
  end if;

  -- الهدف: يجب أن يكون مما يحق للمبلغ رؤيته، وليس له.
  if p_target_type = 'LISTING' then
    select l.owner_id, l.id into v_target_user, v_listing from public.listings l
      where l.id = p_target_id and l.status = 'PUBLISHED' and l.deleted_at is null;
  elsif p_target_type = 'ACCOUNT' then
    select p.id into v_target_user from public.profiles p where p.id = p_target_id;
  elsif p_target_type = 'COMMENT' then
    select c.author_id, c.listing_id into v_target_user, v_listing
      from public.comments c
      join public.listings l on l.id = c.listing_id and l.status = 'PUBLISHED' and l.deleted_at is null
      where c.id = p_target_id and c.deleted_at is null and c.hidden_at is null;
  else
    -- رسالة: المبلغ طرف في المحادثة والرسالة من الطرف الآخر.
    select m.sender_id, c.listing_id into v_target_user, v_listing
      from public.messages m
      join public.conversations c on c.id = m.conversation_id
      where m.id = p_target_id and v_uid in (c.buyer_id, c.seller_id) and m.sender_id <> v_uid;
  end if;
  if v_target_user is null then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'report_target'));
  end if;
  if v_target_user = v_uid then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_target_id')));
  end if;

  -- بلاغ مفتوح لهذا الهدف.
  select * into v_existing from public.reports r
    where r.reporter_id = v_uid and r.target_type = p_target_type and r.target_id = p_target_id
      and r.status <> 'CLOSED';
  if found then
    return pg_catalog.jsonb_build_object(
      'report_id', v_existing.id, 'ref', v_existing.ref, 'status', v_existing.status,
      'created', false, 'duplicate', true);
  end if;

  select count(*)::integer into v_recent from public.reports r
    where r.reporter_id = v_uid and r.created_at > now() - interval '24 hours';
  if v_recent >= v_limit then
    perform private.raise_error('RATE_LIMITED', pg_catalog.jsonb_build_object(
      'limit', v_limit, 'window_hours', 24,
      'retry_at', (select min(r.created_at) + interval '24 hours' from public.reports r
        where r.reporter_id = v_uid and r.created_at > now() - interval '24 hours')));
  end if;

  insert into public.reports
    (reporter_id, target_type, target_id, target_user_id, listing_id, reason, description, request_id)
    values (v_uid, p_target_type, p_target_id, v_target_user, v_listing, p_reason, v_desc, p_request_id)
    returning * into v_report;

  return pg_catalog.jsonb_build_object(
    'report_id', v_report.id, 'ref', v_report.ref, 'status', v_report.status,
    'created', true, 'duplicate', false);
end;
$$;

comment on function public.submit_report(text, uuid, text, text, uuid) is
  'يرسل بلاغًا عن إعلان أو حساب أو رسالة أو رد. التكرار بمعرف الطلب آمن؛ لا بلاغ عما لا يحق للمبلغ رؤيته.';

-- حالة بلاغ المبلغ: رقمه وحالته ورد الإدارة عند الإغلاق. لا ملاحظات داخلية.
create function public.get_report_status(p_report_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_report public.reports;
begin
  select * into v_report from public.reports r where r.id = p_report_id and r.reporter_id = v_uid;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'report'));
  end if;
  return pg_catalog.jsonb_build_object(
    'report_id', v_report.id, 'ref', v_report.ref, 'status', v_report.status,
    'target_type', v_report.target_type, 'created_at', v_report.created_at,
    'closed_at', v_report.closed_at, 'response_text', v_report.response_text);
end;
$$;

comment on function public.get_report_status(uuid) is
  'حالة بلاغ المبلغ ورد الإدارة عند الإغلاق، دون ملاحظات داخلية.';

------------------------------------------------------------------------------
-- إدارة البلاغات (reports.handle)
------------------------------------------------------------------------------

create function private.lock_report(p_report uuid)
returns public.reports
language plpgsql
set search_path = ''
as $$
declare
  v_report public.reports;
begin
  select * into v_report from public.reports r where r.id = p_report for update;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'report'));
  end if;
  return v_report;
end;
$$;

-- إسناد بلاغ إلى مسؤول (نفسه إن لم يحدد) فيصير قيد المراجعة.
create function public.admin_assign_report(p_report_id uuid, p_assignee uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('reports.handle');
  v_assignee uuid := coalesce(p_assignee, v_actor);
  v_report public.reports;
begin
  v_report := private.lock_report(p_report_id);
  if v_report.status = 'CLOSED' then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('status', v_report.status));
  end if;
  if not exists (
    select 1 from public.admin_roles ar
    where ar.user_id = v_assignee and ar.is_active
      and (ar.role = 'ADMIN' or 'reports.handle' = any (ar.capabilities))) then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_assignee')));
  end if;
  update public.reports r set assigned_to = v_assignee, status = 'IN_REVIEW' where r.id = v_report.id;
  perform private.audit(
    v_actor, 'report.assigned', 'report', v_report.id::text,
    pg_catalog.jsonb_build_object('assignee', v_assignee));
  return pg_catalog.jsonb_build_object('report_id', v_report.id, 'status', 'IN_REVIEW', 'assigned_to', v_assignee);
end;
$$;

comment on function public.admin_assign_report(uuid, uuid) is
  'يسند بلاغًا إلى مسؤول ويجعله قيد المراجعة. القدرة: reports.handle.';

-- إعادة فتح بلاغ قيد المراجعة أو تحويله إليها دون إغلاق. الإغلاق بدالته.
create function public.admin_set_report_status(p_report_id uuid, p_status text, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('reports.handle');
  v_note text := nullif(pg_catalog.btrim(coalesce(p_note, '')), '');
  v_report public.reports;
begin
  if p_status is null or p_status not in ('OPEN', 'IN_REVIEW') or pg_catalog.char_length(v_note) > 2000 then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_status')));
  end if;
  v_report := private.lock_report(p_report_id);
  if v_report.status = 'CLOSED' then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('status', v_report.status));
  end if;
  update public.reports r set
    status = p_status,
    internal_note = coalesce(v_note, r.internal_note)
    where r.id = v_report.id;
  perform private.audit(
    v_actor, 'report.status_changed', 'report', v_report.id::text,
    pg_catalog.jsonb_build_object('from', v_report.status, 'to', p_status), null, v_note);
  return pg_catalog.jsonb_build_object('report_id', v_report.id, 'status', p_status);
end;
$$;

comment on function public.admin_set_report_status(uuid, text, text) is
  'يغير حالة بلاغ بين مفتوح وقيد المراجعة. القدرة: reports.handle.';

-- إغلاق بلاغ بقرار: سبب الإغلاق إلزامي، والرد للمبلغ اختياري، والملاحظة داخلية.
-- يصل المبلغ إشعار بالإغلاق دون الملاحظة الداخلية.
create function public.admin_close_report(
  p_report_id uuid,
  p_close_reason text,
  p_response_text text default null,
  p_internal_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('reports.handle');
  v_response text := nullif(pg_catalog.btrim(coalesce(p_response_text, '')), '');
  v_note text := nullif(pg_catalog.btrim(coalesce(p_internal_note, '')), '');
  v_report public.reports;
begin
  if p_close_reason is null then
    perform private.raise_error('REASON_REQUIRED', pg_catalog.jsonb_build_object('field', 'close_reason'));
  end if;
  if p_close_reason not in ('ACTION_TAKEN', 'NO_VIOLATION', 'DUPLICATE', 'INVALID')
     or pg_catalog.char_length(v_response) > 1000 or pg_catalog.char_length(v_note) > 2000 then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_close_reason')));
  end if;
  v_report := private.lock_report(p_report_id);
  if v_report.status = 'CLOSED' then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('status', v_report.status));
  end if;

  update public.reports r set
    status = 'CLOSED', close_reason = p_close_reason, response_text = v_response,
    internal_note = coalesce(v_note, r.internal_note),
    closed_by = v_actor, closed_at = now(),
    assigned_to = coalesce(r.assigned_to, v_actor)
    where r.id = v_report.id;

  perform private.audit(
    v_actor, 'report.closed', 'report', v_report.id::text,
    pg_catalog.jsonb_build_object('target_type', v_report.target_type, 'target_id', v_report.target_id),
    p_close_reason, v_note);

  perform private.notify(
    v_report.reporter_id, 'REPORTS', 'report.closed', 'report', v_report.id::text,
    pg_catalog.jsonb_build_object('report_id', v_report.id, 'ref', v_report.ref, 'response_text', v_response),
    'report-closed:' || v_report.id::text);

  return pg_catalog.jsonb_build_object('report_id', v_report.id, 'status', 'CLOSED', 'close_reason', p_close_reason);
end;
$$;

comment on function public.admin_close_report(uuid, text, text, text) is
  'يغلق بلاغًا بسبب وردّ للمبلغ وملاحظة داخلية، ويُشعر المبلغ. القدرة: reports.handle.';

-- الدليل: الرسالة المبلّغ عنها وسياق محدود (حتى ثلاث قبلها وثلاث بعدها في المحادثة
-- نفسها)، أو نص الرد. يتطلب evidence.read ويسجل كل اطلاع في سجل منفصل وفي سجل
-- الإجراءات. لا وصول عام للمحادثات (AD-FR-036).
create function public.admin_get_report_evidence(p_report_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('evidence.read');
  v_report public.reports;
  v_conv uuid;
  v_at timestamptz;
  v_id uuid;
  v_items jsonb;
begin
  v_report := private.lock_report(p_report_id);
  if v_report.target_type not in ('MESSAGE', 'COMMENT') then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('target_type', v_report.target_type));
  end if;

  insert into public.report_evidence_access (report_id, actor_id) values (v_report.id, v_actor);
  perform private.audit(
    v_actor, 'report.evidence_read', 'report', v_report.id::text,
    pg_catalog.jsonb_build_object('target_type', v_report.target_type, 'target_id', v_report.target_id));

  if v_report.target_type = 'COMMENT' then
    select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id', c.id, 'author_id', c.author_id, 'body', c.body, 'created_at', c.created_at,
      'is_reported', c.id = v_report.target_id) order by c.created_at, c.id)
      into v_items
      from public.comments c where c.id = v_report.target_id;
  else
    select m.conversation_id, m.created_at, m.id into v_conv, v_at, v_id
      from public.messages m where m.id = v_report.target_id;
    select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id', x.id, 'sender_id', x.sender_id, 'body', x.body, 'created_at', x.created_at,
      'is_reported', x.id = v_report.target_id) order by x.created_at, x.id)
      into v_items
      from (
        (select m.* from public.messages m
          where m.conversation_id = v_conv and (m.created_at, m.id) < (v_at, v_id)
          order by m.created_at desc, m.id desc limit 3)
        union all
        (select m.* from public.messages m where m.id = v_report.target_id)
        union all
        (select m.* from public.messages m
          where m.conversation_id = v_conv and (m.created_at, m.id) > (v_at, v_id)
          order by m.created_at, m.id limit 3)
      ) x;
  end if;

  return pg_catalog.jsonb_build_object(
    'report_id', v_report.id, 'target_type', v_report.target_type, 'items', coalesce(v_items, '[]'::jsonb));
end;
$$;

comment on function public.admin_get_report_evidence(uuid) is
  'الرسالة أو الرد المبلّغ عنه وسياق محدود، بتسجيل الاطلاع. القدرة: evidence.read.';

grant execute on function public.submit_report(text, uuid, text, text, uuid) to authenticated;
grant execute on function public.get_report_status(uuid) to authenticated;
grant execute on function public.admin_assign_report(uuid, uuid) to authenticated;
grant execute on function public.admin_set_report_status(uuid, text, text) to authenticated;
grant execute on function public.admin_close_report(uuid, text, text, text) to authenticated;
grant execute on function public.admin_get_report_evidence(uuid) to authenticated;
