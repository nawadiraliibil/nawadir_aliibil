import { errorMessage, toApiError, type ApiError } from '@admin/lib/errors'
import type { FieldErrors } from './types'

const FIELD_MESSAGES: Record<string, string> = {
  name_ar: 'الاسم مطلوب ولا يتجاوز الحد المسموح.',
  label_ar: 'التسمية مطلوبة ولا تتجاوز 120 حرفًا.',
  region_id: 'المنطقة غير موجودة. اختر منطقة من القائمة.',
  code: 'الرمز يبدأ بحرف إنجليزي كبير ويحوي أحرفًا كبيرة وأرقامًا و_ فقط (2 إلى 40).',
  applies_to: 'اختر إجراءً واحدًا على الأقل.',
  sort_order: 'أدخل رقمًا صحيحًا.',
}

export const DUPLICATE_MESSAGE = 'الاسم مكرر'

/**
 * يحول VALIDATION_FAILED إلى أخطاء حقول النموذج.
 * fieldMap: اسم الحقل في رد الخادم ← اسم حقل النموذج (مثل name_ar ← label_ar لأسباب الإشراف،
 * لأن private.clean_lookup_name يبلغ عن name_ar دائمًا).
 */
export function fieldErrorsFrom(error: unknown, fieldMap: Record<string, string> = {}, duplicateMessage = DUPLICATE_MESSAGE): FieldErrors {
  const e = toApiError(error)
  if (e.code !== 'VALIDATION_FAILED') return {}
  const out: FieldErrors = {}
  const duplicate = e.details.reason === 'duplicate'
  for (const f of e.fields) {
    const target = fieldMap[f] ?? f
    out[target] = duplicate && f === 'name_ar' ? duplicateMessage : (FIELD_MESSAGES[target] ?? 'قيمة غير صالحة.')
  }
  return out
}

/** نص الخطأ العام للقوائم مع حالات خاصة من الترحيلات. */
export function lookupErrorMessage(error: unknown): string {
  const e: ApiError = toApiError(error)
  if (e.code === 'INVALID_STATE' && e.details.reason === 'in_use') {
    return 'المدينة مستخدمة في إعلانات، فلا يمكن نقلها إلى منطقة أخرى. أضف مدينة جديدة في المنطقة المطلوبة بدلًا من ذلك.'
  }
  if (e.code === 'NOT_FOUND') return 'لم تعد هذه القيمة موجودة. أعيد تحميل القائمة لعرض آخر حالة.'
  if (e.code === 'VALIDATION_FAILED' && e.details.reason === 'duplicate') return 'الاسم مكرر. اختر اسمًا آخر.'
  return errorMessage(e)
}

/** أخطاء تستدعي إعادة تحميل القائمة (القيمة تغيرت أو حذفت من جلسة أخرى). */
export function shouldRefetch(error: unknown): boolean {
  const code = toApiError(error).code
  return code === 'NOT_FOUND' || code === 'INVALID_STATE' || code === 'VERSION_CHANGED'
}

export interface SortOrderParse {
  value?: number
  error?: string
}

/** ترتيب اختياري: فارغ ← undefined (يبقى الترتيب أو يضاف في الآخر)، وإلا عدد صحيح. */
export function parseSortOrder(raw: string): SortOrderParse {
  const t = raw.trim()
  if (t === '') return {}
  if (!/^-?\d{1,9}$/.test(t)) return { error: FIELD_MESSAGES.sort_order }
  return { value: Number(t) }
}

/** تنظيف الاسم كما يفعل private.clean_lookup_name: قص الأطراف ودمج المسافات. */
export function cleanName(raw: string): string {
  return raw.replace(/\s+/g, ' ').trim()
}

export function validateName(raw: string, max: number, emptyMessage = 'الاسم مطلوب.'): string | undefined {
  const v = cleanName(raw)
  if (v.length === 0) return emptyMessage
  if (v.length > max) return `لا يتجاوز ${max} حرفًا.`
  return undefined
}

export const REASON_CODE_PATTERN = /^[A-Z][A-Z0-9_]{1,39}$/
export { FIELD_MESSAGES }
