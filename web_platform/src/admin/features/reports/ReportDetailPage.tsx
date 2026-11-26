import { useState, type ReactNode } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Link, useParams } from 'react-router'
import { useAuth } from '@admin/auth/AuthContext'
import { errorMessage, toApiError } from '@admin/lib/errors'
import { formatDateTime, shortId } from '@admin/lib/format'
import { label, REPORT_CLOSE_REASON_LABELS, REPORT_REASON_LABELS, REPORT_STATUS_LABELS, REPORT_TARGET_LABELS } from '@admin/lib/labels'
import { Alert, Badge, Button, Card, ConfirmDialog, EmptyState, ErrorState, KeyValue, Loading, PageHeader, reportStatusTone, useNotify } from '@admin/ui'
import { assignReport, closeReport, fetchReport, REPORTS_KEY, reportDetailKey, setReportStatus, type CloseReportInput } from './api'
import { AssignReportDialog } from './AssignReportDialog'
import { CloseReportDialog } from './CloseReportDialog'
import { CommentModeration } from './CommentModeration'
import { EvidencePanel } from './EvidencePanel'
import { staffLabel } from './labels'
import type { ReportRow } from './types'

const LISTING_CAPS = ['listings.hide', 'listings.review'] as const
const CRUMB_ROOT = { label: 'البلاغات', to: '/admin/reports' }

type DialogName = 'assign' | 'status' | 'close' | null

