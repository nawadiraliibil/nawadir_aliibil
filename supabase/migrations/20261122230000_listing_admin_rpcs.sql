-- 10 listing_admin_rpcs — MOBILE-BE-107
-- دوال الإدارة للإعلانات والحسابات: AD-FR-008، AD-FR-009، AD-FR-017، AD-FR-018،
-- TEAM-DEC-011، ADMIN-HANDOFF-20261122.md القسمان 4 و5.
-- كل دالة تفحص الدور والقدرة ومستوى aal2 وتكتب سجل الإجراءات.
-- انتقالات الحالة من جهة الإدارة:
--   اعتماد        UNDER_REVIEW -> PUBLISHED
--   رفض           UNDER_REVIEW -> REJECTED
--   إخفاء         PUBLISHED -> HIDDEN
--   إعادة إظهار   HIDDEN -> PUBLISHED
--   تعليق حساب    يخفي إعلاناته المنشورة؛ التفعيل لا يعيد نشرها.

------------------------------------------------------------------------------
-- مساعدات داخلية
------------------------------------------------------------------------------

-- يتحقق من سبب الإشراف للإجراء المذكور ويعيد النص الحر بعد تنظيفه.
create function private.require_moderation_reason(p_action text, p_code text, p_text text)
returns text
language plpgsql
set search_path = ''
as $$
declare
  v_reason public.moderation_reasons;
  v_text text := nullif(btrim(coalesce(p_text, '')), '');
begin
  if p_code is null or btrim(p_code) = '' then
    perform private.raise_error('REASON_REQUIRED', pg_catalog.jsonb_build_object('field', 'reason_code'));
  end if;

  select * into v_reason from public.moderation_reasons r where r.code = p_code;
  if not found or not v_reason.is_active or not (p_action = any (v_reason.applies_to)) then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('reason_code')));
  end if;

  -- النص إلزامي عند «أخرى» (TEAM-DEC-011 البند 3).
  if v_reason.requires_note and v_text is null then
    perform private.raise_error('REASON_REQUIRED', pg_catalog.jsonb_build_object('field', 'reason_text'));
  end if;
  if char_length(v_text) > 1000 then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('reason_text')));
  end if;

  return v_text;
end;
$$;

-- يقفل الإعلان للإدارة. المحذوف منطقيًا يبقى مرئيًا للإدارة.
create function private.lock_listing(p_listing uuid)
returns public.listings
language plpgsql
set search_path = ''
as $$
declare
  v_listing public.listings;
begin
  select * into v_listing from public.listings l where l.id = p_listing for update;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'listing'));
  end if;
  return v_listing;
end;
$$;

-- النسخة قيد المراجعة مطابقة لما رآه المراجع؛ وإلا VERSION_CHANGED.
create function private.require_reviewed_version(
  p_listing public.listings, p_version_id uuid, p_content_hash text
)
returns public.listing_versions
language plpgsql
set search_path = ''
as $$
declare
  v_version public.listing_versions;
begin
  if p_listing.status <> 'UNDER_REVIEW' then
    perform private.raise_error(
      'INVALID_STATE', pg_catalog.jsonb_build_object('status', p_listing.status));
  end if;

  select * into v_version from public.listing_versions v
    where v.id = p_listing.current_version_id and v.status = 'SUBMITTED';
  if not found
    or v_version.id is distinct from p_version_id
    or v_version.content_hash is distinct from p_content_hash
  then
    perform private.raise_error('VERSION_CHANGED', pg_catalog.jsonb_build_object(
      'current_version_id', p_listing.current_version_id));
  end if;
  return v_version;
end;
$$;

create function private.listing_admin_json(p_listing uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'id', l.id, 'owner_id', l.owner_id, 'status', l.status,
    'current_version_id', l.current_version_id,
    'published_version_id', l.published_version_id,
    'first_submitted_at', l.first_submitted_at,
    'first_published_at', l.first_published_at,
    'published_version_at', l.published_version_at,
    'last_published_at', l.last_published_at,
    'last_bumped_at', l.last_bumped_at,
    'visibility_updated_at', l.visibility_updated_at,
    'status_changed_at', l.status_changed_at,
    'deleted_at', l.deleted_at, 'created_at', l.created_at)
  from public.listings l where l.id = p_listing
