// بيانات اختبار مشتقة من contracts/fixtures (ردود خادم حقيقية) وقيود ترحيل ratings.
import appealDecided from '@contracts/fixtures/admin-appeal-decided.json'
import ratingAppealed from '@contracts/fixtures/rating-appealed.json'
import ratingSubmitted from '@contracts/fixtures/rating-submitted.json'
import publicRatings from '@contracts/fixtures/public-ratings.json'
import type { Row } from '@admin/test/fakeSupabase'
import type { AppealDecidedResult } from './types'

const pr = publicRatings[0]!

export const RATER_ID = pr.rater_id
export const SELLER_ID = ratingSubmitted.seller_id
export const STAFF_ID = '95002fec-541b-4085-b6db-671b43ea977f'

export const R1 = ratingSubmitted.rating_id
export const R2 = '2b8e7c1a-0d4e-4c55-9b1f-4c8f1f8a0001'
export const R3 = '2b8e7c1a-0d4e-4c55-9b1f-4c8f1f8a0002'
export const APPEAL_OPEN = ratingAppealed.appeal_id
export const APPEAL_DONE = '6a1d7c2e-5f3b-4e8a-9c0d-1b2a3c4d0003'

export const DECIDED_FIXTURE = appealDecided as AppealDecidedResult

export function ratingRow(over: Row = {}): Row {
  return {
    id: R1,
    rater_id: RATER_ID,
    seller_id: SELLER_ID,
    conversation_id: '0c8e1d1a-1111-4a2b-8c3d-000000000001',
    score: ratingSubmitted.score,
    body: ratingSubmitted.body,
    declaration_at: ratingSubmitted.created_at,
    status: ratingSubmitted.status,
    hidden_at: null,
    hidden_by: null,
    hidden_reason_code: null,
    hidden_reason_text: null,
    request_id: '0c8e1d1a-2222-4a2b-8c3d-000000000002',
    edited_at: ratingSubmitted.edited_at,
    created_at: ratingSubmitted.created_at,
    updated_at: ratingSubmitted.created_at,
    ...over,
  }
}

export function hiddenRow(over: Row = {}): Row {
  return ratingRow({
    id: R2,
    score: 1,
    body: 'تقييم مسيء',
    status: 'HIDDEN',
    hidden_at: '2026-11-23T10:00:00+00:00',
    hidden_by: STAFF_ID,
    hidden_reason_code: 'ABUSE',
    hidden_reason_text: 'ألفاظ مسيئة',
    created_at: '2026-11-22T08:00:00+00:00',
    ...over,
  })
}

export function appealRow(over: Row = {}): Row {
  return {
    id: APPEAL_OPEN,
    rating_id: R1,
    seller_id: SELLER_ID,
    reason: 'لم أتعامل مع هذا المقيّم أبدًا',
    status: ratingAppealed.status,
    decision_note: null,
    decided_by: null,
    decided_at: null,
    created_at: '2026-11-23T05:00:00+00:00',
    ...over,
  }
}

export function decidedAppealRow(over: Row = {}): Row {
  return appealRow({
    id: APPEAL_DONE,
    rating_id: R3,
    reason: 'اعتراض قديم',
    status: DECIDED_FIXTURE.status,
    decision_note: 'التقييم مبني على تعامل فعلي',
    decided_by: STAFF_ID,
    decided_at: '2026-11-23T09:00:00+00:00',
    created_at: '2026-11-22T05:00:00+00:00',
    ...over,
  })
}

export const PROFILES: Row[] = [
  { id: RATER_ID, display_name: pr.rater_display_name },
  { id: SELLER_ID, display_name: 'معلن تجريبي' },
]

export const REASONS: Row[] = [
  { code: 'UNFAIR_RATING', label_ar: 'تقييم غير مبني على تعامل فعلي', applies_to: ['RATING_HIDE'], requires_note: false, sort_order: 96, is_active: true },
  { code: 'ABUSE', label_ar: 'إساءة', applies_to: ['LISTING_HIDE', 'COMMENT_HIDE', 'RATING_HIDE'], requires_note: false, sort_order: 40, is_active: true },
  { code: 'OTHER', label_ar: 'أخرى', applies_to: ['LISTING_HIDE', 'ACCOUNT_SUSPEND', 'COMMENT_HIDE', 'RATING_HIDE'], requires_note: true, sort_order: 1000, is_active: true },
  { code: 'DUP_ONLY', label_ar: 'سبب للإعلانات فقط', applies_to: ['LISTING_HIDE'], requires_note: false, sort_order: 5, is_active: true },
]

export const REPLY_BODY = pr.reply_body
