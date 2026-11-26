import { useInfiniteQuery } from '@tanstack/react-query'
import { Link } from 'react-router'
import { useAuth } from '@admin/auth/AuthContext'
import { formatDateTime, shortId } from '@admin/lib/format'
import { unwrap } from '@admin/lib/rpc'
import { getSupabase } from '@admin/lib/supabase'
import { Alert, Button, DataTable, EmptyState, ErrorState, Loading, LoadMore, type Column } from '@admin/ui'
import { ActorLabel } from './shared'
import { EVIDENCE_ACCESS_COLUMNS, type EvidenceAccessRow } from './types'

const PAGE_SIZE = 50

async function fetchPage(beforeId: number | null): Promise<EvidenceAccessRow[]> {
  let q = getSupabase().from('report_evidence_access').select(EVIDENCE_ACCESS_COLUMNS)
  if (beforeId !== null) q = q.lt('id', beforeId)
  const rows = unwrap(await q.order('id', { ascending: false }).limit(PAGE_SIZE))
  return rows as EvidenceAccessRow[]
}

/** سجل الاطلاع على أدلة البلاغات (report_evidence_access): قراءة فقط. */
export function EvidenceAccessTab() {
  const { whoami } = useAuth()
  const meId = whoami?.user_id ?? null
  const query = useInfiniteQuery({
    queryKey: ['admin', 'audit', 'evidence'],
    queryFn: ({ pageParam }) => fetchPage(pageParam),
    initialPageParam: null as number | null,
    getNextPageParam: (last) => (last.length === PAGE_SIZE ? (last[last.length - 1]?.id ?? undefined) : undefined),
  })
  const { fetchNextPage, isFetchNextPageError: nextPageError } = query

  const columns: Column<EvidenceAccessRow>[] = [
    { key: 'time', header: 'الوقت', render: (r) => <span className="small">{formatDateTime(r.created_at)}</span> },
    { key: 'actor', header: 'الموظف', render: (r) => <ActorLabel id={r.actor_id} meId={meId} /> },
    {
      key: 'report',
      header: 'البلاغ',
      render: (r) => (
        <Link to={`/admin/reports/${r.report_id}`} aria-label={`البلاغ ${r.report_id}`}>
          <span className="mono ltr" dir="ltr" title={r.report_id}>
            {shortId(r.report_id)}
          </span>
        </Link>
      ),
    },
  ]

  if (query.isPending) return <Loading />
  if (query.data === undefined) return <ErrorState error={query.error} onRetry={() => void query.refetch()} />
  const rows = query.data.pages.flat()
  return (
    <div className="stack">
      <p className="muted small">كل اطلاع على الرسالة المبلغ عنها وسياقها يسجل هنا تلقائيًا.</p>
      <DataTable
        caption="سجل الاطلاع على الأدلة"
        columns={columns}
        rows={rows}
        rowKey={(r) => String(r.id)}
        empty={<EmptyState title="لا اطلاع مسجل على الأدلة" />}
      />
      {nextPageError && (
        <Alert tone="danger" title="تعذر تحميل المزيد">
          <Button size="sm" onClick={() => void fetchNextPage()}>
            إعادة المحاولة
          </Button>
        </Alert>
      )}
      <LoadMore hasMore={query.hasNextPage} loading={query.isFetchingNextPage} onClick={() => void query.fetchNextPage()} />
    </div>
  )
}
