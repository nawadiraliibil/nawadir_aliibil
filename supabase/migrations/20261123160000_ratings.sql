-- 21 ratings — MOBILE-BE-401
-- تقييم المعلن: AD-FR-029، AD-FR-024، AD-FR-036، AD-AC-017.
-- الأهلية تقلل الإساءة ولا تثبت الشراء؛ لا يستخدم وصف «شراء موثق». لا يعدل
-- المعلن تقييم غيره: الرد لا يغير الدرجة، والاعتراض لا يخفي التقييم تلقائيًا.

------------------------------------------------------------------------------
-- إجراء الإشراف على التقييمات
------------------------------------------------------------------------------

create or replace function private.moderation_actions()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array['LISTING_REJECT', 'LISTING_HIDE', 'ACCOUNT_SUSPEND', 'COMMENT_HIDE', 'RATING_HIDE']::text[];
$$;

alter table public.moderation_reasons drop constraint moderation_reasons_applies_to_check;
alter table public.moderation_reasons add constraint moderation_reasons_applies_to_check
  check (
    cardinality(applies_to) > 0
    and applies_to <@ array[
      'LISTING_REJECT', 'LISTING_HIDE', 'ACCOUNT_SUSPEND', 'COMMENT_HIDE', 'RATING_HIDE']::text[]);

update public.moderation_reasons set applies_to = array_append(applies_to, 'RATING_HIDE'::text)
  where code in ('MISLEADING', 'PROHIBITED_CONTENT', 'FRAUD', 'ABUSE', 'SPAM', 'OTHER')
    and not ('RATING_HIDE' = any (applies_to));

insert into public.moderation_reasons (code, label_ar, applies_to, requires_note, sort_order) values
  ('UNFAIR_RATING', 'تقييم غير مبني على تعامل فعلي', array['RATING_HIDE'], false, 96);

------------------------------------------------------------------------------
-- الجداول
------------------------------------------------------------------------------

create table public.seller_ratings (
  id uuid primary key default gen_random_uuid(),
  rater_id uuid not null references public.profiles (id),
  seller_id uuid not null references public.profiles (id),
  -- المحادثة التي ثبتت بها الأهلية (طرفاها تبادلا الرسائل).
  conversation_id uuid not null references public.conversations (id),
  score smallint not null check (score between 1 and 5),
  body text check (body is null or char_length(body) between 1 and 5000),
  -- إقرار المقيّم بتجربة تعامل (لا يعني شراء موثقًا).
  declaration_at timestamptz not null,
  status text not null default 'VISIBLE' check (status in ('VISIBLE', 'HIDDEN')),
  hidden_at timestamptz,
  hidden_by uuid references auth.users (id),
  hidden_reason_code text references public.moderation_reasons (code),
  hidden_reason_text text,
  -- معرف الطلب لمنع التكرار (AD-NFR-005).
  request_id uuid not null,
  edited_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default now(),
  -- تقييم واحد للمعلن نفسه لكل مقيّم (AD-FR-029).
  unique (rater_id, seller_id),
  unique (rater_id, request_id),
  constraint seller_ratings_not_self check (rater_id <> seller_id),
  constraint seller_ratings_hidden_has_reason check (
    (status = 'HIDDEN') = (hidden_at is not null and hidden_by is not null and hidden_reason_code is not null))
);

create trigger seller_ratings_set_updated_at before update on public.seller_ratings
  for each row execute function private.set_updated_at();

create index seller_ratings_seller_idx on public.seller_ratings (seller_id, created_at desc);

-- سجل تعديلات التقييم: كل تعديل يحفظ الصيغة السابقة (إضافة فقط).
create table public.seller_rating_history (
  id bigint generated always as identity primary key,
  rating_id uuid not null references public.seller_ratings (id),
  score smallint not null,
  body text,
  replaced_at timestamptz not null default now()
);

create trigger seller_rating_history_append_only
  before update or delete on public.seller_rating_history
  for each row execute function private.forbid_change();

-- رد المعلن: واحد لكل تقييم.
create table public.rating_replies (
  rating_id uuid primary key references public.seller_ratings (id),
  seller_id uuid not null references public.profiles (id),
  body text not null check (char_length(body) between 1 and 5000),
  edited_at timestamptz,
  created_at timestamptz not null default now()
);

