import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router'
import { useInfiniteQuery } from '@tanstack/react-query'
import { useCan } from '@admin/auth/AuthContext'
import { formatDateTime, formatPrice } from '@admin/lib/format'
import { ACCOUNT_STATUS_LABELS, LISTING_FILTER_STATUSES, LISTING_STATUS_LABELS, OFFER_TYPE_LABELS, label } from '@admin/lib/labels'
import { Badge, Button, DataTable, EmptyState, ErrorState, LoadMore, Loading, PageHeader, SelectField, TextField, listingStatusTone, type Column } from '@admin/ui'
import { fetchListingsPage, listingKeys, nextCursor, sanitizeStatus, useReasonLabels } from './api'
import { CoverThumb } from './media'
import type { AdminListingItem, ListCursor, ListFilters } from './types'
import './listings.css'

function OfferCell({ row }: { row: AdminListingItem }) {
  if (row.offer_type === 'IN_PERSON_AUCTION') {
    return (
      <div className="stack">
        <span>{label(OFFER_TYPE_LABELS, row.offer_type)}</span>
        <span className="small muted">{formatDateTime(row.auction_starts_at)}</span>
      </div>
    )
  }
  return (
    <div className="stack">
      <span>{label(OFFER_TYPE_LABELS, row.offer_type)}</span>
      <span className="small">{formatPrice(row.price)}</span>
    </div>
  )
}

