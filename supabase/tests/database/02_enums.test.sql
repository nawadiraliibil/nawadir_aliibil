-- MOBILE-BE-101 — الترحيل 02 enums
-- القيم وترتيبها مطابقة لـcontracts/api/enums.json.
begin;

create extension if not exists pgtap with schema extensions;

select plan(12);

select enum_has_labels('public', 'listing_status',
  array['DRAFT', 'UNDER_REVIEW', 'REJECTED', 'PUBLISHED', 'HIDDEN', 'ARCHIVED']);
select enum_has_labels('public', 'listing_version_status',
  array['DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED']);
select enum_has_labels('public', 'offer_type',
  array['FIXED_PRICE', 'IN_PERSON_AUCTION']);
select enum_has_labels('public', 'animal_sex',
  array['MALE', 'FEMALE']);
select enum_has_labels('public', 'media_kind',
  array['IMAGE', 'VIDEO']);
select enum_has_labels('public', 'media_status',
  array['PENDING', 'READY', 'FAILED']);
select enum_has_labels('public', 'account_status',
  array['ACTIVE', 'SUSPENDED']);
select enum_has_labels('public', 'staff_role',
  array['MODERATOR', 'ADMIN']);
select enum_has_labels('public', 'notification_category',
  array['LISTING_STATUS', 'ACCOUNT', 'REPORTS', 'FOLLOWS', 'MESSAGES', 'COMMENTS', 'RATINGS']);

select enum_has_labels('public', 'policy_kind',
  array['TERMS', 'PRIVACY']);

select enum_has_labels('public', 'review_decision',
  array['APPROVED', 'REJECTED', 'HIDDEN', 'UNHIDDEN']);

-- لا enum في public خارج هذه القائمة دون تحديث العقد والاختبار.
select enums_are('public', array[
  'listing_status', 'listing_version_status', 'offer_type', 'animal_sex',
  'media_kind', 'media_status', 'account_status', 'staff_role', 'notification_category',
  'policy_kind', 'review_decision'
]);

select * from finish();
rollback;
