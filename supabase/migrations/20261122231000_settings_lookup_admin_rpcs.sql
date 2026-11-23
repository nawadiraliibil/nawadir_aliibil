-- 11 settings_lookup_admin_rpcs — MOBILE-BE-108
-- إدارة القوائم والإعدادات: AD-FR-037، DEC-02، SRS 10.2، AD-AC-024.
-- القوائم (سلالات، مناطق، مدن، أسباب إشراف): تعديلها يسري فورًا. لا حذف لقيمة؛
-- تعطيل فقط، والقيمة المعطلة تبقى في الإعلانات السابقة ولا تقبل في جديد.
-- الإعدادات: تعدل على مسودة، وتنشر ذريًا بإصدار جديد، والتراجع ينشر إصدارًا جديدًا
-- بمحتوى إصدار سابق.

------------------------------------------------------------------------------
-- مساعدات داخلية
------------------------------------------------------------------------------

-- اسم عرض لقيمة قائمة بعد تنظيفه؛ خطأ إن كان فارغًا أو أطول من السقف.
create function private.clean_lookup_name(p_name text, p_max integer)
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_name text := btrim(pg_catalog.regexp_replace(coalesce(p_name, ''), '\s+', ' ', 'g'));
begin
  if char_length(v_name) not between 1 and p_max or v_name ~ '[[:cntrl:]]' then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('name_ar')));
  end if;
  return v_name;
end;
$$;

