-- 20 push — MOBILE-BE-305
-- تفضيلات الإشعارات وتسجيل أجهزة الدفع وتهيئة مرسل الدفع: AD-FR-016، AD-FR-027،
-- AD-NFR-008، AD-AC-015. مركز الإشعارات داخل التطبيق لا يتأثر بالتفضيلات ولا
-- بالدفع: التفضيل يوقف الدفع وحده. لا نص خاص في حمولة الدفع (يركبه المرسل من
-- نوع الحدث).

create table public.notification_preferences (
  user_id uuid not null references public.profiles (id) on delete cascade,
  category public.notification_category not null,
  push_enabled boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (user_id, category)
);

create trigger notification_preferences_set_updated_at before update on public.notification_preferences
  for each row execute function private.set_updated_at();

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  -- رمز FCM. فريد: انتقاله لمستخدم آخر (جهاز مشترك) ينقل ملكيته.
  token text not null unique check (char_length(token) between 20 and 4096),
  platform text not null check (platform in ('ANDROID', 'IOS')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  -- عُطل برفض المزود (رمز غير صالح) أو بإلغاء التسجيل.
  disabled_at timestamptz
);

create index device_tokens_user_idx on public.device_tokens (user_id) where disabled_at is null;

alter table public.notification_preferences enable row level security;
alter table public.device_tokens enable row level security;

create policy notification_preferences_read_own on public.notification_preferences
  for select to authenticated using ((select auth.uid()) = user_id);

-- الرموز لا تقرأ من العميل: الجهاز يعرف رمزه، والخادم وحده يرسل إليه.
grant select on public.notification_preferences to authenticated;

------------------------------------------------------------------------------
-- تفضيلات الفئات
------------------------------------------------------------------------------

-- كل الفئات مع القيمة الفعلية (الافتراضي مفعل).
create view public.my_notification_preferences
with (security_barrier = true) as
select
  c.category::text as category,
  coalesce(p.push_enabled, true) as push_enabled
from unnest(enum_range(null::public.notification_category)) as c(category)
left join public.notification_preferences p
  on p.category = c.category and p.user_id = (select auth.uid())
where (select auth.uid()) is not null;

comment on view public.my_notification_preferences is
  'تفضيلات الدفع لصاحب الجلسة لكل فئة؛ الافتراضي مفعل.';

grant select on public.my_notification_preferences to authenticated;

create function public.set_notification_preference(p_category text, p_push_enabled boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_category public.notification_category;
begin
  if p_push_enabled is null or p_category is null
     or p_category not in (select e::text from unnest(enum_range(null::public.notification_category)) e) then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array(
        case when p_push_enabled is null then 'p_push_enabled' else 'p_category' end)));
  end if;
  v_category := p_category::public.notification_category;
  insert into public.notification_preferences (user_id, category, push_enabled)
    values (v_uid, v_category, p_push_enabled)
    on conflict (user_id, category) do update set push_enabled = excluded.push_enabled;
  return pg_catalog.jsonb_build_object('category', p_category, 'push_enabled', p_push_enabled);
end;
$$;

comment on function public.set_notification_preference(text, boolean) is
  'يفعل الدفع لفئة إشعارات أو يوقفه. مركز الإشعارات داخل التطبيق لا يتأثر.';

------------------------------------------------------------------------------
-- أجهزة الدفع
------------------------------------------------------------------------------

-- تسجيل رمز الجهاز لصاحب الجلسة. الرمز الموجود يعاد تفعيله وينتقل إلى صاحب
-- الجلسة الحالي: من خرج من الجهاز لا يصله شيء بعد دخول غيره.
create function public.register_device_token(p_token text, p_platform text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_token text := pg_catalog.btrim(coalesce(p_token, ''));
begin
  if pg_catalog.char_length(v_token) < 20 or pg_catalog.char_length(v_token) > 4096
     or p_platform is null or p_platform not in ('ANDROID', 'IOS') then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array(
        case when p_platform is null or p_platform not in ('ANDROID', 'IOS') then 'p_platform' else 'p_token' end)));
  end if;
  insert into public.device_tokens as d (user_id, token, platform)
    values (v_uid, v_token, p_platform)
    on conflict (token) do update set
      user_id = excluded.user_id, platform = excluded.platform,
      last_seen_at = now(), disabled_at = null;
  return pg_catalog.jsonb_build_object('registered', true);
end;
$$;

comment on function public.register_device_token(text, text) is
  'يسجل رمز دفع الجهاز لصاحب الجلسة. التكرار آمن، وانتقال الجهاز لمستخدم آخر ينقل ملكيته.';

