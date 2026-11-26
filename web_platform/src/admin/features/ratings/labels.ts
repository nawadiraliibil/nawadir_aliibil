import type { Tone } from '@admin/ui'

// تسميات محلية للميزة (قيم قيود seller_ratings وrating_appeals).

export const RATING_STATUS_LABELS: Record<string, string> = {
  VISIBLE: 'ظاهر',
  HIDDEN: 'مخفي',
}

export const RATING_FILTER_STATUSES = ['VISIBLE', 'HIDDEN'] as const

export const APPEAL_STATUS_LABELS: Record<string, string> = {
  OPEN: 'مفتوح',
  ACCEPTED: 'مقبول (أخفي التقييم)',
  REJECTED: 'مرفوض (أبقي التقييم)',
}

export const APPEAL_FILTER_STATUSES = ['OPEN', 'ACCEPTED', 'REJECTED'] as const

export const APPEAL_DECISION_LABELS: Record<string, string> = {
  ACCEPTED: 'قبول: إخفاء التقييم',
  REJECTED: 'رفض: إبقاء التقييم',
}

export function ratingStatusTone(status: string | null | undefined): Tone {
  return status === 'HIDDEN' ? 'danger' : status === 'VISIBLE' ? 'success' : 'neutral'
}

export function appealStatusTone(status: string | null | undefined): Tone {
  return status === 'OPEN' ? 'warning' : status === 'ACCEPTED' ? 'danger' : status === 'REJECTED' ? 'neutral' : 'neutral'
}
