// تسميات خاصة بالبلاغات (المشتركة في @admin/lib/labels).
import { shortId } from '@admin/lib/format'
import type { StatusFilter } from './api'

export const STATUS_FILTER_LABELS: Record<StatusFilter, string> = {
  ACTIVE: 'المفتوحة وقيد المراجعة',
  OPEN: 'مفتوح',
  IN_REVIEW: 'قيد المراجعة',
  CLOSED: 'مغلق',
  ALL: 'الكل',
}

export const STATUS_FILTERS = Object.keys(STATUS_FILTER_LABELS) as StatusFilter[]

export const COMMENT_STATE_LABELS: Record<string, string> = {
  HIDDEN: 'مخفي إداريًا',
  VISIBLE: 'ظاهر',
  DELETED: 'محذوف من صاحبه',
}

/** «أنت» للموظف الحالي، أو المعرف المختصر، أو «غير مسند». */
export function staffLabel(id: string | null | undefined, me: string | null | undefined, empty = 'غير مسند'): string {
  if (!id) return empty
  return me && id === me ? 'أنت' : shortId(id)
}