$$;

create function private.version_media_json(p_version uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'id', m.id, 'kind', m.kind, 'status', m.status, 'bucket', m.bucket,
      'object_path', m.object_path, 'mime_type', m.mime_type, 'size_bytes', m.size_bytes,
      'width', m.width, 'height', m.height, 'duration_seconds', m.duration_seconds,
      'sort_order', m.sort_order, 'is_cover', m.is_cover)
    order by m.sort_order, m.created_at, m.id), '[]'::jsonb)
  from public.media m where m.version_id = p_version
$$;

------------------------------------------------------------------------------
-- المراجعة
------------------------------------------------------------------------------

-- قائمة الإعلانات المنتظرة، الأقدم أولًا. التصفح بالمفتاح (p_after_*).
create function public.admin_review_queue(
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
begin
  perform private.require_staff('listings.review');

  return (
    select coalesce(pg_catalog.jsonb_agg(q.item order by q.status_changed_at, q.id), '[]'::jsonb)
    from (
      select l.status_changed_at, l.id,
        pg_catalog.jsonb_build_object(
          'listing_id', l.id, 'version_id', v.id, 'version_no', v.version_no,
          'content_hash', v.content_hash, 'submitted_at', v.submitted_at,
          'status_changed_at', l.status_changed_at,
          -- تعديل لإعلان سبق نشره، لا إعلان جديد.
          'is_edit', l.published_version_id is not null,
          'title', v.title, 'offer_type', v.offer_type, 'price', v.price,
          'auction_starts_at', v.auction_starts_at,
          'region_id', v.region_id, 'city_id', v.city_id,
          'owner_id', l.owner_id, 'owner_display_name', p.display_name,
          'cover', (
            select pg_catalog.jsonb_build_object('bucket', m.bucket, 'object_path', m.object_path)
            from public.media m where m.version_id = v.id and m.is_cover)
        ) as item
      from public.listings l
      join public.listing_versions v on v.id = l.current_version_id
      join public.profiles p on p.id = l.owner_id
      where l.status = 'UNDER_REVIEW' and l.deleted_at is null
        and (
          p_after_changed_at is null
          or (l.status_changed_at, l.id) > (p_after_changed_at, coalesce(p_after_id, '00000000-0000-0000-0000-000000000000'::uuid))
        )
      order by l.status_changed_at, l.id
      limit v_limit
    ) q
  );
end;
$$;

comment on function public.admin_review_queue(integer, timestamptz, uuid) is
  'قائمة الإعلانات قيد المراجعة، الأقدم أولًا. القدرة: listings.review.';

-- تفاصيل إعلان للمراجعة أو الإشراف: النسخة الحالية ووسائطها، والمنشورة إن اختلفت،
-- والمعلن، وسجل القرارات.
create function public.admin_get_listing_review(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_listing public.listings;
begin
  if not public.has_staff_capability('listings.hide') then
    perform private.require_staff('listings.review');
  end if;

  select * into v_listing from public.listings l where l.id = p_listing_id;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'listing'));
  end if;

  return pg_catalog.jsonb_build_object(
    'listing', private.listing_admin_json(p_listing_id),
    'version', (
      select pg_catalog.to_jsonb(v) - 'submit_request_id'
      from public.listing_versions v where v.id = v_listing.current_version_id),
    'media', private.version_media_json(v_listing.current_version_id),
    'published_version', case
      when v_listing.published_version_id is not null
        and v_listing.published_version_id is distinct from v_listing.current_version_id
      then (
        select pg_catalog.to_jsonb(v) - 'submit_request_id'
        from public.listing_versions v where v.id = v_listing.published_version_id)
    end,
    'published_media', case
      when v_listing.published_version_id is not null
        and v_listing.published_version_id is distinct from v_listing.current_version_id
      then private.version_media_json(v_listing.published_version_id)
    end,
    'owner', (
      select pg_catalog.jsonb_build_object(
        'id', p.id, 'display_name', p.display_name, 'region_id', p.region_id,
        'status', p.status, 'created_at', p.created_at)
      from public.profiles p where p.id = v_listing.owner_id),
    'reviews', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', r.id, 'version_id', r.version_id, 'decision', r.decision,
          'reason_code', r.reason_code, 'reason_text', r.reason_text,
          'moderator_id', r.moderator_id, 'created_at', r.created_at)
        order by r.created_at desc, r.id desc)
      from public.reviews r where r.listing_id = p_listing_id), '[]'::jsonb)
  );
