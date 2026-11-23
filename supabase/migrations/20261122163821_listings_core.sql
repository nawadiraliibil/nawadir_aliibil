-- 07 listings_core — MOBILE-BE-105
-- جداول الإعلانات: AD-FR-005 إلى AD-FR-010، AD-FR-014، AD-FR-025، AD-FR-030،
-- SRS الأقسام 5 و6 و7. دون خرائط أو إحداثيات (TEAM-DEC-009).
-- الكتابة عبر دوال في ترحيلات لاحقة؛ هنا الجداول والقيود والقراءة فقط.
-- الحدود القابلة للإدارة (أطوال النصوص وعدد الصور) تتحقق منها الدوال من الإعدادات
-- المنشورة؛ قيود الجداول سقوف تقنية ثابتة وقواعد لا تتغير.

create type public.review_decision as enum (
  'APPROVED',
  'REJECTED',
  'HIDDEN',
  'UNHIDDEN'
);

-- أسباب الإشراف — TEAM-DEC-011 البند 3. لا حذف لقيمة؛ تعطيل فقط.
create table public.moderation_reasons (
  code text primary key check (code ~ '^[A-Z][A-Z0-9_]{1,39}$'),
  label_ar text not null check (char_length(btrim(label_ar)) between 1 and 120),
  -- الإجراءات التي ينطبق عليها السبب.
  applies_to text[] not null
    check (
      cardinality(applies_to) > 0
      and applies_to <@ array['LISTING_REJECT', 'LISTING_HIDE', 'ACCOUNT_SUSPEND']::text[]
    ),
  -- «أخرى»: النص الحر إلزامي معها.
  requires_note boolean not null default false,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger moderation_reasons_set_updated_at before update on public.moderation_reasons
  for each row execute function private.set_updated_at();

-- قائمة بدء تديرها الإدارة لاحقًا.
insert into public.moderation_reasons (code, label_ar, applies_to, requires_note, sort_order) values
  ('MISSING_INFO', 'بيانات ناقصة أو غير واضحة', array['LISTING_REJECT'], false, 10),
  ('BAD_MEDIA', 'صور غير واضحة أو لا تخص المعروض', array['LISTING_REJECT', 'LISTING_HIDE'], false, 20),
  ('OUT_OF_SCOPE', 'المعروض خارج نطاق المنصة', array['LISTING_REJECT', 'LISTING_HIDE'], false, 30),
  ('MISLEADING', 'معلومات مضللة أو غير صحيحة', array['LISTING_REJECT', 'LISTING_HIDE', 'ACCOUNT_SUSPEND'], false, 40),
  ('DUPLICATE', 'إعلان مكرر', array['LISTING_REJECT', 'LISTING_HIDE'], false, 50),
  ('INVALID_CONTACT', 'بيانات تواصل غير صحيحة', array['LISTING_REJECT', 'LISTING_HIDE'], false, 60),
  ('PROHIBITED_CONTENT', 'محتوى مخالف لشروط الاستخدام', array['LISTING_REJECT', 'LISTING_HIDE', 'ACCOUNT_SUSPEND'], false, 70),
  ('FRAUD', 'اشتباه احتيال أو إساءة استخدام', array['LISTING_HIDE', 'ACCOUNT_SUSPEND'], false, 80),
  ('ABUSE', 'إساءة إلى مستخدمين آخرين', array['ACCOUNT_SUSPEND'], false, 90),
  ('OTHER', 'أخرى', array['LISTING_REJECT', 'LISTING_HIDE', 'ACCOUNT_SUSPEND'], true, 1000);

-- سبب تعليق الحساب (SRS القسم 2: يحفظ سبب الإجراء).
alter table public.profiles
  add column suspension_reason_code text references public.moderation_reasons (code),
  add column suspension_reason_text text
    check (suspension_reason_text is null or char_length(suspension_reason_text) <= 1000);

-- لضمان أن المدينة تتبع المنطقة بمفتاح أجنبي مركب.
alter table public.cities add constraint cities_id_region_key unique (id, region_id);

-- رأس الإعلان: الحالة وأوقات النشر والظهور (SRS القسم 6).
create table public.listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id),
  status public.listing_status not null default 'DRAFT',
  -- آخر نسخة يعمل عليها المعلن أو تراجعها الإدارة.
  current_version_id uuid,
  -- النسخة المعتمدة المعروضة للعامة.
  published_version_id uuid,
  -- معرف طلب الإنشاء لمنع التكرار (AD-NFR-005).
  create_request_id uuid not null,
  -- أول إرسال للمراجعة: مرجع حد الإعلانات الجديدة (TEAM-DEC-011 البند 4).
  first_submitted_at timestamptz,
  first_published_at timestamptz,
  published_version_at timestamptz,
  last_published_at timestamptz,
  last_bumped_at timestamptz,
  visibility_updated_at timestamptz,
  status_changed_at timestamptz not null default now(),
  -- حذف المعلن لإعلان له سجل مراجعة: يخفى عنه ويبقى السجل (AD-FR-018).
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, create_request_id),
  constraint listings_published_has_version check (
    status <> 'PUBLISHED'
    or (published_version_id is not null and first_published_at is not null
        and last_published_at is not null and visibility_updated_at is not null)
  ),
  constraint listings_review_has_version check (
    status <> 'UNDER_REVIEW' or (current_version_id is not null and first_submitted_at is not null)
  )
);

