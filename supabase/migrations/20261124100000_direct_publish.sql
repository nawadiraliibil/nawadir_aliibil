-- 24 direct_publish — MOBILE-BE-DIRECT-PUBLISH-20261124
-- إلغاء اعتماد الإدارة للإعلانات (TEAM-DEC-013): الإرسال ينشر مباشرة، والإدارة
-- تتحكم بالظهور بالإخفاء وإعادة الإظهار فقط.
-- انتقالات الحالة الجديدة من جهة المعلن:
--   إرسال   DRAFT -> PUBLISHED (أول نشر)
--   إرسال   PUBLISHED (بمسودة تعديل) -> PUBLISHED بالنسخة الجديدة فورًا
--   بدء تعديل REJECTED أو ARCHIVED -> DRAFT ثم إرسال -> PUBLISHED
-- الحالتان UNDER_REVIEW وREJECTED تبقيان في النوع المعدد للتوافق ولا تنتجان:
--   * قيد يمنع UNDER_REVIEW نهائيًا (يحول الموجود منه في هذا الترحيل).
--   * REJECTED يبقى مقبولًا للبيانات القديمة فقط.
-- سجل «النشر التلقائي»: صف في reviews بقرار APPROVED وmoderator_id = معرف المعلن
-- وreason_text = 'AUTO_PUBLISH' (لا قيمة جديدة في النوع المعدد؛ moderator_id بلا مفتاح أجنبي
-- فلا ينكسر قيد). لا إشعار للمعلن عنه، ولا يقرأ المعلن جدول reviews.

------------------------------------------------------------------------------
-- قرار الإشراف -> إشعار: لا إشعار لنشر تلقائي أو لاعتماد/رفض قديم
------------------------------------------------------------------------------

create or replace function private.notify_listing_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_owner_status public.account_status;
  v_title text;
begin
  -- لا اعتماد ولا رفض بعد TEAM-DEC-013؛ النشر التلقائي لا يشعر صاحبه.
  if new.decision in ('APPROVED', 'REJECTED') then
    return new;
  end if;

  select l.owner_id, p.status into v_owner, v_owner_status
    from public.listings l
    join public.profiles p on p.id = l.owner_id
    where l.id = new.listing_id;

  -- إخفاء ناتج عن تعليق الحساب: يكفي إشعار التعليق.
  if new.decision = 'HIDDEN' and v_owner_status = 'SUSPENDED' then
    return new;
  end if;

  select v.title into v_title from public.listing_versions v where v.id = new.version_id;

  perform private.notify(
    v_owner,
    'LISTING_STATUS',
    'listing.' || pg_catalog.lower(new.decision::text),
    'listing',
    new.listing_id::text,
    pg_catalog.jsonb_build_object(
      'listing_id', new.listing_id,
      'title', v_title,
      'decision', new.decision,
      'reason_code', new.reason_code,
      'reason_label_ar', (
        select mr.label_ar from public.moderation_reasons mr where mr.code = new.reason_code),
      -- نص السبب يراه المعلن عند الإخفاء؛ ملاحظة إعادة الإظهار داخلية.
      'reason_text', case when new.decision in ('REJECTED', 'HIDDEN') then new.reason_text end),
    'review:' || new.id::text);

  return new;
end;
$$;

------------------------------------------------------------------------------
-- النشر المشترك
------------------------------------------------------------------------------

