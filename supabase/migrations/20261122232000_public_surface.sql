-- 12 public_surface — MOBILE-BE-109
-- القراءة العامة و«إعلاناتي»: AD-FR-010، AD-FR-011، AD-FR-024، AD-NFR-002،
-- SRS القسمان 6 و7.
-- الجداول مغلقة أمام الزائر. هذه الـviews تملكها قاعدة البيانات وتعرض أعمدة
-- محددة من النسخة المعتمدة لإعلان منشور فقط؛ الإعلان غير المنشور لا يعيد صفًا،
-- فيعرض العميل «الإعلان غير متاح» دون سبب. لا هاتف دخول في أي view.
-- أعمدة كل view مثبتة باختبار، وهي جزء من العقد (contracts/api/read-surface.md).

-- الملف العام للمعلن (AD-FR-024).
create view public.public_profiles
with (security_barrier = true) as
select
  p.id,
  p.display_name,
  p.region_id,
  r.name_ar as region_name_ar,
  p.created_at as joined_at,
  (
    select count(*)::integer from public.listings l
    where l.owner_id = p.id and l.status = 'PUBLISHED' and l.deleted_at is null
  ) as published_listings_count
from public.profiles p
left join public.regions r on r.id = p.region_id
where p.display_name is not null;

comment on view public.public_profiles is
  'إسقاط عام آمن للملف الشخصي: اسم العرض والمنطقة وتاريخ الانضمام وعدد المنشور.';

-- بطاقة الإعلان في القوائم (AD-FR-011).
create view public.public_listing_cards
with (security_barrier = true) as
select
  l.id as listing_id,
  l.owner_id,
  p.display_name as owner_display_name,
  v.title,
  v.offer_type,
  v.price,
  v.auction_starts_at,
  -- بعد الموعد تعرض «مضى موعد المزاد» ويستبعد من النتائج الافتراضية.
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
  -- مفتاح الترتيب الافتراضي: أول نشر أو آخر تجديد ظهور، مع listing_id لفك التعادل.
  l.visibility_updated_at
from public.listings l
join public.listing_versions v on v.id = l.published_version_id
join public.profiles p on p.id = l.owner_id
join public.breeds b on b.id = v.breed_id
join public.regions rg on rg.id = v.region_id
join public.cities c on c.id = v.city_id
left join public.media cover on cover.version_id = v.id and cover.is_cover and cover.status = 'READY'
where l.status = 'PUBLISHED' and l.deleted_at is null;

comment on view public.public_listing_cards is
  'بطاقات الإعلانات المنشورة من نسختها المعتمدة.';

-- تفاصيل الإعلان المنشور.
create view public.public_listing_details
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
  -- رقم التواصل الذي نشره المعلن لهذا الإعلان، وقنواته المفعلة (AD-FR-014).
  v.contact_phone,
  v.contact_call_enabled,
  v.contact_whatsapp_enabled,
  l.first_published_at,
  l.published_version_at,
  l.visibility_updated_at
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
  'تفاصيل الإعلان المنشور من نسخته المعتمدة، ومنها رقم التواصل المنشور.';

-- وسائط الإعلان المنشور. الملف نفسه يقرأ من التخزين بسياسة تتحقق من النشر.
create view public.public_listing_media
with (security_barrier = true) as
select
  l.id as listing_id,
  m.id as media_id,
  m.kind,
  m.bucket,
  m.object_path,
  m.mime_type,
  m.width,
  m.height,
  m.duration_seconds,
  m.sort_order,
  m.is_cover
from public.listings l
join public.media m on m.version_id = l.published_version_id
where l.status = 'PUBLISHED' and l.deleted_at is null and m.status = 'READY';

comment on view public.public_listing_media is
  'الوسائط الجاهزة للنسخة المعتمدة لإعلان منشور.';

-- «إعلاناتي»: إعلانات صاحب الجلسة بكل حالاتها من نسختها الحالية (AD-FR-010).
-- سبب الرفض أو الإخفاء: آخر قرار من نوعه، بتسمية السبب ونصه (TEAM-DEC-011 البند 3).
create view public.my_listings
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
  l.updated_at
from public.listings l
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

comment on view public.my_listings is
  'إعلانات صاحب الجلسة بحالاتها، مع سبب الرفض أو الإخفاء وموعد التجديد التالي.';

grant select on public.public_profiles, public.public_listing_cards,
  public.public_listing_details, public.public_listing_media to anon, authenticated;
grant select on public.my_listings to authenticated;
