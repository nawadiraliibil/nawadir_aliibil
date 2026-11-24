-- MOBILE-BE-WA-20261123 — TEAM-DEC-012: رقم واتساب مستقل عن رقم الاتصال.
--
-- لكل نسخة إعلان رقمان اختياريان مستقلان: contact_phone (اتصال) وcontact_whatsapp_phone (واتساب)،
-- ويلزم أحدهما على الأقل عند الإرسال، ويبقى contact_consent_at مطلوبًا.
-- التوافق: العمودان contact_call_enabled وcontact_whatsapp_enabled يبقيان في الجدول والـviews
-- والمخرجات، لكن قيمتهما مشتقة دائمًا بمشغل (اتصال = contact_phone غير فارغ؛ واتساب = رقم واتساب غير فارغ).
-- مفتاحا patch القديمان يقبلان ويحوَّلان: contact_whatsapp_enabled=true ينسخ رقم الاتصال إلى رقم واتساب،
-- =false يفرغ رقم واتساب، وcontact_call_enabled=false يفرغ رقم الاتصال، وذلك فقط إذا لم يرد
-- المفتاح contact_whatsapp_phone في الـpatch نفسه (الصريح يغلب).

alter table public.listing_versions
  add column contact_whatsapp_phone text
    check (contact_whatsapp_phone is null or contact_whatsapp_phone ~ '^\+9665[0-9]{8}$');

comment on column public.listing_versions.contact_phone is 'رقم الاتصال فقط (اختياري).';
comment on column public.listing_versions.contact_whatsapp_phone is 'رقم واتساب المستقل (اختياري)؛ يلزم أحد الرقمين عند الإرسال.';

-- القيد القديم يشترط رقمًا واحدًا بعلامتي قناة.
alter table public.listing_versions drop constraint listing_versions_complete_when_submitted;

-- مشتق العلامتين من الرقمين.
create function private.derive_contact_flags()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.contact_call_enabled := new.contact_phone is not null;
  new.contact_whatsapp_enabled := new.contact_whatsapp_phone is not null;
  return new;
end;
$$;

create trigger listing_versions_derive_contact before insert or update on public.listing_versions
  for each row execute function private.derive_contact_flags();

-- تحويل البيانات الموجودة. حارس ثبات النسخة يعطل أثناء التحويل فقط.
alter table public.listing_versions disable trigger listing_versions_guard;
update public.listing_versions
  set contact_whatsapp_phone = case when contact_whatsapp_enabled then contact_phone end,
      contact_phone = case when contact_call_enabled then contact_phone end
  where contact_phone is not null;
alter table public.listing_versions enable trigger listing_versions_guard;

alter table public.listing_versions add constraint listing_versions_complete_when_submitted check (
  status = 'DRAFT'
  or (
    title is not null and description is not null
    and breed_id is not null and sex is not null and age_months is not null
    and region_id is not null and city_id is not null
    and health_notes is not null and owner_declaration_at is not null
    and offer_type is not null
    and (
      (offer_type = 'FIXED_PRICE' and price is not null)
      or (offer_type = 'IN_PERSON_AUCTION'
          and auction_region_id is not null and auction_city_id is not null
          and auction_venue is not null and auction_starts_at is not null)
    )
    and (contact_phone is not null or contact_whatsapp_phone is not null)
    and contact_consent_at is not null
    and settings_version is not null and content_hash is not null
    and submitted_at is not null
  )
);

create or replace function private.listing_content_hash(p_version public.listing_versions)
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
      'contact_whatsapp_phone', p_version.contact_whatsapp_phone,
      'media', coalesce((
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'bucket', m.bucket, 'path', m.object_path, 'kind', m.kind,
            'cover', m.is_cover, 'order', m.sort_order)
          order by m.sort_order, m.object_path)
        from public.media m where m.version_id = p_version.id), '[]'::jsonb)
    )::text, 'UTF8')), 'hex')
$$;

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
      contact_phone, contact_whatsapp_phone, contact_consent_at)
    values (
      v_new_id, p_listing_id,
      (select max(v.version_no) + 1 from public.listing_versions v where v.listing_id = p_listing_id),
      v_source.title, v_source.description, v_source.breed_id, v_source.breed_note,
      v_source.sex, v_source.age_months, v_source.color,
      v_source.region_id, v_source.city_id, v_source.health_notes, v_source.owner_declaration_at,
      v_source.offer_type, v_source.price,
      v_source.auction_region_id, v_source.auction_city_id, v_source.auction_venue, v_source.auction_starts_at,
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

-- الـview العام: عمود contact_whatsapp_phone مضاف في الآخر (create or replace لا يغير ترتيب الأعمدة).
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
  v.contact_whatsapp_phone
from public.listings l
join public.listing_versions v on v.id = l.published_version_id
join public.profiles p on p.id = l.owner_id
join public.breeds b on b.id = v.breed_id
join public.regions rg on rg.id = v.region_id
join public.cities c on c.id = v.city_id
left join public.regions arg on arg.id = v.auction_region_id
left join public.cities ac on ac.id = v.auction_city_id
where l.status = 'PUBLISHED' and l.deleted_at is null;

comment on view public.public_listing_details is
  'تفاصيل الإعلان المنشور من نسخته المعتمدة، ومنها رقما الاتصال وواتساب المنشوران (TEAM-DEC-012).';