-- محتوى إعدادات بالمفاتيح المعرفة فقط؛ ما عداها يهمل.
create function private.normalize_settings(p jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'listing', pg_catalog.jsonb_build_object(
      'title_min', p #> '{listing,title_min}',
      'title_max', p #> '{listing,title_max}',
      'description_min', p #> '{listing,description_min}',
      'description_max', p #> '{listing,description_max}',
      'daily_new_limit', p #> '{listing,daily_new_limit}',
      'open_drafts_max', p #> '{listing,open_drafts_max}'),
    'media', pg_catalog.jsonb_build_object(
      'images_min', p #> '{media,images_min}',
      'images_max', p #> '{media,images_max}',
      'image_max_bytes', p #> '{media,image_max_bytes}',
      'image_mime_types', p #> '{media,image_mime_types}',
      'video_enabled', p #> '{media,video_enabled}',
      'video_max_seconds', p #> '{media,video_max_seconds}',
      'video_max_bytes', p #> '{media,video_max_bytes}'),
    'interaction', pg_catalog.jsonb_build_object(
      'message_max', p #> '{interaction,message_max}',
      'comment_max', p #> '{interaction,comment_max}',
      'rating_max', p #> '{interaction,rating_max}'),
    'rate_limits', pg_catalog.jsonb_build_object(
      'messages_per_minute', p #> '{rate_limits,messages_per_minute}',
      'new_conversations_per_hour', p #> '{rate_limits,new_conversations_per_hour}',
      'comments_per_minute', p #> '{rate_limits,comments_per_minute}',
      'reports_per_day', p #> '{rate_limits,reports_per_day}'),
    'follows', pg_catalog.jsonb_build_object(
      'saved_searches_max', p #> '{follows,saved_searches_max}',
      'followed_sellers_max', p #> '{follows,followed_sellers_max}'),
    'bump', pg_catalog.jsonb_build_object(
      'interval_hours', p #> '{bump,interval_hours}')
  )
$$;

-- تفعيل الإعدادات في مصدر التنفيذ خارج الجداول (SRS 10.2): حدود التخزين تتبع
-- الإصدار المنشور في المعاملة نفسها، فلا ينجح النشر دون تفعيلها.
create function private.apply_settings_to_storage(p_content jsonb)
returns void
language sql
set search_path = ''
as $$
  update storage.buckets b set
    file_size_limit = (p_content #>> '{media,image_max_bytes}')::bigint,
    allowed_mime_types = (
      select pg_catalog.array_agg(t.value order by t.value)
      from pg_catalog.jsonb_array_elements_text(p_content #> '{media,image_mime_types}') as t (value))
  where b.id = 'listing-images';

  update storage.buckets b set
    file_size_limit = (p_content #>> '{media,video_max_bytes}')::bigint
  where b.id = 'listing-videos';
$$;

create function private.settings_admin_json()
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'published_version', s.published_version,
    'published', v.content,
    'published_at', v.published_at,
    'draft', s.draft,
    'draft_updated_by', s.draft_updated_by,
    'draft_updated_at', s.draft_updated_at)
  from public.platform_settings s
  join public.settings_versions v on v.version = s.published_version
$$;

------------------------------------------------------------------------------
-- القوائم
------------------------------------------------------------------------------

create function public.admin_upsert_region(
  p_id integer,
  p_name_ar text,
  p_sort_order integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('lookups.manage');
  v_name text := private.clean_lookup_name(p_name_ar, 60);
  v_row public.regions;
begin
  if p_id is null then
    insert into public.regions (name_ar, sort_order)
      values (v_name, coalesce(p_sort_order,
        (select coalesce(max(r.sort_order), 0) + 10 from public.regions r)))
      returning * into v_row;
  else
    update public.regions r set
        name_ar = v_name, sort_order = coalesce(p_sort_order, r.sort_order)
      where r.id = p_id returning * into v_row;
    if not found then
      perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'region'));
    end if;
  end if;

  perform private.audit(
    v_actor, 'lookup.upserted', 'region', v_row.id::text,
    pg_catalog.jsonb_build_object('created', p_id is null, 'name_ar', v_row.name_ar));
  return pg_catalog.to_jsonb(v_row);
exception when unique_violation then
  perform private.raise_error('VALIDATION_FAILED', pg_catalog.jsonb_build_object(
    'fields', pg_catalog.jsonb_build_array('name_ar'), 'reason', 'duplicate'));
  return null;
end;
$$;

comment on function public.admin_upsert_region(integer, text, integer) is
  'إضافة منطقة (p_id فارغ) أو تعديلها. القدرة: lookups.manage.';

create function public.admin_upsert_city(
  p_id integer,
  p_region_id integer,
  p_name_ar text,
  p_sort_order integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('lookups.manage');
  v_name text := private.clean_lookup_name(p_name_ar, 60);
  v_row public.cities;
begin
  if p_region_id is null
    or not exists (select 1 from public.regions r where r.id = p_region_id)
  then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('region_id')));
  end if;

  if p_id is null then
    insert into public.cities (region_id, name_ar, sort_order)
      values (p_region_id, v_name, coalesce(p_sort_order,
        (select coalesce(max(c.sort_order), 0) + 10 from public.cities c where c.region_id = p_region_id)))
      returning * into v_row;
  else
    update public.cities c set
        region_id = p_region_id, name_ar = v_name, sort_order = coalesce(p_sort_order, c.sort_order)
      where c.id = p_id returning * into v_row;
    if not found then
      perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'city'));
    end if;
  end if;

  perform private.audit(
    v_actor, 'lookup.upserted', 'city', v_row.id::text,
    pg_catalog.jsonb_build_object(
      'created', p_id is null, 'name_ar', v_row.name_ar, 'region_id', v_row.region_id));
  return pg_catalog.to_jsonb(v_row);
exception
  when unique_violation then
    perform private.raise_error('VALIDATION_FAILED', pg_catalog.jsonb_build_object(
      'fields', pg_catalog.jsonb_build_array('name_ar'), 'reason', 'duplicate'));
    return null;
  -- مدينة مستخدمة في إعلانات لا تنقل إلى منطقة أخرى.
  when foreign_key_violation then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('reason', 'in_use'));
    return null;
end;
$$;

comment on function public.admin_upsert_city(integer, integer, text, integer) is
  'إضافة مدينة تابعة لمنطقة أو تعديلها. القدرة: lookups.manage.';

create function public.admin_upsert_breed(
  p_id integer,
  p_name_ar text,
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
  v_name text := private.clean_lookup_name(p_name_ar, 60);
  v_row public.breeds;
begin
  if p_id is null then
    insert into public.breeds (name_ar, requires_note, sort_order)
      values (v_name, coalesce(p_requires_note, false), coalesce(p_sort_order,
        (select coalesce(max(b.sort_order), 0) + 10 from public.breeds b)))
      returning * into v_row;
  else
    update public.breeds b set
        name_ar = v_name,
        requires_note = coalesce(p_requires_note, b.requires_note),
        sort_order = coalesce(p_sort_order, b.sort_order)
      where b.id = p_id returning * into v_row;
    if not found then
      perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'breed'));
    end if;
  end if;

  perform private.audit(
    v_actor, 'lookup.upserted', 'breed', v_row.id::text,
    pg_catalog.jsonb_build_object('created', p_id is null, 'name_ar', v_row.name_ar));
  return pg_catalog.to_jsonb(v_row);
exception when unique_violation then
  perform private.raise_error('VALIDATION_FAILED', pg_catalog.jsonb_build_object(
    'fields', pg_catalog.jsonb_build_array('name_ar'), 'reason', 'duplicate'));
  return null;
end;
$$;

comment on function public.admin_upsert_breed(integer, text, boolean, integer) is
  'إضافة سلالة أو تعديلها. القدرة: lookups.manage.';

create function public.admin_upsert_moderation_reason(
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
    or not (p_applies_to <@ array['LISTING_REJECT', 'LISTING_HIDE', 'ACCOUNT_SUSPEND']::text[])
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

comment on function public.admin_upsert_moderation_reason(text, text, text[], boolean, integer) is
  'إضافة سبب إشراف أو تعديله. القدرة: lookups.manage.';

-- تعطيل قيمة أو تفعيلها. p_kind: region | city | breed | moderation_reason.
-- p_id: المعرف نصًا (رقم القيمة، أو رمز سبب الإشراف).
create function public.admin_set_lookup_active(
  p_kind text,
  p_id text,
  p_is_active boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('lookups.manage');
  v_int integer;
  v_result jsonb;
begin
  if p_is_active is null then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('is_active')));
  end if;
  if p_kind in ('region', 'city', 'breed') then
    if p_id is null or p_id !~ '^[0-9]{1,9}$' then
      perform private.raise_error(
        'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('id')));
    end if;
    v_int := p_id::integer;
  end if;

  if p_kind = 'region' then
    update public.regions r set is_active = p_is_active where r.id = v_int
      returning pg_catalog.to_jsonb(r) into v_result;
  elsif p_kind = 'city' then
    update public.cities c set is_active = p_is_active where c.id = v_int
      returning pg_catalog.to_jsonb(c) into v_result;
  elsif p_kind = 'breed' then
    update public.breeds b set is_active = p_is_active where b.id = v_int
      returning pg_catalog.to_jsonb(b) into v_result;
  elsif p_kind = 'moderation_reason' then
    update public.moderation_reasons m set is_active = p_is_active where m.code = p_id
      returning pg_catalog.to_jsonb(m) into v_result;
  else
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('kind')));
  end if;

  if v_result is null then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', p_kind));
  end if;

  perform private.audit(
    v_actor,
    case when p_is_active then 'lookup.activated' else 'lookup.deactivated' end,
    p_kind, p_id);
  return v_result;
end;
$$;

comment on function public.admin_set_lookup_active(text, text, boolean) is
  'تعطيل قيمة قائمة أو تفعيلها دون حذف. القدرة: lookups.manage.';

-- ترتيب قيم قائمة: المعرفات بالترتيب المطلوب. ما لم يذكر يبقى ترتيبه.
create function public.admin_reorder_lookup(p_kind text, p_ids text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('lookups.manage');
  v_updated integer;
begin
  if p_kind is null or p_kind not in ('region', 'city', 'breed', 'moderation_reason') then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('kind')));
  end if;
  if p_ids is null or pg_catalog.cardinality(p_ids) = 0
    or pg_catalog.array_position(p_ids, null) is not null
    or (select count(distinct x) from pg_catalog.unnest(p_ids) as x) <> pg_catalog.cardinality(p_ids)
    or (p_kind <> 'moderation_reason' and exists (
      select 1 from pg_catalog.unnest(p_ids) as x where x !~ '^[0-9]{1,9}$'))
  then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('ids')));
  end if;

  if p_kind = 'region' then
    update public.regions r set sort_order = (o.ord * 10)::integer
      from pg_catalog.unnest(p_ids) with ordinality as o (id, ord) where r.id = o.id::integer;
  elsif p_kind = 'city' then
    update public.cities c set sort_order = (o.ord * 10)::integer
      from pg_catalog.unnest(p_ids) with ordinality as o (id, ord) where c.id = o.id::integer;
  elsif p_kind = 'breed' then
    update public.breeds b set sort_order = (o.ord * 10)::integer
      from pg_catalog.unnest(p_ids) with ordinality as o (id, ord) where b.id = o.id::integer;
  else
    update public.moderation_reasons m set sort_order = (o.ord * 10)::integer
      from pg_catalog.unnest(p_ids) with ordinality as o (id, ord) where m.code = o.id;
  end if;
  get diagnostics v_updated = row_count;

  -- معرف غير موجود يلغي العملية كلها.
  if v_updated <> pg_catalog.cardinality(p_ids) then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', p_kind));
  end if;

  perform private.audit(
    v_actor, 'lookup.reordered', p_kind, null,
    pg_catalog.jsonb_build_object('ids', pg_catalog.to_jsonb(p_ids)));
  return pg_catalog.jsonb_build_object('kind', p_kind, 'updated', v_updated);
