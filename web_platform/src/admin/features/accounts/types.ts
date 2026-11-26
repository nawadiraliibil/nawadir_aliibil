// أنواع ميزة الحسابات (AD-FR-018). الأعمدة من contracts/generated/database.types.ts،
// وشكل admin_get_account من private.account_admin_json في
// supabase/migrations/20261122230000_listing_admin_rpcs.sql (لم يعد تعريفها لاحقًا).
import type { Database } from '@contracts/generated/database.types'

export type AccountStatus = Database['public']['Enums']['account_status']

type ProfileTableRow = Database['public']['Tables']['profiles']['Row']

/** صف من جدول profiles كما تقرؤه قائمة الحسابات (قراءة الموظف بقدرة accounts.manage). */
export type ProfileListRow = Pick<
  ProfileTableRow,
  'id' | 'display_name' | 'region_id' | 'status' | 'status_changed_at' | 'suspension_reason_code' | 'suspension_reason_text' | 'created_at'
>

/**
 * رد admin_get_account وadmin_suspend_account وadmin_reactivate_account (jsonb).
 * phone: هاتف الدخول من auth.users (قد يكون null). listing_counts: عدد الإعلانات
 * غير المحذوفة بحسب الحالة، والحالة الغائبة عددها صفر.
 */
export interface AdminAccount {
  id: string
  display_name: string | null
  region_id: number | null
  status: AccountStatus
  status_changed_at: string | null
  suspension_reason_code: string | null
  suspension_reason_text: string | null
  created_at: string
  phone: string | null
  listing_counts: Partial<Record<string, number>>
}

export interface ProfilesPage {
  rows: ProfileListRow[]
  /** العدد الكلي المطابق للمرشحات (count: 'exact')، أو null إن لم يعده الخادم. */
  total: number | null
}

export interface RegionName {
  id: number
  name_ar: string
}