/** تفاصيل البلاغ وإدارته (AD-FR-019) والدليل المقيد (AD-FR-036) وإشراف الرد (AD-FR-032). */
export default function ReportDetailPage() {
  const { reportId = '' } = useParams()
  const { whoami, can, handleApiError } = useAuth()
  const me = whoami?.user_id ?? null
  const queryClient = useQueryClient()
  const notify = useNotify()
  const [dialog, setDialog] = useState<DialogName>(null)

  const query = useQuery({ queryKey: reportDetailKey(reportId), queryFn: () => fetchReport(reportId) })

  async function refreshReports() {
    await queryClient.invalidateQueries({ queryKey: REPORTS_KEY })
  }

  /** أخطاء الإجراءات: معالجة الجلسة، وإعادة تحميل البلاغ عند تغير حالته. لا إعادة محاولة تلقائية. */
  function onActionError(err: unknown) {
    const e = toApiError(err)
    handleApiError(e)
    if (e.code === 'INVALID_STATE' || e.code === 'NOT_FOUND') void queryClient.invalidateQueries({ queryKey: REPORTS_KEY })
    return e
  }

  const assignSelf = useMutation({
    mutationFn: () => assignReport(reportId),
    retry: false,
    onSuccess: async () => {
      await refreshReports()
      notify.success('أسند البلاغ إليك وصار قيد المراجعة.')
    },
    onError: (err) => notify.error(errorMessage(onActionError(err))),
  })

  if (query.isPending) {
    return (
      <div className="page">
        <PageHeader title="تفاصيل البلاغ" crumbs={[CRUMB_ROOT, { label: 'تفاصيل البلاغ' }]} />
        <Loading label="جارٍ تحميل البلاغ…" />
      </div>
    )
  }

  if (query.isError) {
    const notFound = toApiError(query.error).code === 'NOT_FOUND'
    return (
      <div className="page">
        <PageHeader title="تفاصيل البلاغ" crumbs={[CRUMB_ROOT, { label: 'تفاصيل البلاغ' }]} />
        {notFound ? (
          <EmptyState title="البلاغ غير موجود">
            <Link to="/admin/reports">العودة إلى البلاغات</Link>
          </EmptyState>
        ) : (
          <ErrorState error={query.error} onRetry={() => void query.refetch()} />
        )}
      </div>
    )
  }

  const report = query.data
  const closed = report.status === 'CLOSED'
  const canHandle = can('reports.handle')
  const hasEvidence = report.target_type === 'MESSAGE' || report.target_type === 'COMMENT'
  const nextStatus = report.status === 'OPEN' ? 'IN_REVIEW' : 'OPEN'

  async function submitAssign(assignee: string) {
    try {
      await assignReport(reportId, assignee)
    } catch (err) {
      throw onActionError(err)
    }
    await refreshReports()
    notify.success('أسند البلاغ وصار قيد المراجعة.')
  }

  async function submitStatus(note: string | undefined) {
    try {
      await setReportStatus(reportId, nextStatus, note)
    } catch (err) {
      throw onActionError(err)
    }
    await refreshReports()
    notify.success(nextStatus === 'OPEN' ? 'أعيد فتح البلاغ.' : 'صار البلاغ قيد المراجعة.')
  }

  async function submitClose(input: CloseReportInput) {
    try {
      await closeReport(reportId, input)
    } catch (err) {
      throw onActionError(err)
    }
    await refreshReports()
    notify.success('أغلق البلاغ وأُشعر المبلغ.')
  }

  return (
    <div className="page">
      <PageHeader
        title={`بلاغ ${report.ref}`}
        crumbs={[CRUMB_ROOT, { label: report.ref }]}
        description={
          <span className="row">
            <Badge tone={reportStatusTone(report.status)}>{label(REPORT_STATUS_LABELS, report.status)}</Badge>
            <span>{`${label(REPORT_TARGET_LABELS, report.target_type)} — ${label(REPORT_REASON_LABELS, report.reason)}`}</span>
          </span>
        }
      />

      {closed && <Alert tone="info">البلاغ مغلق ولا يقبل إسنادًا أو تغيير حالة.</Alert>}

      <div className="stack">
        <Card title="تفاصيل البلاغ">
          <KeyValue items={detailItems(report, me, can)} />
        </Card>

        {canHandle && !closed && (
          <Card title="إدارة البلاغ">
            <div className="stack">
              <p className="muted small">
                {report.assigned_to ? `البلاغ مسند إلى: ${staffLabel(report.assigned_to, me)}.` : 'البلاغ غير مسند بعد. الإسناد يجعله «قيد المراجعة».'}
              </p>
              <div className="row">
                {report.assigned_to !== me && (
                  <Button variant="primary" onClick={() => assignSelf.mutate()} loading={assignSelf.isPending}>
                    إسناد إليّ
                  </Button>
                )}
                <Button onClick={() => setDialog('assign')}>إسناد إلى موظف آخر</Button>
                <Button onClick={() => setDialog('status')}>{nextStatus === 'IN_REVIEW' ? 'تحويل إلى قيد المراجعة' : 'إعادة فتح البلاغ'}</Button>
                <Button variant="danger" onClick={() => setDialog('close')}>
                  إغلاق البلاغ
                </Button>
              </div>
            </div>
          </Card>
        )}

        {closed && (
          <Card title="قرار الإغلاق">
            <KeyValue
              items={[
                { label: 'سبب الإغلاق', value: label(REPORT_CLOSE_REASON_LABELS, report.close_reason) },
                { label: 'أغلقه', value: <StaffId id={report.closed_by} me={me} empty="—" /> },
                { label: 'تاريخ الإغلاق', value: formatDateTime(report.closed_at) },
                { label: 'الرد المرسل إلى المبلغ', value: report.response_text ? <p className="pre">{report.response_text}</p> : 'لم يرسل رد', wide: true },
                { label: 'ملاحظة داخلية', value: report.internal_note ? <p className="pre">{report.internal_note}</p> : null, wide: true },
              ]}
            />
          </Card>
        )}

        {hasEvidence && <EvidencePanel key={report.id} report={report} />}

        {report.target_type === 'COMMENT' && <CommentModeration key={report.target_id} commentId={report.target_id} />}
      </div>

      {canHandle && (
        <>
          <AssignReportDialog open={dialog === 'assign'} onClose={() => setDialog(null)} onSubmit={submitAssign} />
          <ConfirmDialog
            open={dialog === 'status'}
            title={nextStatus === 'IN_REVIEW' ? 'تحويل البلاغ إلى قيد المراجعة' : 'إعادة فتح البلاغ'}
            message={nextStatus === 'IN_REVIEW' ? 'يصير البلاغ «قيد المراجعة» دون تغيير المسؤول عنه.' : 'يعود البلاغ «مفتوحًا» دون تغيير المسؤول عنه.'}
            confirmLabel={nextStatus === 'IN_REVIEW' ? 'تحويل' : 'إعادة الفتح'}
            noteLabel="ملاحظة داخلية (اختيارية)"
            noteHint="للموظفين فقط. إن كتبت تحل محل الملاحظة الداخلية الحالية للبلاغ."
            onClose={() => setDialog(null)}
            onConfirm={submitStatus}
          />
          <CloseReportDialog open={dialog === 'close'} onClose={() => setDialog(null)} onSubmit={submitClose} />
        </>
      )}
    </div>
  )
}

