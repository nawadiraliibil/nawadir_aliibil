// أنواع ميزة البلاغات. صف الجدول من الأنواع المولدة، وأشكال jsonb من
// supabase/migrations/20261123130000_reports.sql و20261123120000_blocks_comments.sql
// ومطابقة لـcontracts/fixtures/admin-report-*.json.
import type { Database } from '@contracts/generated/database.types'

export type ReportRow = Database['public']['Tables']['reports']['Row']

export type ReportStatus = 'OPEN' | 'IN_REVIEW' | 'CLOSED'
export type ReportTargetType = 'LISTING' | 'ACCOUNT' | 'MESSAGE' | 'COMMENT' | 'RATING'
export type ReportCloseReason = 'ACTION_TAKEN' | 'NO_VIOLATION' | 'DUPLICATE' | 'INVALID'

/** أعمدة صف القائمة. */
export type ReportListRow = Pick<ReportRow, 'id' | 'ref' | 'status' | 'target_type' | 'target_id' | 'reason' | 'assigned_to' | 'created_at'>

/** رد admin_assign_report (contracts/fixtures/admin-report-assigned.json). */
export interface AssignReportResult {
  report_id: string
  status: 'IN_REVIEW'
  assigned_to: string
}

/** رد admin_set_report_status. */
export interface SetReportStatusResult {
  report_id: string
  status: 'OPEN' | 'IN_REVIEW'
}

/** رد admin_close_report (contracts/fixtures/admin-report-closed.json). */
export interface CloseReportResult {
  report_id: string
  status: 'CLOSED'
  close_reason: ReportCloseReason
}

/**
 * عنصر من الدليل: رسالة (sender_id) في سياق محدود حتى ثلاث قبلها وثلاث بعدها،
 * أو الرد نفسه (author_id). is_reported يميز العنصر المبلغ عنه.
 */
export interface EvidenceItem {
  id: string
  body: string
  created_at: string
  is_reported: boolean
  sender_id?: string
  author_id?: string
}

/** رد admin_get_report_evidence (contracts/fixtures/admin-report-evidence.json). */
export interface ReportEvidence {
  report_id: string
  target_type: 'MESSAGE' | 'COMMENT'
  items: EvidenceItem[]
}

export type CommentState = 'HIDDEN' | 'VISIBLE' | 'DELETED'

/** رد admin_hide_comment وadmin_unhide_comment. */
export interface CommentModerationResult {
  comment_id: string
  state: CommentState
}