end;
$$;

comment on function public.admin_get_listing_review(uuid) is
  'تفاصيل إعلان للمراجعة مع بصمة النسخة. القدرة: listings.review أو listings.hide.';

create function public.admin_approve_listing_version(
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
  v_actor uuid := private.require_staff('listings.review');
  v_listing public.listings;
  v_version public.listing_versions;
begin
  v_listing := private.lock_listing(p_listing_id);
  v_version := private.require_reviewed_version(v_listing, p_version_id, p_content_hash);

  if v_listing.deleted_at is not null then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('reason', 'deleted'));
  end if;
  if (select p.status from public.profiles p where p.id = v_listing.owner_id) <> 'ACTIVE' then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('reason', 'owner_suspended'));
  end if;
  -- موعد مستقبلي عند الاعتماد أيضًا (AD-FR-025).
  if v_version.offer_type = 'IN_PERSON_AUCTION' and v_version.auction_starts_at <= now() then
    perform private.raise_error('AUCTION_TIME_PASSED');
  end if;

  update public.listing_versions v set status = 'APPROVED', decided_at = now()
    where v.id = v_version.id;

  -- ترتيب الظهور يبدأ بأول نشر ولا يرتفع بإعادة النشر أو تعديل المحتوى؛
  -- last_published_at يتجدد مع كل انتقال للنشر لضبط أهلية التجديد (SRS القسم 6).
  update public.listings l set
    status = 'PUBLISHED',
    published_version_id = v_version.id,
    first_published_at = coalesce(l.first_published_at, now()),
    published_version_at = now(),
    last_published_at = now(),
    visibility_updated_at = coalesce(l.visibility_updated_at, now()),
    status_changed_at = now()
  where l.id = p_listing_id;

  insert into public.reviews (listing_id, version_id, decision, content_hash, moderator_id)
    values (p_listing_id, v_version.id, 'APPROVED', v_version.content_hash, v_actor);
  perform private.audit(
    v_actor, 'listing.approved', 'listing', p_listing_id::text,
    pg_catalog.jsonb_build_object(
      'version_id', v_version.id, 'version_no', v_version.version_no,
      'first_publish', v_listing.first_published_at is null));

  return private.listing_admin_json(p_listing_id);
end;
$$;

comment on function public.admin_approve_listing_version(uuid, uuid, text) is
  'اعتماد النسخة قيد المراجعة ونشر الإعلان. القدرة: listings.review.';