end;
$$;

comment on function public.admin_reorder_lookup(text, text[]) is
  'ترتيب قيم قائمة بحسب تسلسل المعرفات المرسلة. القدرة: lookups.manage.';

------------------------------------------------------------------------------
-- الإعدادات
------------------------------------------------------------------------------

create function public.admin_get_settings()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_staff('settings.manage');
  return private.settings_admin_json();
end;
$$;

comment on function public.admin_get_settings() is
  'الإصدار المنشور ومسودة التعديل. القدرة: settings.manage.';

-- حفظ مسودة الإعدادات كاملة. null يلغي المسودة.
create function public.admin_update_settings_draft(p_content jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('settings.manage');
  v_content jsonb;
begin
  if p_content is not null and pg_catalog.jsonb_typeof(p_content) <> 'null' then
    if pg_catalog.jsonb_typeof(p_content) <> 'object' then
      perform private.raise_error(
        'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('content')));
    end if;
    v_content := private.normalize_settings(p_content);
    perform private.validate_settings(v_content);
  end if;

  update public.platform_settings s set
    draft = v_content,
    draft_updated_by = case when v_content is null then null else v_actor end,
    draft_updated_at = case when v_content is null then null else now() end;

  return private.settings_admin_json();
end;
$$;

comment on function public.admin_update_settings_draft(jsonb) is
  'حفظ مسودة الإعدادات بعد التحقق منها، أو إلغاؤها بـnull. لا يغير المنشور. القدرة: settings.manage.';

create function public.admin_publish_settings(p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('settings.manage');
  v_settings public.platform_settings;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_version integer;
begin
  select * into v_settings from public.platform_settings s for update;

  if v_settings.draft is null then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('reason', 'no_draft'));
  end if;
  if v_settings.draft = private.published_settings() then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('reason', 'no_changes'));
  end if;
  if char_length(v_note) > 500 then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('note')));
  end if;
  perform private.validate_settings(v_settings.draft);

  select coalesce(max(v.version), 0) + 1 into v_version from public.settings_versions v;
  insert into public.settings_versions (version, content, note, published_by)
    values (v_version, v_settings.draft, v_note, v_actor);
  update public.platform_settings s set
    published_version = v_version, draft = null, draft_updated_by = null, draft_updated_at = null;
  perform private.apply_settings_to_storage(v_settings.draft);

  perform private.audit(
    v_actor, 'settings.published', 'settings_version', v_version::text,
    pg_catalog.jsonb_build_object('previous_version', v_settings.published_version), null, v_note);

  return private.settings_admin_json();
