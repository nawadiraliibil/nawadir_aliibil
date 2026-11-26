// الأوقات تخزن UTC وتعرض بتوقيت Asia/Riyadh (ADMIN-HANDOFF القسم 5). أرقام لاتينية للوضوح.

export const RIYADH_TZ = 'Asia/Riyadh'
const LOCALE = 'ar-SA-u-nu-latn-ca-gregory'

const dateTimeFmt = new Intl.DateTimeFormat(LOCALE, {
  timeZone: RIYADH_TZ,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  hour12: true,
})
const dateFmt = new Intl.DateTimeFormat(LOCALE, { timeZone: RIYADH_TZ, year: 'numeric', month: '2-digit', day: '2-digit' })
const numberFmt = new Intl.NumberFormat('en-US')

function toDate(value: string | number | Date | null | undefined): Date | null {
  if (value === null || value === undefined || value === '') return null
  const d = value instanceof Date ? value : new Date(value)
  return Number.isNaN(d.getTime()) ? null : d
}

/** تاريخ ووقت بتوقيت الرياض، أو «—» للقيمة الفارغة. */
export function formatDateTime(value: string | number | Date | null | undefined): string {
  const d = toDate(value)
  return d ? dateTimeFmt.format(d) : '—'
}

export function formatDate(value: string | number | Date | null | undefined): string {
  const d = toDate(value)
  return d ? dateFmt.format(d) : '—'
}

export function formatNumber(value: number | null | undefined): string {
  return value === null || value === undefined ? '—' : numberFmt.format(value)
}

export function formatPrice(value: number | null | undefined): string {
  return value === null || value === undefined ? '—' : `${numberFmt.format(value)} ر.س`
}

/** يوم بتوقيت الرياض (YYYY-MM-DD) لقيم حقول التاريخ. */
export function riyadhDayString(value: Date): string {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: RIYADH_TZ, year: 'numeric', month: '2-digit', day: '2-digit' }).format(value)
  return parts
}

/**
 * بداية يوم (YYYY-MM-DD) بتوقيت الرياض كـISO UTC. الرياض UTC+3 دون توقيت صيفي.
 * endOfDay=true يعيد بداية اليوم التالي (حد علوي حصري).
 */
export function riyadhDayToIso(day: string, endOfDay = false): string {
  const [y, m, d] = day.split('-').map(Number)
  if (!y || !m || !d) throw new Error(`invalid day: ${day}`)
  const utc = Date.UTC(y, m - 1, d + (endOfDay ? 1 : 0), 0, 0, 0) - 3 * 60 * 60 * 1000
  return new Date(utc).toISOString()
}

export function shortId(id: string | null | undefined): string {
  return id ? id.slice(0, 8) : '—'
}
