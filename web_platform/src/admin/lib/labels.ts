// تسميات عربية لقيم العقد (contracts/api/enums.json وقيود الترحيلات).

export const LISTING_STATUS_LABELS: Record<string, string> = {
  DRAFT: 'مسودة',
  UNDER_REVIEW: 'قيد المراجعة (قديم)',
  REJECTED: 'مرفوض (قديم)',
  PUBLISHED: 'منشور',
  HIDDEN: 'مخفي',
  ARCHIVED: 'مؤرشف',
}

/** الحالات المعروضة في مرشح الإعلانات (TEAM-DEC-013: لا «قيد المراجعة»). */
export const LISTING_FILTER_STATUSES = ['PUBLISHED', 'HIDDEN', 'ARCHIVED', 'DRAFT', 'REJECTED'] as const

export const ACCOUNT_STATUS_LABELS: Record<string, string> = {
  ACTIVE: 'فعال',
  SUSPENDED: 'معلق',
}

export const OFFER_TYPE_LABELS: Record<string, string> = {
  FIXED_PRICE: 'سعر ثابت',
  IN_PERSON_AUCTION: 'مزاد حضوري',
}

export const ANIMAL_SEX_LABELS: Record<string, string> = {
  MALE: 'ذكر',
  FEMALE: 'أنثى',
}

export const REVIEW_DECISION_LABELS: Record<string, string> = {
  APPROVED: 'نشر',
  REJECTED: 'رفض (قديم)',
  HIDDEN: 'إخفاء',
  UNHIDDEN: 'إعادة إظهار',
}

export const REPORT_STATUS_LABELS: Record<string, string> = {
  OPEN: 'مفتوح',
  IN_REVIEW: 'قيد المراجعة',
  CLOSED: 'مغلق',
}

export const REPORT_TARGET_LABELS: Record<string, string> = {
  LISTING: 'إعلان',
  ACCOUNT: 'حساب',
  MESSAGE: 'رسالة',
  COMMENT: 'رد عام',
  RATING: 'تقييم',
}

export const REPORT_REASON_LABELS: Record<string, string> = {
  SPAM: 'إزعاج أو دعاية',
  FRAUD: 'احتيال',
  ABUSE: 'إساءة',
  MISLEADING: 'معلومات مضللة',
  PROHIBITED_CONTENT: 'محتوى مخالف',
  OTHER: 'أخرى',
}

export const REPORT_CLOSE_REASON_LABELS: Record<string, string> = {
  ACTION_TAKEN: 'اتخذ إجراء',
  NO_VIOLATION: 'لا مخالفة',
  DUPLICATE: 'بلاغ مكرر',
  INVALID: 'بلاغ غير صالح',
}

export const MODERATION_ACTION_LABELS: Record<string, string> = {
  LISTING_HIDE: 'إخفاء إعلان',
  LISTING_REJECT: 'رفض إعلان (قديم)',
  ACCOUNT_SUSPEND: 'تعليق حساب',
  COMMENT_HIDE: 'إخفاء رد',
  RATING_HIDE: 'إخفاء تقييم',
}

export type ModerationAction = 'LISTING_HIDE' | 'ACCOUNT_SUSPEND' | 'COMMENT_HIDE' | 'RATING_HIDE'

export function label(map: Record<string, string>, value: string | null | undefined): string {
  if (value === null || value === undefined || value === '') return '—'
  return map[value] ?? value
}
