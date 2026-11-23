-- 13 notifications_core — MOBILE-BE-109
-- مركز الإشعارات وطابور الدفع: AD-FR-016، AD-NFR-008، DEC-08، SRS القسم 7.
-- الإشعار يكتب داخل معاملة الحدث نفسها بمفتاح يمنع تكراره للمستلم. نص الإشعار
-- يركبه العميل من event وpayload؛ لا نص رسائل خاصة في أي إشعار.
-- هذا الترحيل يغطي أحداث قرارات الإعلان وحالة الحساب. الإرسال الفعلي للدفع
-- (FCM) وتفضيلات الفئات في ترحيل لاحق؛ صفوف الطابور تنتظره.

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  category public.notification_category not null,
  -- اسم الحدث، مثل listing.approved. قائمته في contracts/api/enums.json.
  event text not null check (event ~ '^[a-z_]+(\.[a-z_]+)+$'),
  -- المورد الذي يفتحه الإشعار.
  resource_type text not null,
  resource_id text not null,
  payload jsonb not null default '{}'::jsonb,
  -- يمنع تكرار الحدث نفسه للمستلم نفسه.
  dedupe_key text not null,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique (recipient_id, dedupe_key)
);

create index notifications_recipient_idx on public.notifications (recipient_id, created_at desc, id);
create index notifications_unread_idx on public.notifications (recipient_id) where read_at is null;

-- طابور الدفع الإشعاري: صف لكل إشعار، يعالجه مرسل الدفع بمحاولات محدودة.
create table public.notification_outbox (
  id bigint generated always as identity primary key,
  notification_id uuid not null unique references public.notifications (id) on delete cascade,
  status text not null default 'PENDING'
    check (status in ('PENDING', 'SENT', 'FAILED', 'SKIPPED')),
  attempts integer not null default 0 check (attempts >= 0),
  next_attempt_at timestamptz not null default now(),
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index notification_outbox_pending_idx
  on public.notification_outbox (next_attempt_at) where status = 'PENDING';

create trigger notification_outbox_set_updated_at before update on public.notification_outbox
  for each row execute function private.set_updated_at();

-- المستلم يقرأ إشعاراته فقط. الطابور مغلق أمام العميل.
alter table public.notifications enable row level security;
alter table public.notification_outbox enable row level security;

grant select on public.notifications to authenticated;

create policy notifications_read_own on public.notifications
  for select to authenticated using ((select auth.uid()) = recipient_id);

-- يكتب الإشعار وصف الطابور. تكرار المفتاح نفسه للمستلم لا ينشئ شيئًا.
create function private.notify(
  p_recipient uuid,
  p_category public.notification_category,
  p_event text,
  p_resource_type text,
  p_resource_id text,
  p_payload jsonb,
  p_dedupe_key text
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
begin
  insert into public.notifications
    (recipient_id, category, event, resource_type, resource_id, payload, dedupe_key)
  values
    (p_recipient, p_category, p_event, p_resource_type, p_resource_id,
     coalesce(p_payload, '{}'::jsonb), p_dedupe_key)
  on conflict (recipient_id, dedupe_key) do nothing
  returning id into v_id;

  if v_id is not null then
    insert into public.notification_outbox (notification_id) values (v_id);
  end if;
end;
$$;

-- قرار إشراف على إعلان -> إشعار لصاحبه، في معاملة القرار.
create function private.notify_listing_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_owner_status public.account_status;
  v_title text;
begin
  select l.owner_id, p.status into v_owner, v_owner_status
    from public.listings l
    join public.profiles p on p.id = l.owner_id
    where l.id = new.listing_id;

  -- إخفاء ناتج عن تعليق الحساب: يكفي إشعار التعليق.
  if new.decision = 'HIDDEN' and v_owner_status = 'SUSPENDED' then
    return new;
  end if;

  select v.title into v_title from public.listing_versions v where v.id = new.version_id;

  perform private.notify(
    v_owner,
    'LISTING_STATUS',
    'listing.' || pg_catalog.lower(new.decision::text),
    'listing',
    new.listing_id::text,
    pg_catalog.jsonb_build_object(
      'listing_id', new.listing_id,
      'title', v_title,
      'decision', new.decision,
      'reason_code', new.reason_code,
      'reason_label_ar', (
        select mr.label_ar from public.moderation_reasons mr where mr.code = new.reason_code),
      -- نص السبب يراه المعلن عند الرفض والإخفاء؛ ملاحظة إعادة الإظهار داخلية.
      'reason_text', case when new.decision in ('REJECTED', 'HIDDEN') then new.reason_text end),
    'review:' || new.id::text);

  return new;
end;
$$;

create trigger reviews_notify_owner
  after insert on public.reviews
  for each row execute function private.notify_listing_review();

-- تعليق حساب أو تفعيله -> إشعار لصاحبه.
create function private.notify_account_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.notify(
    new.id,
    'ACCOUNT',
    case when new.status = 'SUSPENDED' then 'account.suspended' else 'account.reactivated' end,
    'account',
    new.id::text,
    case when new.status = 'SUSPENDED' then
      pg_catalog.jsonb_build_object(
        'reason_code', new.suspension_reason_code,
        'reason_label_ar', (
          select mr.label_ar from public.moderation_reasons mr where mr.code = new.suspension_reason_code),
        'reason_text', new.suspension_reason_text)
    else '{}'::jsonb end,
    'account:' || pg_catalog.lower(new.status::text) || ':'
      || pg_catalog.to_char(coalesce(new.status_changed_at, now()) at time zone 'UTC', 'YYYYMMDDHH24MISSUS'));
  return new;
end;
$$;

create trigger profiles_notify_status
  after update of status on public.profiles
  for each row when (old.status is distinct from new.status)
  execute function private.notify_account_status();

-- تعليم إشعارات صاحب الجلسة كمقروءة. p_ids فارغ: كل غير المقروء.
create function public.mark_notifications_read(p_ids uuid[] default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_count integer;
begin
  update public.notifications n set read_at = now()
    where n.recipient_id = v_uid
      and n.read_at is null
      and (p_ids is null or n.id = any (p_ids));
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

comment on function public.mark_notifications_read(uuid[]) is
  'تعليم إشعارات صاحب الجلسة كمقروءة ويعيد عددها. دون معرفات: كل غير المقروء.';

grant execute on function public.mark_notifications_read(uuid[]) to authenticated;
