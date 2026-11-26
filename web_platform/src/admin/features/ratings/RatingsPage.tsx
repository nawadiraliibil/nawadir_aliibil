import { useRef, type KeyboardEvent } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router'
import { formatDateTime } from '@admin/lib/format'
import { label } from '@admin/lib/labels'
import { Badge, DataTable, EmptyState, ErrorState, LoadMore, Loading, PageHeader, SelectField, type Column } from '@admin/ui'
import { useAppeals, useDisplayNames, useRatings, useRatingScores, useReasonLabels } from './api'
import { APPEAL_FILTER_STATUSES, APPEAL_STATUS_LABELS, RATING_FILTER_STATUSES, RATING_STATUS_LABELS, appealStatusTone, ratingStatusTone } from './labels'
import { PersonName, Stars, excerpt } from './parts'
import type { AppealListItem, RatingListItem } from './types'
import './ratings.css'

type TabKey = 'appeals' | 'ratings'
const TABS: Array<{ key: TabKey; label: string }> = [
  { key: 'appeals', label: 'الاعتراضات' },
  { key: 'ratings', label: 'التقييمات' },
]
const ALL = 'ALL'

function detailPath(ratingId: string) {
  return `/admin/ratings/${ratingId}`
}

/** التقييمات والاعتراضات (AD-FR-036). المسار محمي بـratings.moderate. */
export default function RatingsPage() {
  const [params, setParams] = useSearchParams()
  const tab: TabKey = params.get('tab') === 'ratings' ? 'ratings' : 'appeals'
  const tabRefs = useRef<Array<HTMLButtonElement | null>>([])

  function selectTab(key: TabKey) {
    setParams(key === 'appeals' ? {} : { tab: key }, { replace: true })
  }

  function onTabKey(e: KeyboardEvent<HTMLButtonElement>, index: number) {
    // RTL: السهم الأيسر للتالي والأيمن للسابق.
    let next = index
    if (e.key === 'ArrowLeft') next = (index + 1) % TABS.length
    else if (e.key === 'ArrowRight') next = (index - 1 + TABS.length) % TABS.length
    else if (e.key === 'Home') next = 0
    else if (e.key === 'End') next = TABS.length - 1
    else return
    e.preventDefault()
    const t = TABS[next]
    if (!t) return
    selectTab(t.key)
    tabRefs.current[next]?.focus()
  }

  return (
    <div className="page">
      <PageHeader
        title="التقييمات والاعتراضات"
        description="إخفاء التقييمات المخالفة بسبب مسجل، وقرار اعتراضات المعلنين. الاعتراض وحده لا يخفي التقييم."
      />
      <div className="tabs" role="tablist" aria-label="أقسام التقييمات">
        {TABS.map((t, i) => (
          <button
            key={t.key}
            ref={(el) => {
              tabRefs.current[i] = el
            }}
            type="button"
            role="tab"
            id={`ratings-tab-${t.key}`}
            aria-selected={tab === t.key}
            aria-controls={`ratings-panel-${t.key}`}
            tabIndex={tab === t.key ? 0 : -1}
            className="tab"
            onClick={() => selectTab(t.key)}
            onKeyDown={(e) => onTabKey(e, i)}
          >
            {t.label}
          </button>
        ))}
      </div>
      <div role="tabpanel" id={`ratings-panel-${tab}`} aria-labelledby={`ratings-tab-${tab}`} className="stack">
        {tab === 'appeals' ? <AppealsTab /> : <RatingsTab />}
      </div>
    </div>
  )
}

function useStatusParam(defaultValue: string): [string, (v: string) => void] {
  const [params, setParams] = useSearchParams()
  const value = params.get('status') ?? defaultValue
  return [
    value,
    (v: string) => {
      const next = new URLSearchParams(params)
      if (v === defaultValue) next.delete('status')
      else next.set('status', v)
      setParams(next, { replace: true })
    },
  ]
}

