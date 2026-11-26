import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { Link, useNavigate, useSearchParams } from 'react-router'
import { useAuth } from '@admin/auth/AuthContext'
import { formatDateTime, formatNumber } from '@admin/lib/format'
import { label, REPORT_REASON_LABELS, REPORT_STATUS_LABELS, REPORT_TARGET_LABELS } from '@admin/lib/labels'
import { Badge, Button, CheckboxField, DataTable, EmptyState, ErrorState, Loading, PageHeader, SelectField, reportStatusTone, type Column } from '@admin/ui'
import { fetchReports, PAGE_SIZE, REPORTS_KEY, type ReportFilters, type StatusFilter } from './api'
import { staffLabel, STATUS_FILTER_LABELS, STATUS_FILTERS } from './labels'
import type { ReportListRow } from './types'

function readFilters(params: URLSearchParams, me: string | null): ReportFilters {
  const status = params.get('status')
  const target = params.get('target') ?? ''
  const reason = params.get('reason') ?? ''
  const page = Number.parseInt(params.get('page') ?? '1', 10)
  return {
    status: STATUS_FILTERS.includes(status as StatusFilter) ? (status as StatusFilter) : 'ACTIVE',
    target: Object.hasOwn(REPORT_TARGET_LABELS, target) ? target : '',
    reason: Object.hasOwn(REPORT_REASON_LABELS, reason) ? reason : '',
    assignedTo: params.get('mine') === '1' && me ? me : null,
    page: Number.isFinite(page) && page > 0 ? page : 1,
  }
}

/** قائمة البلاغات (AD-FR-019): تصفية بالحالة والنوع والسبب والإسناد، الأحدث أولًا. */
export default function ReportsPage() {
  const { whoami } = useAuth()
  const me = whoami?.user_id ?? null
  const navigate = useNavigate()
  const [params, setParams] = useSearchParams()
  const filters = readFilters(params, me)
  const mine = params.get('mine') === '1'

  const query = useQuery({
    queryKey: [...REPORTS_KEY, 'list', filters],
    queryFn: () => fetchReports(filters),
    placeholderData: keepPreviousData,
  })

  function setParam(key: string, value: string | null) {
    setParams(
      (prev) => {
        const next = new URLSearchParams(prev)
        if (value === null || value === '') next.delete(key)
        else next.set(key, value)
        if (key !== 'page') next.delete('page')
        return next
      },
      { replace: true },
    )
  }

  const isDefault = filters.status === 'ACTIVE' && !filters.target && !filters.reason && !mine
  const total = query.data?.total ?? 0
  const pages = Math.max(1, Math.ceil(total / PAGE_SIZE))
  const first = (filters.page - 1) * PAGE_SIZE + 1
  const last = Math.min(total, filters.page * PAGE_SIZE)

  const columns: Column<ReportListRow>[] = [
    {
      key: 'ref',
      header: 'الرقم المرجعي',
      render: (r) => (
        <Link to={`/admin/reports/${r.id}`} className="ltr mono" onClick={(e) => e.stopPropagation()}>
          {r.ref}
        </Link>
      ),
    },
    { key: 'target', header: 'نوع الهدف', render: (r) => label(REPORT_TARGET_LABELS, r.target_type) },
    { key: 'reason', header: 'السبب', render: (r) => label(REPORT_REASON_LABELS, r.reason) },
    { key: 'status', header: 'الحالة', render: (r) => <Badge tone={reportStatusTone(r.status)}>{label(REPORT_STATUS_LABELS, r.status)}</Badge> },
    {
      key: 'assigned',
      header: 'المسؤول',
      render: (r) => <span className={r.assigned_to && r.assigned_to !== me ? 'ltr mono' : undefined}>{staffLabel(r.assigned_to, me)}</span>,
    },
    { key: 'created', header: 'تاريخ البلاغ', render: (r) => formatDateTime(r.created_at) },
  ]

  return (
    <div className="page">
      <PageHeader title="البلاغات" description="بلاغات المستخدمين عن الإعلانات والحسابات والرسائل والردود العامة والتقييمات. البلاغ خاص ولا يكشف مقدمه للمبلغ عنه." />

      <form className="filters" role="search" aria-label="تصفية البلاغات" onSubmit={(e) => e.preventDefault()}>
        <SelectField label="الحالة" value={filters.status} onChange={(e) => setParam('status', e.target.value === 'ACTIVE' ? null : e.target.value)}>
          {STATUS_FILTERS.map((s) => (
            <option key={s} value={s}>
              {STATUS_FILTER_LABELS[s]}
            </option>
          ))}
        </SelectField>
        <SelectField label="نوع الهدف" value={filters.target} onChange={(e) => setParam('target', e.target.value)}>
          <option value="">الكل</option>
          {Object.entries(REPORT_TARGET_LABELS).map(([v, l]) => (
            <option key={v} value={v}>
              {l}
            </option>
          ))}
        </SelectField>
        <SelectField label="سبب البلاغ" value={filters.reason} onChange={(e) => setParam('reason', e.target.value)}>
          <option value="">الكل</option>
          {Object.entries(REPORT_REASON_LABELS).map(([v, l]) => (
            <option key={v} value={v}>
              {l}
            </option>
          ))}
        </SelectField>
        <CheckboxField label="المسندة إليّ" checked={mine} onChange={(e) => setParam('mine', e.target.checked ? '1' : null)} disabled={!me} />
        {!isDefault && (
          <Button variant="ghost" onClick={() => setParams(new URLSearchParams(), { replace: true })}>
            مسح المرشحات
          </Button>
        )}
      </form>

      {query.isPending ? (
        <Loading label="جارٍ تحميل البلاغات…" />
      ) : query.isError ? (
        <div className="stack">
          <ErrorState error={query.error} onRetry={() => void query.refetch()} />
          {filters.page > 1 && (
            <div>
              <Button variant="ghost" onClick={() => setParam('page', null)}>
                العودة إلى الصفحة الأولى
              </Button>
            </div>
          )}
        </div>
      ) : (
        <div className="stack">
          <DataTable
            caption="قائمة البلاغات"
            columns={columns}
            rows={query.data.rows}
            rowKey={(r) => r.id}
            onRowClick={(r) => void navigate(`/admin/reports/${r.id}`)}
            empty={
              <EmptyState title={filters.page > 1 ? 'لا نتائج في هذه الصفحة' : 'لا توجد بلاغات مطابقة'}>
                {filters.page > 1 ? (
                  <Button variant="ghost" onClick={() => setParam('page', null)}>
                    العودة إلى الصفحة الأولى
                  </Button>
                ) : (
                  !isDefault && <p className="muted">جرّب تغيير المرشحات.</p>
                )}
              </EmptyState>
            }
          />
          {total > 0 && (
            <nav className="spread" aria-label="تصفح الصفحات">
              <span className="muted small" aria-live="polite">
                {`عرض ${formatNumber(first)}–${formatNumber(last)} من ${formatNumber(total)}`}
              </span>
              <span className="row">
                <Button size="sm" disabled={filters.page <= 1 || query.isFetching} onClick={() => setParam('page', String(filters.page - 1))}>
                  السابقة
                </Button>
                <span className="small">{`صفحة ${formatNumber(filters.page)} من ${formatNumber(pages)}`}</span>
                <Button size="sm" disabled={filters.page >= pages || query.isFetching} onClick={() => setParam('page', String(filters.page + 1))}>
                  التالية
                </Button>
              </span>
            </nav>
          )}
        </div>
      )}
    </div>
  )
}