-- اعتراض المعلن: واحد لكل تقييم. لا يخفي التقييم؛ تقرره الإدارة.
create table public.rating_appeals (
  id uuid primary key default gen_random_uuid(),
  rating_id uuid not null unique references public.seller_ratings (id),
  seller_id uuid not null references public.profiles (id),
  reason text not null check (char_length(reason) between 1 and 2000),
  status text not null default 'OPEN' check (status in ('OPEN', 'ACCEPTED', 'REJECTED')),
  decision_note text check (decision_note is null or char_length(decision_note) <= 2000),
  decided_by uuid references auth.users (id),
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  constraint rating_appeals_decided_complete check (
    (status = 'OPEN') = (decided_by is null and decided_at is null))
);

create index rating_appeals_queue_idx on public.rating_appeals (status, created_at);

alter table public.seller_ratings enable row level security;
alter table public.seller_rating_history enable row level security;
alter table public.rating_replies enable row level security;
alter table public.rating_appeals enable row level security;

-- الموظف بقدرة التقييمات يقرأها وسجلها واعتراضاتها. غير ذلك عبر views.
create policy seller_ratings_read_staff on public.seller_ratings
  for select to authenticated using ((select public.has_staff_capability('ratings.moderate')));
create policy seller_rating_history_read_staff on public.seller_rating_history
  for select to authenticated using ((select public.has_staff_capability('ratings.moderate')));
create policy rating_replies_read_staff on public.rating_replies
  for select to authenticated using ((select public.has_staff_capability('ratings.moderate')));
create policy rating_appeals_read_staff on public.rating_appeals
  for select to authenticated using ((select public.has_staff_capability('ratings.moderate')));

grant select on public.seller_ratings, public.seller_rating_history,
  public.rating_replies, public.rating_appeals to authenticated;

------------------------------------------------------------------------------
-- القراءة العامة
------------------------------------------------------------------------------

-- التقييمات الظاهرة لمعلن. المخفي لا يظهر ولا يدخل في المتوسط (AD-AC-017).
create view public.public_ratings
with (security_barrier = true) as
select
  r.id as rating_id,
  r.seller_id,
  r.rater_id,
  p.display_name as rater_display_name,
  r.score,
  r.body,
  rp.body as reply_body,
  coalesce(rp.edited_at, rp.created_at) as reply_at,
  r.edited_at,
  r.created_at
from public.seller_ratings r
join public.profiles p on p.id = r.rater_id
left join public.rating_replies rp on rp.rating_id = r.id
where r.status = 'VISIBLE';

comment on view public.public_ratings is 'التقييمات الظاهرة للعامة وردود المعلنين عليها.';

grant select on public.public_ratings to anon, authenticated;

-- الملف العام يضيف ملخص التقييم في آخر الأعمدة.
create or replace view public.public_profiles
with (security_barrier = true) as
select
  p.id,
  p.display_name,
  p.region_id,
  r.name_ar as region_name_ar,
  p.created_at as joined_at,
  (
    select count(*)::integer from public.listings l
    where l.owner_id = p.id and l.status = 'PUBLISHED' and l.deleted_at is null
  ) as published_listings_count,
  (
    select round(avg(sr.score)::numeric, 2) from public.seller_ratings sr
    where sr.seller_id = p.id and sr.status = 'VISIBLE'
  ) as rating_avg,
  (
    select count(*)::integer from public.seller_ratings sr
    where sr.seller_id = p.id and sr.status = 'VISIBLE'
  ) as rating_count
from public.profiles p
left join public.regions r on r.id = p.region_id
where p.display_name is not null;

-- تقييمات صاحب الجلسة كمعلن، مع حالتها وحالة اعتراضه. المخفي يظهر له بحالته.
create view public.my_received_ratings
with (security_barrier = true) as
select
  r.id as rating_id,
  r.rater_id,
  p.display_name as rater_display_name,
  r.score,
  r.body,
  r.status,
  rp.body as reply_body,
  a.id as appeal_id,
  a.status as appeal_status,
  r.edited_at,
  r.created_at
from public.seller_ratings r
join public.profiles p on p.id = r.rater_id
left join public.rating_replies rp on rp.rating_id = r.id
left join public.rating_appeals a on a.rating_id = r.id
where r.seller_id = (select auth.uid());

comment on view public.my_received_ratings is
  'تقييمات صاحب الجلسة كمعلن بحالتها وردّه واعتراضه.';

grant select on public.my_received_ratings to authenticated;

------------------------------------------------------------------------------
-- الأهلية
------------------------------------------------------------------------------