-- إلغاء تسجيل الجهاز (عند الخروج أو رفض الإذن). يوقف الدفع إليه فورًا.
create function public.unregister_device_token(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_count integer;
begin
  update public.device_tokens d set disabled_at = now()
    where d.token = pg_catalog.btrim(coalesce(p_token, '')) and d.user_id = v_uid and d.disabled_at is null;
  get diagnostics v_count = row_count;
  return pg_catalog.jsonb_build_object('unregistered', v_count > 0);
end;
$$;

comment on function public.unregister_device_token(text) is
  'يوقف الدفع إلى جهاز صاحب الجلسة. التكرار آمن.';

------------------------------------------------------------------------------
-- مرسل الدفع (دالة Edge push-dispatch بدور الخدمة)
------------------------------------------------------------------------------

-- يطالب بدفعة من الطابور: الصفوف المستحقة بقفل SKIP LOCKED، فلا تعالجها
-- معالجتان. يحسم هنا ما لا يرسل: فئة موقوفة أو لا جهاز فعال (SKIPPED). ويعيد
-- لكل إشعار مرسل: نوع الحدث ورمزه الجهاز، وما يلزم لفتح المورد. لا نص رسائل.
create function public.claim_push_batch(p_limit integer default 50)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_jobs jsonb := '[]'::jsonb;
  r record;
  v_tokens jsonb;
begin
  for r in
    select o.id as outbox_id, o.attempts, n.id as notification_id, n.recipient_id,
           n.category, n.event, n.resource_type, n.resource_id
      from public.notification_outbox o
      join public.notifications n on n.id = o.notification_id
      where o.status = 'PENDING' and o.next_attempt_at <= now()
      order by o.next_attempt_at, o.id
      limit greatest(1, least(coalesce(p_limit, 50), 200))
      for update of o skip locked
  loop
    if not coalesce((
      select p.push_enabled from public.notification_preferences p
      where p.user_id = r.recipient_id and p.category = r.category), true) then
      update public.notification_outbox o set status = 'SKIPPED', last_error = 'preference_off'
        where o.id = r.outbox_id;
      continue;
    end if;

    select coalesce(pg_catalog.jsonb_agg(d.token), '[]'::jsonb) into v_tokens
      from public.device_tokens d where d.user_id = r.recipient_id and d.disabled_at is null;
    if pg_catalog.jsonb_array_length(v_tokens) = 0 then
      update public.notification_outbox o set status = 'SKIPPED', last_error = 'no_device'
        where o.id = r.outbox_id;
      continue;
    end if;

    -- حجز: يؤجل موعد المحاولة إلى أن يبلغ المرسل النتيجة، فلا يعيد دفعة أخرى أخذه.
    update public.notification_outbox o set
      attempts = o.attempts + 1, next_attempt_at = now() + interval '5 minutes'
      where o.id = r.outbox_id;

    v_jobs := v_jobs || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'outbox_id', r.outbox_id, 'notification_id', r.notification_id,
      'category', r.category, 'event', r.event,
      'resource_type', r.resource_type, 'resource_id', r.resource_id,
      'tokens', v_tokens));
  end loop;
  return v_jobs;
end;
$$;

comment on function public.claim_push_batch(integer) is
  'للمرسل (service_role): يطالب بدفعة من طابور الدفع ويحسم المتخطى. لا يستدعيها العميل.';

-- نتيجة الإرسال: SENT، أو FAILED مع إعادة محاولة مؤجلة حتى خمس محاولات.
-- الرموز التي رفضها المزود كغير صالحة تعطل.
create function public.complete_push(
  p_outbox_id bigint,
  p_status text,
  p_error text default null,
  p_invalid_tokens text[] default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempts integer;
begin
  if p_status not in ('SENT', 'FAILED') then
    raise exception 'حالة غير صالحة: %', p_status;
  end if;
  if p_invalid_tokens is not null then
    update public.device_tokens d set disabled_at = now()
      where d.token = any (p_invalid_tokens) and d.disabled_at is null;
  end if;
  select o.attempts into v_attempts from public.notification_outbox o where o.id = p_outbox_id;
  if p_status = 'SENT' then
    update public.notification_outbox o set status = 'SENT', last_error = null where o.id = p_outbox_id;
  elsif v_attempts >= 5 then
    update public.notification_outbox o set status = 'FAILED', last_error = left(p_error, 500)
      where o.id = p_outbox_id;
  else
    -- تراجع أسي: 1 ثم 2 ثم 4 ثم 8 دقائق.
    update public.notification_outbox o set
      last_error = left(p_error, 500),
      next_attempt_at = now() + make_interval(mins => (2 ^ greatest(v_attempts - 1, 0))::integer)
      where o.id = p_outbox_id;
  end if;
end;
$$;

comment on function public.complete_push(bigint, text, text, text[]) is
  'للمرسل (service_role): يسجل نتيجة الإرسال ويعطل الرموز غير الصالحة.';

grant execute on function public.set_notification_preference(text, boolean) to authenticated;
grant execute on function public.register_device_token(text, text) to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;
-- دوال المرسل لدور الخدمة فقط (يمنح service_role افتراضيًا ولا يمنح غيره).