/** إدارة الإعلانات (INT-008، AD-FR-018): بحث وتصفية بالحالة وتصفح بمفتاح آخر عنصر. لا مراجعة ولا اعتماد. */
export default function ListingsPage() {
  const navigate = useNavigate()
  const [params, setParams] = useSearchParams()
  const canAccounts = useCan('accounts.manage')
  const reasonLabels = useReasonLabels()

  const status = sanitizeStatus(params.get('status'))
  const q = (params.get('q') ?? '').trim()
  const filters = useMemo<ListFilters>(() => ({ status, q }), [status, q])

  const [search, setSearch] = useState(q)
  useEffect(() => setSearch(q), [q])

  const query = useInfiniteQuery({
    queryKey: listingKeys.list(filters),
    initialPageParam: null as ListCursor | null,
    queryFn: ({ pageParam }) => fetchListingsPage(filters, pageParam),
    getNextPageParam: (last) => nextCursor(last),
  })

  function updateParams(next: Partial<ListFilters>) {
    const merged = { ...filters, ...next }
    const p = new URLSearchParams()
    if (merged.status) p.set('status', merged.status)
    if (merged.q.trim()) p.set('q', merged.q.trim())
    setParams(p, { replace: true })
  }

  function onSearch(e: FormEvent) {
    e.preventDefault()
    updateParams({ q: search })
  }

  const rows = query.data?.pages.flat() ?? []
  const filtered = Boolean(status || q)

  const columns: Column<AdminListingItem>[] = [
    {
      key: 'cover',
      header: <span className="sr-only">الغلاف</span>,
      render: (r) => <CoverThumb cover={r.cover} alt={`غلاف ${r.title ?? ''}`.trim()} />,
    },
    {
      key: 'title',
      header: 'الإعلان',
      className: 'listing-title-cell',
      render: (r) => (
        <div className="stack">
          <Link to={`/admin/listings/${r.listing_id}`} onClick={(e) => e.stopPropagation()}>
            {r.title || 'بلا عنوان'}
          </Link>
          <span className="small muted ltr mono" dir="ltr">
            {r.public_ref}
          </span>
        </div>
      ),
    },
    {
      key: 'status',
      header: 'الحالة',
      render: (r) => (
        <div className="row">
          <Badge tone={listingStatusTone(r.status)}>{label(LISTING_STATUS_LABELS, r.status)}</Badge>
          {r.has_draft && r.published_version_id !== null && (r.status === 'PUBLISHED' || r.status === 'HIDDEN') && <Badge tone="info">تعديل غير منشور</Badge>}
          {r.deleted_at && <Badge tone="neutral">حذفه المعلن</Badge>}
        </div>
      ),
    },
    { key: 'offer', header: 'العرض', render: (r) => <OfferCell row={r} /> },
    {
      key: 'owner',
      header: 'المعلن',
      render: (r) => (
        <div className="row">
          {canAccounts ? (
            <Link to={`/admin/accounts/${r.owner_id}`} onClick={(e) => e.stopPropagation()}>
              {r.owner_display_name || 'بلا اسم'}
            </Link>
          ) : (
            <span>{r.owner_display_name || 'بلا اسم'}</span>
          )}
          {r.owner_status === 'SUSPENDED' && <Badge tone="danger">{label(ACCOUNT_STATUS_LABELS, r.owner_status)}</Badge>}
        </div>
      ),
    },
    { key: 'changed', header: 'آخر تغيير للحالة', render: (r) => <span className="small">{formatDateTime(r.status_changed_at)}</span> },
    {
      key: 'hide',
      header: 'سبب الإخفاء',
      render: (r) =>
        r.status === 'HIDDEN' && r.hide_reason_code ? (
          <div className="stack small">
            <span>{reasonLabels.data?.get(r.hide_reason_code) ?? r.hide_reason_code}</span>
            {r.hide_reason_text && <span className="muted">{r.hide_reason_text}</span>}
            {r.hidden_at && <span className="muted">{formatDateTime(r.hidden_at)}</span>}
          </div>
        ) : (
          <span className="muted">—</span>
        ),
    },
  ]

  const statusLabel = status ? label(LISTING_STATUS_LABELS, status) : ''

  return (
    <div className="page">
      <PageHeader title="إدارة الإعلانات" description="ابحث في الإعلانات بكل حالاتها، وأخفِ المخالف منها أو أعد إظهاره. الإعلانات تنشر مباشرة عند إرسالها." />

      <form className="filters" onSubmit={onSearch} role="search" aria-label="تصفية الإعلانات">
        <SelectField label="الحالة" value={status} onChange={(e) => updateParams({ status: e.target.value })}>
          <option value="">الكل</option>
          {LISTING_FILTER_STATUSES.map((s) => (
            <option key={s} value={s}>
              {label(LISTING_STATUS_LABELS, s)}
            </option>
          ))}
        </SelectField>
        <div className="field-grow">
          <TextField
            label="بحث"
            type="search"
            value={search}
            maxLength={100}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="العنوان أو اسم المعلن أو المعرف العام أو معرف الإعلان"
            hint="المعرف العام ومعرف الإعلان يطابقان كاملين."
          />
        </div>
        <div className="row">
          <Button type="submit" variant="primary">
            بحث
          </Button>
          {filtered && (
            <Button
              variant="ghost"
              onClick={() => {
                setSearch('')
                setParams(new URLSearchParams(), { replace: true })
              }}
            >
              مسح التصفية
            </Button>
          )}
        </div>
      </form>

      {query.isPending ? (
        <Loading label="جارٍ تحميل الإعلانات…" />
      ) : query.isError && !query.data ? (
        <ErrorState error={query.error} onRetry={() => void query.refetch()} />
      ) : (
        <>
          <DataTable
            caption="الإعلانات"
            columns={columns}
            rows={rows}
            rowKey={(r) => r.listing_id}
            onRowClick={(r) => navigate(`/admin/listings/${r.listing_id}`)}
            empty={
              filtered ? (
                <EmptyState title="لا توجد إعلانات مطابقة">
                  <p>
                    {statusLabel && <>الحالة: {statusLabel}. </>}
                    {q && <>البحث: «{q}». </>}
                    جرب تغيير التصفية.
                  </p>
                </EmptyState>
              ) : (
                <EmptyState title="لا توجد إعلانات بعد" />
              )
            }
          />
          {query.isFetchNextPageError && <ErrorState title="تعذر تحميل الصفحة التالية" error={query.error} onRetry={() => void query.fetchNextPage()} />}
          <LoadMore hasMore={Boolean(query.hasNextPage) && !query.isFetchNextPageError} loading={query.isFetchingNextPage} onClick={() => void query.fetchNextPage()} />
        </>
      )}
    </div>
  )
}
