-- MOBILE-BE-AUCTION-GEO-20261124 — الموقع الدقيق للمزاد الحضوري، وعدّاد المشاهدات، وعدد الإعجابات العام.
--
-- 1) listing_versions.auction_lat/auction_lng: إحداثيات موقع المزاد (WGS84)، تحفظ معًا أو تمسح معًا،
--    وتمسح تلقائيًا إن لم يكن العرض مزادًا حضوريًا. تلزم عند الإرسال للمزاد (listing_submit_errors)،
--    ولا يفرض ذلك قيدًا على الجدول كي لا تنكسر النسخ القديمة المنشورة قبل هذا الترحيل.
-- 2) listing_stats: عدّاد مشاهدات وعدد إعجابات (المفضلة) لكل إعلان؛ الإعجابات يصونها مشغل على favorites،
--    والمشاهدة تسجلها record_listing_view (لا تحسب مشاهدة المعلن لإعلانه).
-- 3) الـviews العامة وsearch_listings تضيف في آخرها: auction_lat وauction_lng وview_count وfavorite_count.

------------------------------------------------------------------------------
-- الإحداثيات
------------------------------------------------------------------------------

alter table public.listing_versions
  add column auction_lat numeric(9, 6) check (auction_lat is null or auction_lat between -90 and 90),
  add column auction_lng numeric(9, 6) check (auction_lng is null or auction_lng between -180 and 180),
  add constraint listing_versions_auction_geo_pair check ((auction_lat is null) = (auction_lng is null));

comment on column public.listing_versions.auction_lat is 'خط عرض موقع المزاد الحضوري (WGS84).';
comment on column public.listing_versions.auction_lng is 'خط طول موقع المزاد الحضوري (WGS84).';

create function private.clear_auction_geo()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.offer_type is distinct from 'IN_PERSON_AUCTION' then
    new.auction_lat := null;
    new.auction_lng := null;
  end if;
  return new;
end;
$$;

create trigger listing_versions_clear_auction_geo before insert or update on public.listing_versions
  for each row execute function private.clear_auction_geo();

------------------------------------------------------------------------------
-- العدّادات
------------------------------------------------------------------------------

create table public.listing_stats (
  listing_id uuid primary key references public.listings (id) on delete cascade,
  view_count integer not null default 0 check (view_count >= 0),
  favorite_count integer not null default 0 check (favorite_count >= 0)
);

-- بلا سياسات: لا وصول مباشر، والقراءة عبر الـviews والدوال.
alter table public.listing_stats enable row level security;

insert into public.listing_stats (listing_id, favorite_count)
  select f.listing_id, count(*)::integer from public.favorites f group by f.listing_id;

create function private.sync_favorite_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.listing_stats (listing_id, favorite_count) values (new.listing_id, 1)
      on conflict (listing_id) do update set favorite_count = public.listing_stats.favorite_count + 1;
  else
    update public.listing_stats s set favorite_count = greatest(s.favorite_count - 1, 0)
      where s.listing_id = old.listing_id;
  end if;
  return null;
end;
$$;

create trigger favorites_sync_count after insert or delete on public.favorites
  for each row execute function private.sync_favorite_count();

-- تسجيل مشاهدة إعلان منشور. غير المنشور NOT_FOUND، ومشاهدة المعلن لإعلانه لا تحسب.
-- يستدعيها العميل مرة لكل فتح لشاشة التفاصيل؛ لا تمنع الخادم تكرارًا متعمدًا (قبول مؤقت).
create function public.record_listing_view(p_listing_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_count integer;
begin
  select l.owner_id into v_owner from public.listings l
    where l.id = p_listing_id and l.status = 'PUBLISHED' and l.deleted_at is null;
  if v_owner is null then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'listing'));
  end if;

  if v_owner is not distinct from auth.uid() then
    select s.view_count into v_count from public.listing_stats s where s.listing_id = p_listing_id;
    return coalesce(v_count, 0);
  end if;

  insert into public.listing_stats (listing_id, view_count) values (p_listing_id, 1)
    on conflict (listing_id) do update set view_count = public.listing_stats.view_count + 1
    returning view_count into v_count;
  return v_count;
end;
$$;

comment on function public.record_listing_view(uuid) is
  'يزيد عدّاد مشاهدات إعلان منشور ويعيده؛ مشاهدة المعلن لإعلانه لا تحسب.';

revoke all on function public.record_listing_view(uuid) from public;
grant execute on function public.record_listing_view(uuid) to anon, authenticated;

------------------------------------------------------------------------------
-- الـviews العامة
------------------------------------------------------------------------------