create trigger listings_set_updated_at before update on public.listings
  for each row execute function private.set_updated_at();

create index listings_owner_status_idx on public.listings (owner_id, status) where deleted_at is null;
create index listings_published_visibility_idx
  on public.listings (visibility_updated_at desc, id) where status = 'PUBLISHED';
create index listings_review_queue_idx
  on public.listings (status_changed_at, id) where status = 'UNDER_REVIEW';

-- نسخة المحتوى. الحقول تقبل الفراغ في المسودة، وتلزم عند الإرسال.
create table public.listing_versions (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  version_no integer not null check (version_no > 0),
  status public.listing_version_status not null default 'DRAFT',

  title text check (title is null or char_length(title) <= 200),
  description text check (description is null or char_length(description) <= 10000),
  breed_id integer references public.breeds (id),
  -- توضيح السلالة عند اختيار «أخرى».
  breed_note text check (breed_note is null or char_length(breed_note) <= 80),
  sex public.animal_sex,
  age_months integer check (age_months is null or age_months between 1 and 600),
  color text check (color is null or char_length(color) <= 60),
  region_id integer references public.regions (id),
  city_id integer,
  health_notes text check (health_notes is null or char_length(health_notes) <= 2000),
  -- إقرار المعلن بأحقيته في العرض وصحة المعلومات.
  owner_declaration_at timestamptz,

  offer_type public.offer_type,
  -- بالريال، منزلتان كحد أقصى. فارغ في المزاد ولا يحول إلى صفر.
  price numeric(12, 2) check (price is null or price > 0),
  -- المزاد الحضوري: منطقة ومدينة ووصف نصي وموعد (UTC).
  auction_region_id integer references public.regions (id),
  auction_city_id integer,
  auction_venue text check (auction_venue is null or char_length(auction_venue) <= 300),
  auction_starts_at timestamptz,

  -- رقم التواصل لهذا الإعلان؛ لا يؤخذ من هاتف الدخول.
  contact_phone text check (contact_phone is null or contact_phone ~ '^\+9665[0-9]{8}$'),
  contact_call_enabled boolean not null default false,
  contact_whatsapp_enabled boolean not null default false,
  -- وقت حفظ الرقم بعد تنبيه النشر (TEAM-DEC-009).
  contact_consent_at timestamptz,

  -- تثبت عند الإرسال.
  settings_version integer references public.settings_versions (version),
  content_hash text,
  submit_request_id uuid,
  submitted_at timestamptz,
  decided_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (listing_id, version_no),
  unique (listing_id, id),
  unique (listing_id, submit_request_id),
  foreign key (city_id, region_id) references public.cities (id, region_id),
  foreign key (auction_city_id, auction_region_id) references public.cities (id, region_id),

  -- المفتاح المركب لا يفحص عند فراغ أحد طرفيه؛ المدينة لا تحفظ دون منطقتها.
  constraint listing_versions_city_needs_region check (
    (city_id is null or region_id is not null)
    and (auction_city_id is null or auction_region_id is not null)
  ),
  -- حقول النوع غير المنطبق تبقى فارغة في كل الحالات.
  constraint listing_versions_offer_fields check (
    (price is null or offer_type = 'FIXED_PRICE')
    and (
      (auction_region_id is null and auction_city_id is null
       and auction_venue is null and auction_starts_at is null)
      or offer_type = 'IN_PERSON_AUCTION'
    )
  ),
  -- نسخة مرسلة مكتملة: السعر للعرض السعري، والمكان والموعد للمزاد، وقناة تواصل.
  constraint listing_versions_complete_when_submitted check (
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
      and contact_phone is not null and contact_consent_at is not null
      and (contact_call_enabled or contact_whatsapp_enabled)
      and settings_version is not null and content_hash is not null
      and submitted_at is not null
    )
  )
);

