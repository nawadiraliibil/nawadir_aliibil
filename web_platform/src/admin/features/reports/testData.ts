// بيانات اختبار البلاغات: صفوف جدول reports مبنية على أمثلة العقد
// (report-submitted.json، admin-report-evidence.json) دون بيانات حقيقية.
import submitted from '@contracts/fixtures/report-submitted.json'
import evidenceFx from '@contracts/fixtures/admin-report-evidence.json'
import { ADMIN_WHOAMI } from '@admin/test/render'
import type { ReportEvidence, ReportRow } from './types'

const reported = evidenceFx.items.find((i) => i.is_reported)!
const other = evidenceFx.items.find((i) => !i.is_reported)!

export const LISTING_ID = 'a0000000-0000-4000-8000-000000000001'
export const COMMENT_ID = 'c0000000-0000-4000-8000-000000000001'
export const OTHER_STAFF = '22222222-2222-4222-8222-222222222222'

export function reportRow(overrides: Partial<ReportRow> = {}): ReportRow {
  return {
    id: submitted.report_id,
    ref: submitted.ref,
    status: submitted.status,
    target_type: 'MESSAGE',
    target_id: reported.id,
    target_user_id: reported.sender_id,
    listing_id: LISTING_ID,
    reason: 'ABUSE',
    description: 'رسالة مسيئة بعد الاتفاق.',
    request_id: 'd0000000-0000-4000-8000-000000000001',
    reporter_id: other.sender_id,
    assigned_to: null,
    close_reason: null,
    closed_at: null,
    closed_by: null,
    response_text: null,
    internal_note: null,
    created_at: '2026-11-23T03:25:05.293087+00:00',
    updated_at: '2026-11-23T03:25:05.293087+00:00',
    ...overrides,
  }
}

export const COMMENT_REPORT = reportRow({
  id: 'b0000000-0000-4000-8000-000000000002',
  ref: 'R-1002',
  target_type: 'COMMENT',
  target_id: COMMENT_ID,
  reason: 'SPAM',
})

export const LISTING_REPORT = reportRow({
  id: 'b0000000-0000-4000-8000-000000000003',
  ref: 'R-1003',
  target_type: 'LISTING',
  target_id: LISTING_ID,
  reason: 'FRAUD',
})

export const CLOSED_REPORT = reportRow({
  id: 'b0000000-0000-4000-8000-000000000004',
  ref: 'R-1004',
  status: 'CLOSED',
  close_reason: 'NO_VIOLATION',
  closed_by: ADMIN_WHOAMI.user_id,
  assigned_to: ADMIN_WHOAMI.user_id,
  closed_at: '2026-11-23T10:00:00+00:00',
  response_text: 'راجعنا البلاغ ولم نجد مخالفة.',
  internal_note: 'محادثة عادية.',
})

export const MESSAGE_EVIDENCE = evidenceFx as ReportEvidence

export const COMMENT_EVIDENCE: ReportEvidence = {
  report_id: COMMENT_REPORT.id,
  target_type: 'COMMENT',
  items: [{ id: COMMENT_ID, author_id: COMMENT_REPORT.target_user_id, body: 'رد دعائي مكرر', created_at: '2026-11-23T05:00:00+00:00', is_reported: true }],
}

export const COMMENT_REASONS = [
  { code: 'SPAM', label_ar: 'رد مزعج أو دعائي', applies_to: ['COMMENT_HIDE'], requires_note: false, sort_order: 95, is_active: true },
  { code: 'OTHER', label_ar: 'أخرى', applies_to: ['LISTING_HIDE', 'COMMENT_HIDE'], requires_note: true, sort_order: 1000, is_active: true },
]