-- أهلية المستخدم لتقييم معلن: ليس هو، وبينهما محادثة تبادلا فيها الرسائل، ولا
-- حظر بينهما. يعيد المحادثة المثبتة للأهلية إن وجدت.
create function private.rating_eligibility(p_rater uuid, p_seller uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_conv uuid;
  v_existing public.seller_ratings;
begin
  if p_rater = p_seller then
    return pg_catalog.jsonb_build_object('eligible', false, 'reason', 'SELF');
  end if;
  select * into v_existing from public.seller_ratings r where r.rater_id = p_rater and r.seller_id = p_seller;
  if found then
    return pg_catalog.jsonb_build_object(
      'eligible', false, 'reason', 'ALREADY_RATED', 'rating_id', v_existing.id);
  end if;
  if private.is_blocked(p_rater, p_seller) then
    return pg_catalog.jsonb_build_object('eligible', false, 'reason', 'BLOCKED');
  end if;
  select c.id into v_conv
    from public.conversations c
    where c.buyer_id = p_rater and c.seller_id = p_seller
      and exists (select 1 from public.messages m where m.conversation_id = c.id and m.sender_id = c.buyer_id)
      and exists (select 1 from public.messages m where m.conversation_id = c.id and m.sender_id = c.seller_id)
    order by c.created_at
    limit 1;
  if v_conv is null then
    return pg_catalog.jsonb_build_object(
      'eligible', false,
      'reason', case when exists (
        select 1 from public.conversations c where c.buyer_id = p_rater and c.seller_id = p_seller)
        then 'NO_EXCHANGE' else 'NO_CONVERSATION' end);
  end if;
  return pg_catalog.jsonb_build_object('eligible', true, 'conversation_id', v_conv);
end;
$$;

-- أهلية صاحب الجلسة لتقييم معلن (لإظهار الزر وسبب غيابه).
create function public.get_rating_eligibility(p_seller_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  return private.rating_eligibility(v_uid, p_seller_id) - 'conversation_id';
end;
$$;

comment on function public.get_rating_eligibility(uuid) is
  'هل يحق لصاحب الجلسة تقييم هذا المعلن؟ eligible وreason عند عدمه.';

------------------------------------------------------------------------------
-- التقييم
------------------------------------------------------------------------------

create function public.submit_rating(
  p_seller_id uuid,
  p_score integer,
  p_body text,
  p_declaration boolean,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_body text := nullif(pg_catalog.btrim(coalesce(p_body, '')), '');
  v_max integer := (private.published_settings() #>> '{interaction,rating_max}')::integer;
  v_existing public.seller_ratings;
  v_elig jsonb;
  v_rating public.seller_ratings;
begin
  if p_request_id is null or p_seller_id is null or p_score is null or p_score not between 1 and 5
     or pg_catalog.char_length(v_body) > v_max or p_declaration is not true then
    perform private.raise_error('VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', (
      select pg_catalog.jsonb_agg(f) from (
        select 'request_id' as f where p_request_id is null
        union all select 'p_seller_id' where p_seller_id is null
        union all select 'p_score' where p_score is null or p_score not between 1 and 5
        union all select 'p_body' where pg_catalog.char_length(v_body) > v_max
        union all select 'p_declaration' where p_declaration is not true) x),
      'max', v_max));
  end if;

  select * into v_existing from public.seller_ratings r
    where r.rater_id = v_uid and r.request_id = p_request_id;
  if found then
    return private.rating_json(v_existing);
  end if;

  v_elig := private.rating_eligibility(v_uid, p_seller_id);
  if not (v_elig ->> 'eligible')::boolean then
    if v_elig ->> 'reason' = 'ALREADY_RATED' then
      perform private.raise_error('RATING_EXISTS', pg_catalog.jsonb_build_object('rating_id', v_elig -> 'rating_id'));
    end if;
    perform private.raise_error('RATING_NOT_ELIGIBLE', pg_catalog.jsonb_build_object('reason', v_elig -> 'reason'));
  end if;

  insert into public.seller_ratings
    (rater_id, seller_id, conversation_id, score, body, declaration_at, request_id)
    values (v_uid, p_seller_id, (v_elig ->> 'conversation_id')::uuid, p_score, v_body, now(), p_request_id)
    returning * into v_rating;

  perform private.notify(
    p_seller_id, 'RATINGS', 'rating.received', 'rating', v_rating.id::text,
    pg_catalog.jsonb_build_object('rating_id', v_rating.id, 'score', p_score),
    'rating:' || v_rating.id::text);

  return private.rating_json(v_rating);
end;
$$;

comment on function public.submit_rating(uuid, integer, text, boolean, uuid) is
  'يقيّم معلنًا بدرجة 1 إلى 5 ونص اختياري وإقرار بتجربة تعامل، بعد تبادل رسائل. تقييم واحد لكل معلن.';

create function private.rating_json(p_rating public.seller_ratings)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'rating_id', p_rating.id, 'seller_id', p_rating.seller_id, 'score', p_rating.score,
    'body', p_rating.body, 'status', p_rating.status,
    'edited_at', p_rating.edited_at, 'created_at', p_rating.created_at);
$$;

-- تعديل المقيّم لتقييمه مع حفظ الصيغة السابقة.
create function public.edit_rating(p_rating_id uuid, p_score integer, p_body text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_body text := nullif(pg_catalog.btrim(coalesce(p_body, '')), '');
  v_max integer := (private.published_settings() #>> '{interaction,rating_max}')::integer;
  v_rating public.seller_ratings;
begin
  if p_score is null or p_score not between 1 and 5 or pg_catalog.char_length(v_body) > v_max then
    perform private.raise_error('VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', (
      select pg_catalog.jsonb_agg(f) from (
        select 'p_score' as f where p_score is null or p_score not between 1 and 5
        union all select 'p_body' where pg_catalog.char_length(v_body) > v_max) x), 'max', v_max));
  end if;
  select * into v_rating from public.seller_ratings r
    where r.id = p_rating_id and r.rater_id = v_uid for update;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'rating'));
  end if;
  if v_rating.status <> 'VISIBLE' then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('status', v_rating.status));
  end if;
  if v_rating.score = p_score and v_rating.body is not distinct from v_body then
    return private.rating_json(v_rating);
  end if;
  insert into public.seller_rating_history (rating_id, score, body)
    values (v_rating.id, v_rating.score, v_rating.body);
  update public.seller_ratings r set score = p_score, body = v_body, edited_at = clock_timestamp()
    where r.id = v_rating.id returning * into v_rating;
  return private.rating_json(v_rating);
