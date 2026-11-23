-- 17 blocks_comments — MOBILE-BE-302
-- حظر المستخدمين والردود العامة على الإعلانات: AD-FR-032، AD-FR-033،
-- AD-AC-019، AD-AC-020. الكتابة بدوال؛ القراءة العامة عبر view.

------------------------------------------------------------------------------
-- الحظر
------------------------------------------------------------------------------

create table public.user_blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_id)
);

create index user_blocks_blocked_idx on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;

-- الحاظر يقرأ قائمته فقط. المحظور لا يعرف أنه محظور.
create policy user_blocks_read_own on public.user_blocks
  for select to authenticated using ((select auth.uid()) = blocker_id);

grant select on public.user_blocks to authenticated;

-- يحل محل المرجع المؤقت في ترحيل المحادثات: حظر في أي اتجاه.
create or replace function private.is_blocked(p_a uuid, p_b uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = p_a and b.blocked_id = p_b)
       or (b.blocker_id = p_b and b.blocked_id = p_a));
$$;

create function public.block_user(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
begin
  if p_user_id is null or p_user_id = v_uid then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_user_id')));
  end if;
  if not exists (select 1 from public.profiles p where p.id = p_user_id) then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'account'));
  end if;
  insert into public.user_blocks (blocker_id, blocked_id) values (v_uid, p_user_id)
    on conflict do nothing;
  return pg_catalog.jsonb_build_object('user_id', p_user_id, 'blocked', true);
end;
$$;

comment on function public.block_user(uuid) is
  'يحظر مستخدمًا: لا رسائل جديدة في الاتجاهين ولا ردود على إعلانات الطرف الآخر. التكرار آمن.';