create trigger listing_versions_set_updated_at before update on public.listing_versions
  for each row execute function private.set_updated_at();

-- مسودة واحدة ونسخة واحدة قيد المراجعة لكل إعلان.
create unique index listing_versions_one_draft_idx
  on public.listing_versions (listing_id) where status = 'DRAFT';
create unique index listing_versions_one_submitted_idx
  on public.listing_versions (listing_id) where status = 'SUBMITTED';

alter table public.listings
  add constraint listings_current_version_fk
    foreign key (id, current_version_id) references public.listing_versions (listing_id, id)
    deferrable initially deferred,
  add constraint listings_published_version_fk
    foreign key (id, published_version_id) references public.listing_versions (listing_id, id)
    deferrable initially deferred;

-- ثبات النسخة: المسودة وحدها تتغير. النسخة المرسلة يتغير قرارها فقط.
create function private.guard_listing_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status = 'DRAFT' then
    return new;
  end if;

  if (pg_catalog.to_jsonb(new) - array['status', 'decided_at', 'updated_at'])
       is distinct from
     (pg_catalog.to_jsonb(old) - array['status', 'decided_at', 'updated_at'])
    or not (
      new.status = old.status
      or (old.status = 'SUBMITTED' and new.status in ('APPROVED', 'REJECTED'))
    )
  then
    perform private.raise_error(
      'VERSION_IMMUTABLE',
      pg_catalog.jsonb_build_object('version_id', old.id, 'status', old.status));
  end if;

  return new;
end;
$$;

create trigger listing_versions_guard before update on public.listing_versions
  for each row execute function private.guard_listing_version();

-- الوسائط: صف لكل ملف في نسخة. نسخة التعديل تنسخ صفوف النسخة السابقة بالمسار نفسه.
create table public.media (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null,
  version_id uuid not null,
  owner_id uuid not null references public.profiles (id),
  kind public.media_kind not null,
  status public.media_status not null default 'PENDING',
  bucket text not null,
  -- {owner}/{listing}/{media}.{ext}
  object_path text not null,
  mime_type text,
  size_bytes bigint check (size_bytes is null or size_bytes > 0),
  width integer check (width is null or width > 0),
  height integer check (height is null or height > 0),
  duration_seconds numeric(6, 2) check (duration_seconds is null or duration_seconds > 0),
  sort_order integer not null default 0,
  is_cover boolean not null default false,
  failure_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (version_id, object_path),
  foreign key (listing_id, version_id)
    references public.listing_versions (listing_id, id) on delete cascade,
  constraint media_cover_is_ready_image check (not is_cover or kind = 'IMAGE'),
  constraint media_ready_has_metadata check (
    status <> 'READY' or (mime_type is not null and size_bytes is not null)
  )
);

create trigger media_set_updated_at before update on public.media
  for each row execute function private.set_updated_at();

create index media_version_idx on public.media (version_id, sort_order);
create index media_owner_idx on public.media (owner_id);
create index media_object_idx on public.media (bucket, object_path);
-- غلاف واحد وفيديو واحد لكل نسخة.
create unique index media_one_cover_idx on public.media (version_id) where is_cover;
create unique index media_one_video_idx on public.media (version_id) where kind = 'VIDEO';

-- وسائط نسخة غير مسودة لا تتغير.
create function private.guard_media()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_version_id uuid := case when tg_op = 'INSERT' then new.version_id else old.version_id end;
  v_status public.listing_version_status;
