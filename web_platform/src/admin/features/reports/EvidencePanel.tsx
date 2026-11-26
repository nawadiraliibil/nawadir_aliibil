import { useEffect, useRef, useState } from 'react'
import { useAuth } from '@admin/auth/AuthContext'
import { formatDateTime, shortId } from '@admin/lib/format'
import { Alert, Badge, Button, Card, EmptyState, ErrorState, Loading } from '@admin/ui'
import { getReportEvidence } from './api'
import type { ReportEvidence, ReportRow } from './types'

/**
 * الدليل المقيد (AD-FR-036): الرسالة المبلغ عنها وسياق محدود، أو الرد نفسه.
 * لا يطلب إلا بنقرة لأن كل اطلاع يسجل، ولا يخزن في ذاكرة الاستعلامات: يبقى في
 * حالة المكون ويزول بمغادرة الصفحة.
 */
export function EvidencePanel({ report }: { report: ReportRow }) {
  const { can, handleApiError } = useAuth()
  const allowed = can('evidence.read')
  const [evidence, setEvidence] = useState<ReportEvidence | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<unknown>(null)
  const alive = useRef(true)

  useEffect(() => {
    alive.current = true
    return () => {
      alive.current = false
    }
  }, [])

  async function load() {
    if (loading) return
    setLoading(true)
    setError(null)
    try {
      const data = await getReportEvidence(report.id)
      if (alive.current) setEvidence(data)
    } catch (err) {
      handleApiError(err)
      if (alive.current) setError(err)
    } finally {
      if (alive.current) setLoading(false)
    }
  }

  const isMessage = report.target_type === 'MESSAGE'
  const title = isMessage ? 'الدليل: الرسالة المبلغ عنها' : 'الدليل: الرد المبلغ عنه'

  if (!allowed) {
    return (
      <Card title={title}>
        <Alert tone="info">الاطلاع على الدليل يتطلب قدرة «الاطلاع على أدلة البلاغات».</Alert>
      </Card>
    )
  }

  return (
    <Card
      title={title}
      actions={
        evidence ? (
          <Button size="sm" variant="ghost" onClick={() => setEvidence(null)}>
            إخفاء الدليل
          </Button>
        ) : null
      }
    >
      {!evidence && (
        <div className="stack">
          <Alert tone="warning" title="الاطلاع مسجل">
            {isMessage
              ? 'المحادثات خاصة. يعرض الدليل الرسالة المبلغ عنها وحتى ثلاث رسائل قبلها وثلاث بعدها فقط. '
              : 'يعرض الدليل نص الرد المبلغ عنه. '}
            كل اطلاع يسجل باسمك في سجل الاطلاع على الأدلة وفي سجل الإجراءات.
          </Alert>
          {error != null && !loading ? (
            <ErrorState error={error} onRetry={() => void load()} title="تعذر تحميل الدليل" />
          ) : (
            <div>
              <Button variant="primary" onClick={() => void load()} loading={loading}>
                عرض الدليل
              </Button>
            </div>
          )}
          {loading && <Loading label="جارٍ تحميل الدليل…" />}
        </div>
      )}
      {evidence && <EvidenceList evidence={evidence} targetUserId={report.target_user_id} reporterId={report.reporter_id} />}
    </Card>
  )
}

function EvidenceList({ evidence, targetUserId, reporterId }: { evidence: ReportEvidence; targetUserId: string; reporterId: string }) {
  if (evidence.items.length === 0) {
    return <EmptyState title="المحتوى غير متاح">لم يعد المحتوى المبلغ عنه موجودًا.</EmptyState>
  }
  const isMessage = evidence.target_type === 'MESSAGE'
  return (
    <ol className="timeline" aria-label={isMessage ? 'الرسائل' : 'الرد'}>
      {evidence.items.map((item) => {
        const who = item.sender_id ?? item.author_id ?? null
        const role = !who ? '' : who === targetUserId ? ' (صاحب المحتوى المبلغ عنه)' : who === reporterId ? ' (مقدم البلاغ)' : ''
        return (
          <li key={item.id} aria-current={item.is_reported ? 'true' : undefined}>
            <div className="row small">
              {item.is_reported && <Badge tone="danger">المبلغ عنه</Badge>}
              <span>
                {isMessage ? 'المرسل: ' : 'الكاتب: '}
                <span className="ltr mono" title={who ?? undefined}>
                  {shortId(who)}
                </span>
                {role}
              </span>
              <span className="muted">{formatDateTime(item.created_at)}</span>
            </div>
            <p className="pre">{item.body}</p>
          </li>
        )
      })}
    </ol>
  )
}
