import { useEffect, useState, type FormEvent } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router'
import { useInfiniteQuery } from '@tanstack/react-query'
import { ACCOUNT_STATUS_LABELS, label } from '@admin/lib/labels'
import { formatDate, formatNumber, shortId } from '@admin/lib/format'
import {
  Badge,
  Button,
  DataTable,
  EmptyState,
  ErrorState,
  LoadMore,
  Loading,
  PageHeader,
  SelectField,
  TextField,
  accountStatusTone,
  type Column,
} from '@admin/ui'
import { ACCOUNT_STATUSES, PAGE_SIZE, accountKeys, fetchProfilesPage, isUuid, parseStatus } from './api'
import { useRegionName, useSuspendReasonLabel } from './hooks'
import type { ProfileListRow } from './types'

const SEARCH_MAX = 100

/** قائمة الحسابات (AD-FR-018، القدرة accounts.manage). المرشحات في عنوان الصفحة ?status=&q=. */
export default function AccountsPage() {
  const [params, setParams] = useSearchParams()
  const navigate = useNavigate()
  const status = parseStatus(params.get('status'))
  const q = (params.get('q') ?? '').trim()
  const [draft, setDraft] = useState(q)

  useEffect(() => {
    setDraft(q)
  }, [q])

  const regionName = useRegionName()
  const reasonLabel = useSuspendReasonLabel()

  const list = useInfiniteQuery({
    queryKey: accountKeys.list(status, q),
    initialPageParam: 0,
    queryFn: ({ pageParam }) => fetchProfilesPage(status, q, pageParam),
    getNextPageParam: (last, all) => {
      const loaded = all.reduce((n, p) => n + p.rows.length, 0)
      if (last.rows.length < PAGE_SIZE) return undefined
      if (last.total !== null && loaded >= last.total) return undefined
      return all.length
    },
  })

  function updateParams(next: { status?: string | null; q?: string }) {
    const p = new URLSearchParams(params)
    if (next.status !== undefined) {
      if (next.status) p.set('status', next.status)
      else p.delete('status')
    }
    if (next.q !== undefined) {
      const v = next.q.trim()
      if (v) p.set('q', v)
      else p.delete('q')
    }
    setParams(p, { replace: true })
  }

  function onSearch(e: FormEvent) {
    e.preventDefault()
    updateParams({ q: draft })
  }

  const rows = list.data?.pages.flatMap((p) => p.rows) ?? []
  const total = list.data?.pages[0]?.total ?? null
  const filtered = Boolean(status || q)

  const columns: Column<ProfileListRow>[] = [
    {
      key: 'name',
      header: 'اسم العرض',
      render: (r) => (
        <Link to={`/admin/accounts/${r.id}`} onClick={(e) => e.stopPropagation()}>
          {r.display_name?.trim() ? r.display_name : <span className="muted">بدون اسم</span>}
        </Link>
      ),
    },
    {
      key: 'id',
      header: 'المعرف',
      render: (r) => (
        <span className="ltr mono" title={r.id}>
          {shortId(r.id)}
        </span>
      ),
    },
    { key: 'region', header: 'المنطقة', render: (r) => regionName(r.region_id) },
    {
      key: 'status',
      header: 'الحالة',
      render: (r) => <Badge tone={accountStatusTone(r.status)}>{label(ACCOUNT_STATUS_LABELS, r.status)}</Badge>,
    },
    {
      key: 'reason',
      header: 'سبب التعليق',
      render: (r) => (r.status === 'SUSPENDED' ? reasonLabel(r.suspension_reason_code) : <span className="muted">—</span>),
    },
    { key: 'joined', header: 'تاريخ الانضمام', className: 'cell-num', render: (r) => formatDate(r.created_at) },
  ]

  return (
    <div className="page">
      <PageHeader title="الحسابات" description="حسابات المستخدمين: البحث بالاسم أو المعرف، وتعليق الحساب أو إعادة تفعيله من صفحة تفاصيله." />

      <form className="filters" onSubmit={onSearch} role="search" aria-label="بحث الحسابات">
        <SelectField label="الحالة" value={status ?? ''} onChange={(e) => updateParams({ status: e.target.value || null })}>
          <option value="">الكل</option>
          {ACCOUNT_STATUSES.map((s) => (
            <option key={s} value={s}>
              {label(ACCOUNT_STATUS_LABELS, s)}
            </option>
          ))}
        </SelectField>
        <div className="field-grow">
          <TextField
            label="بحث"
            type="search"
            value={draft}
            maxLength={SEARCH_MAX}
            placeholder="جزء من اسم العرض أو معرف الحساب كاملًا"
            onChange={(e) => setDraft(e.target.value)}
            hint={draft.trim() && isUuid(draft) ? 'سيبحث بالمعرف مطابقةً تامة.' : undefined}
          />
        </div>
        <Button type="submit" variant="primary">
          بحث
        </Button>
        {filtered && (
          <Button
            type="button"
            variant="ghost"
            onClick={() => {
              setDraft('')
              setParams(new URLSearchParams(), { replace: true })
            }}
          >
            مسح المرشحات
          </Button>
        )}
      </form>

      {list.isPending ? (
        <Loading />
      ) : list.isError && !list.data ? (
        <ErrorState error={list.error} onRetry={() => void list.refetch()} />
      ) : (
        <>
          <p className="muted small" aria-live="polite">
            {total !== null ? `إجمالي النتائج: ${formatNumber(total)}` : `المعروض: ${formatNumber(rows.length)}`}
          </p>
          <DataTable
            caption="قائمة الحسابات"
            columns={columns}
            rows={rows}
            rowKey={(r) => r.id}
            onRowClick={(r) => navigate(`/admin/accounts/${r.id}`)}
            empty={
              <EmptyState title={filtered ? 'لا حسابات مطابقة' : 'لا حسابات بعد'}>
                {filtered ? 'جرّب تغيير الحالة أو نص البحث.' : null}
              </EmptyState>
            }
          />
          {list.isFetchNextPageError && !list.isFetchingNextPage && <ErrorState error={list.error} onRetry={() => void list.fetchNextPage()} title="تعذر تحميل المزيد" />}
          <LoadMore hasMore={Boolean(list.hasNextPage) && !(list.isFetchNextPageError && !list.isFetchingNextPage)} loading={list.isFetchingNextPage} onClick={() => void list.fetchNextPage()} />
        </>
      )}
    </div>
  )
}
