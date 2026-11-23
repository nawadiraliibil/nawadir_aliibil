-- 16 conversations — MOBILE-BE-301
-- المحادثات النصية الخاصة بين مستخدم ومعلن حول إعلان: AD-FR-031، AD-FR-016،
-- AD-AC-019. محادثة واحدة لكل إعلان وطرفين. القراءة للطرفين فقط؛ الكتابة
-- بدوال. بعد إخفاء الإعلان أو تعليق طرف أو الحظر تصير المحادثة للقراءة فقط.

------------------------------------------------------------------------------
-- الحظر: مرجع مؤقت يحل محله ترحيل blocks_comments (MOBILE-BE-302).
------------------------------------------------------------------------------

create function private.is_blocked(p_a uuid, p_b uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select false;
$$;

------------------------------------------------------------------------------
-- الجداول
------------------------------------------------------------------------------

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id),
  buyer_id uuid not null references public.profiles (id),
  -- مالك الإعلان وقت بدء المحادثة.
  seller_id uuid not null references public.profiles (id),
  last_message_at timestamptz,
  -- آخر قراءة لكل طرف؛ الفارغ يعني لم يقرأ بعد.
  buyer_read_at timestamptz,
  seller_read_at timestamptz,
  -- كتم تنبيهات هذه المحادثة لكل طرف (AD-FR-027).
  buyer_muted boolean not null default false,
  seller_muted boolean not null default false,
  created_at timestamptz not null default now(),
  unique (listing_id, buyer_id),
  constraint conversations_not_self check (buyer_id <> seller_id)
);

create index conversations_buyer_idx on public.conversations (buyer_id, last_message_at desc);
create index conversations_seller_idx on public.conversations (seller_id, last_message_at desc);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.profiles (id),
  -- سقف تقني ثابت؛ الحد القابل للإدارة من الإعدادات المنشورة.
  body text not null check (char_length(body) between 1 and 10000),
  -- معرف طلب الإرسال لمنع التكرار (AD-NFR-005).
  request_id uuid not null,
  -- وقت الساعة لا وقت المعاملة: يضمن ترتيب رسائل متتابعة في معاملة واحدة.
  created_at timestamptz not null default clock_timestamp(),
  unique (conversation_id, sender_id, request_id)
);

create index messages_conversation_idx on public.messages (conversation_id, created_at desc, id);
create index messages_sender_recent_idx on public.messages (sender_id, created_at desc);

alter table public.conversations enable row level security;
alter table public.messages enable row level security;

-- الطرفان فقط. طرف ثالث لا يقرأ ولا يشترك في Realtime.
create policy conversations_read_participants on public.conversations
  for select to authenticated
  using ((select auth.uid()) in (buyer_id, seller_id));

create policy messages_read_participants on public.messages
  for select to authenticated
  using (exists (
    select 1 from public.conversations c
    where c.id = messages.conversation_id
      and (select auth.uid()) in (c.buyer_id, c.seller_id)));

grant select on public.conversations, public.messages to authenticated;

-- نشر التغييرات لاشتراكات Realtime (تحترم سياسات القراءة أعلاه).
alter publication supabase_realtime add table public.messages;

------------------------------------------------------------------------------
-- قابلية الكتابة
------------------------------------------------------------------------------

-- هل تقبل المحادثة رسائل جديدة؟ الإعلان منشور، والطرفان فعالان، ولا حظر بينهما.
create function private.conversation_writable(p_conversation uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
      select 1 from public.conversations c
      join public.listings l on l.id = c.listing_id
      where c.id = p_conversation
        and l.status = 'PUBLISHED' and l.deleted_at is null
        and not exists (
          select 1 from public.profiles p
          where p.id in (c.buyer_id, c.seller_id) and p.status <> 'ACTIVE')
        and not private.is_blocked(c.buyer_id, c.seller_id)
    );
$$;

-- محادثة يشارك فيها المستخدم، أو NOT_FOUND (طرف ثالث كغير موجودة).
create function private.own_conversation(p_conversation uuid, p_user uuid)
returns public.conversations
language plpgsql
set search_path = ''
as $$
declare
  v_conv public.conversations;
begin
  select * into v_conv from public.conversations c
    where c.id = p_conversation and p_user in (c.buyer_id, c.seller_id);
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'conversation'));
  end if;
  return v_conv;
end;
$$;

------------------------------------------------------------------------------
-- الدوال
------------------------------------------------------------------------------

