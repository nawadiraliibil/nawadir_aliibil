-- 15 favorites_share — MOBILE-BE-202
-- المفضلة وتفاصيل الإعلان وملف المعلن العام: AD-FR-013، AD-FR-022، AD-FR-023،
-- AD-FR-024، AD-AC-013، AD-AC-014. الكتابة عبر دوال فقط.

create table public.favorites (
  user_id uuid not null references public.profiles (id) on delete cascade,
  listing_id uuid not null references public.listings (id) on delete cascade,
  created_at timestamptz not null default now(),
  -- حفظ واحد لكل مستخدم وإعلان.
  primary key (user_id, listing_id)
);

create index favorites_user_created_idx on public.favorites (user_id, created_at desc, listing_id);

alter table public.favorites enable row level security;

-- المستخدم يقرأ قائمته فقط؛ لا يطلع عليها غيره.
create policy favorites_read_own on public.favorites
  for select to authenticated using ((select auth.uid()) = user_id);

grant select on public.favorites to authenticated;

-- إضافة إلى المفضلة. يلزم إعلان منشور؛ غيره NOT_FOUND دون كشف السبب.
-- التكرار آمن: لا يغير تاريخ الحفظ الأول.
create function public.add_favorite(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_active_user();
  v_saved_at timestamptz;
begin
  if not exists (
    select 1 from public.listings l
    where l.id = p_listing_id and l.status = 'PUBLISHED' and l.deleted_at is null) then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'listing'));
  end if;

  insert into public.favorites (user_id, listing_id) values (v_uid, p_listing_id)
    on conflict (user_id, listing_id) do nothing;
  select f.created_at into v_saved_at from public.favorites f
    where f.user_id = v_uid and f.listing_id = p_listing_id;

  return pg_catalog.jsonb_build_object('listing_id', p_listing_id, 'saved_at', v_saved_at);
end;
$$;

comment on function public.add_favorite(uuid) is
  'يحفظ إعلانًا منشورًا في مفضلة صاحب الجلسة. التكرار آمن.';

-- إزالة من المفضلة، وتعمل على إعلان لم يعد منشورًا (يزيله المستخدم من قائمته).
-- الإزالة المتكررة تعيد removed=false.
create function public.remove_favorite(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_count integer;
begin
  delete from public.favorites f where f.user_id = v_uid and f.listing_id = p_listing_id;
  get diagnostics v_count = row_count;
  return pg_catalog.jsonb_build_object('listing_id', p_listing_id, 'removed', v_count > 0);
end;
$$;

comment on function public.remove_favorite(uuid) is
  'يزيل إعلانًا من مفضلة صاحب الجلسة. الإزالة المتكررة آمنة.';

-- المفضلة بالأحدث حفظًا. الإعلان الذي لم يعد منشورًا يبقى صفًا «غير متاح»
-- (available=false) وكل أعمدة البطاقة فارغة: لا محتوى ولا وسائط ولا سبب (AD-FR-022).
create view public.my_favorites
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
  c.public_ref
from public.favorites f
left join public.public_listing_cards c on c.listing_id = f.listing_id
where f.user_id = (select auth.uid());

comment on view public.my_favorites is
  'مفضلة صاحب الجلسة؛ غير المنشور يظهر available=false دون محتوى.';

grant select on public.my_favorites to authenticated;

-- تفاصيل الإعلان في طلب واحد: الرأس والوسائط وحالة المفضلة لصاحب الجلسة.
-- إعلان غير منشور (مسودة أو مخفي أو مؤرشف أو محذوف أو غير موجود) NOT_FOUND
-- بالرد نفسه، فلا يعرف الزائر أيها هو (AD-FR-011).
create function public.get_listing(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_listing jsonb;
begin
  select pg_catalog.to_jsonb(d) into v_listing
  from public.public_listing_details d where d.listing_id = p_listing_id;
  if v_listing is null then
    perform private.raise_error('NOT_FOUND', pg_catalog.jsonb_build_object('resource', 'listing'));
  end if;

  return pg_catalog.jsonb_build_object(
    'listing', v_listing,
    'media', coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(m) - 'listing_id' order by m.sort_order, m.media_id)
      from public.public_listing_media m where m.listing_id = p_listing_id), '[]'::jsonb),
    'is_favorite', v_uid is not null and exists (
      select 1 from public.favorites f where f.user_id = v_uid and f.listing_id = p_listing_id)
  );
end;
$$;

comment on function public.get_listing(uuid) is
  'تفاصيل إعلان منشور ووسائطه وحالة المفضلة؛ غير المنشور NOT_FOUND.';

grant execute on function public.add_favorite(uuid) to authenticated;
grant execute on function public.remove_favorite(uuid) to authenticated;
grant execute on function public.get_listing(uuid) to anon, authenticated;