end;
$$;

comment on function public.edit_rating(uuid, integer, text) is
  'يعدّل المقيّم تقييمه الظاهر مع حفظ الصيغة السابقة في السجل.';

-- رد المعلن على تقييم ظاهر. لا يغير الدرجة. يمكن استبدال الرد.
create function public.reply_to_rating(p_rating_id uuid, p_body text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_body text := pg_catalog.btrim(coalesce(p_body, ''));
  v_max integer := (private.published_settings() #>> '{interaction,rating_max}')::integer;
  v_rating public.seller_ratings;
  v_existed boolean;
begin
  if pg_catalog.char_length(v_body) < 1 or pg_catalog.char_length(v_body) > v_max then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_body'), 'max', v_max));
  end if;
  select * into v_rating from public.seller_ratings r
    where r.id = p_rating_id and r.seller_id = v_uid;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'rating'));
  end if;
  if v_rating.status <> 'VISIBLE' then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('status', v_rating.status));
  end if;
  v_existed := exists (select 1 from public.rating_replies rp where rp.rating_id = v_rating.id);
  insert into public.rating_replies (rating_id, seller_id, body) values (v_rating.id, v_uid, v_body)
    on conflict (rating_id) do update set body = excluded.body, edited_at = clock_timestamp();
  if not v_existed then
    perform private.notify(
      v_rating.rater_id, 'RATINGS', 'rating.replied', 'rating', v_rating.id::text,
      pg_catalog.jsonb_build_object('rating_id', v_rating.id, 'seller_id', v_uid),
      'rating-reply:' || v_rating.id::text);
  end if;
  return pg_catalog.jsonb_build_object('rating_id', v_rating.id, 'replied', true);
end;
$$;

comment on function public.reply_to_rating(uuid, text) is
  'يرد المعلن على تقييم ظاهر. الرد لا يغير الدرجة.';

