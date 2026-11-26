-- 29 promotions — MOBILE-PROMO-20261126 (TEAM-DEC-017، INT-010)
-- الدعايات التجارية: ينشئها الموظفون من لوحة الإدارة وتظهر في التطبيق بين إعلانات المستخدمين
-- بشارة «إعلان ممول». لا دفع ولا فوترة في النظام. الجدول بلا وصول مباشر؛ كل قراءة وكتابة عبر الدوال.
-- مسار الصورة في bucket ‏promotions: {uuid مجلد}/{اسم}.{ext} (المجلد يولده العميل قبل الحفظ).

------------------------------------------------------------------------------
-- القدرة الجديدة promotions.manage (تمنح للمشرف؛ المدير يملكها ضمنًا)
------------------------------------------------------------------------------

create or replace function private.all_capabilities()
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array[
    'listings.review', 'listings.hide', 'accounts.manage', 'reports.handle',
    'evidence.read', 'comments.moderate', 'ratings.moderate', 'lookups.manage',
    'settings.manage', 'staff.manage', 'audit.read', 'stats.read',
    'promotions.manage'
  ]::text[]
$$;

------------------------------------------------------------------------------
-- الجداول
------------------------------------------------------------------------------

create type public.promotion_status as enum ('ACTIVE', 'PAUSED', 'ARCHIVED');
create type public.promotion_action as enum ('URL', 'WHATSAPP', 'CALL', 'NONE');

create table public.promotions (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 2 and 60),
  body text check (body is null or char_length(body) between 1 and 140),
  advertiser_name text not null check (char_length(advertiser_name) between 2 and 60),
  image_path text not null check (
    char_length(image_path) <= 120 and image_path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]+$'),
  action_type public.promotion_action not null,
  action_value text,
  placements text[] not null check (
    pg_catalog.cardinality(placements) > 0
    and placements <@ array['HOME_FEED', 'SEARCH_RESULTS']::text[]),
  -- NULL: كل المناطق.
  region_ids integer[] check (region_ids is null or pg_catalog.cardinality(region_ids) > 0),
  starts_at timestamptz not null,
  -- حد غير شامل؛ NULL: بلا نهاية.
  ends_at timestamptz,
  priority integer not null default 50 check (priority between 0 and 100),
  status public.promotion_status not null default 'ACTIVE',
  impression_count integer not null default 0 check (impression_count >= 0),
  click_count integer not null default 0 check (click_count >= 0),
  created_by uuid,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint promotions_period check (ends_at is null or ends_at > starts_at),
  constraint promotions_action_value check (
    (action_type = 'NONE' and action_value is null)
    or (action_type = 'URL' and char_length(action_value) <= 500
        and action_value ~ '^https://[^[:space:]/?#@]+\.[^[:space:]/?#@]+([/?#][^[:space:]]*)?$')
    or (action_type in ('WHATSAPP', 'CALL') and action_value ~ '^\+9665[0-9]{8}$'))
);

create trigger promotions_set_updated_at before update on public.promotions
  for each row execute function private.set_updated_at();

create index promotions_running_idx on public.promotions (priority desc, starts_at desc)
  where status = 'ACTIVE';

-- إعدادات العرض: صف واحد. خارج إصدارات platform_settings لأنها تشغيلية تتغير كثيرًا.
create table public.promotion_settings (
  id boolean primary key default true check (id),
  enabled boolean not null default true,
  feed_interval integer not null default 8 check (feed_interval between 4 and 30),
  updated_by uuid,
  updated_at timestamptz not null default now()
);
insert into public.promotion_settings default values;

-- منع تضخيم العدادات: حدث واحد لكل مشاهد ودعاية ونوع في نافذة زمنية (ساعة للظهور، دقيقة للنقر).
create table public.promotion_event_log (
  promotion_id uuid not null references public.promotions (id) on delete cascade,
  viewer text not null check (char_length(viewer) <= 64),
  kind text not null check (kind in ('IMPRESSION', 'CLICK')),
  window_start timestamptz not null,
  primary key (promotion_id, viewer, kind, window_start)
);
create index promotion_event_log_window_idx on public.promotion_event_log (window_start);