create function public.unblock_user(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  delete from public.user_blocks b where b.blocker_id = v_uid and b.blocked_id = p_user_id;
  return pg_catalog.jsonb_build_object('user_id', p_user_id, 'blocked', false);
end;
$$;

comment on function public.unblock_user(uuid) is
  'يلغي حظر مستخدم. لا يغير تقييمًا قائمًا. التكرار آمن.';

-- قائمة المحظورين لصاحب الجلسة (G08).
create view public.my_blocks
with (security_barrier = true) as
select
  b.blocked_id as user_id,
  p.display_name,
  b.created_at as blocked_at
from public.user_blocks b
join public.profiles p on p.id = b.blocked_id
where b.blocker_id = (select auth.uid());

comment on view public.my_blocks is 'المحظورون من صاحب الجلسة.';

grant select on public.my_blocks to authenticated;

-- قائمة المحادثات: قابلية الكتابة تشمل الحظر. مضمّنة لأن دوال الـview تُنفذ
-- بصلاحيات المستدعي. الأعمدة كما هي.
create or replace view public.my_conversations
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
  (
    card.listing_id is not null
    and other.status = 'ACTIVE'
    and exists (
      select 1 from public.profiles self
      where self.id = me.uid and self.status = 'ACTIVE')
    and not exists (
      select 1 from public.user_blocks ub
      where (ub.blocker_id = c.buyer_id and ub.blocked_id = c.seller_id)
         or (ub.blocker_id = c.seller_id and ub.blocked_id = c.buyer_id))
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

------------------------------------------------------------------------------
-- أسباب الإشراف على الردود
------------------------------------------------------------------------------

-- إجراءات الإشراف المعروفة. قائمة واحدة تستعملها القيود والدوال.
create function private.moderation_actions()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['LISTING_REJECT', 'LISTING_HIDE', 'ACCOUNT_SUSPEND', 'COMMENT_HIDE']::text[];
$$;

alter table public.moderation_reasons drop constraint moderation_reasons_applies_to_check;
alter table public.moderation_reasons add constraint moderation_reasons_applies_to_check
  check (
    cardinality(applies_to) > 0
    and applies_to <@ array['LISTING_REJECT', 'LISTING_HIDE', 'ACCOUNT_SUSPEND', 'COMMENT_HIDE']::text[]);

update public.moderation_reasons set applies_to = array_append(applies_to, 'COMMENT_HIDE'::text)
  where code in ('MISLEADING', 'PROHIBITED_CONTENT', 'FRAUD', 'ABUSE', 'OTHER')
    and not ('COMMENT_HIDE' = any (applies_to));

insert into public.moderation_reasons (code, label_ar, applies_to, requires_note, sort_order) values
  ('SPAM', 'رد مزعج أو دعائي', array['COMMENT_HIDE'], false, 95);

-- إدارة الأسباب تقبل الإجراء الجديد (أعيد تعريفها لتستعمل القائمة الموحدة).
create or replace function public.admin_upsert_moderation_reason(
  p_code text,
  p_label_ar text,
  p_applies_to text[],
  p_requires_note boolean default false,
  p_sort_order integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('lookups.manage');
  v_label text := private.clean_lookup_name(p_label_ar, 120);
  v_row public.moderation_reasons;
  v_created boolean;
  v_fields text[] := array[]::text[];
begin
  if p_code is null or p_code !~ '^[A-Z][A-Z0-9_]{1,39}$' then
    v_fields := v_fields || 'code'::text;
  end if;
  if p_applies_to is null or pg_catalog.cardinality(p_applies_to) = 0
    or pg_catalog.array_position(p_applies_to, null) is not null
    or not (p_applies_to <@ private.moderation_actions())
  then
    v_fields := v_fields || 'applies_to'::text;
  end if;
  if pg_catalog.cardinality(v_fields) > 0 then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.to_jsonb(v_fields)));
  end if;

  v_created := not exists (select 1 from public.moderation_reasons r where r.code = p_code);

  insert into public.moderation_reasons as r (code, label_ar, applies_to, requires_note, sort_order)
    values (
      p_code, v_label,
      (select pg_catalog.array_agg(distinct a order by a) from pg_catalog.unnest(p_applies_to) as a),
      coalesce(p_requires_note, false),
      coalesce(p_sort_order, (select coalesce(max(m.sort_order), 0) + 10 from public.moderation_reasons m)))
    on conflict (code) do update set
      label_ar = excluded.label_ar,
      applies_to = excluded.applies_to,
      requires_note = coalesce(p_requires_note, r.requires_note),
      sort_order = coalesce(p_sort_order, r.sort_order)
    returning * into v_row;

  perform private.audit(
    v_actor, 'lookup.upserted', 'moderation_reason', v_row.code,
    pg_catalog.jsonb_build_object('created', v_created, 'label_ar', v_row.label_ar));
  return pg_catalog.to_jsonb(v_row);
end;
$$;

------------------------------------------------------------------------------
-- الردود العامة
------------------------------------------------------------------------------

alter table public.listings add column comments_closed boolean not null default false;

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id),
  author_id uuid not null references public.profiles (id),
  -- رد المعلن على رد: مستوى واحد فقط.
  parent_id uuid references public.comments (id),
  body text not null check (char_length(body) between 1 and 5000),
  -- معرف الطلب لمنع التكرار (AD-NFR-005).
  request_id uuid not null,
  edited_at timestamptz,
  -- حذف الكاتب لردّه: يبقى الصف ليحفظ الخيط والأدلة، ويظهر «محذوف» بلا نص.
  deleted_at timestamptz,
  hidden_at timestamptz,
  hidden_by uuid references auth.users (id),
  hidden_reason_code text references public.moderation_reasons (code),
  hidden_reason_text text,
  created_at timestamptz not null default clock_timestamp(),
  unique (author_id, request_id),
  constraint comments_hidden_has_reason check (
    hidden_at is null or (hidden_by is not null and hidden_reason_code is not null))
);

create index comments_listing_idx on public.comments (listing_id, created_at, id);
create index comments_author_recent_idx on public.comments (author_id, created_at desc);
create index comments_parent_idx on public.comments (parent_id) where parent_id is not null;

-- مغلق أمام العميل: القراءة العامة عبر public_comments، والإشراف عبر دوال لاحقة.
alter table public.comments enable row level security;

