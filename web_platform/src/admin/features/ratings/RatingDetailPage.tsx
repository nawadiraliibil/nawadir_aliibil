import { useState } from 'react'
import { Link, useParams } from 'react-router'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useCan } from '@admin/auth/AuthContext'
import { toApiError } from '@admin/lib/errors'
import { formatDateTime, shortId } from '@admin/lib/format'
import { label } from '@admin/lib/labels'
import { rpc } from '@admin/lib/rpc'
import { Alert, Badge, Button, Card, ConfirmDialog, EmptyState, ErrorState, KeyValue, Loading, PageHeader, ReasonDialog, useNotify, type ReasonValue } from '@admin/ui'
import { AppealDecisionDialog, type AppealDecisionValue } from './AppealDecisionDialog'
import { ratingKeys, useDisplayNames, useRatingDetail, useReasonLabels } from './api'
import { APPEAL_STATUS_LABELS, RATING_STATUS_LABELS, appealStatusTone, ratingStatusTone } from './labels'
import { PersonName, Stars } from './parts'
import type { AppealDecidedResult, RatingAppealRow, RatingDetail, RatingStatusResult } from './types'
import './ratings.css'

const CRUMBS = [{ label: 'التقييمات والاعتراضات', to: '/admin/ratings' }, { label: 'تفاصيل التقييم' }]
/** رموز تعني أن الحالة تغيرت على الخادم: نعيد التحميل ولا نعيد المحاولة. */
const STALE_CODES = new Set(['INVALID_STATE', 'VERSION_CHANGED', 'NOT_FOUND'])

export default function RatingDetailPage() {
  const { ratingId = '' } = useParams()
  const q = useRatingDetail(ratingId)

  if (q.isPending) {
    return (
      <div className="page">
        <PageHeader title="تفاصيل التقييم" crumbs={CRUMBS} />
        <Loading />
      </div>
    )
  }
  if (q.isError) {
    const notFound = toApiError(q.error).code === 'NOT_FOUND'
    return (
      <div className="page">
        <PageHeader title="تفاصيل التقييم" crumbs={CRUMBS} />
        {notFound ? (
          <EmptyState title="التقييم غير موجود">
            <p>تحقق من الرابط أو عد إلى <Link to="/admin/ratings">قائمة التقييمات</Link>.</p>
          </EmptyState>
        ) : (
          <ErrorState error={q.error} onRetry={() => void q.refetch()} />
        )}
      </div>
    )
  }
  return <RatingDetailView detail={q.data} refreshing={q.isFetching} />
}

type DialogKind = 'hide' | 'unhide' | { appeal: RatingAppealRow } | null

