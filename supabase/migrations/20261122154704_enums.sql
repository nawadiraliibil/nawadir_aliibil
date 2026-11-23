-- 02 enums — MOBILE-BE-101
-- القيم جزء من العقد (contracts/api/enums.json). إضافة قيمة تغيير إضافي؛
-- حذف قيمة أو إعادة تسميتها تغيير كاسر (contracts/README.md «قواعد التغيير»).

-- حالات الإعلان — SRS القسم 6.
create type public.listing_status as enum (
  'DRAFT',
  'UNDER_REVIEW',
  'REJECTED',
  'PUBLISHED',
  'HIDDEN',
  'ARCHIVED'
);

-- حالة نسخة المحتوى: المسودة قابلة للتعديل، وما بعدها ثابت.
create type public.listing_version_status as enum (
  'DRAFT',
  'SUBMITTED',
  'APPROVED',
  'REJECTED'
);

-- نوع العرض — SRS القسم 5.
create type public.offer_type as enum (
  'FIXED_PRICE',
  'IN_PERSON_AUCTION'
);

create type public.animal_sex as enum (
  'MALE',
  'FEMALE'
);

create type public.media_kind as enum (
  'IMAGE',
  'VIDEO'
);

-- PENDING: رفع لم يكتمل فحصه. READY: اجتاز الفحص. FAILED: رفضه الفحص.
create type public.media_status as enum (
  'PENDING',
  'READY',
  'FAILED'
);

create type public.account_status as enum (
  'ACTIVE',
  'SUSPENDED'
);

-- أدوار الموظفين — AD-FR-017، TEAM-DEC-011 البند 6.
create type public.staff_role as enum (
  'MODERATOR',
  'ADMIN'
);

-- فئات الإشعارات — خطة MOBILE-PLAN-20261122.
create type public.notification_category as enum (
  'LISTING_STATUS',
  'ACCOUNT',
  'REPORTS',
  'FOLLOWS',
  'MESSAGES',
  'COMMENTS',
  'RATINGS'
);