function AppealsTab() {
  const navigate = useNavigate()
  const [status, setStatus] = useStatusParam('OPEN')
  const filter = status === ALL ? '' : status
  const q = useAppeals(filter)
  const rows = q.data?.pages.flat() ?? []
  const scores = useRatingScores(rows.map((r) => r.rating_id))
  const names = useDisplayNames(rows.map((r) => r.seller_id))

  const columns: Column<AppealListItem>[] = [
    {
      key: 'score',
      header: 'التقييم',
      render: (r) => {
        const s = scores.data?.get(r.rating_id)
        return s ? <Stars score={s.score} /> : <span className="muted">—</span>
      },
    },
    { key: 'reason', header: 'سبب الاعتراض', render: (r) => <span title={r.reason}>{excerpt(r.reason)}</span> },
    { key: 'seller', header: 'المعلن', render: (r) => <PersonName id={r.seller_id} names={names.data} /> },
    { key: 'status', header: 'الحالة', render: (r) => <Badge tone={appealStatusTone(r.status)}>{label(APPEAL_STATUS_LABELS, r.status)}</Badge> },
    { key: 'created', header: 'تاريخ الاعتراض', render: (r) => formatDateTime(r.created_at) },
    { key: 'decided', header: 'تاريخ القرار', render: (r) => formatDateTime(r.decided_at) },
    {
      key: 'open',
      header: <span className="sr-only">فتح</span>,
      className: 'cell-actions',
      render: (r) => (
        <Link to={detailPath(r.rating_id)} onClick={(e) => e.stopPropagation()}>
          فتح التقييم
        </Link>
      ),
    },
  ]

  return (
    <>
      <div className="filters">
        <SelectField label="حالة الاعتراض" value={status} onChange={(e) => setStatus(e.target.value)}>
          {APPEAL_FILTER_STATUSES.map((s) => (
            <option key={s} value={s}>
              {label(APPEAL_STATUS_LABELS, s)}
            </option>
          ))}
          <option value={ALL}>الكل</option>
        </SelectField>
      </div>
      {q.isPending ? (
        <Loading />
      ) : q.isError && !q.data ? (
        <ErrorState error={q.error} onRetry={() => void q.refetch()} />
      ) : (
        <>
          <DataTable
            caption="الاعتراضات"
            columns={columns}
            rows={rows}
            rowKey={(r) => r.id}
            onRowClick={(r) => navigate(detailPath(r.rating_id))}
            empty={<EmptyState title={filter === 'OPEN' ? 'لا اعتراضات مفتوحة' : 'لا اعتراضات مطابقة'} />}
          />
          {q.isFetchNextPageError && <ErrorState title="تعذر تحميل الصفحة التالية" error={q.error} onRetry={() => void q.fetchNextPage()} />}
          <LoadMore hasMore={Boolean(q.hasNextPage) && !q.isFetchNextPageError} loading={q.isFetchingNextPage} onClick={() => void q.fetchNextPage()} />
        </>
      )}
    </>
  )
}

function RatingsTab() {
  const navigate = useNavigate()
  const [status, setStatus] = useStatusParam(ALL)
  const filter = status === ALL ? '' : status
  const q = useRatings(filter)
  const rows = q.data?.pages.flat() ?? []
  const names = useDisplayNames(rows.flatMap((r) => [r.rater_id, r.seller_id]))
  const reasons = useReasonLabels(rows.map((r) => r.hidden_reason_code))

  const columns: Column<RatingListItem>[] = [
    { key: 'score', header: 'الدرجة', render: (r) => <Stars score={r.score} /> },
    { key: 'body', header: 'النص', render: (r) => <span title={r.body ?? undefined}>{excerpt(r.body)}</span> },
    { key: 'rater', header: 'المقيّم', render: (r) => <PersonName id={r.rater_id} names={names.data} /> },
    { key: 'seller', header: 'المعلن', render: (r) => <PersonName id={r.seller_id} names={names.data} /> },
    { key: 'status', header: 'الحالة', render: (r) => <Badge tone={ratingStatusTone(r.status)}>{label(RATING_STATUS_LABELS, r.status)}</Badge> },
    {
      key: 'created',
      header: 'الإنشاء / التعديل',
      render: (r) => (
        <>
          <div>{formatDateTime(r.created_at)}</div>
          {r.edited_at && <div className="muted small">عُدل: {formatDateTime(r.edited_at)}</div>}
        </>
      ),
    },
    {
      key: 'hidden',
      header: 'سبب الإخفاء',
      render: (r) =>
        r.status === 'HIDDEN' && r.hidden_reason_code ? (
          <>
            <div>{reasons.data?.get(r.hidden_reason_code) ?? r.hidden_reason_code}</div>
            {r.hidden_reason_text && <div className="muted small">{excerpt(r.hidden_reason_text, 60)}</div>}
          </>
        ) : (
          <span className="muted">—</span>
        ),
    },
    {
      key: 'open',
      header: <span className="sr-only">فتح</span>,
      className: 'cell-actions',
      render: (r) => (
        <Link to={detailPath(r.id)} onClick={(e) => e.stopPropagation()}>
          التفاصيل
        </Link>
      ),
    },
  ]

  return (
    <>
      <div className="filters">
        <SelectField label="حالة التقييم" value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value={ALL}>الكل</option>
          {RATING_FILTER_STATUSES.map((s) => (
            <option key={s} value={s}>
              {label(RATING_STATUS_LABELS, s)}
            </option>
          ))}
        </SelectField>
      </div>
      {q.isPending ? (
        <Loading />
      ) : q.isError && !q.data ? (
        <ErrorState error={q.error} onRetry={() => void q.refetch()} />
      ) : (
        <>
          <DataTable
            caption="التقييمات"
            columns={columns}
            rows={rows}
            rowKey={(r) => r.id}
            onRowClick={(r) => navigate(detailPath(r.id))}
            empty={<EmptyState title="لا تقييمات مطابقة" />}
          />
          {q.isFetchNextPageError && <ErrorState title="تعذر تحميل الصفحة التالية" error={q.error} onRetry={() => void q.fetchNextPage()} />}
          <LoadMore hasMore={Boolean(q.hasNextPage) && !q.isFetchNextPageError} loading={q.isFetchingNextPage} onClick={() => void q.fetchNextPage()} />
        </>
      )}
    </>
  )
}