function RatingDetailView({ detail, refreshing }: { detail: RatingDetail; refreshing: boolean }) {
  const { rating, history, reply, appeals } = detail
  const canModerate = useCan('ratings.moderate')
  const queryClient = useQueryClient()
  const notify = useNotify()
  const [dialog, setDialog] = useState<DialogKind>(null)

  const names = useDisplayNames([rating.rater_id, rating.seller_id, rating.hidden_by, ...appeals.map((a) => a.decided_by)])
  const reasons = useReasonLabels([rating.hidden_reason_code])

  const invalidate = () => queryClient.invalidateQueries({ queryKey: ratingKeys.all })

  /** فشل الخادم: عند تغير الحالة نعيد تحميل التفاصيل، ثم نرمي ليعرض الحوار الرسالة العربية. */
  function onServerError(err: unknown): never {
    const e = toApiError(err)
    if (STALE_CODES.has(e.code)) void invalidate()
    throw e
  }

  const hide = useMutation({
    retry: false,
    mutationFn: async (v: ReasonValue) =>
      (await rpc('admin_hide_rating', { p_rating_id: rating.id, p_reason_code: v.reason_code, p_reason_text: v.reason_text })) as RatingStatusResult,
  })
  const unhide = useMutation({
    retry: false,
    mutationFn: async (note: string | undefined) => (await rpc('admin_unhide_rating', { p_rating_id: rating.id, p_note: note })) as RatingStatusResult,
  })
  const decide = useMutation({
    retry: false,
    mutationFn: async ({ appealId, v }: { appealId: string; v: AppealDecisionValue }) =>
      (await rpc('admin_decide_rating_appeal', {
        p_appeal_id: appealId,
        p_decision: v.decision,
        p_reason_code: v.reason_code,
        p_note: v.note,
      })) as AppealDecidedResult,
  })

  async function onHide(v: ReasonValue) {
    try {
      await hide.mutateAsync(v)
    } catch (err) {
      onServerError(err)
    }
    await invalidate()
    notify.success('أُخفي التقييم ولن يظهر للعامة أو في المتوسط.')
  }

  async function onUnhide(note: string | undefined) {
    try {
      await unhide.mutateAsync(note)
    } catch (err) {
      onServerError(err)
    }
    await invalidate()
    notify.success('أُعيد إظهار التقييم.')
  }

  async function onDecide(appealId: string, v: AppealDecisionValue) {
    // الرفض يبقي التقييم على حالته قبل القرار (ظاهرًا أو مخفيًا).
    const wasHidden = rating.status === 'HIDDEN'
    let res: AppealDecidedResult
    try {
      res = await decide.mutateAsync({ appealId, v })
    } catch (err) {
      onServerError(err)
    }
    await invalidate()
    notify.success(
      res.status === 'ACCEPTED' ? 'قُبل الاعتراض والتقييم مخفي الآن.' : wasHidden ? 'رُفض الاعتراض وبقي التقييم مخفيًا.' : 'رُفض الاعتراض وبقي التقييم ظاهرًا.',
    )
  }

  const hidden = rating.status === 'HIDDEN'
  const openAppeal = appeals.find((a) => a.status === 'OPEN')

  const actions = canModerate ? (
    hidden ? (
      <Button variant="secondary" onClick={() => setDialog('unhide')}>
        إعادة إظهار التقييم
      </Button>
    ) : rating.status === 'VISIBLE' ? (
      <Button variant="danger" onClick={() => setDialog('hide')}>
        إخفاء التقييم
      </Button>
    ) : null
  ) : null

  return (
    <div className="page">
      <PageHeader
        title="تفاصيل التقييم"
        crumbs={CRUMBS}
        description={<span className="mono ltr">{rating.id}</span>}
        actions={actions}
      />
      {refreshing && <p className="muted small" role="status">جارٍ التحديث…</p>}
      {openAppeal && (
        <Alert tone="warning" title="اعتراض مفتوح">
          اعترض المعلن على هذا التقييم بتاريخ {formatDateTime(openAppeal.created_at)}. الاعتراض لا يخفي التقييم حتى يقبل.
        </Alert>
      )}

      <div className="grid grid-2">
        <Card title="التقييم">
          <KeyValue
            items={[
              { label: 'الحالة', value: <Badge tone={ratingStatusTone(rating.status)}>{label(RATING_STATUS_LABELS, rating.status)}</Badge> },
              { label: 'الدرجة', value: <Stars score={rating.score} /> },
              { label: 'المقيّم', value: <PersonName id={rating.rater_id} names={names.data} /> },
              { label: 'المعلن', value: <PersonName id={rating.seller_id} names={names.data} /> },
              { label: 'تاريخ التقييم', value: formatDateTime(rating.created_at) },
              { label: 'آخر تعديل', value: rating.edited_at ? formatDateTime(rating.edited_at) : 'لم يعدل' },
              { label: 'إقرار التعامل', value: formatDateTime(rating.declaration_at) },
              { label: 'المحادثة المثبتة للأهلية', value: <span className="mono ltr" title={rating.conversation_id}>{shortId(rating.conversation_id)}</span> },
              {
                label: 'النص',
                wide: true,
                value: rating.body ? <p className="rating-body">{rating.body}</p> : <span className="muted">بلا نص</span>,
              },
            ]}
          />
        </Card>

        <div className="stack">
          {hidden && (
            <Card title="الإخفاء">
              <KeyValue
                items={[
                  { label: 'السبب', value: rating.hidden_reason_code ? (reasons.data?.get(rating.hidden_reason_code) ?? rating.hidden_reason_code) : '—' },
                  { label: 'تاريخ الإخفاء', value: formatDateTime(rating.hidden_at) },
                  { label: 'بواسطة', value: <PersonName id={rating.hidden_by} names={names.data} link={false} /> },
                  { label: 'التوضيح', wide: true, value: rating.hidden_reason_text ? <p className="rating-body">{rating.hidden_reason_text}</p> : null },
                ]}
              />
            </Card>
          )}

          <Card title="رد المعلن">
            {reply ? (
              <div className="stack">
                <p className="rating-body">{reply.body}</p>
                <p className="muted small">
                  {formatDateTime(reply.created_at)}
                  {reply.edited_at && <> — عُدل: {formatDateTime(reply.edited_at)}</>}
                </p>
              </div>
            ) : (
              <EmptyState title="لا رد من المعلن" />
            )}
          </Card>
        </div>
      </div>

      <Card title="الاعتراضات">
        {appeals.length === 0 ? (
          <EmptyState title="لا اعتراض على هذا التقييم" />
        ) : (
          <ul className="timeline" aria-label="اعتراضات التقييم">
            {appeals.map((a) => (
              <li key={a.id}>
                <div className="spread">
                  <Badge tone={appealStatusTone(a.status)}>{label(APPEAL_STATUS_LABELS, a.status)}</Badge>
                  {a.status === 'OPEN' && canModerate && (
                    <Button variant="primary" size="sm" onClick={() => setDialog({ appeal: a })}>
                      قرار الاعتراض
                    </Button>
                  )}
                </div>
                <KeyValue
                  items={[
                    { label: 'سبب الاعتراض', wide: true, value: <p className="rating-body">{a.reason}</p> },
                    { label: 'تاريخ الاعتراض', value: formatDateTime(a.created_at) },
                    ...(a.status === 'OPEN'
                      ? []
                      : [
                          { label: 'القرار', value: label(APPEAL_STATUS_LABELS, a.status) },
                          { label: 'تاريخ القرار', value: formatDateTime(a.decided_at) },
                          { label: 'بواسطة', value: <PersonName id={a.decided_by} names={names.data} link={false} /> },
                          { label: 'ملاحظة القرار', wide: true, value: a.decision_note ? <p className="rating-body">{a.decision_note}</p> : null },
                        ]),
                  ]}
                />
              </li>
            ))}
          </ul>
        )}
      </Card>

      <Card title="سجل التعديلات">
        {history.length === 0 ? (
          <EmptyState title="لم يعدل التقييم" />
        ) : (
          <>
            <p className="muted small">كل صف صيغة سابقة حفظت عند تعديل المقيّم لتقييمه.</p>
            <ol className="timeline" aria-label="الصيغ السابقة">
              {history.map((h) => (
                <li key={h.id}>
                  <div className="row">
                    <Stars score={h.score} />
                    <span className="muted small">استبدلت في {formatDateTime(h.replaced_at)}</span>
                  </div>
                  {h.body ? <p className="rating-body">{h.body}</p> : <p className="muted">بلا نص</p>}
                </li>
              ))}
            </ol>
          </>
        )}
      </Card>

      <ReasonDialog
        open={dialog === 'hide'}
        action="RATING_HIDE"
        title="إخفاء التقييم"
        description="يخرج التقييم من العرض العام ومن متوسط المعلن. السبب إلزامي ويسجل في سجل الإجراءات."
        confirmLabel="إخفاء"
        onClose={() => setDialog(null)}
        onSubmit={onHide}
      />
      <ConfirmDialog
        open={dialog === 'unhide'}
        title="إعادة إظهار التقييم"
        message="يعود التقييم للعرض العام ويدخل في متوسط المعلن."
        confirmLabel="إعادة الإظهار"
        noteLabel="ملاحظة داخلية (اختياري)"
        noteHint="تسجل في سجل الإجراءات."
        onClose={() => setDialog(null)}
        onConfirm={onUnhide}
      />
      <AppealDecisionDialog
        open={typeof dialog === 'object' && dialog !== null}
        ratingHidden={hidden}
        onClose={() => setDialog(null)}
        onSubmit={(v) => (typeof dialog === 'object' && dialog !== null ? onDecide(dialog.appeal.id, v) : Promise.resolve())}
      />
    </div>
  )
}
