-- 09 listing_owner_rpcs — MOBILE-BE-106
-- دوال المعلن: AD-FR-005 إلى AD-FR-010، AD-FR-014، AD-FR-025، AD-FR-030،
-- AD-NFR-005، AD-NFR-008، TEAM-DEC-011.
-- انتقالات الحالة من جهة المعلن:
--   إنشاء              -> DRAFT
--   إرسال              DRAFT أو PUBLISHED (بمسودة تعديل) -> UNDER_REVIEW
--   بدء تعديل          PUBLISHED يبقى منشورًا؛ REJECTED وARCHIVED -> DRAFT
--   أرشفة              PUBLISHED -> ARCHIVED
--   حذف                DRAFT أو REJECTED
-- الاعتماد والرفض والإخفاء في ترحيل دوال الإدارة.

------------------------------------------------------------------------------
-- مساعدات داخلية
------------------------------------------------------------------------------

-- صاحب الجلسة بحساب فعال. الحساب المعلق لا يملك وظائف النشر والتعديل.
create function private.require_active_user()
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
begin
  if (select p.status from public.profiles p where p.id = v_uid) <> 'ACTIVE' then
    perform private.raise_error('ACCOUNT_SUSPENDED');
  end if;
  return v_uid;
end;
$$;

-- يقفل إعلان المالك ويعيده. إعلان غيره أو محذوف يعامل كغير موجود.
create function private.lock_own_listing(p_listing uuid, p_user uuid)
returns public.listings
language plpgsql
set search_path = ''
as $$
declare
  v_listing public.listings;
begin
  select * into v_listing from public.listings l
    where l.id = p_listing and l.owner_id = p_user and l.deleted_at is null
    for update;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'listing'));
  end if;
  return v_listing;
end;
$$;

-- مسودة الإعلان القابلة للتعديل؛ خطأ إن لم توجد.
create function private.require_draft_version(p_listing uuid)
returns public.listing_versions
language plpgsql
set search_path = ''
as $$
declare
  v_version public.listing_versions;
begin
  select * into v_version from public.listing_versions v
    where v.listing_id = p_listing and v.status = 'DRAFT';
  if not found then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('reason', 'no_draft'));
  end if;
  return v_version;
end;
$$;

-- موعد استحقاق تجديد الظهور التالي (SRS القسم 6).
create function private.next_bump_at(p_listing public.listings)
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select case
    when p_listing.status = 'PUBLISHED' then
      greatest(p_listing.last_published_at, coalesce(p_listing.last_bumped_at, p_listing.last_published_at))
      + pg_catalog.make_interval(hours => (private.published_settings() #>> '{bump,interval_hours}')::integer)
  end
$$;

-- رد دوال المعلن: رأس الإعلان، والنسخة الحالية، ووسائطها.
create function private.listing_owner_json(p_listing uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'listing', pg_catalog.jsonb_build_object(
      'id', l.id,
      'status', l.status,
      'current_version_id', l.current_version_id,
      'published_version_id', l.published_version_id,
      'has_draft', exists (
        select 1 from public.listing_versions d
        where d.listing_id = l.id and d.status = 'DRAFT'),
      'first_submitted_at', l.first_submitted_at,
      'first_published_at', l.first_published_at,
      'last_published_at', l.last_published_at,
      'last_bumped_at', l.last_bumped_at,
      'next_bump_at', private.next_bump_at(l),
      'status_changed_at', l.status_changed_at,
      'created_at', l.created_at
    ),
    'version', (
      select pg_catalog.to_jsonb(v) - 'submit_request_id'
      from public.listing_versions v where v.id = l.current_version_id),
    'media', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', m.id, 'kind', m.kind, 'status', m.status, 'bucket', m.bucket,
          'object_path', m.object_path, 'mime_type', m.mime_type, 'size_bytes', m.size_bytes,
          'width', m.width, 'height', m.height, 'duration_seconds', m.duration_seconds,
          'sort_order', m.sort_order, 'is_cover', m.is_cover, 'failure_reason', m.failure_reason)
        order by m.sort_order, m.created_at, m.id)
      from public.media m where m.version_id = l.current_version_id
    ), '[]'::jsonb)
  )
  from public.listings l
  where l.id = p_listing
