-- 19 follows — MOBILE-BE-304
-- حفظ عمليات البحث ومتابعة المعلنين وتنبيه أول نشر معتمد: AD-FR-026، AD-AC-015.
-- لا تنبيه لتجديد الظهور ولا لإعادة الإظهار ولا لتعديل منشور؛ تنبيه واحد لكل
-- مستخدم وإعلان مهما تعددت الاشتراكات المطابقة.

create table public.saved_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text check (name is null or char_length(name) between 1 and 80),
  -- المرشحات المعتمدة فقط، بصيغة search_listings دون p_ (query وregion_id…).
  filters jsonb not null,
  -- بصمة المرشحات المنظمة: بحث مكرر للمستخدم نفسه لا يحفظ مرتين.
  filters_hash text not null,
  created_at timestamptz not null default now(),
  unique (user_id, filters_hash)
);

create index saved_searches_user_idx on public.saved_searches (user_id, created_at desc);

create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  seller_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, seller_id),
  constraint follows_not_self check (follower_id <> seller_id)
);

create index follows_seller_idx on public.follows (seller_id);

alter table public.saved_searches enable row level security;
alter table public.follows enable row level security;

create policy saved_searches_read_own on public.saved_searches
  for select to authenticated using ((select auth.uid()) = user_id);
create policy follows_read_own on public.follows
  for select to authenticated using ((select auth.uid()) = follower_id);

grant select on public.saved_searches, public.follows to authenticated;

------------------------------------------------------------------------------
-- تنظيم المرشحات
------------------------------------------------------------------------------