create or replace view public.public_listing_cards
with (security_barrier = true) as
select
  l.id as listing_id,
  l.owner_id,
  p.display_name as owner_display_name,
  v.title,
  v.offer_type,
  v.price,
  v.auction_starts_at,
  (v.offer_type = 'IN_PERSON_AUCTION' and v.auction_starts_at <= now()) as auction_passed,
  v.breed_id,
  b.name_ar as breed_name_ar,
  v.breed_note,
  v.sex,
  v.age_months,
  v.region_id,
  rg.name_ar as region_name_ar,
  v.city_id,
  c.name_ar as city_name_ar,
  cover.bucket as cover_bucket,
  cover.object_path as cover_path,
  l.first_published_at,
  l.visibility_updated_at,
  l.public_ref,
  v.auction_lat,
  v.auction_lng,
  coalesce(st.view_count, 0) as view_count,
  coalesce(st.favorite_count, 0) as favorite_count
from public.listings l
join public.listing_versions v on v.id = l.published_version_id
join public.profiles p on p.id = l.owner_id
join public.breeds b on b.id = v.breed_id
join public.regions rg on rg.id = v.region_id
join public.cities c on c.id = v.city_id
left join public.media cover on cover.version_id = v.id and cover.is_cover and cover.status = 'READY'
left join public.listing_stats st on st.listing_id = l.id
where l.status = 'PUBLISHED' and l.deleted_at is null;

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
  l.comments_closed,
  v.contact_whatsapp_phone,
  v.auction_lat,
  v.auction_lng,
  coalesce(st.view_count, 0) as view_count,
  coalesce(st.favorite_count, 0) as favorite_count
from public.listings l
join public.listing_versions v on v.id = l.published_version_id
join public.profiles p on p.id = l.owner_id
join public.breeds b on b.id = v.breed_id
join public.regions rg on rg.id = v.region_id
join public.cities c on c.id = v.city_id
left join public.regions arg on arg.id = v.auction_region_id
left join public.cities ac on ac.id = v.auction_city_id
left join public.listing_stats st on st.listing_id = l.id
where l.status = 'PUBLISHED' and l.deleted_at is null;

create or replace view public.my_favorites
with (security_barrier = true) as
select
  f.listing_id,
  f.created_at as saved_at,
  (c.listing_id is not null) as available,
  c.owner_id,
  c.owner_display_name,
  c.title,
  c.offer_type,
  c.price,
  c.auction_starts_at,
  c.auction_passed,
  c.breed_id,
  c.breed_name_ar,
  c.breed_note,
  c.sex,
  c.age_months,
  c.region_id,
  c.region_name_ar,
  c.city_id,
  c.city_name_ar,
  c.cover_bucket,
  c.cover_path,
  c.public_ref,
  c.auction_lat,
  c.auction_lng,
  c.view_count,
  c.favorite_count
from public.favorites f
left join public.public_listing_cards c on c.listing_id = f.listing_id
where f.user_id = (select auth.uid());

------------------------------------------------------------------------------
-- دوال المعلن
------------------------------------------------------------------------------

create or replace function private.listing_submit_errors(p_version public.listing_versions, p_settings jsonb)
returns text[]
language plpgsql
stable
set search_path = ''
as $$
declare
  v_bad text[] := array[]::text[];
  v_images integer;
  v_covers integer;