end;
$$;

comment on function public.admin_publish_settings(text) is
  'نشر مسودة الإعدادات بإصدار جديد. ذري مع حدود التخزين. القدرة: settings.manage.';

create function public.admin_rollback_settings(p_version integer, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('settings.manage');
  v_settings public.platform_settings;
  v_content jsonb;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_version integer;
begin
  select * into v_settings from public.platform_settings s for update;

  select v.content into v_content from public.settings_versions v where v.version = p_version;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'settings_version'));
  end if;
  if p_version = v_settings.published_version then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('reason', 'already_published'));
  end if;
  if char_length(v_note) > 500 then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('note')));
  end if;
  -- محتوى قديم يخالف القواعد الحالية لا يعاد نشره.
  perform private.validate_settings(v_content);

  select coalesce(max(v.version), 0) + 1 into v_version from public.settings_versions v;
  insert into public.settings_versions (version, content, note, restored_from_version, published_by)
    values (v_version, v_content, v_note, p_version, v_actor);
  update public.platform_settings s set published_version = v_version;
  perform private.apply_settings_to_storage(v_content);

  perform private.audit(
    v_actor, 'settings.rolled_back', 'settings_version', v_version::text,
    pg_catalog.jsonb_build_object(
      'previous_version', v_settings.published_version, 'restored_from_version', p_version),
    null, v_note);

  return private.settings_admin_json();
end;
$$;

comment on function public.admin_rollback_settings(integer, text) is
  'التراجع: نشر إصدار جديد بمحتوى إصدار سابق. القدرة: settings.manage.';

------------------------------------------------------------------------------
-- الصلاحيات
------------------------------------------------------------------------------

grant execute on function public.admin_upsert_region(integer, text, integer) to authenticated;
grant execute on function public.admin_upsert_city(integer, integer, text, integer) to authenticated;
grant execute on function public.admin_upsert_breed(integer, text, boolean, integer) to authenticated;
grant execute on function public.admin_upsert_moderation_reason(text, text, text[], boolean, integer) to authenticated;
grant execute on function public.admin_set_lookup_active(text, text, boolean) to authenticated;
grant execute on function public.admin_reorder_lookup(text, text[]) to authenticated;
grant execute on function public.admin_get_settings() to authenticated;
grant execute on function public.admin_update_settings_draft(jsonb) to authenticated;
grant execute on function public.admin_publish_settings(text) to authenticated;
grant execute on function public.admin_rollback_settings(integer, text) to authenticated;
