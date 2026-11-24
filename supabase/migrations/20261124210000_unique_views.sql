-- MOBILE-BE-VIEWS-UNIQUE-20261124 — مشاهدة واحدة لكل شخص، وعدّادات «إعلاناتي».
--
-- record_listing_view(p_listing_id, p_device_id): تحسب المشاهدة مرة واحدة لكل مشاهد؛ المشاهد هو حساب
-- المستخدم إن كان داخلًا، وإلا معرف الجهاز الذي يولده التطبيق (uuid). بلا حساب ولا معرف جهاز لا تحسب.
-- my_listings يضيف في آخره view_count وfavorite_count.

create table public.listing_view_log (
  listing_id uuid not null references public.listings (id) on delete cascade,
  viewer text not null check (char_length(viewer) <= 64),
  primary key (listing_id, viewer)
);
alter table public.listing_view_log enable row level security;

drop function public.record_listing_view(uuid);

create function public.record_listing_view(p_listing_id uuid, p_device_id uuid default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
  v_uid uuid := auth.uid();
  v_viewer text;
  v_count integer;
  v_new integer;
begin
  select l.owner_id into v_owner from public.listings l
    where l.id = p_listing_id and l.status = 'PUBLISHED' and l.deleted_at is null;
  if v_owner is null then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'listing'));
  end if;

  v_viewer := case
    when v_uid is not null then 'u:' || v_uid::text
    when p_device_id is not null then 'd:' || p_device_id::text
  end;

  if v_viewer is not null and v_owner is distinct from v_uid then
    insert into public.listing_view_log (listing_id, viewer) values (p_listing_id, v_viewer)
      on conflict do nothing;
    get diagnostics v_new = row_count;
    if v_new > 0 then
      insert into public.listing_stats (listing_id, view_count) values (p_listing_id, 1)
        on conflict (listing_id) do update set view_count = public.listing_stats.view_count + 1;
    end if;
  end if;

  select s.view_count into v_count from public.listing_stats s where s.listing_id = p_listing_id;
  return coalesce(v_count, 0);
end;
$$;

comment on function public.record_listing_view(uuid, uuid) is
  'يسجل مشاهدة إعلان منشور مرة واحدة لكل مشاهد (حساب أو معرف جهاز) ويعيد العدد؛ مشاهدة المعلن لإعلانه لا تحسب.';

revoke all on function public.record_listing_view(uuid, uuid) from public;
grant execute on function public.record_listing_view(uuid, uuid) to anon, authenticated;

create or replace view public.my_listings
with (security_barrier = true) as
select
  l.id as listing_id,
  l.status,
  l.current_version_id,
  l.published_version_id,
  exists (
    select 1 from public.listing_versions d
    where d.listing_id = l.id and d.status = 'DRAFT') as has_draft,
  v.version_no,
  v.status as version_status,
  v.title,
  v.offer_type,
  v.price,
  v.auction_starts_at,
  (v.offer_type = 'IN_PERSON_AUCTION' and v.auction_starts_at <= now()) as auction_passed,
  cover.bucket as cover_bucket,
  cover.object_path as cover_path,
  decision.reason_code,
  decision.reason_label_ar,
  decision.reason_text,
  decision.decided_at as reason_decided_at,
  l.first_submitted_at,
  l.first_published_at,
  l.last_published_at,
  l.last_bumped_at,
  case when l.status = 'PUBLISHED' then
    greatest(l.last_published_at, coalesce(l.last_bumped_at, l.last_published_at))
    + make_interval(hours => (
        select (sv.content #>> '{bump,interval_hours}')::integer
        from public.platform_settings ps
        join public.settings_versions sv on sv.version = ps.published_version))
  end as next_bump_at,
  l.status_changed_at,
  l.created_at,
  l.updated_at,
  coalesce(st.view_count, 0) as view_count,
  coalesce(st.favorite_count, 0) as favorite_count
from public.listings l
left join public.listing_stats st on st.listing_id = l.id
left join public.listing_versions v on v.id = l.current_version_id
left join public.media cover on cover.version_id = v.id and cover.is_cover
left join lateral (
  select r.reason_code, mr.label_ar as reason_label_ar, r.reason_text, r.created_at as decided_at
  from public.reviews r
  left join public.moderation_reasons mr on mr.code = r.reason_code
  where r.listing_id = l.id
    and (
      (l.status = 'REJECTED' and r.decision = 'REJECTED')
      or (l.status = 'HIDDEN' and r.decision = 'HIDDEN')
    )
  order by r.created_at desc, r.id desc
  limit 1
) decision on true
where l.owner_id = (select auth.uid()) and l.deleted_at is null;
