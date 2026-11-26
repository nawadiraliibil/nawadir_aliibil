// تسميات ومساعدات خاصة بإدارة الإعلانات (محلية؛ مرشحة للنقل إلى lib/labels.ts المشتركة).
import { REVIEW_DECISION_LABELS, label } from '@admin/lib/labels'
import { formatNumber } from '@admin/lib/format'
import type { ListingReview } from './types'

/** listing_version_status في contracts/api/enums.json. */
export const VERSION_STATUS_LABELS: Record<string, string> = {
  DRAFT: 'مسودة',
  SUBMITTED: 'مرسلة',
  APPROVED: 'منشورة',
  REJECTED: 'مرفوضة (قديم)',
}

/** media_status في contracts/api/enums.json. */
export const MEDIA_STATUS_LABELS: Record<string, string> = {
  PENDING: 'قيد التجهيز',
  READY: 'جاهز',
  FAILED: 'فشلت المعالجة',
}

/** reason_text لصف النشر التلقائي عند إرسال المعلن (TEAM-DEC-013). */
export const AUTO_PUBLISH = 'AUTO_PUBLISH'

export function isAutoPublish(r: Pick<ListingReview, 'decision' | 'reason_text'>): boolean {
  return r.decision === 'APPROVED' && r.reason_text === AUTO_PUBLISH
}

/** تسمية القرار في السجل؛ النشر التلقائي ليس قرار موظف. */
export function decisionLabel(r: Pick<ListingReview, 'decision' | 'reason_text'>): string {
  return isAutoPublish(r) ? 'نشر تلقائي' : label(REVIEW_DECISION_LABELS, r.decision)
}

/** آخر إخفاء في السجل (الرد مرتب الأحدث أولًا، ونرتب احتياطًا). */
export function latestHide(reviews: ListingReview[]): ListingReview | null {
  let best: ListingReview | null = null
  for (const r of reviews) {
    if (r.decision !== 'HIDDEN') continue
    if (!best || r.created_at > best.created_at || (r.created_at === best.created_at && r.id > best.id)) best = r
  }
  return best
}

export function formatAge(months: number | null | undefined): string {
  if (months === null || months === undefined) return '—'
  if (months < 12) return `${formatNumber(months)} شهر`
  const years = Math.floor(months / 12)
  const rest = months % 12
  return rest === 0 ? `${formatNumber(years)} سنة (${formatNumber(months)} شهر)` : `${formatNumber(years)} سنة و${formatNumber(rest)} شهر`
}

export function osmUrl(lat: number, lng: number): string {
  return `https://www.openstreetmap.org/?mlat=${lat}&mlon=${lng}#map=15/${lat}/${lng}`
}

export function lookupName(map: Map<number, string> | undefined, id: number | null | undefined): string {
  if (id === null || id === undefined) return '—'
  return map?.get(id) ?? `#${id}`
}

export function formatBytes(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—'
  if (n < 1024) return `${formatNumber(n)} بايت`
  if (n < 1024 * 1024) return `${formatNumber(Math.round(n / 102.4) / 10)} ك.ب`
  return `${formatNumber(Math.round(n / (1024 * 102.4)) / 10)} م.ب`
}