-- اعتراض المعلن على تقييم: مرة واحدة، ولا يخفي التقييم.
create function public.appeal_rating(p_rating_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_reason text := pg_catalog.btrim(coalesce(p_reason, ''));
  v_rating public.seller_ratings;
  v_appeal public.rating_appeals;
begin
  if pg_catalog.char_length(v_reason) < 1 or pg_catalog.char_length(v_reason) > 2000 then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_reason')));
  end if;
  select * into v_rating from public.seller_ratings r where r.id = p_rating_id and r.seller_id = v_uid;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'rating'));
  end if;
  select * into v_appeal from public.rating_appeals a where a.rating_id = v_rating.id;
  if found then
    -- إعادة الطلب نفسه بعد انقطاع تعيد الاعتراض القائم.
    return pg_catalog.jsonb_build_object('appeal_id', v_appeal.id, 'status', v_appeal.status, 'created', false);
  end if;
  if v_rating.status <> 'VISIBLE' then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('status', v_rating.status));
  end if;
  insert into public.rating_appeals (rating_id, seller_id, reason)
    values (v_rating.id, v_uid, v_reason) returning * into v_appeal;
  return pg_catalog.jsonb_build_object('appeal_id', v_appeal.id, 'status', v_appeal.status, 'created', true);
end;
$$;

comment on function public.appeal_rating(uuid, text) is
  'يعترض المعلن على تقييم مرة واحدة. لا يخفيه؛ تقرر الإدارة.';

------------------------------------------------------------------------------
-- الإدارة (ratings.moderate)
------------------------------------------------------------------------------

create function public.admin_hide_rating(
  p_rating_id uuid,
  p_reason_code text,
  p_reason_text text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('ratings.moderate');
  v_text text := private.require_moderation_reason('RATING_HIDE', p_reason_code, p_reason_text);
  v_rating public.seller_ratings;
begin
  select * into v_rating from public.seller_ratings r where r.id = p_rating_id for update;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'rating'));
  end if;
  if v_rating.status = 'HIDDEN' then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('status', v_rating.status));
  end if;
  update public.seller_ratings r set
    status = 'HIDDEN', hidden_at = clock_timestamp(), hidden_by = v_actor,
    hidden_reason_code = p_reason_code, hidden_reason_text = v_text
    where r.id = v_rating.id;
  perform private.audit(
    v_actor, 'rating.hidden', 'rating', v_rating.id::text,
    pg_catalog.jsonb_build_object('seller_id', v_rating.seller_id, 'rater_id', v_rating.rater_id),
    p_reason_code, v_text);
  return pg_catalog.jsonb_build_object('rating_id', v_rating.id, 'status', 'HIDDEN');
end;
$$;

comment on function public.admin_hide_rating(uuid, text, text) is
  'إخفاء تقييم مخالف بسبب إلزامي؛ يخرج من العرض والمتوسط. القدرة: ratings.moderate.';

create function public.admin_unhide_rating(p_rating_id uuid, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('ratings.moderate');
  v_note text := nullif(pg_catalog.btrim(coalesce(p_note, '')), '');
  v_rating public.seller_ratings;
begin
  select * into v_rating from public.seller_ratings r where r.id = p_rating_id for update;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'rating'));
  end if;
  if v_rating.status <> 'HIDDEN' then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('status', v_rating.status));
  end if;
  if pg_catalog.char_length(v_note) > 1000 then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('note')));
  end if;
  update public.seller_ratings r set
    status = 'VISIBLE', hidden_at = null, hidden_by = null,
    hidden_reason_code = null, hidden_reason_text = null
    where r.id = v_rating.id;
  perform private.audit(
    v_actor, 'rating.unhidden', 'rating', v_rating.id::text,
    pg_catalog.jsonb_build_object('seller_id', v_rating.seller_id), null, v_note);
  return pg_catalog.jsonb_build_object('rating_id', v_rating.id, 'status', 'VISIBLE');
end;
$$;

comment on function public.admin_unhide_rating(uuid, text) is
  'إعادة إظهار تقييم أُخفي. القدرة: ratings.moderate.';