-- الردود المرئية للعامة على إعلان منشور. المخفي إداريًا والمحذوف يظهران بحالتهما
-- دون نص ولا سبب، فيبقى الخيط مفهومًا (AD-FR-032).
create view public.public_comments
with (security_barrier = true) as
select
  c.id as comment_id,
  c.listing_id,
  c.parent_id,
  c.author_id,
  a.display_name as author_display_name,
  (c.author_id = l.owner_id) as is_owner,
  case
    when c.hidden_at is not null then 'HIDDEN'
    when c.deleted_at is not null then 'DELETED'
    else 'VISIBLE'
  end as state,
  case when c.hidden_at is null and c.deleted_at is null then c.body end as body,
  c.edited_at,
  c.created_at
from public.comments c
join public.listings l on l.id = c.listing_id
join public.profiles a on a.id = c.author_id
where l.status = 'PUBLISHED' and l.deleted_at is null;

comment on view public.public_comments is
  'ردود إعلان منشور. المخفي والمحذوف بحالته دون نص.';

grant select on public.public_comments to anon, authenticated;

-- حالة إغلاق الردود في التفاصيل العامة (عمود في الآخر).
create or replace view public.public_listing_details
with (security_barrier = true) as
select
  l.id as listing_id,
  l.owner_id,
  p.display_name as owner_display_name,
  p.created_at as owner_joined_at,
  v.title,
  v.description,
  v.offer_type,
  v.price,
  v.auction_region_id,
  arg.name_ar as auction_region_name_ar,
  v.auction_city_id,
  ac.name_ar as auction_city_name_ar,
  v.auction_venue,
  v.auction_starts_at,
  (v.offer_type = 'IN_PERSON_AUCTION' and v.auction_starts_at <= now()) as auction_passed,
  v.breed_id,
  b.name_ar as breed_name_ar,
  v.breed_note,
  v.sex,
  v.age_months,
  v.color,
  v.health_notes,
  v.region_id,
  rg.name_ar as region_name_ar,
  v.city_id,
  c.name_ar as city_name_ar,
  v.contact_phone,
  v.contact_call_enabled,
  v.contact_whatsapp_enabled,
  l.first_published_at,
  l.published_version_at,
  l.visibility_updated_at,
  l.public_ref,
  l.comments_closed
from public.listings l
join public.listing_versions v on v.id = l.published_version_id
join public.profiles p on p.id = l.owner_id
join public.breeds b on b.id = v.breed_id
join public.regions rg on rg.id = v.region_id
join public.cities c on c.id = v.city_id
left join public.regions arg on arg.id = v.auction_region_id
left join public.cities ac on ac.id = v.auction_city_id
where l.status = 'PUBLISHED' and l.deleted_at is null;