create function public.admin_reject_listing_version(
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
  v_actor uuid := private.require_staff('listings.review');
  v_listing public.listings;
  v_version public.listing_versions;
  v_text text := private.require_moderation_reason('LISTING_REJECT', p_reason_code, p_reason_text);
begin
  v_listing := private.lock_listing(p_listing_id);
  v_version := private.require_reviewed_version(v_listing, p_version_id, p_content_hash);

  update public.listing_versions v set status = 'REJECTED', decided_at = now()
    where v.id = v_version.id;
  -- رفض تعديل منشور يتركه مرفوضًا دون استعادة النسخة السابقة (TEAM-DEC-011 البند 1).
  update public.listings l set status = 'REJECTED', status_changed_at = now()
    where l.id = p_listing_id;

  insert into public.reviews
    (listing_id, version_id, decision, reason_code, reason_text, content_hash, moderator_id)
    values (p_listing_id, v_version.id, 'REJECTED', p_reason_code, v_text, v_version.content_hash, v_actor);
  perform private.audit(
    v_actor, 'listing.rejected', 'listing', p_listing_id::text,
    pg_catalog.jsonb_build_object('version_id', v_version.id, 'version_no', v_version.version_no),
    p_reason_code, v_text);

  return private.listing_admin_json(p_listing_id);
end;
$$;

comment on function public.admin_reject_listing_version(uuid, uuid, text, text, text) is
  'رفض النسخة قيد المراجعة بسبب إلزامي. القدرة: listings.review.';

------------------------------------------------------------------------------
-- الإخفاء وإعادة الإظهار
------------------------------------------------------------------------------

create function public.admin_hide_listing(
  p_listing_id uuid,
  p_reason_code text,
  p_reason_text text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('listings.hide');
  v_listing public.listings;
  v_text text := private.require_moderation_reason('LISTING_HIDE', p_reason_code, p_reason_text);
begin
  v_listing := private.lock_listing(p_listing_id);
  if v_listing.status <> 'PUBLISHED' then
    perform private.raise_error(
      'INVALID_STATE', pg_catalog.jsonb_build_object('status', v_listing.status));
  end if;

  update public.listings l set status = 'HIDDEN', status_changed_at = now()
    where l.id = p_listing_id;

  insert into public.reviews (listing_id, version_id, decision, reason_code, reason_text, moderator_id)
    values (p_listing_id, v_listing.published_version_id, 'HIDDEN', p_reason_code, v_text, v_actor);
  perform private.audit(
    v_actor, 'listing.hidden', 'listing', p_listing_id::text,
    pg_catalog.jsonb_build_object('version_id', v_listing.published_version_id),
    p_reason_code, v_text);

  return private.listing_admin_json(p_listing_id);
end;
$$;

comment on function public.admin_hide_listing(uuid, text, text) is
  'إخفاء إعلان منشور بسبب إلزامي. يسري على القراءة والوسائط من الطلب التالي. القدرة: listings.hide.';

create function public.admin_unhide_listing(p_listing_id uuid, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('listings.hide');
  v_listing public.listings;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  v_listing := private.lock_listing(p_listing_id);
  if v_listing.status <> 'HIDDEN' then
    perform private.raise_error(
      'INVALID_STATE', pg_catalog.jsonb_build_object('status', v_listing.status));
  end if;
  if v_listing.deleted_at is not null then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('reason', 'deleted'));
  end if;
  if (select p.status from public.profiles p where p.id = v_listing.owner_id) <> 'ACTIVE' then
    perform private.raise_error('INVALID_STATE', pg_catalog.jsonb_build_object('reason', 'owner_suspended'));
  end if;
  if char_length(v_note) > 1000 then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('note')));
  end if;

  -- العودة للنشر تجدد مرجع أهلية التجديد، فلا يتجاوز الإخفاء وإعادة النشر المهلة.
  update public.listings l set
    status = 'PUBLISHED', last_published_at = now(), status_changed_at = now()
  where l.id = p_listing_id;

  insert into public.reviews (listing_id, version_id, decision, reason_text, moderator_id)
    values (p_listing_id, v_listing.published_version_id, 'UNHIDDEN', v_note, v_actor);
  perform private.audit(
    v_actor, 'listing.unhidden', 'listing', p_listing_id::text,
    pg_catalog.jsonb_build_object('version_id', v_listing.published_version_id), null, v_note);

  return private.listing_admin_json(p_listing_id);
end;
$$;

comment on function public.admin_unhide_listing(uuid, text) is
  'إعادة إظهار إعلان مخفي بقرار إداري. القدرة: listings.hide.';

------------------------------------------------------------------------------
-- الحسابات
------------------------------------------------------------------------------

create function private.account_admin_json(p_user uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'id', p.id, 'display_name', p.display_name, 'region_id', p.region_id,
    'status', p.status, 'status_changed_at', p.status_changed_at,
    'suspension_reason_code', p.suspension_reason_code,
    'suspension_reason_text', p.suspension_reason_text,
    'created_at', p.created_at,
    'phone', (select u.phone from auth.users u where u.id = p.id),
    'listing_counts', coalesce((
      select pg_catalog.jsonb_object_agg(c.status, c.n)
      from (
        select l.status, count(*) as n from public.listings l
        where l.owner_id = p.id and l.deleted_at is null group by l.status) c
    ), '{}'::jsonb)
  )
  from public.profiles p where p.id = p_user
$$;

create function public.admin_get_account(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_account jsonb;
begin
  perform private.require_staff('accounts.manage');
  v_account := private.account_admin_json(p_user_id);
  if v_account is null then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'account'));
  end if;
  return v_account;
end;
$$;