$$;

-- قراءة حقول الرقعة. المفتاح الغائب يبقي القيمة الحالية، وnull يمسحها.
-- القيمة المخالفة تضيف اسم الحقل إلى p_bad وتبقي القيمة الحالية.

create function private.patch_text(
  p_patch jsonb, p_key text, p_max integer, p_multiline boolean,
  inout p_value text, inout p_bad text[]
)
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text;
begin
  if not (p_patch ? p_key) then
    return;
  end if;
  if pg_catalog.jsonb_typeof(p_patch -> p_key) = 'null' then
    p_value := null;
    return;
  end if;
  if pg_catalog.jsonb_typeof(p_patch -> p_key) <> 'string' then
    p_bad := p_bad || p_key;
    return;
  end if;

  v_text := p_patch ->> p_key;
  if p_multiline then
    v_text := btrim(pg_catalog.replace(v_text, E'\r\n', E'\n'));
    if v_text ~ '[\x01-\x08\x0b\x0c\x0e-\x1f]' then
      p_bad := p_bad || p_key;
      return;
    end if;
  else
    v_text := btrim(pg_catalog.regexp_replace(v_text, '\s+', ' ', 'g'));
    if v_text ~ '[[:cntrl:]]' then
      p_bad := p_bad || p_key;
      return;
    end if;
  end if;

  if char_length(v_text) > p_max then
    p_bad := p_bad || p_key;
    return;
  end if;
  p_value := nullif(v_text, '');
end;
$$;

create function private.patch_int(
  p_patch jsonb, p_key text,
  inout p_value integer, inout p_bad text[]
)
language plpgsql
immutable
set search_path = ''
as $$
begin
  if not (p_patch ? p_key) then
    return;
  end if;
  if pg_catalog.jsonb_typeof(p_patch -> p_key) = 'null' then
    p_value := null;
  elsif pg_catalog.jsonb_typeof(p_patch -> p_key) = 'number'
    and (p_patch ->> p_key) ~ '^[0-9]{1,9}$'
  then
    p_value := (p_patch ->> p_key)::integer;
  else
    p_bad := p_bad || p_key;
  end if;
end;
$$;

create function private.patch_bool(
  p_patch jsonb, p_key text,
  inout p_value boolean, inout p_bad text[]
)
language plpgsql
immutable
set search_path = ''
as $$
begin
  if not (p_patch ? p_key) then
    return;
  end if;
  if pg_catalog.jsonb_typeof(p_patch -> p_key) = 'boolean' then
    p_value := (p_patch ->> p_key)::boolean;
  else
    p_bad := p_bad || p_key;
  end if;
end;
$$;

-- بصمة محتوى النسخة ووسائطها. قرار الإدارة يصدر على هذه البصمة.
create function private.listing_content_hash(p_version public.listing_versions)
returns text
language sql
stable
set search_path = ''
as $$
  select pg_catalog.encode(pg_catalog.sha256(pg_catalog.convert_to(
    pg_catalog.jsonb_build_object(
      'title', p_version.title, 'description', p_version.description,
      'breed_id', p_version.breed_id, 'breed_note', p_version.breed_note,
      'sex', p_version.sex, 'age_months', p_version.age_months, 'color', p_version.color,
      'region_id', p_version.region_id, 'city_id', p_version.city_id,
      'health_notes', p_version.health_notes,
      'offer_type', p_version.offer_type, 'price', p_version.price,
      'auction_region_id', p_version.auction_region_id,
      'auction_city_id', p_version.auction_city_id,
      'auction_venue', p_version.auction_venue,
      'auction_starts_at', p_version.auction_starts_at,
      'contact_phone', p_version.contact_phone,
      'contact_call_enabled', p_version.contact_call_enabled,
      'contact_whatsapp_enabled', p_version.contact_whatsapp_enabled,
      'media', coalesce((
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'bucket', m.bucket, 'path', m.object_path, 'kind', m.kind,
            'cover', m.is_cover, 'order', m.sort_order)
          order by m.sort_order, m.object_path)
        from public.media m where m.version_id = p_version.id), '[]'::jsonb)
    )::text, 'UTF8')), 'hex')
