import { useState } from 'react'
import { useInfiniteQuery } from '@tanstack/react-query'
import { useAuth } from '@admin/auth/AuthContext'
import { formatDateTime, riyadhDayToIso } from '@admin/lib/format'
import { unwrap } from '@admin/lib/rpc'
import { getSupabase } from '@admin/lib/supabase'
import { Alert, Button, DataTable, EmptyState, ErrorState, Loading, LoadMore, SelectField, TextField, type Column } from '@admin/ui'
import { AUDIT_FILTER_ACTIONS, AUDIT_RESOURCE_TYPES, auditActionLabel, resourceTypeLabel } from './labels'
import { ActorLabel, ResourceCell, isUuid } from './shared'
import { AUDIT_LOG_COLUMNS, EMPTY_AUDIT_FILTERS, type AuditFilters, type AuditLogRow } from './types'

export const AUDIT_PAGE_SIZE = 50

async function fetchAuditPage(filters: AuditFilters, meId: string | null, beforeId: number | null): Promise<AuditLogRow[]> {
  let q = getSupabase().from('audit_log').select(AUDIT_LOG_COLUMNS)
  if (filters.action) q = q.eq('action', filters.action)
  if (filters.resourceType) q = q.eq('resource_type', filters.resourceType)
  if (filters.actorMode === 'me' && meId) q = q.eq('actor_id', meId)
  else if (filters.actorMode === 'system') q = q.is('actor_id', null)
  else if (filters.actorMode === 'id' && filters.actorId) q = q.eq('actor_id', filters.actorId.trim().toLowerCase())
  if (filters.from) q = q.gte('created_at', riyadhDayToIso(filters.from))
  if (filters.to) q = q.lt('created_at', riyadhDayToIso(filters.to, true))
  if (beforeId !== null) q = q.lt('id', beforeId)
  const rows = unwrap(await q.order('id', { ascending: false }).limit(AUDIT_PAGE_SIZE))
  return rows as AuditLogRow[]
}

function DetailsCell({ details }: { details: unknown }) {
  const empty =
    details === null ||
    details === undefined ||
    (typeof details === 'object' && !Array.isArray(details) && Object.keys(details as object).length === 0)
  if (empty) return <span className="muted">—</span>
  return (
    <details>
      <summary>عرض التفاصيل</summary>
      <pre className="pre ltr" dir="ltr">
        {JSON.stringify(details, null, 2)}
      </pre>
    </details>
  )
}

function validateFilters(f: AuditFilters): Partial<Record<'actorId' | 'to', string>> {
  const e: Partial<Record<'actorId' | 'to', string>> = {}
  if (f.actorMode === 'id' && !isUuid(f.actorId)) e.actorId = 'أدخل معرف UUID صالحًا للفاعل.'
  if (f.from && f.to && f.to < f.from) e.to = 'تاريخ النهاية قبل تاريخ البداية.'
  return e
}