alter table public.promotions enable row level security;
alter table public.promotion_settings enable row level security;
alter table public.promotion_event_log enable row level security;

------------------------------------------------------------------------------
-- التخزين: bucket عام للقراءة؛ الرفع والحذف للموظف بالقدرة.
------------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('promotions', 'promotions', true, 1048576, array['image/jpeg', 'image/png', 'image/webp']);

create policy promotions_images_insert_staff on storage.objects
  for insert to authenticated
  with check (bucket_id = 'promotions' and (select public.has_staff_capability('promotions.manage')));

create policy promotions_images_read_staff on storage.objects
  for select to authenticated
  using (bucket_id = 'promotions' and (select public.has_staff_capability('promotions.manage')));

create policy promotions_images_delete_staff on storage.objects
  for delete to authenticated
  using (bucket_id = 'promotions' and (select public.has_staff_capability('promotions.manage')));

------------------------------------------------------------------------------
-- مساعدات
------------------------------------------------------------------------------

create function private.promotion_admin_json(p public.promotions)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'id', p.id,
    'title', p.title,
    'body', p.body,
    'advertiser_name', p.advertiser_name,
    'image_path', p.image_path,
    'action_type', p.action_type,
    'action_value', p.action_value,
    'placements', pg_catalog.to_jsonb(p.placements),
    'region_ids', pg_catalog.to_jsonb(p.region_ids),
    'starts_at', p.starts_at,
    'ends_at', p.ends_at,
    'priority', p.priority,
    'status', p.status,
    'impression_count', p.impression_count,
    'click_count', p.click_count,
    'created_by', p.created_by,
    'updated_by', p.updated_by,
    'created_at', p.created_at,
    'updated_at', p.updated_at)
$$;

create function private.promotion_settings_json()
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'enabled', s.enabled, 'feed_interval', s.feed_interval,
    'updated_by', s.updated_by, 'updated_at', s.updated_at)
  from public.promotion_settings s
$$;

