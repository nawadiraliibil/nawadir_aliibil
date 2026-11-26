// القراءة من جدول reports (RLS: reports.handle) والكتابة عبر دوال admin_* فقط.
import { getSupabase } from '@admin/lib/supabase'
import { rpc, unwrap } from '@admin/lib/rpc'
import { ApiError } from '@admin/lib/errors'
import type {
  AssignReportResult,
  CloseReportResult,
  CommentModerationResult,
  ReportCloseReason,
  ReportEvidence,
  ReportListRow,
  ReportRow,
} from './types'

export const REPORTS_KEY = ['admin', 'reports'] as const
export const reportDetailKey = (id: string) => ['admin', 'reports', 'detail', id] as const

export const PAGE_SIZE = 25

/** مرشح الحالة: ACTIVE (غير المغلقة، الافتراضي) أو حالة بعينها أو الكل. */
export type StatusFilter = 'ACTIVE' | 'OPEN' | 'IN_REVIEW' | 'CLOSED' | 'ALL'

export interface ReportFilters {
  status: StatusFilter
  target: string
  reason: string
  /** معرف الموظف عند «المسندة إليّ». */
  assignedTo: string | null
  page: number
}

export interface ReportPage {
  rows: ReportListRow[]
  total: number
}

const LIST_COLUMNS = 'id, ref, status, target_type, target_id, reason, assigned_to, created_at'

export async function fetchReports(f: ReportFilters): Promise<ReportPage> {
  let q = getSupabase().from('reports').select(LIST_COLUMNS, { count: 'exact' })
  if (f.status === 'ACTIVE') q = q.in('status', ['OPEN', 'IN_REVIEW'])
  else if (f.status !== 'ALL') q = q.eq('status', f.status)
  if (f.target) q = q.eq('target_type', f.target)
  if (f.reason) q = q.eq('reason', f.reason)
  if (f.assignedTo) q = q.eq('assigned_to', f.assignedTo)
  const from = (f.page - 1) * PAGE_SIZE
  const res = await q.order('created_at', { ascending: false }).order('id', { ascending: false }).range(from, from + PAGE_SIZE - 1)
  const rows = unwrap(res) as ReportListRow[]
  return { rows, total: res.count ?? rows.length }
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export function isUuid(value: string): boolean {
  return UUID_RE.test(value.trim())
}

export async function fetchReport(id: string): Promise<ReportRow> {
  // معرف غير صالح يرفضه Postgres بخطأ نوع؛ يعامل كغير موجود.
  if (!isUuid(id)) throw new ApiError('NOT_FOUND', { resource: 'report' })
  const res = await getSupabase().from('reports').select('*').eq('id', id).maybeSingle()
  return unwrap(res) as ReportRow
}

/** إسناد البلاغ؛ دون assignee يسند للموظف الحالي (coalesce في الدالة). */
export async function assignReport(reportId: string, assignee?: string): Promise<AssignReportResult> {
  return (await rpc('admin_assign_report', assignee ? { p_report_id: reportId, p_assignee: assignee } : { p_report_id: reportId })) as AssignReportResult
}

export async function setReportStatus(reportId: string, status: 'OPEN' | 'IN_REVIEW', note: string | undefined) {
  return rpc('admin_set_report_status', { p_report_id: reportId, p_status: status, p_note: note })
}

export interface CloseReportInput {
  closeReason: ReportCloseReason
  responseText: string | undefined
  internalNote: string | undefined
}

export async function closeReport(reportId: string, input: CloseReportInput): Promise<CloseReportResult> {
  return (await rpc('admin_close_report', {
    p_report_id: reportId,
    p_close_reason: input.closeReason,
    p_response_text: input.responseText,
    p_internal_note: input.internalNote,
  })) as CloseReportResult
}

/** كل استدعاء يسجل في report_evidence_access وسجل الإجراءات؛ لا يستدعى إلا بنقرة. */
export async function getReportEvidence(reportId: string): Promise<ReportEvidence> {
  return (await rpc('admin_get_report_evidence', { p_report_id: reportId })) as ReportEvidence
}

export async function hideComment(commentId: string, reasonCode: string, reasonText: string | undefined): Promise<CommentModerationResult> {
  return (await rpc('admin_hide_comment', { p_comment_id: commentId, p_reason_code: reasonCode, p_reason_text: reasonText })) as CommentModerationResult
}

export async function unhideComment(commentId: string, note: string | undefined): Promise<CommentModerationResult> {
  return (await rpc('admin_unhide_comment', { p_comment_id: commentId, p_note: note })) as CommentModerationResult
}