/** سجل الإجراءات الإدارية: قراءة فقط (AD-FR-021). */
export function AuditLogTab() {
  const { whoami } = useAuth()
  const meId = whoami?.user_id ?? null
  const [draft, setDraft] = useState<AuditFilters>(EMPTY_AUDIT_FILTERS)
  const [applied, setApplied] = useState<AuditFilters>(EMPTY_AUDIT_FILTERS)
  const [errors, setErrors] = useState<Partial<Record<'actorId' | 'to', string>>>({})

  const query = useInfiniteQuery({
    queryKey: ['admin', 'audit', 'log', applied, meId],
    queryFn: ({ pageParam }) => fetchAuditPage(applied, meId, pageParam),
    initialPageParam: null as number | null,
    getNextPageParam: (last) => (last.length === AUDIT_PAGE_SIZE ? (last[last.length - 1]?.id ?? undefined) : undefined),
  })
  const { fetchNextPage, isFetchNextPageError: nextPageError } = query

  function set<K extends keyof AuditFilters>(key: K, value: AuditFilters[K]) {
    setDraft((d) => ({ ...d, [key]: value }))
  }

  function apply() {
    const e = validateFilters(draft)
    setErrors(e)
    if (Object.keys(e).length > 0) return
    setApplied({ ...draft, actorId: draft.actorMode === 'id' ? draft.actorId.trim() : '' })
  }

  function reset() {
    setDraft(EMPTY_AUDIT_FILTERS)
    setErrors({})
    setApplied(EMPTY_AUDIT_FILTERS)
  }

  const rows = query.data?.pages.flat() ?? []

  const columns: Column<AuditLogRow>[] = [
    { key: 'time', header: 'الوقت', render: (r) => <span className="small">{formatDateTime(r.created_at)}</span> },
    { key: 'actor', header: 'الفاعل', render: (r) => <ActorLabel id={r.actor_id} meId={meId} /> },
    {
      key: 'action',
      header: 'الإجراء',
      render: (r) => (
        <div className="stack" style={{ gap: 2 }}>
          <span>{auditActionLabel(r.action)}</span>
          <span className="muted small mono ltr" dir="ltr">
            {r.action}
          </span>
        </div>
      ),
    },
    { key: 'resource', header: 'المورد', render: (r) => <ResourceCell type={r.resource_type} id={r.resource_id} details={r.details} /> },
    {
      key: 'reason',
      header: 'السبب',
      render: (r) =>
        r.reason_code || r.reason_text ? (
          <div className="stack small" style={{ gap: 2 }}>
            {r.reason_code && (
              <span className="mono ltr" dir="ltr">
                {r.reason_code}
              </span>
            )}
            {r.reason_text && <span>{r.reason_text}</span>}
          </div>
        ) : (
          <span className="muted">—</span>
        ),
    },
    { key: 'details', header: 'التفاصيل', render: (r) => <DetailsCell details={r.details} /> },
  ]

  return (
    <div className="stack">
      <form
        className="filters"
        aria-label="مرشحات سجل الإجراءات"
        noValidate
        onSubmit={(e) => {
          e.preventDefault()
          apply()
        }}
      >
        <SelectField label="الإجراء" value={draft.action} onChange={(e) => set('action', e.target.value)}>
          <option value="">كل الإجراءات</option>
          {AUDIT_FILTER_ACTIONS.map((a) => (
            <option key={a} value={a}>
              {auditActionLabel(a)}
            </option>
          ))}
        </SelectField>
        <SelectField label="نوع المورد" value={draft.resourceType} onChange={(e) => set('resourceType', e.target.value)}>
          <option value="">كل الأنواع</option>
          {AUDIT_RESOURCE_TYPES.map((t) => (
            <option key={t} value={t}>
              {resourceTypeLabel(t)}
            </option>
          ))}
        </SelectField>
        <SelectField label="الفاعل" value={draft.actorMode} onChange={(e) => set('actorMode', e.target.value as AuditFilters['actorMode'])}>
          <option value="">الكل</option>
          <option value="me">أنا</option>
          <option value="system">النظام</option>
          <option value="id">معرف محدد</option>
        </SelectField>
        {draft.actorMode === 'id' && (
          <div className="field-grow">
            <TextField
              label="معرف الفاعل (UUID)"
              dir="ltr"
              className="input ltr mono"
              value={draft.actorId}
              onChange={(e) => set('actorId', e.target.value)}
              error={errors.actorId}
              autoComplete="off"
              spellCheck={false}
            />
          </div>
        )}
        <TextField label="من يوم" type="date" value={draft.from} onChange={(e) => set('from', e.target.value)} hint="بتوقيت الرياض" />
        <TextField label="إلى يوم" type="date" value={draft.to} onChange={(e) => set('to', e.target.value)} error={errors.to} hint="شاملًا" />
        <div className="row">
          <Button type="submit" variant="primary">
            تطبيق
          </Button>
          <Button variant="ghost" onClick={reset}>
            مسح المرشحات
          </Button>
        </div>
      </form>

      {query.isPending ? (
        <Loading />
      ) : query.data === undefined ? (
        <ErrorState error={query.error} onRetry={() => void query.refetch()} />
      ) : (
        <>
          <DataTable
            caption="سجل الإجراءات"
            columns={columns}
            rows={rows}
            rowKey={(r) => String(r.id)}
            empty={<EmptyState title="لا إجراءات مطابقة">غير المرشحات أو وسع نطاق التاريخ.</EmptyState>}
          />
          {nextPageError && (
            <Alert tone="danger" title="تعذر تحميل المزيد">
              <Button size="sm" onClick={() => void fetchNextPage()}>
                إعادة المحاولة
              </Button>
            </Alert>
          )}
          <LoadMore hasMore={query.hasNextPage} loading={query.isFetchingNextPage} onClick={() => void query.fetchNextPage()} />
        </>
      )}
    </div>
  )
}