-- نشر رد أو رد المعلن على رد. التكرار بمعرف الطلب يعيد الرد الأول.
--  * الرد الأول (parent فارغ): أي مستخدم فعال غير المعلن نفسه.
--  * رد المعلن: على رد رئيسي مرئي من الإعلان نفسه، ولا يغلقه إغلاق الردود.
create function public.post_comment(
  p_listing_id uuid,
  p_body text,
  p_request_id uuid,
  p_parent_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_listing public.listings;
  v_parent public.comments;
  v_existing public.comments;
  v_comment public.comments;
  v_body text := pg_catalog.btrim(coalesce(p_body, ''));
  v_max integer := (private.published_settings() #>> '{interaction,comment_max}')::integer;
  v_limit integer := (private.published_settings() #>> '{rate_limits,comments_per_minute}')::integer;
  v_recent integer;
begin
  if p_request_id is null then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('request_id')));
  end if;

  select * into v_existing from public.comments c
    where c.author_id = v_uid and c.request_id = p_request_id;
  if found then
    return pg_catalog.to_jsonb(v_existing) - 'request_id' - 'hidden_by' - 'hidden_reason_code' - 'hidden_reason_text';
  end if;

  select * into v_listing from public.listings l
    where l.id = p_listing_id and l.status = 'PUBLISHED' and l.deleted_at is null;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'listing'));
  end if;
  if private.is_blocked(v_uid, v_listing.owner_id) then
    perform private.raise_error('FORBIDDEN');
  end if;

  if p_parent_id is null then
    if v_uid = v_listing.owner_id then
      perform private.raise_error('FORBIDDEN');
    end if;
    if v_listing.comments_closed then
      perform private.raise_error('COMMENTS_CLOSED');
    end if;
  else
    select * into v_parent from public.comments c
      where c.id = p_parent_id and c.listing_id = p_listing_id;
    if not found or v_parent.parent_id is not null
       or v_parent.deleted_at is not null or v_parent.hidden_at is not null then
      perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'comment'));
    end if;
    if v_uid <> v_listing.owner_id then
      perform private.raise_error('FORBIDDEN');
    end if;
  end if;

  if pg_catalog.char_length(v_body) < 1 or pg_catalog.char_length(v_body) > v_max then
    perform private.raise_error(
      'VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('body'), 'max', v_max));
  end if;

  select count(*)::integer into v_recent from public.comments c
    where c.author_id = v_uid and c.created_at > now() - interval '1 minute';
  if v_recent >= v_limit then
    perform private.raise_error('RATE_LIMITED', pg_catalog.jsonb_build_object(
      'limit', v_limit, 'window_minutes', 1,
      'retry_at', (select min(c.created_at) + interval '1 minute' from public.comments c
        where c.author_id = v_uid and c.created_at > now() - interval '1 minute')));
  end if;

  insert into public.comments (listing_id, author_id, parent_id, body, request_id)
    values (p_listing_id, v_uid, p_parent_id, v_body, p_request_id)
    returning * into v_comment;

  -- إشعار بلا نص: المعلن بردّ جديد، وكاتب الرد برد المعلن عليه.
  if p_parent_id is null then
    perform private.notify(
      v_listing.owner_id, 'COMMENTS', 'comment.created', 'listing', p_listing_id::text,
      pg_catalog.jsonb_build_object('listing_id', p_listing_id, 'comment_id', v_comment.id),
      'comment:' || v_comment.id::text);
  elsif v_parent.author_id <> v_uid then
    perform private.notify(
      v_parent.author_id, 'COMMENTS', 'comment.replied', 'listing', p_listing_id::text,
      pg_catalog.jsonb_build_object('listing_id', p_listing_id, 'comment_id', v_comment.id),
      'comment:' || v_comment.id::text);
  end if;

  return pg_catalog.to_jsonb(v_comment) - 'request_id' - 'hidden_by' - 'hidden_reason_code' - 'hidden_reason_text';
end;
$$;

comment on function public.post_comment(uuid, text, uuid, uuid) is
  'ينشر ردًا على إعلان منشور، أو ردّ المعلن على رد. التكرار بمعرف الطلب آمن.';

-- تحرير الكاتب لردّه (المرئي فقط).
create function public.edit_comment(p_comment_id uuid, p_body text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_comment public.comments;
  v_body text := pg_catalog.btrim(coalesce(p_body, ''));
  v_max integer := (private.published_settings() #>> '{interaction,comment_max}')::integer;
begin
  select * into v_comment from public.comments c
    where c.id = p_comment_id and c.author_id = v_uid for update;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'comment'));
  end if;
  if v_comment.deleted_at is not null or v_comment.hidden_at is not null then
    perform private.raise_error('INVALID_STATE');
  end if;
  if pg_catalog.char_length(v_body) < 1 or pg_catalog.char_length(v_body) > v_max then
    perform private.raise_error(
      'VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('body'), 'max', v_max));
  end if;
  update public.comments c set body = v_body, edited_at = clock_timestamp()
    where c.id = v_comment.id returning * into v_comment;
  return pg_catalog.to_jsonb(v_comment) - 'request_id' - 'hidden_by' - 'hidden_reason_code' - 'hidden_reason_text';
end;
$$;

comment on function public.edit_comment(uuid, text) is
  'يحرر الكاتب نص ردّه المرئي. لا يحرر أحد نص غيره.';

-- حذف الكاتب لردّه (منطقي). التكرار آمن.
create function public.delete_comment(p_comment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_comment public.comments;
begin
  select * into v_comment from public.comments c
    where c.id = p_comment_id and c.author_id = v_uid for update;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'comment'));
  end if;
  if v_comment.deleted_at is null then
    update public.comments c set deleted_at = clock_timestamp() where c.id = v_comment.id;
  end if;
  return pg_catalog.jsonb_build_object('comment_id', v_comment.id, 'deleted', true);
end;
$$;

comment on function public.delete_comment(uuid) is
  'يحذف الكاتب ردّه حذفًا منطقيًا. التكرار آمن.';

-- إغلاق الردود الجديدة على إعلان أو إعادة فتحها (المعلن).
create function public.set_comments_closed(p_listing_id uuid, p_closed boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_listing public.listings;
begin
  if p_closed is null then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_closed')));
  end if;
  v_listing := private.lock_own_listing(p_listing_id, v_uid);
  update public.listings l set comments_closed = p_closed where l.id = v_listing.id;
  return pg_catalog.jsonb_build_object('listing_id', v_listing.id, 'comments_closed', p_closed);
end;
$$;

comment on function public.set_comments_closed(uuid, boolean) is
  'يغلق المعلن الردود الجديدة على إعلانه أو يعيد فتحها. لا يحذف ما نُشر.';

-- إخفاء الإشراف لرد مخالف بسبب مسجل، وإعادة إظهاره (comments.moderate).
create function public.admin_hide_comment(
  p_comment_id uuid,
  p_reason_code text,
  p_reason_text text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('comments.moderate');
  v_text text := private.require_moderation_reason('COMMENT_HIDE', p_reason_code, p_reason_text);
  v_comment public.comments;
begin
  select * into v_comment from public.comments c where c.id = p_comment_id for update;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'comment'));
  end if;
  if v_comment.hidden_at is not null then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('status', 'HIDDEN'));
  end if;
  update public.comments c set
    hidden_at = clock_timestamp(), hidden_by = v_actor,
    hidden_reason_code = p_reason_code, hidden_reason_text = v_text
    where c.id = v_comment.id;
  perform private.audit(
    v_actor, 'comment.hidden', 'comment', v_comment.id::text,
    pg_catalog.jsonb_build_object('listing_id', v_comment.listing_id, 'author_id', v_comment.author_id),
    p_reason_code, v_text);
  return pg_catalog.jsonb_build_object('comment_id', v_comment.id, 'state', 'HIDDEN');
