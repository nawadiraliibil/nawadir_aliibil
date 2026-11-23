-- 04 settings — MOBILE-BE-102
-- إعدادات المنصة بإصدارات. AD-FR-037، DEC-02، SRS 10.1 و10.2.
-- settings_versions سجل إضافة فقط؛ platform_settings صف واحد يشير إلى الإصدار
-- المنشور ويحمل مسودة التعديل. النشر والتراجع عبر دوال admin_* في ترحيل لاحق.
-- لا تخزن هنا أسرار مزودين.

-- قراءة عدد صحيح موجب من مسار JSON، أو NULL إن لم يكن كذلك.
create function private.json_positive_int(p jsonb, variadic p_path text[])
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case
    when pg_catalog.jsonb_typeof(p #> p_path) = 'number'
      and (p #>> p_path) ~ '^[1-9][0-9]{0,15}$'
    then (p #>> p_path)::bigint
  end
$$;

-- التحقق من محتوى إصدار إعدادات: الحقول المطلوبة، السقوف التقنية، الحد لا يتجاوز
-- الأعلى، والحد الأدنى الثابت لتجديد الظهور (24 ساعة، غير قابل للتخفيض).
create function private.validate_settings(p jsonb)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_fields text[] := array[]::text[];
  v_value bigint;
  r record;
begin
  for r in
    select * from (values
      ('listing', 'title_min', 200::bigint),
      ('listing', 'title_max', 200),
      ('listing', 'description_min', 10000),
      ('listing', 'description_max', 10000),
      ('listing', 'daily_new_limit', 100),
      ('listing', 'open_drafts_max', 100),
      ('media', 'images_min', 20),
      ('media', 'images_max', 20),
      ('media', 'image_max_bytes', 20971520),
      ('media', 'video_max_seconds', 300),
      ('media', 'video_max_bytes', 524288000),
      ('interaction', 'message_max', 5000),
      ('interaction', 'comment_max', 5000),
      ('interaction', 'rating_max', 5000),
      ('rate_limits', 'messages_per_minute', 1000),
      ('rate_limits', 'new_conversations_per_hour', 1000),
      ('rate_limits', 'comments_per_minute', 1000),
      ('rate_limits', 'reports_per_day', 1000),
      ('follows', 'saved_searches_max', 200),
      ('follows', 'followed_sellers_max', 1000),
      ('bump', 'interval_hours', 8760)
    ) as t (section, key, ceiling)
  loop
    v_value := private.json_positive_int(p, r.section, r.key);
    if v_value is null or v_value > r.ceiling then
      v_fields := v_fields || (r.section || '.' || r.key);
    end if;
  end loop;

  if pg_catalog.jsonb_typeof(p #> '{media,video_enabled}') is distinct from 'boolean' then
    v_fields := v_fields || 'media.video_enabled'::text;
  end if;

  -- الصيغ من قائمة مدعومة فعلًا بالشيفرة (SRS 10.2).
  if pg_catalog.jsonb_typeof(p #> '{media,image_mime_types}') is distinct from 'array'
    or pg_catalog.jsonb_array_length(p #> '{media,image_mime_types}') = 0
    or not ((p #> '{media,image_mime_types}') <@ '["image/jpeg", "image/png"]'::jsonb)
  then
    v_fields := v_fields || 'media.image_mime_types'::text;
  end if;

  if private.json_positive_int(p, 'listing', 'title_min')
     > private.json_positive_int(p, 'listing', 'title_max') then
    v_fields := v_fields || 'listing.title_min'::text;
  end if;
  if private.json_positive_int(p, 'listing', 'description_min')
     > private.json_positive_int(p, 'listing', 'description_max') then
    v_fields := v_fields || 'listing.description_min'::text;
  end if;
  if private.json_positive_int(p, 'media', 'images_min')
     > private.json_positive_int(p, 'media', 'images_max') then
    v_fields := v_fields || 'media.images_min'::text;
  end if;

  if pg_catalog.cardinality(v_fields) > 0 then
    perform private.raise_error(
      'VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.to_jsonb(v_fields))
    );
  end if;

  if private.json_positive_int(p, 'bump', 'interval_hours') < 24 then
    perform private.raise_error(
      'BELOW_HARD_MINIMUM',
      pg_catalog.jsonb_build_object('field', 'bump.interval_hours', 'minimum', 24)
    );
  end if;
end;
$$;

create table public.settings_versions (
  version integer primary key check (version > 0),
  content jsonb not null,
  note text check (note is null or char_length(note) <= 500),
  -- عند التراجع: الإصدار الذي أعيد نشر محتواه.
  restored_from_version integer references public.settings_versions (version),
  -- معرف الموظف الناشر. دون مفتاح أجنبي ليبقى السجل ثابتًا؛ NULL لإصدار الترحيل.
  published_by uuid,
  published_at timestamptz not null default now()
);

create trigger settings_versions_append_only
  before update or delete on public.settings_versions
  for each row execute function private.forbid_change();

create table public.platform_settings (
  -- صف واحد فقط.
  id boolean primary key default true check (id),
  published_version integer not null references public.settings_versions (version),
  draft jsonb,
  draft_updated_by uuid,
  draft_updated_at timestamptz,
  updated_at timestamptz not null default now()
);

create trigger platform_settings_set_updated_at before update on public.platform_settings
  for each row execute function private.set_updated_at();

-- مغلقان أمام أدوار العميل: لا منح ولا سياسات. القراءة للعميل عبر
-- get_published_settings()، وقراءة الموظف تضاف مع جدول الأدوار.
alter table public.settings_versions enable row level security;
alter table public.platform_settings enable row level security;

-- الإصدار 1: قيم البدء من SRS 10.1، مع حد المسودات المفتوحة (TEAM-DEC-011 البند 4)
-- والفيديو معطل افتراضيًا (خطة MOBILE-PLAN-20261122).
do $$
declare
  v_content constant jsonb := '{
    "listing": {
      "title_min": 10,
      "title_max": 80,
      "description_min": 20,
      "description_max": 2000,
      "daily_new_limit": 5,
      "open_drafts_max": 20
    },
    "media": {
      "images_min": 3,
      "images_max": 10,
      "image_max_bytes": 10485760,
      "image_mime_types": ["image/jpeg", "image/png"],
      "video_enabled": false,
      "video_max_seconds": 60,
      "video_max_bytes": 104857600
    },
    "interaction": {
      "message_max": 2000,
      "comment_max": 1000,
      "rating_max": 1000
    },
    "rate_limits": {
      "messages_per_minute": 20,
      "new_conversations_per_hour": 5,
      "comments_per_minute": 5,
      "reports_per_day": 10
    },
    "follows": {
      "saved_searches_max": 20,
      "followed_sellers_max": 100
    },
    "bump": {
      "interval_hours": 24
    }
  }';
begin
  perform private.validate_settings(v_content);
  insert into public.settings_versions (version, content, note)
    values (1, v_content, 'قيم البدء — SRS 10.1');
  insert into public.platform_settings (published_version) values (1);
end;
$$;

-- محتوى الإصدار المنشور، لاستخدام دوال الخادم.
create function private.published_settings()
returns jsonb
language sql
stable
set search_path = ''
as $$
  select v.content
  from public.platform_settings s
  join public.settings_versions v on v.version = s.published_version
$$;

-- الإعدادات المنشورة والقوائم الفعالة للعملاء (الجوال والويب).
create function public.get_published_settings()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'version', v.version,
    'published_at', v.published_at,
    'settings', v.content,
    'lookups', pg_catalog.jsonb_build_object(
      'regions', coalesce((
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object('id', r.id, 'name_ar', r.name_ar)
          order by r.sort_order, r.id)
        from public.regions r
        where r.is_active
      ), '[]'::jsonb),
      'cities', coalesce((
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object('id', c.id, 'region_id', c.region_id, 'name_ar', c.name_ar)
          order by c.region_id, c.sort_order, c.id)
        from public.cities c
        join public.regions r on r.id = c.region_id
        where c.is_active and r.is_active
      ), '[]'::jsonb),
      'breeds', coalesce((
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object('id', b.id, 'name_ar', b.name_ar, 'requires_note', b.requires_note)
          order by b.sort_order, b.id)
        from public.breeds b
        where b.is_active
      ), '[]'::jsonb)
    )
  )
  from public.platform_settings s
  join public.settings_versions v on v.version = s.published_version
$$;

comment on function public.get_published_settings() is
  'الإصدار المنشور من الإعدادات مع القوائم الفعالة. متاح للزائر والمستخدم.';

grant execute on function public.get_published_settings() to anon, authenticated;