-- بدء محادثة حول إعلان منشور، أو إعادة الموجودة. التكرار آمن.
create function public.start_conversation(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_owner uuid;
  v_conv public.conversations;
  v_limit integer;
  v_recent integer;
begin
  select l.owner_id into v_owner from public.listings l
    where l.id = p_listing_id and l.status = 'PUBLISHED' and l.deleted_at is null;
  if v_owner is null then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'listing'));
  end if;
  if v_owner = v_uid then
    perform private.raise_error('CANNOT_MESSAGE_SELF');
  end if;
  -- لا يكشف الحظر لمن حُظر.
  if private.is_blocked(v_uid, v_owner) then
    perform private.raise_error('FORBIDDEN');
  end if;

  select * into v_conv from public.conversations c
    where c.listing_id = p_listing_id and c.buyer_id = v_uid;
  if found then
    return pg_catalog.jsonb_build_object('conversation_id', v_conv.id, 'created', false);
  end if;

  v_limit := (private.published_settings() #>> '{rate_limits,new_conversations_per_hour}')::integer;
  select count(*)::integer into v_recent from public.conversations c
    where c.buyer_id = v_uid and c.created_at > now() - interval '1 hour';
  if v_recent >= v_limit then
    perform private.raise_error('RATE_LIMITED', pg_catalog.jsonb_build_object(
      'limit', v_limit, 'window_hours', 1,
      'retry_at', (select min(c.created_at) + interval '1 hour' from public.conversations c
        where c.buyer_id = v_uid and c.created_at > now() - interval '1 hour')));
  end if;

  insert into public.conversations (listing_id, buyer_id, seller_id)
    values (p_listing_id, v_uid, v_owner)
    on conflict (listing_id, buyer_id) do nothing
    returning * into v_conv;
  if v_conv.id is null then
    -- سباق: أنشأها طلب متزامن.
    select * into v_conv from public.conversations c
      where c.listing_id = p_listing_id and c.buyer_id = v_uid;
    return pg_catalog.jsonb_build_object('conversation_id', v_conv.id, 'created', false);
  end if;
  return pg_catalog.jsonb_build_object('conversation_id', v_conv.id, 'created', true);
end;
$$;

comment on function public.start_conversation(uuid) is
  'يبدأ محادثة حول إعلان منشور أو يعيد الموجودة. لا محادثة مع النفس.';

-- إرسال رسالة. إعادة الطلب بالمعرف نفسه تعيد الرسالة الأولى دون تكرار.
create function public.send_message(p_conversation_id uuid, p_body text, p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_conv public.conversations;
  v_body text := pg_catalog.btrim(coalesce(p_body, ''));
  v_max integer := (private.published_settings() #>> '{interaction,message_max}')::integer;
  v_limit integer := (private.published_settings() #>> '{rate_limits,messages_per_minute}')::integer;
  v_msg public.messages;
  v_recipient uuid;
  v_recipient_read timestamptz;
  v_recipient_muted boolean;
  v_recent integer;
begin
  if p_request_id is null then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('request_id')));
  end if;
  v_conv := private.own_conversation(p_conversation_id, v_uid);

  -- الإعادة أولًا: لا تخضع لحد المعدل ولا لقابلية الكتابة.
  select * into v_msg from public.messages m
    where m.conversation_id = v_conv.id and m.sender_id = v_uid and m.request_id = p_request_id;
  if found then
    return pg_catalog.to_jsonb(v_msg) - 'request_id';
  end if;

  if pg_catalog.char_length(v_body) < 1 or pg_catalog.char_length(v_body) > v_max then
    perform private.raise_error(
      'VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('body'), 'max', v_max));
  end if;

  if not private.conversation_writable(v_conv.id) then
    perform private.raise_error('CONVERSATION_READ_ONLY');
  end if;

  select count(*)::integer into v_recent from public.messages m
    where m.sender_id = v_uid and m.created_at > now() - interval '1 minute';
  if v_recent >= v_limit then
    perform private.raise_error('RATE_LIMITED', pg_catalog.jsonb_build_object(
      'limit', v_limit, 'window_minutes', 1,
      'retry_at', (select min(m.created_at) + interval '1 minute' from public.messages m
        where m.sender_id = v_uid and m.created_at > now() - interval '1 minute')));
  end if;

  insert into public.messages (conversation_id, sender_id, body, request_id)
    values (v_conv.id, v_uid, v_body, p_request_id)
    returning * into v_msg;
  -- المرسل قرأ ما سبق.
  update public.conversations c set
    last_message_at = v_msg.created_at,
    buyer_read_at = case when v_uid = c.buyer_id then v_msg.created_at else c.buyer_read_at end,
    seller_read_at = case when v_uid = c.seller_id then v_msg.created_at else c.seller_read_at end
    where c.id = v_conv.id;

  -- إشعار واحد لكل رسائل غير مقروءة: المفتاح يتبع آخر قراءة للمستلم. دون نص الرسالة.
  if v_uid = v_conv.buyer_id then
    v_recipient := v_conv.seller_id;
    v_recipient_read := v_conv.seller_read_at;
    v_recipient_muted := v_conv.seller_muted;
  else
    v_recipient := v_conv.buyer_id;
    v_recipient_read := v_conv.buyer_read_at;
    v_recipient_muted := v_conv.buyer_muted;
  end if;
  if not v_recipient_muted then
    perform private.notify(
      v_recipient, 'MESSAGES', 'message.received', 'conversation', v_conv.id::text,
      pg_catalog.jsonb_build_object('conversation_id', v_conv.id, 'listing_id', v_conv.listing_id),
      'message:' || v_conv.id::text || ':'
        || coalesce(pg_catalog.floor(extract(epoch from v_recipient_read))::bigint, 0)::text);
  end if;

  return pg_catalog.to_jsonb(v_msg) - 'request_id';
end;
$$;

comment on function public.send_message(uuid, text, uuid) is
  'يرسل رسالة نصية في محادثة يشارك فيها المستخدم. التكرار بمعرف الطلب آمن.';

-- تعليم المحادثة مقروءة لصاحب الجلسة (متاح حتى في القراءة فقط).
create function public.mark_conversation_read(p_conversation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_conv public.conversations;
  v_now timestamptz := clock_timestamp();
begin
  v_conv := private.own_conversation(p_conversation_id, v_uid);
  update public.conversations c set
    buyer_read_at = case when v_uid = c.buyer_id then v_now else c.buyer_read_at end,
    seller_read_at = case when v_uid = c.seller_id then v_now else c.seller_read_at end
    where c.id = v_conv.id;
  return pg_catalog.jsonb_build_object('conversation_id', v_conv.id, 'read_at', v_now);
end;
$$;

comment on function public.mark_conversation_read(uuid) is
  'يعلّم المحادثة مقروءة لصاحب الجلسة.';

-- كتم تنبيهات محادثة أو إلغاء كتمها (AD-FR-027). الرسائل تبقى تصل.
create function public.set_conversation_muted(p_conversation_id uuid, p_muted boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_conv public.conversations;
begin
  if p_muted is null then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_muted')));
  end if;
  v_conv := private.own_conversation(p_conversation_id, v_uid);
  update public.conversations c set
    buyer_muted = case when v_uid = c.buyer_id then p_muted else c.buyer_muted end,
    seller_muted = case when v_uid = c.seller_id then p_muted else c.seller_muted end
    where c.id = v_conv.id;
  return pg_catalog.jsonb_build_object('conversation_id', v_conv.id, 'muted', p_muted);
end;
$$;

comment on function public.set_conversation_muted(uuid, boolean) is
  'يكتم تنبيهات محادثة لصاحب الجلسة أو يلغي الكتم.';

------------------------------------------------------------------------------
-- قائمة المحادثات
------------------------------------------------------------------------------

-- محادثات صاحب الجلسة. محتوى الإعلان (العنوان والغلاف) يظهر ما دام منشورًا؛
-- غير ذلك listing_available=false وحقوله فارغة فلا يتسرب محتوى المحجوب.
create view public.my_conversations
with (security_barrier = true) as
select
  c.id as conversation_id,
  c.listing_id,
  case when me.uid = c.buyer_id then 'BUYER' else 'SELLER' end as my_role,
  other.id as other_user_id,
  other.display_name as other_display_name,
  (card.listing_id is not null) as listing_available,
  card.title as listing_title,
  card.cover_bucket,
  card.cover_path,
  -- مطابق لـprivate.conversation_writable. مضمّن لأن دوال الـview تُنفذ بصلاحيات
  -- المستدعي ولا صلاحية له على مخطط private. ترحيل الحظر يعيد تعريفه بشرط الحظر.
  (
    card.listing_id is not null
    and other.status = 'ACTIVE'
    and exists (
      select 1 from public.profiles self
      where self.id = me.uid and self.status = 'ACTIVE')
  ) as writable,
  case when me.uid = c.buyer_id then c.buyer_muted else c.seller_muted end as muted,
  c.last_message_at,
  last_msg.body as last_message_body,
  last_msg.sender_id as last_message_sender_id,
  (
    select count(*)::integer from public.messages m
    where m.conversation_id = c.id and m.sender_id <> me.uid
      and m.created_at > coalesce(
        case when me.uid = c.buyer_id then c.buyer_read_at else c.seller_read_at end,
        '-infinity'::timestamptz)
  ) as unread_count,
  c.created_at
from public.conversations c
cross join lateral (select (select auth.uid()) as uid) me
join public.profiles other on other.id = case when me.uid = c.buyer_id then c.seller_id else c.buyer_id end
left join public.public_listing_cards card on card.listing_id = c.listing_id
left join lateral (
  select m.body, m.sender_id from public.messages m
  where m.conversation_id = c.id
  order by m.created_at desc, m.id desc
  limit 1
) last_msg on true
where me.uid in (c.buyer_id, c.seller_id);

comment on view public.my_conversations is
  'محادثات صاحب الجلسة مع آخر رسالة وعدد غير المقروء وقابلية الكتابة.';

grant select on public.my_conversations to authenticated;

grant execute on function public.start_conversation(uuid) to authenticated;
grant execute on function public.send_message(uuid, text, uuid) to authenticated;
grant execute on function public.mark_conversation_read(uuid) to authenticated;
grant execute on function public.set_conversation_muted(uuid, boolean) to authenticated;