comment on function public.admin_get_account(uuid) is
  'تفاصيل حساب مستخدم مع هاتف الدخول وعدد إعلاناته بحسب الحالة. القدرة: accounts.manage.';

create function public.admin_suspend_account(
  p_user_id uuid,
  p_reason_code text,
  p_reason_text text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('accounts.manage');
  v_profile public.profiles;
  v_text text := private.require_moderation_reason('ACCOUNT_SUSPEND', p_reason_code, p_reason_text);
  v_hidden uuid[];
begin
  select * into v_profile from public.profiles p where p.id = p_user_id for update;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'account'));
  end if;
  if v_profile.status <> 'ACTIVE' then
    perform private.raise_error(
      'INVALID_STATE', pg_catalog.jsonb_build_object('status', v_profile.status));
  end if;

  update public.profiles p set
    status = 'SUSPENDED', status_changed_at = now(),
    suspension_reason_code = p_reason_code, suspension_reason_text = v_text
  where p.id = p_user_id;

  -- التعليق يخفي إعلاناته المنشورة (SRS القسم 2).
  with hidden as (
    update public.listings l set status = 'HIDDEN', status_changed_at = now()
      where l.owner_id = p_user_id and l.status = 'PUBLISHED'
      returning l.id, l.published_version_id
  ), logged as (
    insert into public.reviews (listing_id, version_id, decision, reason_code, reason_text, moderator_id)
      select h.id, h.published_version_id, 'HIDDEN', p_reason_code, v_text, v_actor from hidden h
      returning listing_id
  )
  select coalesce(pg_catalog.array_agg(listing_id), array[]::uuid[]) into v_hidden from logged;

  perform private.audit(
    v_actor, 'account.suspended', 'account', p_user_id::text,
    pg_catalog.jsonb_build_object('hidden_listing_ids', pg_catalog.to_jsonb(v_hidden)),
    p_reason_code, v_text);

  return private.account_admin_json(p_user_id);
end;
$$;

comment on function public.admin_suspend_account(uuid, text, text) is
  'تعليق حساب بسبب إلزامي وإخفاء إعلاناته المنشورة. القدرة: accounts.manage.';

create function public.admin_reactivate_account(p_user_id uuid, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('accounts.manage');
  v_profile public.profiles;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  select * into v_profile from public.profiles p where p.id = p_user_id for update;
  if not found then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'account'));
  end if;
  if v_profile.status <> 'SUSPENDED' then
    perform private.raise_error(
      'INVALID_STATE', pg_catalog.jsonb_build_object('status', v_profile.status));
  end if;
  if char_length(v_note) > 1000 then
    perform private.raise_error(
      'VALIDATION_FAILED', pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('note')));
  end if;

  -- التفعيل لا يعيد نشر الإعلانات؛ كل إعلان يعاد إظهاره بقرار منفصل.
  update public.profiles p set
    status = 'ACTIVE', status_changed_at = now(),
    suspension_reason_code = null, suspension_reason_text = null
  where p.id = p_user_id;

  perform private.audit(
    v_actor, 'account.reactivated', 'account', p_user_id::text,
    pg_catalog.jsonb_build_object(
      'previous_reason_code', v_profile.suspension_reason_code), null, v_note);

  return private.account_admin_json(p_user_id);
end;
$$;

comment on function public.admin_reactivate_account(uuid, text) is
  'إعادة تفعيل حساب معلق دون إعادة نشر إعلاناته. القدرة: accounts.manage.';

------------------------------------------------------------------------------
-- الصلاحيات
------------------------------------------------------------------------------

grant execute on function public.admin_review_queue(integer, timestamptz, uuid) to authenticated;
grant execute on function public.admin_get_listing_review(uuid) to authenticated;
grant execute on function public.admin_approve_listing_version(uuid, uuid, text) to authenticated;
grant execute on function public.admin_reject_listing_version(uuid, uuid, text, text, text) to authenticated;
grant execute on function public.admin_hide_listing(uuid, text, text) to authenticated;
grant execute on function public.admin_unhide_listing(uuid, text) to authenticated;
grant execute on function public.admin_get_account(uuid) to authenticated;
grant execute on function public.admin_suspend_account(uuid, text, text) to authenticated;
grant execute on function public.admin_reactivate_account(uuid, text) to authenticated;