begin
  if p_version.title is null
    or char_length(p_version.title) < (p_settings #>> '{listing,title_min}')::integer
    or char_length(p_version.title) > (p_settings #>> '{listing,title_max}')::integer
  then
    v_bad := v_bad || 'title'::text;
  end if;
  if p_version.description is null
    or char_length(p_version.description) < (p_settings #>> '{listing,description_min}')::integer
    or char_length(p_version.description) > (p_settings #>> '{listing,description_max}')::integer
  then
    v_bad := v_bad || 'description'::text;
  end if;

  if p_version.breed_id is null
    or not exists (select 1 from public.breeds b where b.id = p_version.breed_id and b.is_active)
  then
    v_bad := v_bad || 'breed_id'::text;
  elsif p_version.breed_note is null and exists (
    select 1 from public.breeds b where b.id = p_version.breed_id and b.requires_note)
  then
    v_bad := v_bad || 'breed_note'::text;
  end if;

  if p_version.sex is null then
    v_bad := v_bad || 'sex'::text;
  end if;
  if p_version.age_months is null then
    v_bad := v_bad || 'age_months'::text;
  end if;

  if p_version.region_id is null
    or not exists (select 1 from public.regions r where r.id = p_version.region_id and r.is_active)
  then
    v_bad := v_bad || 'region_id'::text;
  end if;
  if p_version.city_id is null
    or not exists (select 1 from public.cities c where c.id = p_version.city_id and c.is_active)
  then
    v_bad := v_bad || 'city_id'::text;
  end if;

  if p_version.health_notes is null then
    v_bad := v_bad || 'health_notes'::text;
  end if;
  if p_version.owner_declaration_at is null then
    v_bad := v_bad || 'owner_declaration'::text;
  end if;

  if p_version.offer_type is null then
    v_bad := v_bad || 'offer_type'::text;
  elsif p_version.offer_type = 'FIXED_PRICE' then
    if p_version.price is null then
      v_bad := v_bad || 'price'::text;
    end if;
  else
    if p_version.auction_region_id is null
      or not exists (select 1 from public.regions r where r.id = p_version.auction_region_id and r.is_active)
    then
      v_bad := v_bad || 'auction_region_id'::text;
    end if;
    if p_version.auction_city_id is null
      or not exists (select 1 from public.cities c where c.id = p_version.auction_city_id and c.is_active)
    then
      v_bad := v_bad || 'auction_city_id'::text;
    end if;
    if p_version.auction_venue is null then
      v_bad := v_bad || 'auction_venue'::text;
    end if;
    -- الموقع الدقيق على الخريطة إلزامي للمزاد الحضوري.
    if p_version.auction_lat is null or p_version.auction_lng is null then
      v_bad := v_bad || 'auction_lat'::text;
      v_bad := v_bad || 'auction_lng'::text;
    end if;
    -- موعد مستقبلي عند الإرسال (AD-FR-025).
    if p_version.auction_starts_at is null or p_version.auction_starts_at <= now() then
      v_bad := v_bad || 'auction_starts_at'::text;
    end if;
  end if;

  -- يلزم أحد الرقمين على الأقل (TEAM-DEC-012).
  if p_version.contact_phone is null and p_version.contact_whatsapp_phone is null then
    v_bad := v_bad || 'contact_phone'::text;
    v_bad := v_bad || 'contact_whatsapp_phone'::text;
  end if;

  select count(*) filter (where m.kind = 'IMAGE'), count(*) filter (where m.is_cover)
    into v_images, v_covers
    from public.media m where m.version_id = p_version.id;
  if v_images < (p_settings #>> '{media,images_min}')::integer
    or v_images > (p_settings #>> '{media,images_max}')::integer
  then
    v_bad := v_bad || 'images'::text;
  end if;
  if v_covers <> 1 then
    v_bad := v_bad || 'cover'::text;
  end if;
  if not (p_settings #>> '{media,video_enabled}')::boolean and exists (
    select 1 from public.media m where m.version_id = p_version.id and m.kind = 'VIDEO')
  then
    v_bad := v_bad || 'video'::text;
  end if;

  return v_bad;
end;
$$;

create or replace function public.save_listing_draft(p_listing_id uuid, p_patch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_listing public.listings;
  v_old public.listing_versions;
  r public.listing_versions;
  v_settings jsonb := private.published_settings();
  v_bad text[] := array[]::text[];
  v_bool boolean;
  v_text text;
  v_legacy_call boolean;
  v_legacy_wa boolean;
  v_allowed constant text[] := array[
    'title', 'description', 'breed_id', 'breed_note', 'sex', 'age_months', 'color',
    'region_id', 'city_id', 'health_notes', 'owner_declaration',
    'offer_type', 'price',
    'auction_region_id', 'auction_city_id', 'auction_venue', 'auction_starts_at',
    'auction_lat', 'auction_lng',
    'contact_phone', 'contact_whatsapp_phone', 'contact_call_enabled', 'contact_whatsapp_enabled'];
begin
  if p_patch is null or pg_catalog.jsonb_typeof(p_patch) <> 'object' then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('patch')));
  end if;

  select coalesce(pg_catalog.array_agg(k), array[]::text[]) into v_bad
    from pg_catalog.jsonb_object_keys(p_patch) as k
    where k <> all (v_allowed);
  if pg_catalog.cardinality(v_bad) > 0 then
    perform private.raise_error(
      'VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.to_jsonb(v_bad), 'reason', 'unknown_field'));
  end if;

  v_listing := private.lock_own_listing(p_listing_id, v_uid);
  v_old := private.require_draft_version(p_listing_id);
  r := v_old;

  -- النصوص: السقف من الإعدادات؛ الحد الأدنى يفحص عند الإرسال.
  select t.p_value, t.p_bad into r.title, v_bad from private.patch_text(
    p_patch, 'title', (v_settings #>> '{listing,title_max}')::integer, false, r.title, v_bad) t;
  select t.p_value, t.p_bad into r.description, v_bad from private.patch_text(
    p_patch, 'description', (v_settings #>> '{listing,description_max}')::integer, true, r.description, v_bad) t;
  select t.p_value, t.p_bad into r.breed_note, v_bad from private.patch_text(
    p_patch, 'breed_note', 80, false, r.breed_note, v_bad) t;
  select t.p_value, t.p_bad into r.color, v_bad from private.patch_text(
    p_patch, 'color', 60, false, r.color, v_bad) t;
  select t.p_value, t.p_bad into r.health_notes, v_bad from private.patch_text(
    p_patch, 'health_notes', 2000, true, r.health_notes, v_bad) t;
  select t.p_value, t.p_bad into r.auction_venue, v_bad from private.patch_text(
    p_patch, 'auction_venue', 300, false, r.auction_venue, v_bad) t;

  select t.p_value, t.p_bad into r.breed_id, v_bad from private.patch_int(p_patch, 'breed_id', r.breed_id, v_bad) t;
  select t.p_value, t.p_bad into r.age_months, v_bad from private.patch_int(p_patch, 'age_months', r.age_months, v_bad) t;
  select t.p_value, t.p_bad into r.region_id, v_bad from private.patch_int(p_patch, 'region_id', r.region_id, v_bad) t;
  select t.p_value, t.p_bad into r.city_id, v_bad from private.patch_int(p_patch, 'city_id', r.city_id, v_bad) t;
  select t.p_value, t.p_bad into r.auction_region_id, v_bad
    from private.patch_int(p_patch, 'auction_region_id', r.auction_region_id, v_bad) t;
  select t.p_value, t.p_bad into r.auction_city_id, v_bad
    from private.patch_int(p_patch, 'auction_city_id', r.auction_city_id, v_bad) t;

  -- مفتاحا العلامتين قديمان: يتحققان نوعًا ثم يحولان إلى الرقمين أدناه.
  select t.p_value, t.p_bad into v_legacy_call, v_bad
    from private.patch_bool(p_patch, 'contact_call_enabled', null::boolean, v_bad) t;
  select t.p_value, t.p_bad into v_legacy_wa, v_bad
    from private.patch_bool(p_patch, 'contact_whatsapp_enabled', null::boolean, v_bad) t;

  if r.age_months is not null and r.age_months not between 1 and 600 then
    v_bad := v_bad || 'age_months'::text;
  end if;

  -- الإقرار: الخادم يحفظ وقته.
  if p_patch ? 'owner_declaration' then
    v_bool := null;
    select t.p_value, t.p_bad into v_bool, v_bad
      from private.patch_bool(p_patch, 'owner_declaration', v_bool, v_bad) t;
    if v_bool then
      r.owner_declaration_at := coalesce(r.owner_declaration_at, now());
    elsif v_bool is false then
      r.owner_declaration_at := null;
    end if;
  end if;

  if p_patch ? 'sex' then
    v_text := p_patch ->> 'sex';
    if pg_catalog.jsonb_typeof(p_patch -> 'sex') = 'null' then
      r.sex := null;
    elsif v_text in ('MALE', 'FEMALE') then
      r.sex := v_text::public.animal_sex;
    else
      v_bad := v_bad || 'sex'::text;
    end if;
  end if;

  if p_patch ? 'offer_type' then
    v_text := p_patch ->> 'offer_type';
    if pg_catalog.jsonb_typeof(p_patch -> 'offer_type') = 'null' then
      r.offer_type := null;
    elsif v_text in ('FIXED_PRICE', 'IN_PERSON_AUCTION') then
      r.offer_type := v_text::public.offer_type;
    else
      v_bad := v_bad || 'offer_type'::text;
    end if;
  end if;

  -- السعر: موجب، منزلتان كحد أقصى.
  if p_patch ? 'price' then
    if pg_catalog.jsonb_typeof(p_patch -> 'price') = 'null' then
      r.price := null;
    elsif pg_catalog.jsonb_typeof(p_patch -> 'price') = 'number'
      and (p_patch ->> 'price') ~ '^[0-9]{1,10}(\.[0-9]{1,2})?$'
      and (p_patch ->> 'price')::numeric > 0
    then
      r.price := (p_patch ->> 'price')::numeric;
    else
      v_bad := v_bad || 'price'::text;
    end if;
  end if;

  -- موعد المزاد: نص ISO 8601 بمنطقة زمنية؛ يحفظ UTC.
  if p_patch ? 'auction_starts_at' then
    if pg_catalog.jsonb_typeof(p_patch -> 'auction_starts_at') = 'null' then
      r.auction_starts_at := null;
    elsif pg_catalog.jsonb_typeof(p_patch -> 'auction_starts_at') = 'string'
      and (p_patch ->> 'auction_starts_at')
        ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]{1,6})?)?(Z|[+-][0-9]{2}:[0-9]{2})$'
    then
      begin
        r.auction_starts_at := (p_patch ->> 'auction_starts_at')::timestamptz;
      exception when others then
        v_bad := v_bad || 'auction_starts_at'::text;
      end;
    else
      v_bad := v_bad || 'auction_starts_at'::text;
    end if;
  end if;

  -- إحداثيات موقع المزاد: رقمان ضمن النطاق الجغرافي، يحفظان معًا أو يمسحان معًا.
  if p_patch ? 'auction_lat' then
    if pg_catalog.jsonb_typeof(p_patch -> 'auction_lat') = 'null' then
      r.auction_lat := null;
    elsif pg_catalog.jsonb_typeof(p_patch -> 'auction_lat') = 'number'
      and (p_patch ->> 'auction_lat')::numeric between -90 and 90
    then
      r.auction_lat := round((p_patch ->> 'auction_lat')::numeric, 6);
    else
      v_bad := v_bad || 'auction_lat'::text;
    end if;
  end if;
  if p_patch ? 'auction_lng' then
    if pg_catalog.jsonb_typeof(p_patch -> 'auction_lng') = 'null' then
      r.auction_lng := null;
    elsif pg_catalog.jsonb_typeof(p_patch -> 'auction_lng') = 'number'
      and (p_patch ->> 'auction_lng')::numeric between -180 and 180
    then
      r.auction_lng := round((p_patch ->> 'auction_lng')::numeric, 6);
    else
      v_bad := v_bad || 'auction_lng'::text;
    end if;
  end if;
  if (r.auction_lat is null) <> (r.auction_lng is null) then
    v_bad := v_bad || 'auction_lat'::text;
    v_bad := v_bad || 'auction_lng'::text;
  end if;

  -- رقما التواصل: جوال سعودي. يقبل 05XXXXXXXX ويحفظ بالصيغة الدولية. الاتصال وواتساب مستقلان.
  if p_patch ? 'contact_phone' then
    if pg_catalog.jsonb_typeof(p_patch -> 'contact_phone') = 'null' then
      r.contact_phone := null;
    elsif pg_catalog.jsonb_typeof(p_patch -> 'contact_phone') = 'string' then
      v_text := pg_catalog.regexp_replace(p_patch ->> 'contact_phone', '[\s-]', '', 'g');
      if v_text ~ '^05[0-9]{8}$' then
        v_text := '+966' || pg_catalog.substr(v_text, 2);
      end if;
      if v_text ~ '^\+9665[0-9]{8}$' then
        r.contact_phone := v_text;
      else
        v_bad := v_bad || 'contact_phone'::text;
      end if;
    else
      v_bad := v_bad || 'contact_phone'::text;
    end if;
  end if;
  if p_patch ? 'contact_whatsapp_phone' then
    if pg_catalog.jsonb_typeof(p_patch -> 'contact_whatsapp_phone') = 'null' then
      r.contact_whatsapp_phone := null;
    elsif pg_catalog.jsonb_typeof(p_patch -> 'contact_whatsapp_phone') = 'string' then
      v_text := pg_catalog.regexp_replace(p_patch ->> 'contact_whatsapp_phone', '[\s-]', '', 'g');
      if v_text ~ '^05[0-9]{8}$' then
        v_text := '+966' || pg_catalog.substr(v_text, 2);
      end if;
      if v_text ~ '^\+9665[0-9]{8}$' then
        r.contact_whatsapp_phone := v_text;
      else
        v_bad := v_bad || 'contact_whatsapp_phone'::text;
      end if;
    else
      v_bad := v_bad || 'contact_whatsapp_phone'::text;
    end if;
  elsif v_legacy_wa is not null or v_legacy_call is not null then
    -- توافق مع التطبيق القديم (رقم واحد بعلامتي قناة): تحويل إلى رقمين.
    if v_legacy_wa is true and r.contact_whatsapp_phone is null then
      r.contact_whatsapp_phone := r.contact_phone;
    elsif v_legacy_wa is false then
      r.contact_whatsapp_phone := null;
    end if;
    if v_legacy_call is false then
      r.contact_phone := null;
    end if;
  end if;
  -- وقت الموافقة على نشر الرقم يحفظه الخادم عند حفظ رقم جديد (TEAM-DEC-009).
  if r.contact_phone is null and r.contact_whatsapp_phone is null then
    r.contact_consent_at := null;
  elsif r.contact_phone is distinct from v_old.contact_phone
    or r.contact_whatsapp_phone is distinct from v_old.contact_whatsapp_phone
  then
    r.contact_consent_at := now();
  end if;

  -- السلالة: فعالة، أو هي القيمة المحفوظة سابقًا.
  if r.breed_id is not null and r.breed_id is distinct from v_old.breed_id
    and not exists (select 1 from public.breeds b where b.id = r.breed_id and b.is_active)
  then
    v_bad := v_bad || 'breed_id'::text;
  end if;
  if r.breed_id is null or not exists (
    select 1 from public.breeds b where b.id = r.breed_id and b.requires_note)
  then
    r.breed_note := null;
  end if;

  -- الموقع العام: تغيير المنطقة يمسح المدينة ما لم ترسل مدينة جديدة (AD-AC-012).
  if r.region_id is distinct from v_old.region_id and not (p_patch ? 'city_id') then
    r.city_id := null;
  end if;
  if r.region_id is null then
    if r.city_id is not null and p_patch ? 'city_id' then
      v_bad := v_bad || 'city_id'::text;
    end if;
    r.city_id := null;
  else
    if r.region_id is distinct from v_old.region_id
      and not exists (select 1 from public.regions g where g.id = r.region_id and g.is_active)
    then
      v_bad := v_bad || 'region_id'::text;
    end if;
    if r.city_id is not null and not exists (
      select 1 from public.cities c
      where c.id = r.city_id and c.region_id = r.region_id
        and (c.is_active or c.id = v_old.city_id))
    then
      v_bad := v_bad || 'city_id'::text;
    end if;
  end if;

  -- نوع العرض: حقول النوع غير المنطبق تمسح (SRS القسم 5).
  if r.offer_type is distinct from 'FIXED_PRICE' then
    if p_patch ? 'price' and r.price is not null then
      v_bad := v_bad || 'price'::text;
    end if;
    r.price := null;
  end if;
  if r.offer_type is distinct from 'IN_PERSON_AUCTION' then
    if (p_patch ? 'auction_region_id' and r.auction_region_id is not null)
      or (p_patch ? 'auction_city_id' and r.auction_city_id is not null)
      or (p_patch ? 'auction_venue' and r.auction_venue is not null)
      or (p_patch ? 'auction_starts_at' and r.auction_starts_at is not null)
      or (p_patch ? 'auction_lat' and r.auction_lat is not null)
      or (p_patch ? 'auction_lng' and r.auction_lng is not null)
    then
      v_bad := v_bad || 'offer_type'::text;
    end if;
    r.auction_region_id := null;
    r.auction_city_id := null;
    r.auction_venue := null;
    r.auction_starts_at := null;
    r.auction_lat := null;
    r.auction_lng := null;
  else
    if r.auction_region_id is distinct from v_old.auction_region_id and not (p_patch ? 'auction_city_id') then
      r.auction_city_id := null;
    end if;
    if r.auction_region_id is null then
      if r.auction_city_id is not null and p_patch ? 'auction_city_id' then
        v_bad := v_bad || 'auction_city_id'::text;
      end if;
      r.auction_city_id := null;
    else
      if r.auction_region_id is distinct from v_old.auction_region_id
        and not exists (select 1 from public.regions g where g.id = r.auction_region_id and g.is_active)
      then
        v_bad := v_bad || 'auction_region_id'::text;
      end if;
      if r.auction_city_id is not null and not exists (
        select 1 from public.cities c
        where c.id = r.auction_city_id and c.region_id = r.auction_region_id
          and (c.is_active or c.id = v_old.auction_city_id))
      then
        v_bad := v_bad || 'auction_city_id'::text;
      end if;
    end if;
  end if;

  if pg_catalog.cardinality(v_bad) > 0 then
    perform private.raise_error(
      'VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', (
        select pg_catalog.jsonb_agg(distinct f) from pg_catalog.unnest(v_bad) as f)));
  end if;

  update public.listing_versions v set
    title = r.title, description = r.description,
    breed_id = r.breed_id, breed_note = r.breed_note,
    sex = r.sex, age_months = r.age_months, color = r.color,
    region_id = r.region_id, city_id = r.city_id,
    health_notes = r.health_notes, owner_declaration_at = r.owner_declaration_at,
    offer_type = r.offer_type, price = r.price,
    auction_region_id = r.auction_region_id, auction_city_id = r.auction_city_id,
    auction_venue = r.auction_venue, auction_starts_at = r.auction_starts_at,
    auction_lat = r.auction_lat, auction_lng = r.auction_lng,
    contact_phone = r.contact_phone,
    contact_whatsapp_phone = r.contact_whatsapp_phone,
    contact_consent_at = r.contact_consent_at
  where v.id = v_old.id;

  return private.listing_owner_json(p_listing_id);
end;
$$;

create or replace function public.start_listing_edit(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_listing public.listings;
  v_source public.listing_versions;
  v_new_id uuid := gen_random_uuid();
begin
  v_listing := private.lock_own_listing(p_listing_id, v_uid);

  if v_listing.status not in ('PUBLISHED', 'REJECTED', 'ARCHIVED') then
    perform private.raise_error(
      'INVALID_STATE', pg_catalog.jsonb_build_object('status', v_listing.status));
  end if;

  if not exists (
    select 1 from public.listing_versions v
    where v.listing_id = p_listing_id and v.status = 'DRAFT')
  then
    select * into v_source from public.listing_versions v where v.id = v_listing.current_version_id;

    insert into public.listing_versions (
      id, listing_id, version_no,
      title, description, breed_id, breed_note, sex, age_months, color,
      region_id, city_id, health_notes, owner_declaration_at,
      offer_type, price,
      auction_region_id, auction_city_id, auction_venue, auction_starts_at,
      auction_lat, auction_lng,
      contact_phone, contact_whatsapp_phone, contact_consent_at)
    values (
      v_new_id, p_listing_id,
      (select max(v.version_no) + 1 from public.listing_versions v where v.listing_id = p_listing_id),
      v_source.title, v_source.description, v_source.breed_id, v_source.breed_note,
      v_source.sex, v_source.age_months, v_source.color,
      v_source.region_id, v_source.city_id, v_source.health_notes, v_source.owner_declaration_at,
      v_source.offer_type, v_source.price,
      v_source.auction_region_id, v_source.auction_city_id, v_source.auction_venue, v_source.auction_starts_at,
      v_source.auction_lat, v_source.auction_lng,
      v_source.contact_phone, v_source.contact_whatsapp_phone,
      v_source.contact_consent_at);

    -- الوسائط الجاهزة تنسخ صفوفها بالمسار نفسه دون إعادة رفع.
    insert into public.media (
      listing_id, version_id, owner_id, kind, status, bucket, object_path,
      mime_type, size_bytes, width, height, duration_seconds, sort_order, is_cover)
    select
      m.listing_id, v_new_id, m.owner_id, m.kind, m.status, m.bucket, m.object_path,
      m.mime_type, m.size_bytes, m.width, m.height, m.duration_seconds, m.sort_order, m.is_cover
    from public.media m
    where m.version_id = v_source.id and m.status = 'READY';

    update public.listings l set current_version_id = v_new_id where l.id = p_listing_id;
  else
    update public.listings l set current_version_id = (
        select v.id from public.listing_versions v
        where v.listing_id = p_listing_id and v.status = 'DRAFT')
      where l.id = p_listing_id;
  end if;

  -- المنشور يبقى منشورًا أثناء تحرير المسودة الخاصة (TEAM-DEC-011 البند 1)؛
  -- المرفوض والمؤرشف يعودان إلى مسودة بالمعرف نفسه (البند 2).
  if v_listing.status in ('REJECTED', 'ARCHIVED') then
    update public.listings l set status = 'DRAFT', status_changed_at = now()
      where l.id = p_listing_id;
  end if;

  return private.listing_owner_json(p_listing_id);
end;
$$;

------------------------------------------------------------------------------
-- search_listings: الحقول الجديدة في بطاقة النتيجة
------------------------------------------------------------------------------

create or replace function public.search_listings(
  p_query text default null,
  p_region_id integer default null,
  p_city_id integer default null,
  p_breed_id integer default null,
  p_sex text default null,
  p_offer_type text default null,
  p_age_min integer default null,
  p_age_max integer default null,
  p_price_min numeric default null,
  p_price_max numeric default null,
  p_owner_id uuid default null,
  p_sort text default 'NEWEST_VISIBLE',
  p_limit integer default 20,
  p_cursor jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bad text[] := array[]::text[];
  v_query text := nullif(pg_catalog.btrim(coalesce(p_query, '')), '');
  v_pattern text;
  v_sort text := coalesce(p_sort, 'NEWEST_VISIBLE');
  v_limit integer := coalesce(p_limit, 20);
  v_sex public.animal_sex;
  v_offer public.offer_type;
  v_c_ts timestamptz;
  v_c_price numeric;
  v_c_id uuid;
  v_rows jsonb;
  v_count integer;
  v_last jsonb;
  v_next jsonb;
begin
  -- التحقق من المدخلات
  if v_query is not null and pg_catalog.char_length(v_query) > 100 then
    v_bad := v_bad || 'p_query'::text;
  end if;
  if p_sex is not null then
    if p_sex in ('MALE', 'FEMALE') then v_sex := p_sex::public.animal_sex;
    else v_bad := v_bad || 'p_sex'::text; end if;
  end if;
  if p_offer_type is not null then
    if p_offer_type in ('FIXED_PRICE', 'IN_PERSON_AUCTION') then
      v_offer := p_offer_type::public.offer_type;
    else v_bad := v_bad || 'p_offer_type'::text; end if;
  end if;
  if v_sort not in ('NEWEST_VISIBLE', 'NEWEST_PUBLISHED', 'PRICE_ASC', 'PRICE_DESC') then
    v_bad := v_bad || 'p_sort'::text;
  end if;
  if v_limit < 1 or v_limit > 50 then
    v_bad := v_bad || 'p_limit'::text;
  end if;
  if (p_age_min is not null and p_age_min < 0) or (p_age_max is not null and p_age_max < 0)
     or (p_age_min is not null and p_age_max is not null and p_age_min > p_age_max) then
    v_bad := v_bad || 'p_age_min'::text || 'p_age_max'::text;
  end if;
  if (p_price_min is not null and p_price_min < 0) or (p_price_max is not null and p_price_max < 0)
     or (p_price_min is not null and p_price_max is not null and p_price_min > p_price_max) then
    v_bad := v_bad || 'p_price_min'::text || 'p_price_max'::text;
  end if;
  if p_city_id is not null and p_region_id is not null
     and not exists (select 1 from public.cities c where c.id = p_city_id and c.region_id = p_region_id) then
    v_bad := v_bad || 'p_city_id'::text;
  end if;

  -- المؤشر: صيغته تتبع الفرز. أي شكل غير متوقع يرفض.
  if p_cursor is not null then
    begin
      v_c_id := (p_cursor ->> 'id')::uuid;
      if v_sort in ('NEWEST_VISIBLE', 'NEWEST_PUBLISHED') then
        v_c_ts := (p_cursor ->> 'ts')::timestamptz;
        if v_c_ts is null then v_bad := v_bad || 'p_cursor'::text; end if;
      else
        v_c_price := (p_cursor ->> 'price')::numeric;
      end if;
      if v_c_id is null then v_bad := v_bad || 'p_cursor'::text; end if;
    exception when others then
      v_bad := v_bad || 'p_cursor'::text;
    end;
  end if;

  if cardinality(v_bad) > 0 then
    perform private.raise_error(
      'VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.to_jsonb(
        (select pg_catalog.array_agg(distinct f) from pg_catalog.unnest(v_bad) f))));
  end if;

  -- نص البحث حرفي: تهرب علامات LIKE.
  if v_query is not null then
    v_pattern := '%' || pg_catalog.replace(pg_catalog.replace(pg_catalog.replace(
      v_query, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  end if;

  with page as (
    select
      l.id as listing_id,
      l.owner_id,
      p.display_name as owner_display_name,
      v.title,
      v.offer_type,
      v.price,
      v.auction_starts_at,
      false as auction_passed,
      v.breed_id,
      b.name_ar as breed_name_ar,
      v.breed_note,
      v.sex,
      v.age_months,
      v.region_id,
      rg.name_ar as region_name_ar,
      v.city_id,
      c.name_ar as city_name_ar,
      cover.bucket as cover_bucket,
      cover.object_path as cover_path,
      l.first_published_at,
      l.visibility_updated_at,
      l.public_ref,
      v.auction_lat,
      v.auction_lng,
      coalesce(st.view_count, 0) as view_count,
      coalesce(st.favorite_count, 0) as favorite_count,
      case v_sort when 'NEWEST_PUBLISHED' then l.first_published_at else l.visibility_updated_at end as sort_ts
    from public.listings l
    join public.listing_versions v on v.id = l.published_version_id
    join public.profiles p on p.id = l.owner_id
    join public.breeds b on b.id = v.breed_id
    join public.regions rg on rg.id = v.region_id
    join public.cities c on c.id = v.city_id
    left join public.media cover on cover.version_id = v.id and cover.is_cover and cover.status = 'READY'
    left join public.listing_stats st on st.listing_id = l.id
    where l.status = 'PUBLISHED' and l.deleted_at is null
      and not (v.offer_type = 'IN_PERSON_AUCTION' and v.auction_starts_at <= now())
      and (v_pattern is null or v.title ilike v_pattern)
      and (p_region_id is null or v.region_id = p_region_id)
      and (p_city_id is null or v.city_id = p_city_id)
      and (p_breed_id is null or v.breed_id = p_breed_id)
      and (v_sex is null or v.sex = v_sex)
      and (v_offer is null or v.offer_type = v_offer)
      and (p_age_min is null or v.age_months >= p_age_min)
      and (p_age_max is null or v.age_months <= p_age_max)
      -- نطاق السعر يستبعد المزاد: لا سعر له فتفشل المقارنة بالـnull.
      and (p_price_min is null or v.price >= p_price_min)
      and (p_price_max is null or v.price <= p_price_max)
      and (p_owner_id is null or l.owner_id = p_owner_id)
      and (
        p_cursor is null
        or case v_sort
          when 'NEWEST_VISIBLE' then
            (l.visibility_updated_at, l.id) < (v_c_ts, v_c_id)
          when 'NEWEST_PUBLISHED' then
            (l.first_published_at, l.id) < (v_c_ts, v_c_id)
          when 'PRICE_ASC' then
            (v.price is null) > (v_c_price is null)
            or ((v.price is null) = (v_c_price is null)
                and (coalesce(v.price, 0) > coalesce(v_c_price, 0)
                     or (coalesce(v.price, 0) = coalesce(v_c_price, 0) and l.id > v_c_id)))
          else -- PRICE_DESC
            (v.price is null) > (v_c_price is null)
            or ((v.price is null) = (v_c_price is null)
                and (coalesce(v.price, 0) < coalesce(v_c_price, 0)
                     or (coalesce(v.price, 0) = coalesce(v_c_price, 0) and l.id > v_c_id)))
        end
      )
    order by
      case when v_sort in ('NEWEST_VISIBLE', 'NEWEST_PUBLISHED') then
        case v_sort when 'NEWEST_PUBLISHED' then l.first_published_at else l.visibility_updated_at end
      end desc,
      case when v_sort in ('NEWEST_VISIBLE', 'NEWEST_PUBLISHED') then l.id end desc,
      (v.price is null),
      case when v_sort = 'PRICE_ASC' then v.price end asc,
      case when v_sort = 'PRICE_DESC' then v.price end desc,
      l.id asc
    limit v_limit + 1
  )
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(page) - 'sort_ts'), '[]'::jsonb),
         pg_catalog.count(*)::integer
    into v_rows, v_count
  from page;

  if v_count > v_limit then
    -- الصف الإضافي دليل على وجود صفحة تالية؛ المؤشر من آخر صف مرجع.
    v_last := v_rows -> (v_limit - 1);
    v_rows := (select pg_catalog.jsonb_agg(e) from pg_catalog.jsonb_array_elements(v_rows) with ordinality t(e, n) where n <= v_limit);
    if v_sort in ('NEWEST_VISIBLE', 'NEWEST_PUBLISHED') then
      v_next := pg_catalog.jsonb_build_object(
        'ts', case v_sort when 'NEWEST_PUBLISHED' then v_last -> 'first_published_at' else v_last -> 'visibility_updated_at' end,
        'id', v_last -> 'listing_id');
    else
      v_next := pg_catalog.jsonb_build_object('price', v_last -> 'price', 'id', v_last -> 'listing_id');
    end if;
  end if;

  return pg_catalog.jsonb_build_object('items', v_rows, 'next_cursor', v_next);
end;
$$;
