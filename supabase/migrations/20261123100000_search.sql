-- 14 search — MOBILE-BE-201
-- البحث والتصفية والفرز والتصفح على دفعات: AD-FR-011، AD-FR-012، AD-FR-024،
-- AD-AC-006، AD-AC-012، AD-AC-014. والمعرّف العام القصير للروابط (AD-FR-023).
-- القراءة عامة للزائر والمستخدم؛ لا تظهر إلا الإعلانات المنشورة من نسختها المعتمدة.

------------------------------------------------------------------------------
-- المعرّف العام القصير
------------------------------------------------------------------------------

-- ثمانية أحرف من أبجدية دون ما يلتبس (0 O 1 I L). ثابت لا يتغير بتعديل الإعلان
-- أو تجديده، ولا يكشف شيئًا عن المالك. التصادم محتمل رياضيًا بنسبة ضئيلة جدًا؛
-- القيد الفريد يرفضه ويعيد العميل المحاولة.
create function private.new_public_ref()
returns text
language sql
volatile
set search_path = ''
as $$
  select pg_catalog.string_agg(
    pg_catalog.substr('abcdefghjkmnpqrstuvwxyz23456789', (pg_catalog.get_byte(b, i) % 31) + 1, 1), '')
  from (select pg_catalog.decode(pg_catalog.replace(pg_catalog.gen_random_uuid()::text, '-', ''), 'hex') as b) r,
       pg_catalog.generate_series(0, 7) i;
$$;

alter table public.listings
  add column public_ref text not null default private.new_public_ref();
alter table public.listings
  add constraint listings_public_ref_format check (public_ref ~ '^[a-z2-9]{8}$'),
  add constraint listings_public_ref_key unique (public_ref);

-- الـviews تضيف العمود في آخرها فلا تنكسر الأعمدة السابقة.
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
  l.public_ref
from public.listings l
join public.listing_versions v on v.id = l.published_version_id
join public.profiles p on p.id = l.owner_id
join public.breeds b on b.id = v.breed_id
join public.regions rg on rg.id = v.region_id
join public.cities c on c.id = v.city_id
left join public.media cover on cover.version_id = v.id and cover.is_cover and cover.status = 'READY'
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
  l.public_ref
from public.listings l
join public.listing_versions v on v.id = l.published_version_id
join public.profiles p on p.id = l.owner_id
join public.breeds b on b.id = v.breed_id
join public.regions rg on rg.id = v.region_id
join public.cities c on c.id = v.city_id
left join public.regions arg on arg.id = v.auction_region_id
left join public.cities ac on ac.id = v.auction_city_id
where l.status = 'PUBLISHED' and l.deleted_at is null;

-- ترجمة المعرّف العام إلى معرف الإعلان. الإعلان غير المنشور لا يعيد شيئًا
-- (NOT_FOUND) فلا يكشف وجوده ولا حالته: الرابط المخفي يتوقف فور الإخفاء.
create function public.resolve_listing_ref(p_ref text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  select l.id into v_id from public.listings l
    where l.public_ref = pg_catalog.lower(pg_catalog.btrim(coalesce(p_ref, '')))
      and l.status = 'PUBLISHED' and l.deleted_at is null;
  if v_id is null then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'listing'));
  end if;
  return v_id;
end;
$$;

comment on function public.resolve_listing_ref(text) is
  'يترجم المعرّف العام القصير في رابط المشاركة إلى معرف إعلان منشور؛ غير المنشور NOT_FOUND.';

------------------------------------------------------------------------------
-- فهرس البحث في العنوان
------------------------------------------------------------------------------

create index listing_versions_title_trgm_idx
  on public.listing_versions using gin (title extensions.gin_trgm_ops)
  where status = 'APPROVED';

------------------------------------------------------------------------------
-- search_listings
------------------------------------------------------------------------------

-- التصفح والبحث. كل المرشحات اختيارية وتعمل مجتمعة.
--  p_query         نص يبحث عنه في العنوان (حرف أو أكثر، حتى 100)
--  p_region_id     المنطقة؛ p_city_id المدينة وتتبع المنطقة إن ذكرت معها
--  p_breed_id، p_sex (MALE|FEMALE)، p_offer_type (FIXED_PRICE|IN_PERSON_AUCTION)
--  p_age_min/p_age_max بالأشهر؛ p_price_min/p_price_max بالريال
--  p_owner_id      إعلانات معلن واحد (ملفه العام)
--  p_sort          NEWEST_VISIBLE (افتراضي) | NEWEST_PUBLISHED | PRICE_ASC | PRICE_DESC
--  p_limit         1 إلى 50، الافتراضي 20
--  p_cursor        next_cursor من الرد السابق، ولا يتغير بين صفحات البحث نفسه
-- قواعد AD-FR-011 وAD-FR-012:
--  * المزاد الذي مضى موعده خارج النتائج.
--  * تحديد نطاق سعر يستبعد المزادات (لا سعر لها، ولا يستخدم الصفر).
--  * الفرز بالسعر يضع المزادات أخيرًا.
--  * النطاق المعكوس أو السالب يرفض بـVALIDATION_FAILED.
create function public.search_listings(
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
      case v_sort when 'NEWEST_PUBLISHED' then l.first_published_at else l.visibility_updated_at end as sort_ts
    from public.listings l
    join public.listing_versions v on v.id = l.published_version_id
    join public.profiles p on p.id = l.owner_id
    join public.breeds b on b.id = v.breed_id
    join public.regions rg on rg.id = v.region_id
    join public.cities c on c.id = v.city_id
    left join public.media cover on cover.version_id = v.id and cover.is_cover and cover.status = 'READY'
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

comment on function public.search_listings(text, integer, integer, integer, text, text, integer, integer, numeric, numeric, uuid, text, integer, jsonb) is
  'تصفح الإعلانات المنشورة وبحثها بمرشحات مجتمعة وفرز ومؤشر keyset. المزاد الماضي خارج النتائج.';

grant execute on function public.resolve_listing_ref(text) to anon, authenticated;
grant execute on function public.search_listings(text, integer, integer, integer, text, text, integer, integer, numeric, numeric, uuid, text, integer, jsonb) to anon, authenticated;
