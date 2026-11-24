-- MOBILE-BE-SORT-VIEWS-20261124 — فرز «الأكثر مشاهدة» في search_listings (p_sort = MOST_VIEWED).
-- الأعلى مشاهدة أولًا ثم الأحدث معرّفًا؛ المؤشر {views, id}. القيم الأخرى بلا تغيير.

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
  v_c_views integer;
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
  if v_sort not in ('NEWEST_VISIBLE', 'NEWEST_PUBLISHED', 'PRICE_ASC', 'PRICE_DESC', 'MOST_VIEWED') then
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
      elsif v_sort = 'MOST_VIEWED' then
        v_c_views := (p_cursor ->> 'views')::integer;
        if v_c_views is null then v_bad := v_bad || 'p_cursor'::text; end if;
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
          when 'MOST_VIEWED' then
            coalesce(st.view_count, 0) < v_c_views
            or (coalesce(st.view_count, 0) = v_c_views and l.id < v_c_id)
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
      case when v_sort = 'MOST_VIEWED' then coalesce(st.view_count, 0) end desc,
      case when v_sort = 'MOST_VIEWED' then l.id end desc,
      case when v_sort in ('PRICE_ASC', 'PRICE_DESC') then (v.price is null) end,
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
    elsif v_sort = 'MOST_VIEWED' then
      v_next := pg_catalog.jsonb_build_object('views', v_last -> 'view_count', 'id', v_last -> 'listing_id');
    else
      v_next := pg_catalog.jsonb_build_object('price', v_last -> 'price', 'id', v_last -> 'listing_id');
    end if;
  end if;

  return pg_catalog.jsonb_build_object('items', v_rows, 'next_cursor', v_next);
end;
$$;
