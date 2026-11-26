import type { LookupKind, LookupTab } from './types'

export const TAB_LABELS: Record<LookupTab, string> = {
  breeds: 'السلالات',
  regions: 'المناطق',
  cities: 'المدن',
  reasons: 'أسباب الإشراف',
}

export const TAB_ORDER: LookupTab[] = ['breeds', 'regions', 'cities', 'reasons']

/** اسم القيمة المفرد لكل نوع (للعناوين والرسائل). */
export const KIND_NOUN: Record<LookupKind, string> = {
  breed: 'السلالة',
  region: 'المنطقة',
  city: 'المدينة',
  moderation_reason: 'سبب الإشراف',
}

/**
 * الإجراءات التي يقبلها admin_upsert_moderation_reason (private.moderation_actions في
 * 20261123160000_ratings.sql). LISTING_REJECT قديم بعد TEAM-DEC-013: لا يعرض إلا لسبب يحمله.
 */
export const CURRENT_REASON_ACTIONS = ['LISTING_HIDE', 'ACCOUNT_SUSPEND', 'COMMENT_HIDE', 'RATING_HIDE'] as const
export const LEGACY_REASON_ACTION = 'LISTING_REJECT'

export const LEGACY_ACTION_HINT = 'إجراء قديم غير مستخدم بعد إلغاء المراجعة المسبقة (TEAM-DEC-013). يمكن إزالته من هذا السبب.'

export const DEACTIVATE_EXPLAIN =
  'لا تحذف القيم. القيمة المعطلة تبقى ظاهرة في الإعلانات والسجلات السابقة، لكن لا يمكن اختيارها في إعلان أو إجراء جديد. يمكن تفعيلها لاحقًا.'