$$;

-- الحقول الناقصة أو المخالفة في نسخة تطلب الإرسال، وفق الإعدادات المنشورة.
create function private.listing_submit_errors(p_version public.listing_versions, p_settings jsonb)
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
    -- موعد مستقبلي عند الإرسال (AD-FR-025).
    if p_version.auction_starts_at is null or p_version.auction_starts_at <= now() then
      v_bad := v_bad || 'auction_starts_at'::text;
    end if;
  end if;

  if p_version.contact_phone is null then
    v_bad := v_bad || 'contact_phone'::text;
  end if;
  if not (p_version.contact_call_enabled or p_version.contact_whatsapp_enabled) then
    v_bad := v_bad || 'contact_channels'::text;
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

------------------------------------------------------------------------------
-- المسودة
------------------------------------------------------------------------------

create function public.create_listing_draft(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_listing_id uuid;
  v_version_id uuid;
  v_limit integer := (private.published_settings() #>> '{listing,open_drafts_max}')::integer;
begin
  if p_request_id is null then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('request_id')));
  end if;

  -- يسلسل إنشاء مسودات الحساب، فلا يتجاوز طلبان متزامنان الحد ولا يتكرر الطلب.
  perform 1 from public.profiles p where p.id = v_uid for update;

  select l.id into v_listing_id from public.listings l
    where l.owner_id = v_uid and l.create_request_id = p_request_id;
  if found then
    return private.listing_owner_json(v_listing_id);
  end if;

  if (select count(*) from public.listings l
      where l.owner_id = v_uid and l.status = 'DRAFT' and l.deleted_at is null) >= v_limit
  then
    perform private.raise_error('DRAFT_LIMIT_REACHED', pg_catalog.jsonb_build_object('limit', v_limit));
  end if;

  insert into public.listings (owner_id, create_request_id)
    values (v_uid, p_request_id) returning id into v_listing_id;
  insert into public.listing_versions (listing_id, version_no)
    values (v_listing_id, 1) returning id into v_version_id;
  update public.listings l set current_version_id = v_version_id where l.id = v_listing_id;

  return private.listing_owner_json(v_listing_id);
end;
$$;

comment on function public.create_listing_draft(uuid) is
  'إنشاء مسودة إعلان. إعادة الطلب بالمعرف نفسه تعيد المسودة نفسها.';

create function public.save_listing_draft(p_listing_id uuid, p_patch jsonb)
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
  v_allowed constant text[] := array[
    'title', 'description', 'breed_id', 'breed_note', 'sex', 'age_months', 'color',
    'region_id', 'city_id', 'health_notes', 'owner_declaration',
    'offer_type', 'price',
    'auction_region_id', 'auction_city_id', 'auction_venue', 'auction_starts_at',
    'contact_phone', 'contact_call_enabled', 'contact_whatsapp_enabled'];
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

  select t.p_value, t.p_bad into r.contact_call_enabled, v_bad
    from private.patch_bool(p_patch, 'contact_call_enabled', r.contact_call_enabled, v_bad) t;
  select t.p_value, t.p_bad into r.contact_whatsapp_enabled, v_bad
    from private.patch_bool(p_patch, 'contact_whatsapp_enabled', r.contact_whatsapp_enabled, v_bad) t;

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

  -- رقم التواصل: جوال سعودي. يقبل 05XXXXXXXX ويحفظ بالصيغة الدولية.
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
  -- وقت الموافقة على نشر الرقم يحفظه الخادم عند حفظ رقم جديد (TEAM-DEC-009).
  if r.contact_phone is null then
    r.contact_consent_at := null;
  elsif r.contact_phone is distinct from v_old.contact_phone then
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
    then
      v_bad := v_bad || 'offer_type'::text;
    end if;
    r.auction_region_id := null;
    r.auction_city_id := null;
    r.auction_venue := null;
    r.auction_starts_at := null;
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
    contact_phone = r.contact_phone,
    contact_call_enabled = r.contact_call_enabled,
    contact_whatsapp_enabled = r.contact_whatsapp_enabled,
    contact_consent_at = r.contact_consent_at
  where v.id = v_old.id;

  return private.listing_owner_json(p_listing_id);