function StaffId({ id, me, empty = 'غير مسند' }: { id: string | null; me: string | null; empty?: string }) {
  const text = staffLabel(id, me, empty)
  return id && id !== me ? (
    <span className="ltr mono" title={id}>
      {text}
    </span>
  ) : (
    <>{text}</>
  )
}

function IdLink({ id, to }: { id: string; to: string | null }) {
  return to ? (
    <Link to={to} className="ltr mono" title={id}>
      {shortId(id)}
    </Link>
  ) : (
    <span className="ltr mono" title={id}>
      {shortId(id)}
    </span>
  )
}

type Can = ReturnType<typeof useAuth>['can']

function detailItems(report: ReportRow, me: string | null, can: Can): Array<{ label: string; value: ReactNode; wide?: boolean }> {
  const canListings = can(LISTING_CAPS)
  const canAccounts = can('accounts.manage')
  const accountTo = (id: string) => (canAccounts ? `/admin/accounts/${id}` : null)
  const listingTo = (id: string) => (canListings ? `/admin/listings/${id}` : null)

  let target: ReactNode
  if (report.target_type === 'LISTING') {
    const id = report.target_id || report.listing_id || ''
    target = <IdLink id={id} to={listingTo(id)} />
  } else if (report.target_type === 'ACCOUNT') {
    target = <IdLink id={report.target_user_id} to={accountTo(report.target_user_id)} />
  } else if (report.target_type === 'RATING') {
    // التقييم المبلغ عنه يدار من صفحة التقييم (إخفاء/إظهار بقدرة ratings.moderate).
    target = <IdLink id={report.target_id} to={can('ratings.moderate') ? `/admin/ratings/${report.target_id}` : null} />
  } else {
    target = (
      <span>
        <IdLink id={report.target_id} to={null} /> <span className="muted small">(المحتوى في قسم الدليل)</span>
      </span>
    )
  }

  const items: Array<{ label: string; value: ReactNode; wide?: boolean }> = [
    { label: 'الرقم المرجعي', value: <span className="ltr mono">{report.ref}</span> },
    { label: 'الحالة', value: <Badge tone={reportStatusTone(report.status)}>{label(REPORT_STATUS_LABELS, report.status)}</Badge> },
    { label: 'نوع الهدف', value: label(REPORT_TARGET_LABELS, report.target_type) },
    { label: 'الهدف', value: target },
    { label: 'صاحب المحتوى المبلغ عنه', value: <IdLink id={report.target_user_id} to={accountTo(report.target_user_id)} /> },
  ]
  if (report.listing_id && report.target_type !== 'LISTING') {
    items.push({ label: 'الإعلان المرتبط', value: <IdLink id={report.listing_id} to={listingTo(report.listing_id)} /> })
  }
  items.push(
    { label: 'سبب البلاغ', value: label(REPORT_REASON_LABELS, report.reason) },
    { label: 'مقدم البلاغ', value: <IdLink id={report.reporter_id} to={accountTo(report.reporter_id)} /> },
    { label: 'المسؤول', value: <StaffId id={report.assigned_to} me={me} /> },
    { label: 'تاريخ البلاغ', value: formatDateTime(report.created_at) },
    { label: 'آخر تحديث', value: formatDateTime(report.updated_at) },
    { label: 'وصف المبلغ', value: report.description ? <p className="pre">{report.description}</p> : 'لا وصف', wide: true },
  )
  if (report.status !== 'CLOSED') {
    items.push({ label: 'ملاحظة داخلية', value: report.internal_note ? <p className="pre">{report.internal_note}</p> : null, wide: true })
  }
  return items
}
