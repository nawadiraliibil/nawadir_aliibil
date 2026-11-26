// أشكال صفوف القوائم كما في contracts/generated/database.types.ts (Tables[...]['Row'])
// وكما تعيدها دوال admin_upsert_* (to_jsonb للصف). AD-FR-037.

/** قيم p_kind المقبولة في admin_set_lookup_active وadmin_reorder_lookup. */
export type LookupKind = 'breed' | 'region' | 'city' | 'moderation_reason'

export interface Breed {
  id: number
  name_ar: string
  requires_note: boolean
  sort_order: number
  is_active: boolean
  updated_at: string
}

export interface Region {
  id: number
  name_ar: string
  sort_order: number
  is_active: boolean
  updated_at: string
}

export interface City {
  id: number
  region_id: number
  name_ar: string
  sort_order: number
  is_active: boolean
  updated_at: string
}

export interface ModerationReasonRow {
  code: string
  label_ar: string
  applies_to: string[]
  requires_note: boolean
  sort_order: number
  is_active: boolean
  updated_at: string
}

/** أخطاء الحقول في نوافذ الإضافة والتعديل: اسم حقل النموذج ← النص العربي. */
export type FieldErrors = Partial<Record<string, string>>

export type LookupTab = 'breeds' | 'regions' | 'cities' | 'reasons'