-- يقبل 05XXXXXXXX و5XXXXXXXX و9665XXXXXXXX و+9665XXXXXXXX بمسافات أو شرطات؛ NULL إن لم يصلح.
create function private.normalize_saudi_mobile(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when d ~ '^05[0-9]{8}$' then '+966' || pg_catalog.substr(d, 2)
    when d ~ '^5[0-9]{8}$' then '+966' || d
    when d ~ '^9665[0-9]{8}$' then '+' || d
  end
  from (select pg_catalog.regexp_replace(pg_catalog.regexp_replace(coalesce(p, ''), '[[:space:]-]', '', 'g'), '^\+', '') as d) x
$$;

-- نص مختصر: مسافات موحدة، بلا محارف تحكم؛ NULL للفارغ.
create function private.clean_short_text(p text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(btrim(pg_catalog.regexp_replace(coalesce(p, ''), '[[:space:]]+', ' ', 'g')), '')
$$;

------------------------------------------------------------------------------
-- دوال الإدارة (القدرة promotions.manage)
------------------------------------------------------------------------------

create function public.admin_list_promotions(
  p_status text default null,
  p_limit integer default 50,
  p_after_updated_at timestamptz default null,
  p_after_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_staff('promotions.manage');
  if (p_status is not null and p_status not in ('ACTIVE', 'PAUSED', 'ARCHIVED'))
    or p_limit is null or p_limit not between 1 and 200
    or ((p_after_updated_at is null) <> (p_after_id is null))
  then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_status', 'p_limit', 'cursor')));
  end if;

  return coalesce((
    select pg_catalog.jsonb_agg(private.promotion_admin_json(p) order by p.updated_at desc, p.id desc)
    from (
      select * from public.promotions p
      where (p_status is null or p.status = p_status::public.promotion_status)
        and (p_after_updated_at is null or (p.updated_at, p.id) < (p_after_updated_at, p_after_id))
      order by p.updated_at desc, p.id desc
      limit p_limit
    ) p
  ), '[]'::jsonb);
end;
$$;

create function public.admin_get_promotion(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v public.promotions;
begin
  perform private.require_staff('promotions.manage');
  select * into v from public.promotions p where p.id = p_id;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'promotion'));
  end if;
  return private.promotion_admin_json(v);
end;
$$;

-- إنشاء (p_id فارغ) أو تعديل. الحقول: title, body, advertiser_name, image_path, action_type,
-- action_value, placements, region_ids, starts_at, ends_at, priority. الحالة تتغير بدالة مستقلة.
create function public.admin_save_promotion(p_id uuid default null, p_payload jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_staff('promotions.manage');
  v_fields text[] := array[]::text[];
  v_title text;
  v_body text;
  v_adv text;
  v_image text;
  v_action public.promotion_action;
  v_value text;
  v_placements text[];
  v_regions integer[];
  v_starts timestamptz;
  v_ends timestamptz;
  v_priority integer;
  v_row public.promotions;
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
begin
  if pg_catalog.jsonb_typeof(v_payload) <> 'object' then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('payload')));
  end if;

  if p_id is not null then
    select * into v_row from public.promotions p where p.id = p_id for update;
    if not found then
      perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'promotion'));
    end if;
  end if;

  v_title := private.clean_short_text(v_payload ->> 'title');
  if v_title is null or char_length(v_title) not between 2 and 60 or v_title ~ '[[:cntrl:]]' then
    v_fields := v_fields || 'title'::text;
  end if;

  v_body := private.clean_short_text(v_payload ->> 'body');
  if v_body is not null and (char_length(v_body) > 140 or v_body ~ '[[:cntrl:]]') then
    v_fields := v_fields || 'body'::text;
  end if;

  v_adv := private.clean_short_text(v_payload ->> 'advertiser_name');
  if v_adv is null or char_length(v_adv) not between 2 and 60 or v_adv ~ '[[:cntrl:]]' then
    v_fields := v_fields || 'advertiser_name'::text;
  end if;

  v_image := v_payload ->> 'image_path';
  if v_image is null or char_length(v_image) > 120 or v_image !~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]+$'
    or not exists (select 1 from storage.objects o where o.bucket_id = 'promotions' and o.name = v_image)
  then
    v_fields := v_fields || 'image_path'::text;
  end if;

  if (v_payload ->> 'action_type') in ('URL', 'WHATSAPP', 'CALL', 'NONE') then
    v_action := (v_payload ->> 'action_type')::public.promotion_action;
    v_value := btrim(coalesce(v_payload ->> 'action_value', ''));
    if v_action = 'NONE' then
      v_value := null;
    elsif v_action = 'URL' then
      if char_length(v_value) > 500
        or v_value !~ '^https://[^[:space:]/?#@]+\.[^[:space:]/?#@]+([/?#][^[:space:]]*)?$'
      then
        v_fields := v_fields || 'action_value'::text;
      end if;
    else
      v_value := private.normalize_saudi_mobile(v_value);
      if v_value is null then
        v_fields := v_fields || 'action_value'::text;
      end if;
    end if;
  else
    v_fields := v_fields || 'action_type'::text;
  end if;

  if pg_catalog.jsonb_typeof(v_payload -> 'placements') = 'array' then
    select pg_catalog.array_agg(distinct e order by e) into v_placements
      from pg_catalog.jsonb_array_elements_text(v_payload -> 'placements') as t (e);
  end if;
  if v_placements is null or pg_catalog.cardinality(v_placements) = 0
    or not (v_placements <@ array['HOME_FEED', 'SEARCH_RESULTS']::text[])
  then
    v_fields := v_fields || 'placements'::text;
  end if;

  if v_payload -> 'region_ids' is null or pg_catalog.jsonb_typeof(v_payload -> 'region_ids') = 'null' then
    v_regions := null;
  elsif pg_catalog.jsonb_typeof(v_payload -> 'region_ids') = 'array'
    and pg_catalog.jsonb_array_length(v_payload -> 'region_ids') > 0
    and not exists (
      select 1 from pg_catalog.jsonb_array_elements(v_payload -> 'region_ids') e
      where pg_catalog.jsonb_typeof(e) <> 'number' or (e #>> '{}') !~ '^[0-9]{1,9}$')
  then
    select pg_catalog.array_agg(distinct (e #>> '{}')::integer order by (e #>> '{}')::integer) into v_regions
      from pg_catalog.jsonb_array_elements(v_payload -> 'region_ids') e;
    if exists (
      select 1 from pg_catalog.unnest(v_regions) r (id)
      where not exists (select 1 from public.regions g where g.id = r.id and g.is_active))
    then
      v_fields := v_fields || 'region_ids'::text;
    end if;
  else
    v_fields := v_fields || 'region_ids'::text;
  end if;

  begin
    v_starts := (v_payload ->> 'starts_at')::timestamptz;
  exception when others then
    v_starts := null;
  end;
  if v_starts is null then
    v_fields := v_fields || 'starts_at'::text;
  end if;

  if v_payload ->> 'ends_at' is not null then
    begin
      v_ends := (v_payload ->> 'ends_at')::timestamptz;
    exception when others then
      v_ends := null;
    end;
    if v_ends is null or (v_starts is not null and v_ends <= v_starts) then
      v_fields := v_fields || 'ends_at'::text;
    end if;
  end if;

  if v_payload -> 'priority' is null or pg_catalog.jsonb_typeof(v_payload -> 'priority') = 'null' then
    v_priority := 50;
  elsif pg_catalog.jsonb_typeof(v_payload -> 'priority') = 'number'
    and (v_payload ->> 'priority') ~ '^[0-9]{1,3}$'
    and (v_payload ->> 'priority')::integer between 0 and 100
  then
    v_priority := (v_payload ->> 'priority')::integer;
  else
    v_fields := v_fields || 'priority'::text;
  end if;

  if pg_catalog.cardinality(v_fields) > 0 then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.to_jsonb(v_fields)));
  end if;

  if p_id is null then
    insert into public.promotions (
      title, body, advertiser_name, image_path, action_type, action_value, placements,
      region_ids, starts_at, ends_at, priority, created_by, updated_by)
    values (
      v_title, v_body, v_adv, v_image, v_action, v_value, v_placements,
      v_regions, v_starts, v_ends, v_priority, v_uid, v_uid)
    returning * into v_row;
    perform private.audit(v_uid, 'promotion.created', 'promotion', v_row.id::text,
      pg_catalog.jsonb_build_object('title', v_row.title, 'advertiser_name', v_row.advertiser_name));
  else
    update public.promotions p set
      title = v_title, body = v_body, advertiser_name = v_adv, image_path = v_image,
      action_type = v_action, action_value = v_value, placements = v_placements,
      region_ids = v_regions, starts_at = v_starts, ends_at = v_ends, priority = v_priority,
      updated_by = v_uid
    where p.id = p_id
    returning * into v_row;
    perform private.audit(v_uid, 'promotion.updated', 'promotion', v_row.id::text,
      pg_catalog.jsonb_build_object('title', v_row.title, 'advertiser_name', v_row.advertiser_name));
  end if;

  return private.promotion_admin_json(v_row);
end;
$$;

create function public.admin_set_promotion_status(p_id uuid, p_status text, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_staff('promotions.manage');
  v_before public.promotion_status;
  v_row public.promotions;
  v_note text := private.clean_short_text(p_note);
begin
  if p_status is null or p_status not in ('ACTIVE', 'PAUSED', 'ARCHIVED')
    or (v_note is not null and char_length(v_note) > 1000)
  then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_status', 'p_note')));
  end if;

  select p.status into v_before from public.promotions p where p.id = p_id for update;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'promotion'));
  end if;

  update public.promotions p set status = p_status::public.promotion_status, updated_by = v_uid
    where p.id = p_id
    returning * into v_row;

  if v_before is distinct from v_row.status then
    perform private.audit(v_uid, 'promotion.status_changed', 'promotion', p_id::text,
      pg_catalog.jsonb_build_object('from', v_before, 'to', v_row.status), null, v_note);
  end if;

  return private.promotion_admin_json(v_row);
end;
$$;

create function public.admin_get_promotion_settings()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_staff('promotions.manage');
  return private.promotion_settings_json();
end;
$$;

create function public.admin_update_promotion_settings(p_enabled boolean, p_feed_interval integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_staff('promotions.manage');
  v_before jsonb := private.promotion_settings_json();
begin
  if p_enabled is null or p_feed_interval is null or p_feed_interval not between 4 and 30 then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_enabled', 'p_feed_interval')));
  end if;

  update public.promotion_settings s
    set enabled = p_enabled, feed_interval = p_feed_interval, updated_by = v_uid, updated_at = now()
    where s.id;

  perform private.audit(v_uid, 'promotion.settings_updated', 'promotion_settings', null,
    pg_catalog.jsonb_build_object(
      'from', pg_catalog.jsonb_build_object('enabled', v_before -> 'enabled', 'feed_interval', v_before -> 'feed_interval'),
      'to', pg_catalog.jsonb_build_object('enabled', p_enabled, 'feed_interval', p_feed_interval)));

  return private.promotion_settings_json();
end;
$$;

------------------------------------------------------------------------------
-- دوال التطبيق (زائر ومستخدم)
------------------------------------------------------------------------------

-- الدعايات الجارية لموضع: الحالة ACTIVE داخل فترة العرض، والموضع ضمن placements، والمنطقة
-- (إن مُررت) ضمن region_ids أو الدعاية عامة. معطلة من الإعدادات: items فارغة.
create function public.list_active_promotions(p_placement text, p_region_id integer default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_settings public.promotion_settings;
begin
  if p_placement is null or p_placement not in ('HOME_FEED', 'SEARCH_RESULTS') then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_placement')));
  end if;

  select * into v_settings from public.promotion_settings s where s.id;

  return pg_catalog.jsonb_build_object(
    'enabled', v_settings.enabled,
    'feed_interval', v_settings.feed_interval,
    'items', case when not v_settings.enabled then '[]'::jsonb else coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
          'id', p.id,
          'title', p.title,
          'body', p.body,
          'advertiser_name', p.advertiser_name,
          'image_path', p.image_path,
          'action_type', p.action_type,
          'action_value', p.action_value)
        order by p.priority desc, p.starts_at desc, p.id)
      from (
        select * from public.promotions p
        where p.status = 'ACTIVE'
          and p.starts_at <= now()
          and (p.ends_at is null or p.ends_at > now())
          and p_placement = any (p.placements)
          and (p.region_ids is null or p_region_id is null or p_region_id = any (p.region_ids))
        order by p.priority desc, p.starts_at desc, p.id
        limit 20
      ) p
    ), '[]'::jsonb) end);
