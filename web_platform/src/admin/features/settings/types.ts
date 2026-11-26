// أنواع ميزة الإعدادات. الشكل من private.settings_admin_json()
// (supabase/migrations/20261122231000_settings_lookup_admin_rpcs.sql) ومن جدول settings_versions
// في contracts/generated/database.types.ts.
import type { Database } from '@contracts/generated/database.types'

/** محتوى إصدار إعدادات (jsonb كائن). المفاتيح المعروفة في schema.ts. */
export type SettingsContent = Record<string, unknown>

/** رد admin_get_settings وadmin_update_settings_draft وadmin_publish_settings وadmin_rollback_settings. */
export interface AdminSettingsPayload {
  published_version: number
  published: SettingsContent
  published_at: string
  draft: SettingsContent | null
  draft_updated_by: string | null
  draft_updated_at: string | null
}

/** صف من settings_versions (سجل إضافة فقط). */
export type SettingsVersionRow = Database['public']['Tables']['settings_versions']['Row']

/** قيم النموذج بمسار الحقل (section.key). الأعداد نصوص كما في الحقل. */
export type FormValues = Record<string, string | boolean | string[]>