-- يعيد المرشحات المعتمدة منظمة، أو null إن كان فيها ما لا يصح (نوع خاطئ، مفتاح
-- غير معروف، نطاق معكوس أو سالب، مدينة لا تتبع المنطقة، أو لا مرشح إطلاقًا).
create function private.normalize_search_filters(p_filters jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_out jsonb := '{}'::jsonb;
  v_key text;
  v_val jsonb;
  v_query text;
  v_age_min integer;
  v_age_max integer;
  v_price_min numeric;
  v_price_max numeric;
begin
  if p_filters is null or pg_catalog.jsonb_typeof(p_filters) <> 'object' then
    return null;
  end if;
  for v_key, v_val in select * from pg_catalog.jsonb_each(p_filters) loop
    if pg_catalog.jsonb_typeof(v_val) = 'null' then
      continue;
    end if;
    if v_key = 'query' then
      if pg_catalog.jsonb_typeof(v_val) <> 'string' then return null; end if;
      v_query := nullif(pg_catalog.btrim(v_val #>> '{}'), '');
      if pg_catalog.char_length(v_query) > 100 then return null; end if;
      if v_query is not null then v_out := v_out || pg_catalog.jsonb_build_object('query', v_query); end if;
    elsif v_key in ('region_id', 'city_id', 'breed_id', 'age_min', 'age_max') then
      if pg_catalog.jsonb_typeof(v_val) <> 'number' or (v_val #>> '{}') !~ '^[0-9]{1,9}$' then return null; end if;
      v_out := v_out || pg_catalog.jsonb_build_object(v_key, (v_val #>> '{}')::integer);
    elsif v_key in ('price_min', 'price_max') then
      if pg_catalog.jsonb_typeof(v_val) <> 'number' or (v_val #>> '{}') !~ '^[0-9]{1,10}(\.[0-9]{1,2})?$' then
        return null;
      end if;
      v_out := v_out || pg_catalog.jsonb_build_object(v_key, (v_val #>> '{}')::numeric);
    elsif v_key = 'sex' then
      if v_val #>> '{}' not in ('MALE', 'FEMALE') then return null; end if;
      v_out := v_out || pg_catalog.jsonb_build_object('sex', v_val #>> '{}');
    elsif v_key = 'offer_type' then
      if v_val #>> '{}' not in ('FIXED_PRICE', 'IN_PERSON_AUCTION') then return null; end if;
      v_out := v_out || pg_catalog.jsonb_build_object('offer_type', v_val #>> '{}');
    else
      return null;
    end if;
  end loop;

  if v_out = '{}'::jsonb then
    return null;
  end if;

  v_age_min := (v_out ->> 'age_min')::integer;
  v_age_max := (v_out ->> 'age_max')::integer;
  v_price_min := (v_out ->> 'price_min')::numeric;
  v_price_max := (v_out ->> 'price_max')::numeric;
  if (v_age_min is not null and v_age_max is not null and v_age_min > v_age_max)
     or (v_price_min is not null and v_price_max is not null and v_price_min > v_price_max) then
    return null;
  end if;
  -- نطاق السعر يستبعد المزاد: لا يجتمع مع نوع «مزاد».
  if (v_price_min is not null or v_price_max is not null) and v_out ->> 'offer_type' = 'IN_PERSON_AUCTION' then
    return null;
  end if;
  if v_out ? 'city_id' and v_out ? 'region_id'
     and not exists (
       select 1 from public.cities c
       where c.id = (v_out ->> 'city_id')::integer and c.region_id = (v_out ->> 'region_id')::integer) then
    return null;
  end if;
  return v_out;
end;
$$;

-- هل تطابق النسخة المنشورة هذه المرشحات؟ القواعد نفسها قواعد search_listings.
create function private.filters_match_version(p_filters jsonb, p_version public.listing_versions)
returns boolean
language sql
stable
set search_path = ''
as $$
  select
    (not p_filters ? 'query'
      or p_version.title ilike '%' || pg_catalog.replace(pg_catalog.replace(pg_catalog.replace(
        p_filters ->> 'query', '\', '\\'), '%', '\%'), '_', '\_') || '%')
    and (not p_filters ? 'region_id' or p_version.region_id = (p_filters ->> 'region_id')::integer)
    and (not p_filters ? 'city_id' or p_version.city_id = (p_filters ->> 'city_id')::integer)
    and (not p_filters ? 'breed_id' or p_version.breed_id = (p_filters ->> 'breed_id')::integer)
    and (not p_filters ? 'sex' or p_version.sex::text = p_filters ->> 'sex')
    and (not p_filters ? 'offer_type' or p_version.offer_type::text = p_filters ->> 'offer_type')
    and (not p_filters ? 'age_min' or p_version.age_months >= (p_filters ->> 'age_min')::integer)
    and (not p_filters ? 'age_max' or p_version.age_months <= (p_filters ->> 'age_max')::integer)
    and (not p_filters ? 'price_min' or p_version.price >= (p_filters ->> 'price_min')::numeric)
    and (not p_filters ? 'price_max' or p_version.price <= (p_filters ->> 'price_max')::numeric);
$$;

------------------------------------------------------------------------------
-- الدوال
------------------------------------------------------------------------------

-- حفظ بحث للمتابعة. المكرر بالمرشحات نفسها يعيد المحفوظ. حد من الإعدادات.
create function public.save_search(p_filters jsonb, p_name text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_filters jsonb := private.normalize_search_filters(p_filters);
  v_name text := nullif(pg_catalog.btrim(coalesce(p_name, '')), '');
  v_max integer := (private.published_settings() #>> '{follows,saved_searches_max}')::integer;
  v_hash text;
  v_row public.saved_searches;
begin
  if v_filters is null or pg_catalog.char_length(v_name) > 80 then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array(
        case when v_filters is null then 'p_filters' else 'p_name' end)));
  end if;
  v_hash := pg_catalog.md5(v_filters::text);

  select * into v_row from public.saved_searches s where s.user_id = v_uid and s.filters_hash = v_hash;
  if found then
    return pg_catalog.jsonb_build_object('id', v_row.id, 'created', false);
  end if;

  if (select count(*) from public.saved_searches s where s.user_id = v_uid) >= v_max then
    perform private.raise_error('FOLLOW_LIMIT_REACHED',
      pg_catalog.jsonb_build_object('kind', 'saved_searches', 'limit', v_max));
  end if;

  insert into public.saved_searches (user_id, name, filters, filters_hash)
    values (v_uid, v_name, v_filters, v_hash)
    on conflict (user_id, filters_hash) do nothing
    returning * into v_row;
  if v_row.id is null then
    select * into v_row from public.saved_searches s where s.user_id = v_uid and s.filters_hash = v_hash;
    return pg_catalog.jsonb_build_object('id', v_row.id, 'created', false);
  end if;
  return pg_catalog.jsonb_build_object('id', v_row.id, 'created', true);
end;
$$;

comment on function public.save_search(jsonb, text) is
  'يحفظ بحثًا بمرشحاته للمتابعة وتنبيه أول نشر مطابق. المكرر يعيد المحفوظ.';

create function public.delete_saved_search(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_count integer;
begin
  delete from public.saved_searches s where s.id = p_id and s.user_id = v_uid;
  get diagnostics v_count = row_count;
  return pg_catalog.jsonb_build_object('id', p_id, 'deleted', v_count > 0);
end;
$$;

comment on function public.delete_saved_search(uuid) is
  'يلغي متابعة بحث محفوظ. الإلغاء المتكرر آمن.';

create function public.follow_seller(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_max integer := (private.published_settings() #>> '{follows,followed_sellers_max}')::integer;
  v_inserted integer;
begin
  if p_user_id is null or p_user_id = v_uid then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_user_id')));
  end if;
  -- معلن له ملف عام فقط؛ الحظر لا يكشف.
  if not exists (select 1 from public.profiles p where p.id = p_user_id and p.display_name is not null)
     or private.is_blocked(v_uid, p_user_id) then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'account'));
  end if;
  if exists (select 1 from public.follows f where f.follower_id = v_uid and f.seller_id = p_user_id) then
    return pg_catalog.jsonb_build_object('user_id', p_user_id, 'following', true, 'created', false);
  end if;
  if (select count(*) from public.follows f where f.follower_id = v_uid) >= v_max then
    perform private.raise_error('FOLLOW_LIMIT_REACHED',
      pg_catalog.jsonb_build_object('kind', 'sellers', 'limit', v_max));
  end if;
  insert into public.follows (follower_id, seller_id) values (v_uid, p_user_id) on conflict do nothing;
  get diagnostics v_inserted = row_count;
  return pg_catalog.jsonb_build_object('user_id', p_user_id, 'following', true, 'created', v_inserted > 0);
end;
$$;

comment on function public.follow_seller(uuid) is
  'يتابع معلنًا لتنبيه أول نشر معتمد لإعلاناته. التكرار آمن.';

create function public.unfollow_seller(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  delete from public.follows f where f.follower_id = v_uid and f.seller_id = p_user_id;
  return pg_catalog.jsonb_build_object('user_id', p_user_id, 'following', false);
end;
$$;

comment on function public.unfollow_seller(uuid) is
  'يلغي متابعة معلن. الإلغاء المتكرر آمن.';

-- متابعات صاحب الجلسة (G03).
create view public.my_saved_searches
with (security_barrier = true) as
select s.id, s.name, s.filters, s.created_at
from public.saved_searches s
where s.user_id = (select auth.uid());

create view public.my_follows
with (security_barrier = true) as
select
  f.seller_id as user_id,
  p.display_name,
  p.region_id,
  r.name_ar as region_name_ar,
  f.created_at as followed_at,
  (select count(*)::integer from public.listings l
    where l.owner_id = f.seller_id and l.status = 'PUBLISHED' and l.deleted_at is null) as published_listings_count
from public.follows f
join public.profiles p on p.id = f.seller_id
left join public.regions r on r.id = p.region_id
where f.follower_id = (select auth.uid());

comment on view public.my_saved_searches is 'عمليات البحث المحفوظة لصاحب الجلسة.';
comment on view public.my_follows is 'المعلنون الذين يتابعهم صاحب الجلسة.';

grant select on public.my_saved_searches, public.my_follows to authenticated;

------------------------------------------------------------------------------
-- تنبيه أول نشر معتمد
------------------------------------------------------------------------------

-- يعمل مرة واحدة لكل إعلان: عند أول اعتماد (first_published_at من فارغ إلى قيمة).
-- التجديد والتعديل وإعادة الإظهار لا تمس first_published_at فلا تنبه.
create function private.notify_first_publication()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_version public.listing_versions;
  v_owner_active boolean;
  r record;
begin
  if new.status <> 'PUBLISHED' or new.published_version_id is null then
    return new;
  end if;
  select * into v_version from public.listing_versions v where v.id = new.published_version_id;
  -- مزاد مضى موعده لا ينبه.
  if v_version.offer_type = 'IN_PERSON_AUCTION' and v_version.auction_starts_at <= now() then
    return new;
  end if;
  select (p.status = 'ACTIVE') into v_owner_active from public.profiles p where p.id = new.owner_id;
  if not coalesce(v_owner_active, false) then
    return new;
  end if;

  -- مستخدم واحد: المتابعة المباشرة للمعلن تسبق، ثم أول بحث مطابق. dedupe_key
  -- واحد لكل مستخدم وإعلان فلا تكرار مع تعدد الاشتراكات.
  for r in
    select u.user_id, min(u.source_rank) as rank
    from (
      select f.follower_id as user_id, 1 as source_rank
        from public.follows f where f.seller_id = new.owner_id
      union all
      select s.user_id, 2
        from public.saved_searches s
        where private.filters_match_version(s.filters, v_version)
    ) u
    where u.user_id <> new.owner_id
      and not private.is_blocked(u.user_id, new.owner_id)
      and exists (select 1 from public.profiles p where p.id = u.user_id and p.status = 'ACTIVE')
    group by u.user_id
  loop
    perform private.notify(
      r.user_id, 'FOLLOWS', 'follow.new_listing', 'listing', new.id::text,
      pg_catalog.jsonb_build_object(
        'listing_id', new.id, 'title', v_version.title,
        'source', case when r.rank = 1 then 'SELLER' else 'SEARCH' end),
      'follow-listing:' || new.id::text);
  end loop;
  return new;
end;
$$;

create trigger listings_notify_first_publication
  after update of first_published_at on public.listings
  for each row
  when (old.first_published_at is null and new.first_published_at is not null)
  execute function private.notify_first_publication();

grant execute on function public.save_search(jsonb, text) to authenticated;
grant execute on function public.delete_saved_search(uuid) to authenticated;
grant execute on function public.follow_seller(uuid) to authenticated;
grant execute on function public.unfollow_seller(uuid) to authenticated;