end;
$$;

-- يسجل ظهورًا أو نقرًا لدعاية جارية. المشاهد: الحساب إن كان داخلًا وإلا معرف الجهاز؛ بلا هوية
-- لا يحسب. حدث واحد لكل مشاهد ودعاية: ظهور في الساعة، ونقر في الدقيقة. يعيد هل حُسب.
create function public.record_promotion_event(p_promotion_id uuid, p_kind text, p_device_id uuid default null)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_viewer text;
  v_window timestamptz;
  v_new integer;
begin
  if p_kind is null or p_kind not in ('IMPRESSION', 'CLICK') then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_kind')));
  end if;

  if not exists (
    select 1 from public.promotions p
    where p.id = p_promotion_id and p.status = 'ACTIVE'
      and p.starts_at <= now() and (p.ends_at is null or p.ends_at > now()))
  then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'promotion'));
  end if;

  v_viewer := case
    when v_uid is not null then 'u:' || v_uid::text
    when p_device_id is not null then 'd:' || p_device_id::text
  end;
  if v_viewer is null then
    return false;
  end if;

  v_window := pg_catalog.date_trunc(case when p_kind = 'IMPRESSION' then 'hour' else 'minute' end, now());
  insert into public.promotion_event_log (promotion_id, viewer, kind, window_start)
    values (p_promotion_id, v_viewer, p_kind, v_window)
    on conflict do nothing;
  get diagnostics v_new = row_count;
  if v_new = 0 then
    return false;
  end if;

  if p_kind = 'IMPRESSION' then
    update public.promotions p set impression_count = p.impression_count + 1 where p.id = p_promotion_id;
  else
    update public.promotions p set click_count = p.click_count + 1 where p.id = p_promotion_id;
  end if;

  -- تنظيف عرضي للنوافذ المنتهية (يكفي الاحتفاظ بآخر ساعتين).
  if pg_catalog.random() < 0.01 then
    delete from public.promotion_event_log l where l.window_start < now() - interval '2 hours';
  end if;

  return true;