-- يجعل النسخة هي المنشورة للإعلان. تستدعى بعد أن تصير حالة النسخة APPROVED.
-- ترتيب الظهور يبدأ بأول نشر ولا يرتفع بتعديل المحتوى؛ last_published_at وstatus_changed_at
-- يتجددان عند الانتقال إلى النشر فقط (تعديل المنشور لا يجدد الظهور: AD-FR-030).
-- first_published_at من فارغ إلى قيمة يطلق إشعار المتابعين (مشغل listings_notify_first_publication).
create function private.publish_listing_version(p_listing uuid, p_version uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_listing public.listings;
  v_version public.listing_versions;
begin
  select * into v_listing from public.listings l where l.id = p_listing;
  select * into v_version from public.listing_versions v where v.id = p_version;

  update public.listings l set
    status = 'PUBLISHED',
    current_version_id = p_version,
    published_version_id = p_version,
    first_submitted_at = coalesce(l.first_submitted_at, v_version.submitted_at, now()),
    first_published_at = coalesce(l.first_published_at, now()),
    published_version_at = now(),
    last_published_at = case when v_listing.status = 'PUBLISHED' then l.last_published_at else now() end,
    visibility_updated_at = coalesce(l.visibility_updated_at, now()),
    status_changed_at = case when v_listing.status = 'PUBLISHED' then l.status_changed_at else now() end
  where l.id = p_listing;

  insert into public.reviews (listing_id, version_id, decision, reason_text, content_hash, moderator_id)
    values (p_listing, p_version, 'APPROVED', 'AUTO_PUBLISH', v_version.content_hash, v_listing.owner_id);
end;
$$;

------------------------------------------------------------------------------
-- submit_listing: ينشر مباشرة
------------------------------------------------------------------------------

create or replace function public.submit_listing(p_listing_id uuid, p_request_id uuid)
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

  -- المخفي إداريًا لا ينشره المعلن ولا يتجاوزه.
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

  -- الاكتمال، والمزاد بموعد مستقبلي، ورقم تواصل واحد على الأقل.
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
    status = 'APPROVED',
    settings_version = (select s.published_version from public.platform_settings s),
    content_hash = private.listing_content_hash(v_version),
    submit_request_id = p_request_id,
    submitted_at = now(),
    decided_at = now()
  where v.id = v_version.id;

  perform private.publish_listing_version(p_listing_id, v_version.id);

  return private.listing_owner_json(p_listing_id);
end;
$$;

comment on function public.submit_listing(uuid, uuid) is
  'إرسال المسودة وينشرها مباشرة (لا مراجعة). يعيد الإعلان بحالة PUBLISHED وإصدار النسخة APPROVED؛ تعديل المنشور يسري فورًا. إعادة الطلب بالمعرف نفسه لا تنشئ إرسالًا ثانيًا.';

------------------------------------------------------------------------------
-- تحويل ما كان قيد المراجعة
------------------------------------------------------------------------------

do $$
declare
  r record;
begin
  for r in
    select l.id, l.current_version_id, l.owner_id
    from public.listings l
    where l.status = 'UNDER_REVIEW'
    order by l.status_changed_at, l.id
    for update
  loop
    update public.listing_versions v set status = 'APPROVED', decided_at = now()
      where v.id = r.current_version_id and v.status = 'SUBMITTED';
    perform private.publish_listing_version(r.id, r.current_version_id);

    -- صاحب حساب معلق: لا يظهر إعلانه (التفعيل لا يعيد النشر)، ويسجل إخفاء.
    if (select p.status from public.profiles p where p.id = r.owner_id) <> 'ACTIVE' then
      update public.listings l set status = 'HIDDEN', status_changed_at = now() where l.id = r.id;
      insert into public.reviews (listing_id, version_id, decision, reason_code, reason_text, moderator_id)
        values (r.id, r.current_version_id, 'HIDDEN', 'OTHER',
                'تحويل تلقائي عند إلغاء المراجعة: حساب المعلن معلق', r.owner_id);
    end if;
  end loop;
end;
$$;

alter table public.listings
  add constraint listings_no_under_review check (status <> 'UNDER_REVIEW');

------------------------------------------------------------------------------
-- دوال الإدارة: الاعتماد والرفض مهملتان
------------------------------------------------------------------------------

create or replace function public.admin_approve_listing_version(
  p_listing_id uuid,
  p_version_id uuid,
  p_content_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_listing public.listings;
begin
  perform private.require_staff('listings.review');
  v_listing := private.lock_listing(p_listing_id);
  perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object(
    'status', v_listing.status, 'reason', 'review_removed'));
  return null;
end;
$$;

comment on function public.admin_approve_listing_version(uuid, uuid, text) is
  'مهملة (TEAM-DEC-013): لا مراجعة قبل النشر؛ ترفع INVALID_STATE دائمًا. تبقى لعدم كسر السطح.';

create or replace function public.admin_reject_listing_version(
  p_listing_id uuid,
  p_version_id uuid,
  p_content_hash text,
  p_reason_code text,
  p_reason_text text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_listing public.listings;
begin
  perform private.require_staff('listings.review');
  v_listing := private.lock_listing(p_listing_id);
  perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object(
    'status', v_listing.status, 'reason', 'review_removed'));
  return null;
end;
$$;

comment on function public.admin_reject_listing_version(uuid, uuid, text, text, text) is
  'مهملة (TEAM-DEC-013): لا رفض؛ ترفع INVALID_STATE دائمًا. الإخفاء وحده أداة التحكم.';

comment on function public.admin_review_queue(integer, timestamptz, uuid) is
  'مهملة (TEAM-DEC-013): تعيد مصفوفة فارغة دائمًا لأنه لا إعلان قيد المراجعة. استخدم admin_list_listings.';

------------------------------------------------------------------------------
-- إدارة الإعلانات: قائمة بحث وتصفية
------------------------------------------------------------------------------

-- كل الإعلانات لتحكم الإدارة بالظهور. الأحدث تغيّرًا أولًا؛ التصفح بالمفتاح.
--  p_status  DRAFT|PUBLISHED|HIDDEN|ARCHIVED|REJECTED (قديم) أو فارغ لكل الحالات
--  p_query   جزء من العنوان أو اسم المعلن، أو المعرف العام القصير، أو معرف الإعلان
--  p_after_changed_at/p_after_id  مفتاح آخر عنصر في الصفحة السابقة
create function public.admin_list_listings(
  p_status text default null,
  p_query text default null,
  p_limit integer default 50,
  p_after_changed_at timestamptz default null,
  p_after_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100);
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
  v_query text := nullif(pg_catalog.lower(btrim(coalesce(p_query, ''))), '');
begin
  if not public.has_staff_capability('listings.hide') then
    perform private.require_staff('listings.review');
  end if;

  if v_status is not null
    and v_status not in ('DRAFT', 'PUBLISHED', 'HIDDEN', 'ARCHIVED', 'REJECTED')
  then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('status')));
  end if;
  if char_length(v_query) > 100 then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('query')));
  end if;

  return (
    select coalesce(pg_catalog.jsonb_agg(q.item order by q.status_changed_at desc, q.id desc), '[]'::jsonb)
    from (
      select l.status_changed_at, l.id,
        pg_catalog.jsonb_build_object(
          'listing_id', l.id, 'public_ref', l.public_ref, 'status', l.status,
          'version_id', v.id, 'version_no', v.version_no,
          'published_version_id', l.published_version_id,
          'has_draft', exists (
            select 1 from public.listing_versions d where d.listing_id = l.id and d.status = 'DRAFT'),
          'title', v.title, 'offer_type', v.offer_type, 'price', v.price,
          'auction_starts_at', v.auction_starts_at,
          'region_id', v.region_id, 'city_id', v.city_id,
          'owner_id', l.owner_id, 'owner_display_name', p.display_name, 'owner_status', p.status,
          'first_published_at', l.first_published_at, 'last_published_at', l.last_published_at,
          'status_changed_at', l.status_changed_at, 'deleted_at', l.deleted_at,
          'created_at', l.created_at,
          -- آخر إخفاء: لعرض السبب بجانب المخفي.
          'hide_reason_code', hr.reason_code, 'hide_reason_text', hr.reason_text,
          'hidden_at', hr.created_at,
          'cover', (
            select pg_catalog.jsonb_build_object('bucket', m.bucket, 'object_path', m.object_path)
            from public.media m where m.version_id = v.id and m.is_cover)
        ) as item
      from public.listings l
      join public.profiles p on p.id = l.owner_id
      -- المنشور يعرض نسخته المنشورة؛ غيره آخر نسخة.
      left join public.listing_versions v
        on v.id = coalesce(case when l.status in ('PUBLISHED', 'HIDDEN') then l.published_version_id end,
                           l.current_version_id)
      left join lateral (
        select r.reason_code, r.reason_text, r.created_at
        from public.reviews r
        where r.listing_id = l.id and r.decision = 'HIDDEN' and l.status = 'HIDDEN'
        order by r.created_at desc, r.id desc limit 1
      ) hr on true
      where (v_status is null or l.status::text = v_status)
        and (
          v_query is null
          or pg_catalog.strpos(pg_catalog.lower(coalesce(v.title, '')), v_query) > 0
          or pg_catalog.strpos(pg_catalog.lower(coalesce(p.display_name, '')), v_query) > 0
          or l.public_ref = v_query
          or l.id::text = v_query
        )
        and (
          p_after_changed_at is null
          or (l.status_changed_at, l.id) < (p_after_changed_at, coalesce(p_after_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid))
        )
      order by l.status_changed_at desc, l.id desc
      limit v_limit
    ) q
  );
end;
$$;

comment on function public.admin_list_listings(text, text, integer, timestamptz, uuid) is
  'قائمة كل الإعلانات للتحكم بالظهور: تصفية بالحالة وبحث نصي، الأحدث تغيّرًا أولًا. القدرة: listings.hide أو listings.review.';

grant execute on function public.admin_list_listings(text, text, integer, timestamptz, uuid) to authenticated;