-- قرار الإدارة في اعتراض: ACCEPTED يخفي التقييم بسبب مسجل، وREJECTED يبقيه.
create function public.admin_decide_rating_appeal(
  p_appeal_id uuid,
  p_decision text,
  p_reason_code text default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('ratings.moderate');
  v_note text := nullif(pg_catalog.btrim(coalesce(p_note, '')), '');
  v_appeal public.rating_appeals;
  v_rating public.seller_ratings;
  v_text text;
begin
  if p_decision is null or p_decision not in ('ACCEPTED', 'REJECTED') or pg_catalog.char_length(v_note) > 2000 then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_decision')));
  end if;
  select * into v_appeal from public.rating_appeals a where a.id = p_appeal_id for update;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'rating_appeal'));
  end if;
  if v_appeal.status <> 'OPEN' then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('status', v_appeal.status));
  end if;
  select * into v_rating from public.seller_ratings r where r.id = v_appeal.rating_id for update;

  if p_decision = 'ACCEPTED' then
    v_text := private.require_moderation_reason('RATING_HIDE', p_reason_code, p_note);
    if v_rating.status = 'VISIBLE' then
      update public.seller_ratings r set
        status = 'HIDDEN', hidden_at = clock_timestamp(), hidden_by = v_actor,
        hidden_reason_code = p_reason_code, hidden_reason_text = v_text
        where r.id = v_rating.id;
    end if;
  end if;

  update public.rating_appeals a set
    status = p_decision, decision_note = v_note, decided_by = v_actor, decided_at = clock_timestamp()
    where a.id = v_appeal.id;

  perform private.audit(
    v_actor, 'rating.appeal_decided', 'rating_appeal', v_appeal.id::text,
    pg_catalog.jsonb_build_object('decision', p_decision, 'rating_id', v_rating.id),
    p_reason_code, v_note);

  perform private.notify(
    v_appeal.seller_id, 'RATINGS', 'rating.appeal_decided', 'rating', v_rating.id::text,
    pg_catalog.jsonb_build_object('rating_id', v_rating.id, 'decision', p_decision),
    'appeal:' || v_appeal.id::text);

  return pg_catalog.jsonb_build_object('appeal_id', v_appeal.id, 'status', p_decision);
end;
$$;

comment on function public.admin_decide_rating_appeal(uuid, text, text, text) is
  'قرار الإدارة في اعتراض على تقييم: القبول يخفيه بسبب، والرفض يبقيه. القدرة: ratings.moderate.';

------------------------------------------------------------------------------
-- البلاغ عن تقييم (AD-FR-015)
------------------------------------------------------------------------------

alter table public.reports drop constraint reports_target_type_check;
alter table public.reports add constraint reports_target_type_check
  check (target_type in ('LISTING', 'ACCOUNT', 'MESSAGE', 'COMMENT', 'RATING'));

-- أعيد تعريفها لإضافة هدف التقييم؛ بقية القواعد كما كانت.
create or replace function public.submit_report(
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
     or p_target_type is null or p_target_type not in ('LISTING', 'ACCOUNT', 'MESSAGE', 'COMMENT', 'RATING')
     or p_reason is null
     or p_reason not in ('SPAM', 'FRAUD', 'ABUSE', 'MISLEADING', 'PROHIBITED_CONTENT', 'OTHER')
     or pg_catalog.char_length(v_desc) > 2000
     or (p_reason = 'OTHER' and v_desc is null) then
    perform private.raise_error('VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', (
      select pg_catalog.jsonb_agg(f) from (
        select 'request_id' as f where p_request_id is null
        union all select 'p_target_id' where p_target_id is null
        union all select 'p_target_type' where p_target_type is null
          or p_target_type not in ('LISTING', 'ACCOUNT', 'MESSAGE', 'COMMENT', 'RATING')
        union all select 'p_reason' where p_reason is null
          or p_reason not in ('SPAM', 'FRAUD', 'ABUSE', 'MISLEADING', 'PROHIBITED_CONTENT', 'OTHER')
        union all select 'p_description' where pg_catalog.char_length(v_desc) > 2000
          or (p_reason = 'OTHER' and v_desc is null)) x)));
  end if;

  select * into v_existing from public.reports r
    where r.reporter_id = v_uid and r.request_id = p_request_id;
  if found then
    return pg_catalog.jsonb_build_object(
      'report_id', v_existing.id, 'ref', v_existing.ref, 'status', v_existing.status,
      'created', false, 'duplicate', false);
  end if;

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
  elsif p_target_type = 'RATING' then
    -- تقييم ظاهر للعامة (أو لصاحبه المقيَّم)، وليس للمبلّغ.
    select r.rater_id into v_target_user from public.seller_ratings r
      where r.id = p_target_id and r.status = 'VISIBLE';
  else
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

grant execute on function public.get_rating_eligibility(uuid) to authenticated;
grant execute on function public.submit_rating(uuid, integer, text, boolean, uuid) to authenticated;
grant execute on function public.edit_rating(uuid, integer, text) to authenticated;
grant execute on function public.reply_to_rating(uuid, text) to authenticated;
grant execute on function public.appeal_rating(uuid, text) to authenticated;
grant execute on function public.admin_hide_rating(uuid, text, text) to authenticated;
grant execute on function public.admin_unhide_rating(uuid, text) to authenticated;
grant execute on function public.admin_decide_rating_appeal(uuid, text, text, text) to authenticated;
