// الدعايات التجارية (TEAM-DEC-017). الأشكال وفق العقد 1.6.0: contracts/schemas/promotion-admin
// وpromotion-input وpromotion-settings، وأمثلة contracts/fixtures/*promotion*.json.

export const PROMOTION_STATUSES = ['ACTIVE', 'PAUSED', 'ARCHIVED'] as const
export type PromotionStatus = (typeof PROMOTION_STATUSES)[number]

/** الحالة الفعلية للعرض: تشتق من الحالة المخزنة وفترة العرض. */
export type EffectiveState = 'RUNNING' | 'SCHEDULED' | 'EXPIRED' | 'PAUSED' | 'ARCHIVED'

export const PLACEMENTS = ['HOME_FEED', 'SEARCH_RESULTS'] as const
export type Placement = (typeof PLACEMENTS)[number]

export const ACTION_TYPES = ['URL', 'WHATSAPP', 'CALL', 'NONE'] as const
export type ActionType = (typeof ACTION_TYPES)[number]

export interface Promotion {
  id: string
  title: string
  body: string | null
  advertiser_name: string
  /** مسار داخل bucket ‏promotions العام. */
  image_path: string
  action_type: ActionType
  action_value: string | null
  placements: Placement[]
  /** null = كل المناطق. */
  region_ids: number[] | null
  starts_at: string
  /** null = بلا نهاية. */
  ends_at: string | null
  /** الأعلى أولًا عند التدوير. 0..100 */
  priority: number
  status: PromotionStatus
  impression_count: number
  click_count: number
  created_by: string | null
  updated_by: string | null
  created_at: string
  updated_at: string
}

/** مدخلات الحفظ: ما يحرره الموظف. */
export interface PromotionInput {
  title: string
  body: string | null
  advertiser_name: string
  image_path: string
  action_type: ActionType
  action_value: string | null
  placements: Placement[]
  region_ids: number[] | null
  starts_at: string
  ends_at: string | null
  priority: number
}

/** إعدادات العرض في التطبيق (admin_get_promotion_settings؛ جدول promotion_settings). */
export interface PromotionDisplaySettings {
  enabled: boolean
  /** دعاية بعد كل N إعلانات من إعلانات المستخدمين. */
  feed_interval: number
}

export const FEED_INTERVAL_MIN = 4
export const FEED_INTERVAL_MAX = 30
export const DEFAULT_DISPLAY_SETTINGS: PromotionDisplaySettings = { enabled: true, feed_interval: 8 }
