// بيانات اختبار مبنية على شكل private.account_admin_json (20261122230000_listing_admin_rpcs.sql)
// وأعمدة profiles في contracts/generated/database.types.ts. لا يوجد مثال عقد (fixture) لـadmin_get_account.
// القيم وهمية وليست بيانات مستخدمين حقيقية.
import type { AdminAccount, ProfileListRow } from './types'

export const ACTIVE_ID = 'ba24f799-5ca6-4002-a95c-9a7e92d37eee'
export const SUSPENDED_ID = 'c3d0e2a1-7b5f-4c1e-9a2b-3f4e5d6c7b8a'

export const ACTIVE_ACCOUNT: AdminAccount = {
  id: ACTIVE_ID,
  display_name: 'معلن تجريبي',
  region_id: 1,
  status: 'ACTIVE',
  status_changed_at: null,
  suspension_reason_code: null,
  suspension_reason_text: null,
  created_at: '2026-11-23T03:25:03.404363+00:00',
  phone: '966500000001',
  listing_counts: { PUBLISHED: 3, DRAFT: 1, ARCHIVED: 2 },
}

export const SUSPENDED_ACCOUNT: AdminAccount = {
  id: SUSPENDED_ID,
  display_name: 'حساب معلق',
  region_id: 2,
  status: 'SUSPENDED',
  status_changed_at: '2026-11-24T09:15:00+00:00',
  suspension_reason_code: 'FRAUD',
  suspension_reason_text: 'تكرار إعلانات مضللة',
  created_at: '2026-11-20T12:00:00+00:00',
  phone: '966500000002',
  listing_counts: { HIDDEN: 4 },
}

export const REASONS = [
  { code: 'FRAUD', label_ar: 'اشتباه احتيال أو إساءة استخدام', applies_to: ['LISTING_HIDE', 'ACCOUNT_SUSPEND'], requires_note: false, sort_order: 80, is_active: true },
  { code: 'ABUSE', label_ar: 'إساءة إلى مستخدمين آخرين', applies_to: ['ACCOUNT_SUSPEND'], requires_note: false, sort_order: 90, is_active: true },
  { code: 'OTHER', label_ar: 'أخرى', applies_to: ['LISTING_HIDE', 'ACCOUNT_SUSPEND'], requires_note: true, sort_order: 1000, is_active: true },
  { code: 'SPAM_COMMENT', label_ar: 'رد مزعج', applies_to: ['COMMENT_HIDE'], requires_note: false, sort_order: 95, is_active: true },
]

export const REGIONS = [
  { id: 1, name_ar: 'الرياض', is_active: true, sort_order: 10, created_at: '2026-11-22T00:00:00Z', updated_at: '2026-11-22T00:00:00Z' },
  { id: 2, name_ar: 'القصيم', is_active: true, sort_order: 20, created_at: '2026-11-22T00:00:00Z', updated_at: '2026-11-22T00:00:00Z' },
]

function profileRow(acc: AdminAccount): ProfileListRow & { updated_at: string } {
  return {
    id: acc.id,
    display_name: acc.display_name,
    region_id: acc.region_id,
    status: acc.status,
    status_changed_at: acc.status_changed_at,
    suspension_reason_code: acc.suspension_reason_code,
    suspension_reason_text: acc.suspension_reason_text,
    created_at: acc.created_at,
    updated_at: acc.created_at,
  }
}

export const PROFILE_ROWS = [
  profileRow(ACTIVE_ACCOUNT),
  profileRow(SUSPENDED_ACCOUNT),
  {
    id: 'aaaaaaaa-0000-4000-8000-000000000003',
    display_name: null,
    region_id: 99,
    status: 'ACTIVE' as const,
    status_changed_at: null,
    suspension_reason_code: null,
    suspension_reason_text: null,
    created_at: '2026-11-18T08:00:00+00:00',
    updated_at: '2026-11-18T08:00:00+00:00',
  },
]

/** صفوف كثيرة لاختبار التصفح. */
export function manyProfiles(n: number) {
  return Array.from({ length: n }, (_, i) => {
    const hex = i.toString(16).padStart(12, '0')
    const day = String(1 + (i % 28)).padStart(2, '0')
    return {
      id: `bbbbbbbb-0000-4000-8000-${hex}`,
      display_name: `مستخدم ${i}`,
      region_id: 1,
      status: 'ACTIVE' as const,
      status_changed_at: null,
      suspension_reason_code: null,
      suspension_reason_text: null,
      created_at: `2026-10-${day}T00:00:00+00:00`,
      updated_at: `2026-10-${day}T00:00:00+00:00`,
    }
  })
}