end;
$$;

comment on function public.admin_hide_comment(uuid, text, text) is
  'إخفاء رد مخالف بسبب إلزامي. القدرة: comments.moderate.';

create function public.admin_unhide_comment(p_comment_id uuid, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('comments.moderate');
  v_note text := nullif(pg_catalog.btrim(coalesce(p_note, '')), '');
  v_comment public.comments;
begin
  select * into v_comment from public.comments c where c.id = p_comment_id for update;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'comment'));
  end if;
  if v_comment.hidden_at is null then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('status', 'VISIBLE'));
  end if;
  if pg_catalog.char_length(v_note) > 1000 then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('note')));
  end if;
  update public.comments c set
    hidden_at = null, hidden_by = null, hidden_reason_code = null, hidden_reason_text = null
    where c.id = v_comment.id;
  perform private.audit(
    v_actor, 'comment.unhidden', 'comment', v_comment.id::text,
    pg_catalog.jsonb_build_object('listing_id', v_comment.listing_id), null, v_note);
  return pg_catalog.jsonb_build_object(
    'comment_id', v_comment.id,
    'state', case when v_comment.deleted_at is not null then 'DELETED' else 'VISIBLE' end);
end;
$$;

comment on function public.admin_unhide_comment(uuid, text) is
  'إعادة إظهار رد أُخفي إداريًا. القدرة: comments.moderate.';

grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.post_comment(uuid, text, uuid, uuid) to authenticated;
grant execute on function public.edit_comment(uuid, text) to authenticated;
grant execute on function public.delete_comment(uuid) to authenticated;
grant execute on function public.set_comments_closed(uuid, boolean) to authenticated;
grant execute on function public.admin_hide_comment(uuid, text, text) to authenticated;
grant execute on function public.admin_unhide_comment(uuid, text) to authenticated;