end;
$$;

comment on function public.save_listing_draft(uuid, jsonb) is
  'حفظ جزئي لحقول المسودة. المفتاح الغائب لا يتغير، وnull يمسح القيمة.';

------------------------------------------------------------------------------
-- الوسائط
------------------------------------------------------------------------------

-- يسجل ملفًا بانتظار الرفع ويعيد مساره. الرفع نفسه عبر واجهة التخزين.
create function public.add_listing_media(
  p_listing_id uuid,
  p_kind public.media_kind,
  p_mime_type text,
  p_size_bytes bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_listing public.listings;
  v_version public.listing_versions;
  v_settings jsonb := private.published_settings();
  v_bad text[] := array[]::text[];
  v_id uuid := gen_random_uuid();
  v_bucket text;
  v_ext text;
  v_count integer;
  v_max integer;
begin
  v_listing := private.lock_own_listing(p_listing_id, v_uid);
  v_version := private.require_draft_version(p_listing_id);

  if p_kind is null then
    v_bad := v_bad || 'kind'::text;
  elsif p_kind = 'IMAGE' then
    v_bucket := 'listing-images';
    v_ext := case p_mime_type when 'image/jpeg' then 'jpg' when 'image/png' then 'png' end;
    if v_ext is null or not ((v_settings #> '{media,image_mime_types}') ? p_mime_type) then
      v_bad := v_bad || 'mime_type'::text;
    end if;
    if p_size_bytes is null or p_size_bytes <= 0
      or p_size_bytes > (v_settings #>> '{media,image_max_bytes}')::bigint
    then
      v_bad := v_bad || 'size_bytes'::text;
    end if;
  else
    if not (v_settings #>> '{media,video_enabled}')::boolean then
      perform private.raise_error('VIDEO_DISABLED');
    end if;
    v_bucket := 'listing-videos';
    v_ext := case p_mime_type when 'video/mp4' then 'mp4' end;
    if v_ext is null then
      v_bad := v_bad || 'mime_type'::text;
    end if;
    if p_size_bytes is null or p_size_bytes <= 0
      or p_size_bytes > (v_settings #>> '{media,video_max_bytes}')::bigint
    then
      v_bad := v_bad || 'size_bytes'::text;
    end if;
  end if;

  if pg_catalog.cardinality(v_bad) > 0 then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.to_jsonb(v_bad)));
  end if;

  select count(*) into v_count from public.media m
    where m.version_id = v_version.id and m.kind = p_kind;
  v_max := case when p_kind = 'IMAGE' then (v_settings #>> '{media,images_max}')::integer else 1 end;
  if v_count >= v_max then
    perform private.raise_error(
      'MEDIA_LIMIT_REACHED', pg_catalog.jsonb_build_object('kind', p_kind, 'limit', v_max));
  end if;

  insert into public.media
    (id, listing_id, version_id, owner_id, kind, bucket, object_path, sort_order)
  values (
    v_id, p_listing_id, v_version.id, v_uid, p_kind, v_bucket,
    v_uid::text || '/' || p_listing_id::text || '/' || v_id::text || '.' || v_ext,
    coalesce((select max(m.sort_order) from public.media m where m.version_id = v_version.id), 0) + 1);

  return pg_catalog.jsonb_build_object(
    'media_id', v_id,
    'bucket', v_bucket,
    'object_path', v_uid::text || '/' || p_listing_id::text || '/' || v_id::text || '.' || v_ext);
end;
$$;

comment on function public.add_listing_media(uuid, public.media_kind, text, bigint) is
  'تسجيل ملف وسائط بانتظار الرفع في مسودة. يعيد bucket والمسار للرفع عبر واجهة التخزين.';

-- نتيجة فحص الملف المرفوع. يستدعيها الخادم (دالة Edge ‏media-finalize) لا العميل.
create function public.finalize_listing_media(
  p_media_id uuid,
  p_mime_type text,
  p_size_bytes bigint,
  p_width integer default null,
  p_height integer default null,
  p_duration_seconds numeric default null,
  p_failure_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_media public.media;
  v_settings jsonb := private.published_settings();
  v_reason text := nullif(btrim(coalesce(p_failure_reason, '')), '');
begin
  select * into v_media from public.media m where m.id = p_media_id for update;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'media'));
  end if;
  if v_media.status <> 'PENDING' then
    return pg_catalog.jsonb_build_object('media_id', v_media.id, 'status', v_media.status);
  end if;

  if v_reason is null then
    if p_size_bytes is null or p_size_bytes <= 0 then
      v_reason := 'EMPTY_FILE';
    elsif v_media.kind = 'IMAGE' then
      if p_mime_type is null or not ((v_settings #> '{media,image_mime_types}') ? p_mime_type) then
        v_reason := 'UNSUPPORTED_TYPE';
      elsif p_size_bytes > (v_settings #>> '{media,image_max_bytes}')::bigint then
        v_reason := 'FILE_TOO_LARGE';
      end if;
    else
      if p_mime_type is distinct from 'video/mp4' then
        v_reason := 'UNSUPPORTED_TYPE';
      elsif p_size_bytes > (v_settings #>> '{media,video_max_bytes}')::bigint then
        v_reason := 'FILE_TOO_LARGE';
      elsif p_duration_seconds is null
        or p_duration_seconds > (v_settings #>> '{media,video_max_seconds}')::numeric
      then
        v_reason := 'VIDEO_TOO_LONG';
      end if;
    end if;
  end if;

  if v_reason is null then
    update public.media m set
      status = 'READY', mime_type = p_mime_type, size_bytes = p_size_bytes,
      width = p_width, height = p_height, duration_seconds = p_duration_seconds,
      failure_reason = null
    where m.id = v_media.id;
  else
    update public.media m set
      status = 'FAILED', is_cover = false, failure_reason = pg_catalog.left(v_reason, 200)
    where m.id = v_media.id;
  end if;

  return pg_catalog.jsonb_build_object(
    'media_id', v_media.id,
    'status', case when v_reason is null then 'READY' else 'FAILED' end,
    'failure_reason', v_reason);
end;
$$;

comment on function public.finalize_listing_media(uuid, text, bigint, integer, integer, numeric, text) is
  'تثبيت نتيجة فحص ملف مرفوع. لدور الخادم فقط.';

create function public.remove_listing_media(p_media_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_media public.media;
  v_listing public.listings;
  v_version public.listing_versions;
begin
  select * into v_media from public.media m where m.id = p_media_id and m.owner_id = v_uid;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'media'));
  end if;

  v_listing := private.lock_own_listing(v_media.listing_id, v_uid);
  v_version := private.require_draft_version(v_media.listing_id);
  if v_media.version_id <> v_version.id then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('reason', 'not_in_draft'));
  end if;

  delete from public.media m where m.id = v_media.id;

  -- الملف يحذفه العميل من التخزين إن لم تعد نسخة أخرى تشير إليه.
  return pg_catalog.jsonb_build_object(
    'bucket', v_media.bucket,
    'object_path', v_media.object_path,
    'delete_object', not exists (
      select 1 from public.media m
      where m.bucket = v_media.bucket and m.object_path = v_media.object_path));
end;
$$;

comment on function public.remove_listing_media(uuid) is
  'حذف ملف وسائط من المسودة. delete_object يبين هل يحذف الملف من التخزين.';

-- ترتيب وسائط المسودة واختيار الغلاف. القائمة تضم كل وسائط المسودة.
create function public.arrange_listing_media(
  p_listing_id uuid,
  p_media_ids uuid[],
  p_cover_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_listing public.listings;
  v_version public.listing_versions;
begin
  v_listing := private.lock_own_listing(p_listing_id, v_uid);
  v_version := private.require_draft_version(p_listing_id);

  if p_media_ids is null
    or pg_catalog.array_position(p_media_ids, null) is not null
    or (select count(distinct x) from pg_catalog.unnest(p_media_ids) as x)
       <> pg_catalog.cardinality(p_media_ids)
    or (select pg_catalog.array_agg(m.id order by m.id) from public.media m where m.version_id = v_version.id)
       is distinct from
       (select pg_catalog.array_agg(x order by x) from pg_catalog.unnest(p_media_ids) as x)
  then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('media_ids')));
  end if;

  if p_cover_id is not null and not exists (
    select 1 from public.media m
    where m.id = p_cover_id and m.version_id = v_version.id
      and m.kind = 'IMAGE' and m.status <> 'FAILED')
  then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('cover_id')));
  end if;

  update public.media m set is_cover = false
    where m.version_id = v_version.id and m.is_cover and m.id is distinct from p_cover_id;
  update public.media m set
      sort_order = o.ord::integer,
      is_cover = (m.id = p_cover_id)
    from pg_catalog.unnest(p_media_ids) with ordinality as o (id, ord)
    where m.id = o.id and m.version_id = v_version.id;

  return private.listing_owner_json(p_listing_id);
end;
$$;

comment on function public.arrange_listing_media(uuid, uuid[], uuid) is
  'ترتيب وسائط المسودة واختيار صورة الغلاف.';

------------------------------------------------------------------------------
-- الإرسال والتعديل
------------------------------------------------------------------------------

create function public.submit_listing(p_listing_id uuid, p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_listing public.listings;
  v_version public.listing_versions;
  v_settings jsonb := private.published_settings();
  v_bad text[];
  v_limit integer := (v_settings #>> '{listing,daily_new_limit}')::integer;
  v_recent integer;
  v_oldest timestamptz;
begin
  if p_request_id is null then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('request_id')));
  end if;

  -- يسلسل إرسال إعلانات الحساب لحساب حد اليوم بدقة.
  perform 1 from public.profiles p where p.id = v_uid for update;
  v_listing := private.lock_own_listing(p_listing_id, v_uid);

  -- طلب مكرر: لا ينشئ شيئًا ويعيد الحالة الحالية (AD-NFR-005).
  if exists (
    select 1 from public.listing_versions v
    where v.listing_id = p_listing_id and v.submit_request_id = p_request_id)
  then
    return private.listing_owner_json(p_listing_id);
  end if;

  -- حساب فعال، ملف مكتمل، موافقة على النصوص السارية (AD-FR-003).
  perform private.assert_can_publish(v_uid);

  if v_listing.status not in ('DRAFT', 'PUBLISHED') then
    perform private.raise_error(
      'INVALID_STATE', pg_catalog.jsonb_build_object('status', v_listing.status));
  end if;
  v_version := private.require_draft_version(p_listing_id);

  if exists (
    select 1 from public.media m where m.version_id = v_version.id and m.status <> 'READY')
  then
    perform private.raise_error('MEDIA_NOT_READY', pg_catalog.jsonb_build_object('media_ids', (
      select pg_catalog.jsonb_agg(m.id) from public.media m
      where m.version_id = v_version.id and m.status <> 'READY')));
  end if;

  v_bad := private.listing_submit_errors(v_version, v_settings);
  if pg_catalog.cardinality(v_bad) > 0 then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.to_jsonb(v_bad)));
  end if;

  -- حد الإعلانات الجديدة يحتسب عند أول إرسال فقط (TEAM-DEC-011 البند 4).
  if v_listing.first_submitted_at is null then
    select count(*), min(l.first_submitted_at) into v_recent, v_oldest
      from public.listings l
      where l.owner_id = v_uid and l.first_submitted_at > now() - interval '24 hours';
    if v_recent >= v_limit then
      perform private.raise_error('RATE_LIMITED', pg_catalog.jsonb_build_object(
        'limit', v_limit, 'window_hours', 24, 'retry_at', v_oldest + interval '24 hours'));
    end if;
  end if;

  update public.listing_versions v set
    status = 'SUBMITTED',
    settings_version = (select s.published_version from public.platform_settings s),
    content_hash = private.listing_content_hash(v_version),
    submit_request_id = p_request_id,
    submitted_at = now()
  where v.id = v_version.id;

  update public.listings l set
    status = 'UNDER_REVIEW',
    current_version_id = v_version.id,
    first_submitted_at = coalesce(l.first_submitted_at, now()),
    status_changed_at = now()
  where l.id = p_listing_id;

  return private.listing_owner_json(p_listing_id);
end;
$$;

comment on function public.submit_listing(uuid, uuid) is
  'إرسال المسودة للمراجعة. إعادة الطلب بالمعرف نفسه لا تنشئ إرسالًا ثانيًا.';

-- بدء تعديل: نسخة مسودة جديدة منسوخة من آخر نسخة مع وسائطها الجاهزة.
create function public.start_listing_edit(p_listing_id uuid)
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
      contact_phone, contact_call_enabled, contact_whatsapp_enabled, contact_consent_at)
    values (
      v_new_id, p_listing_id,
      (select max(v.version_no) + 1 from public.listing_versions v where v.listing_id = p_listing_id),
      v_source.title, v_source.description, v_source.breed_id, v_source.breed_note,
      v_source.sex, v_source.age_months, v_source.color,
      v_source.region_id, v_source.city_id, v_source.health_notes, v_source.owner_declaration_at,
      v_source.offer_type, v_source.price,
      v_source.auction_region_id, v_source.auction_city_id, v_source.auction_venue, v_source.auction_starts_at,
      v_source.contact_phone, v_source.contact_call_enabled, v_source.contact_whatsapp_enabled,
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

comment on function public.start_listing_edit(uuid) is
  'بدء تعديل إعلان منشور أو مرفوض أو مؤرشف بنسخة مسودة جديدة.';

-- التراجع عن تعديل إعلان منشور لم يرسل: تحذف مسودة التعديل ويبقى المنشور كما هو.
create function public.discard_listing_edit(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_listing public.listings;
  v_draft public.listing_versions;
begin
  v_listing := private.lock_own_listing(p_listing_id, v_uid);
  if v_listing.status <> 'PUBLISHED' then
    perform private.raise_error(
      'INVALID_STATE', pg_catalog.jsonb_build_object('status', v_listing.status));
  end if;
  v_draft := private.require_draft_version(p_listing_id);

  update public.listings l set current_version_id = l.published_version_id where l.id = p_listing_id;
  delete from public.listing_versions v where v.id = v_draft.id;

  return private.listing_owner_json(p_listing_id);
end;
$$;

comment on function public.discard_listing_edit(uuid) is
  'حذف مسودة تعديل إعلان منشور دون المساس بالمنشور.';

------------------------------------------------------------------------------
-- الأرشفة والحذف والتجديد
------------------------------------------------------------------------------

create function public.archive_listing(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_listing public.listings;
begin
  v_listing := private.lock_own_listing(p_listing_id, v_uid);
  if v_listing.status <> 'PUBLISHED' then
    perform private.raise_error(
      'INVALID_STATE', pg_catalog.jsonb_build_object('status', v_listing.status));
  end if;

  update public.listings l set status = 'ARCHIVED', status_changed_at = now()
    where l.id = p_listing_id;

  return private.listing_owner_json(p_listing_id);
end;
$$;

comment on function public.archive_listing(uuid) is
  'أرشفة إعلان منشور. يختفي عن العامة ويبقى لصاحبه.';

create function public.delete_listing(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_listing public.listings;
  v_objects jsonb := '[]'::jsonb;
  v_hard boolean;
begin
  v_listing := private.lock_own_listing(p_listing_id, v_uid);
  if v_listing.status not in ('DRAFT', 'REJECTED') then
    perform private.raise_error(
      'INVALID_STATE', pg_catalog.jsonb_build_object('status', v_listing.status));
  end if;

  -- إعلان أرسل للمراجعة يومًا يبقى سجله: حذف منطقي (AD-FR-018).
  v_hard := v_listing.first_submitted_at is null;

  if v_hard then
    select coalesce(pg_catalog.jsonb_agg(distinct
        pg_catalog.jsonb_build_object('bucket', m.bucket, 'object_path', m.object_path)), '[]'::jsonb)
      into v_objects
      from public.media m where m.listing_id = p_listing_id;
    update public.listings l set current_version_id = null where l.id = p_listing_id;
    delete from public.listings l where l.id = p_listing_id;
  else
    update public.listings l set deleted_at = now() where l.id = p_listing_id;
  end if;

  -- delete_objects: ملفات لم يعد صف يشير إليها؛ يحذفها العميل من التخزين.
  return pg_catalog.jsonb_build_object(
    'listing_id', p_listing_id, 'deleted', true, 'delete_objects', v_objects);
end;
$$;

comment on function public.delete_listing(uuid) is
  'حذف مسودة أو إعلان مرفوض. ما أرسل للمراجعة يومًا يحذف منطقيًا ويبقى سجله.';

-- تجديد الظهور: ذري بقفل الصف وبوقت الخادم (AD-FR-030).
create function public.bump_listing(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_listing public.listings;
  v_published public.listing_versions;
  v_eligible_at timestamptz;
begin
  v_listing := private.lock_own_listing(p_listing_id, v_uid);
  if v_listing.status <> 'PUBLISHED' then
    perform private.raise_error(
      'INVALID_STATE', pg_catalog.jsonb_build_object('status', v_listing.status));
  end if;

  select * into v_published from public.listing_versions v where v.id = v_listing.published_version_id;
  if v_published.offer_type = 'IN_PERSON_AUCTION' and v_published.auction_starts_at <= now() then
    perform private.raise_error('AUCTION_TIME_PASSED');
  end if;

  v_eligible_at := private.next_bump_at(v_listing);
  if now() < v_eligible_at then
    perform private.raise_error(
      'BUMP_TOO_EARLY', pg_catalog.jsonb_build_object('eligible_at', v_eligible_at));
  end if;

  update public.listings l set last_bumped_at = now(), visibility_updated_at = now()
    where l.id = p_listing_id;
  insert into public.listing_bumps (listing_id, actor_id) values (p_listing_id, v_uid);

  return private.listing_owner_json(p_listing_id);
end;
$$;

comment on function public.bump_listing(uuid) is
  'تجديد ظهور إعلان منشور بعد مرور المهلة. لا يغير محتواه ولا تاريخ نشره الأول.';

------------------------------------------------------------------------------
-- الصلاحيات
------------------------------------------------------------------------------

grant execute on function public.create_listing_draft(uuid) to authenticated;
grant execute on function public.save_listing_draft(uuid, jsonb) to authenticated;
grant execute on function public.add_listing_media(uuid, public.media_kind, text, bigint) to authenticated;
grant execute on function public.remove_listing_media(uuid) to authenticated;
grant execute on function public.arrange_listing_media(uuid, uuid[], uuid) to authenticated;
grant execute on function public.submit_listing(uuid, uuid) to authenticated;
grant execute on function public.start_listing_edit(uuid) to authenticated;
grant execute on function public.discard_listing_edit(uuid) to authenticated;
grant execute on function public.archive_listing(uuid) to authenticated;
grant execute on function public.delete_listing(uuid) to authenticated;
grant execute on function public.bump_listing(uuid) to authenticated;
-- finalize_listing_media: لا تمنح لأدوار العميل؛ يستدعيها service_role.