end;
$$;

-- العدادات لا تغير updated_at (ترتيب القائمة في اللوحة يتبع تعديل الموظف).
create or replace function private.promotions_keep_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (new.impression_count, new.click_count) is distinct from (old.impression_count, old.click_count)
    and (new.title, new.body, new.advertiser_name, new.image_path, new.action_type, new.action_value,
         new.placements, new.region_ids, new.starts_at, new.ends_at, new.priority, new.status)
      is not distinct from
        (old.title, old.body, old.advertiser_name, old.image_path, old.action_type, old.action_value,
         old.placements, old.region_ids, old.starts_at, old.ends_at, old.priority, old.status)
  then
    new.updated_at := old.updated_at;
  end if;
  return new;
end;
$$;

create trigger promotions_zz_keep_updated_at before update on public.promotions
  for each row execute function private.promotions_keep_updated_at();

------------------------------------------------------------------------------
-- الصلاحيات والتوثيق
------------------------------------------------------------------------------

comment on table public.promotions is 'الدعايات التجارية (TEAM-DEC-017). لا وصول مباشر؛ عبر admin_*_promotion وlist_active_promotions.';
comment on function public.admin_list_promotions(text, integer, timestamptz, uuid) is 'قائمة الدعايات للموظف، الأحدث تعديلًا أولًا، بمؤشر (updated_at, id).';
comment on function public.admin_get_promotion(uuid) is 'دعاية واحدة للموظف.';
comment on function public.admin_save_promotion(uuid, jsonb) is 'إنشاء دعاية (p_id فارغ) أو تعديلها؛ يتحقق من كل الحقول ويعيد الصف.';
comment on function public.admin_set_promotion_status(uuid, text, text) is 'تغيير حالة الدعاية: ACTIVE أو PAUSED أو ARCHIVED.';
comment on function public.admin_get_promotion_settings() is 'إعدادات عرض الدعايات: التشغيل والفاصل.';
comment on function public.admin_update_promotion_settings(boolean, integer) is 'تحديث إعدادات عرض الدعايات (الفاصل 4 إلى 30).';
comment on function public.list_active_promotions(text, integer) is 'الدعايات الجارية لموضع في التطبيق مع الفاصل وحالة التشغيل.';
comment on function public.record_promotion_event(uuid, text, uuid) is 'تسجيل ظهور (مرة في الساعة) أو نقر (مرة في الدقيقة) لكل مشاهد.';

grant execute on function public.admin_list_promotions(text, integer, timestamptz, uuid) to authenticated;
grant execute on function public.admin_get_promotion(uuid) to authenticated;
grant execute on function public.admin_save_promotion(uuid, jsonb) to authenticated;
grant execute on function public.admin_set_promotion_status(uuid, text, text) to authenticated;
grant execute on function public.admin_get_promotion_settings() to authenticated;
grant execute on function public.admin_update_promotion_settings(boolean, integer) to authenticated;
grant execute on function public.list_active_promotions(text, integer) to anon, authenticated;
grant execute on function public.record_promotion_event(uuid, text, uuid) to anon, authenticated;
