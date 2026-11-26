import { riyadhDayString, riyadhDayToIso } from '@admin/lib/format'
import type { DayRange } from './types'

/** الحد الأعلى لطول الفترة كما في admin_stats (366 يومًا). */
export const MAX_RANGE_DAYS = 366
/** الفترة الافتراضية: آخر 30 يومًا تنتهي اليوم (بتوقيت الرياض). */
export const DEFAULT_RANGE_DAYS = 30

const DAY_RE = /^\d{4}-\d{2}-\d{2}$/
const DAY_MS = 24 * 60 * 60 * 1000

function dayToUtcMs(day: string): number | null {
  if (!DAY_RE.test(day)) return null
  const [y, m, d] = day.split('-').map(Number)
  if (!y || !m || !d) return null
  const ms = Date.UTC(y, m - 1, d)
  const back = new Date(ms)
  // يرفض تواريخ غير موجودة مثل 2026-02-30.
  if (back.getUTCFullYear() !== y || back.getUTCMonth() !== m - 1 || back.getUTCDate() !== d) return null
  return ms
}

/** يزيح يومًا (YYYY-MM-DD) بعدد أيام. */
export function shiftDay(day: string, days: number): string {
  const ms = dayToUtcMs(day)
  if (ms === null) throw new Error(`invalid day: ${day}`)
  return new Date(ms + days * DAY_MS).toISOString().slice(0, 10)
}

export function defaultRange(now: Date = new Date()): DayRange {
  const to = riyadhDayString(now)
  return { from: shiftDay(to, -(DEFAULT_RANGE_DAYS - 1)), to }
}

/** عدد الأيام شاملًا البداية والنهاية، أو null لتاريخ غير صالح. */
export function rangeDays(range: DayRange): number | null {
  const a = dayToUtcMs(range.from)
  const b = dayToUtcMs(range.to)
  if (a === null || b === null) return null
  return Math.round((b - a) / DAY_MS) + 1
}

export interface RangeErrors {
  from?: string
  to?: string
}

/** فحص محلي مطابق لشرط الخادم (from < to، والمدة لا تتجاوز 366 يومًا). */
export function validateRange(range: DayRange): RangeErrors {
  const errors: RangeErrors = {}
  if (!range.from) errors.from = 'أدخل تاريخ البداية.'
  else if (dayToUtcMs(range.from) === null) errors.from = 'تاريخ البداية غير صالح.'
  if (!range.to) errors.to = 'أدخل تاريخ النهاية.'
  else if (dayToUtcMs(range.to) === null) errors.to = 'تاريخ النهاية غير صالح.'
  if (errors.from || errors.to) return errors
  const days = rangeDays(range)
  if (days === null) return errors
  if (days < 1) errors.to = 'تاريخ النهاية يجب أن يكون في يوم البداية أو بعده.'
  else if (days > MAX_RANGE_DAYS) errors.to = `الفترة لا تتجاوز ${MAX_RANGE_DAYS} يومًا.`
  return errors
}

/** حدود الاستدعاء: بداية يوم البداية وبداية اليوم التالي ليوم النهاية (حد أعلى حصري) بتوقيت الرياض. */
export function rangeToArgs(range: DayRange): { p_from: string; p_to: string } {
  return { p_from: riyadhDayToIso(range.from), p_to: riyadhDayToIso(range.to, true) }
}