begin
  select v.status into v_status from public.listing_versions v where v.id = v_version_id;

  -- النسخة غير موجودة: حذف متسلسل مع الإعلان.
  if found and v_status <> 'DRAFT' then
    perform private.raise_error(
      'VERSION_IMMUTABLE',
      pg_catalog.jsonb_build_object('version_id', v_version_id, 'status', v_status));
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger media_guard before insert or update or delete on public.media
  for each row execute function private.guard_media();

-- سجل قرارات الإشراف على الإعلانات: إضافة فقط (AD-FR-008، AD-FR-018).
create table public.reviews (
  id bigint generated always as identity primary key,
  listing_id uuid not null references public.listings (id),
  version_id uuid,
  decision public.review_decision not null,
  reason_code text references public.moderation_reasons (code),
  reason_text text check (reason_text is null or char_length(reason_text) <= 1000),
  -- بصمة المحتوى الذي صدر عليه القرار.
  content_hash text,
  moderator_id uuid not null,
  created_at timestamptz not null default now(),
  foreign key (listing_id, version_id) references public.listing_versions (listing_id, id),
  constraint reviews_reason_required check (
    decision not in ('REJECTED', 'HIDDEN') or reason_code is not null
  )
);

create index reviews_listing_idx on public.reviews (listing_id, created_at desc);

create trigger reviews_append_only
  before update or delete on public.reviews
  for each row execute function private.forbid_change();

-- سجل تجديد الظهور: تاريخ تدقيق لا يعدله المعلن (AD-FR-030).
create table public.listing_bumps (
  id bigint generated always as identity primary key,
  listing_id uuid not null references public.listings (id),
  actor_id uuid not null,
  bumped_at timestamptz not null default now()
);

create index listing_bumps_listing_idx on public.listing_bumps (listing_id, bumped_at desc);

create trigger listing_bumps_append_only
  before update or delete on public.listing_bumps
  for each row execute function private.forbid_change();

-- القراءة: المالك يقرأ إعلاناته، والموظف بحسب قدرته. القراءة العامة عبر views
-- في ترحيل public_surface.
alter table public.moderation_reasons enable row level security;
alter table public.listings enable row level security;
alter table public.listing_versions enable row level security;
alter table public.media enable row level security;
alter table public.reviews enable row level security;
alter table public.listing_bumps enable row level security;

grant select on public.moderation_reasons, public.listings, public.listing_versions,
  public.media, public.reviews, public.listing_bumps to authenticated;

create policy moderation_reasons_read_active on public.moderation_reasons
  for select to authenticated using (is_active);
create policy moderation_reasons_read_staff on public.moderation_reasons
  for select to authenticated using ((select public.has_staff_capability('lookups.manage')));

create policy listings_read_own on public.listings
  for select to authenticated
  using ((select auth.uid()) = owner_id and deleted_at is null);
create policy listings_read_reviewer on public.listings
  for select to authenticated using ((select public.has_staff_capability('listings.review')));
create policy listings_read_hider on public.listings
  for select to authenticated using ((select public.has_staff_capability('listings.hide')));

create policy listing_versions_read_own on public.listing_versions
  for select to authenticated
  using (exists (
    select 1 from public.listings l
    where l.id = listing_id and l.owner_id = (select auth.uid()) and l.deleted_at is null));
create policy listing_versions_read_reviewer on public.listing_versions
  for select to authenticated using ((select public.has_staff_capability('listings.review')));
create policy listing_versions_read_hider on public.listing_versions
  for select to authenticated using ((select public.has_staff_capability('listings.hide')));

create policy media_read_own on public.media
  for select to authenticated using ((select auth.uid()) = owner_id);
create policy media_read_reviewer on public.media
  for select to authenticated using ((select public.has_staff_capability('listings.review')));
create policy media_read_hider on public.media
  for select to authenticated using ((select public.has_staff_capability('listings.hide')));

-- المعلن يعرف سبب الرفض عبر دالة «إعلاناتي»، لا بقراءة السجل.
create policy reviews_read_reviewer on public.reviews
  for select to authenticated using ((select public.has_staff_capability('listings.review')));
create policy reviews_read_hider on public.reviews
  for select to authenticated using ((select public.has_staff_capability('listings.hide')));

create policy listing_bumps_read_own on public.listing_bumps
  for select to authenticated using ((select auth.uid()) = actor_id);
create policy listing_bumps_read_reviewer on public.listing_bumps
  for select to authenticated using ((select public.has_staff_capability('listings.review')));
