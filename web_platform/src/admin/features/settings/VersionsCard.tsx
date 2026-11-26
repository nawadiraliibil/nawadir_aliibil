import { useState } from 'react'
import { Badge, Button, Card, ConfirmDialog, DataTable, Dialog, EmptyState, ErrorState, Loading, LoadMore } from '@admin/ui'
import { formatDateTime, shortId } from '@admin/lib/format'
import type { SettingsVersionRow } from './types'
import { isPlainObject, NOTE_MAX } from './schema'
import { SettingsContentView } from './SettingsView'
import { useSettingsVersions } from './api'

export interface VersionsCardProps {
  publishedVersion: number
  canManage: boolean
  onRollback: (version: number, note: string | undefined) => Promise<unknown>
}

export function publisherLabel(id: string | null | undefined) {
  return id ? (
    <span className="mono ltr" dir="ltr" title={id}>
      {shortId(id)}
    </span>
  ) : (
    <span className="muted">النظام (قيم البدء)</span>
  )
}

/** سجل إصدارات الإعدادات مع عرض المحتوى والتراجع. */
export function VersionsCard({ publishedVersion, canManage, onRollback }: VersionsCardProps) {
  const q = useSettingsVersions(canManage)
  const [viewing, setViewing] = useState<SettingsVersionRow | null>(null)
  const [rollbackTo, setRollbackTo] = useState<number | null>(null)
  const rows = q.data?.pages.flat() ?? []

  let body
  if (q.isPending) body = <Loading />
  else if (q.isError) body = <ErrorState error={q.error} onRetry={() => void q.refetch()} title="تعذر تحميل سجل الإصدارات" />
  else
    body = (
      <>
        <DataTable<SettingsVersionRow>
          caption="سجل إصدارات الإعدادات"
          rows={rows}
          rowKey={(r) => String(r.version)}
          empty={<EmptyState title="لا توجد إصدارات" />}
          columns={[
            {
              key: 'version',
              header: 'الإصدار',
              className: 'cell-num',
              render: (r) => (
                <span className="row">
                  <strong>{r.version}</strong>
                  {r.version === publishedVersion && <Badge tone="success">المنشور حاليًا</Badge>}
                </span>
              ),
            },
            { key: 'published_at', header: 'تاريخ النشر', render: (r) => formatDateTime(r.published_at) },
            { key: 'published_by', header: 'الناشر', render: (r) => publisherLabel(r.published_by) },
            { key: 'note', header: 'الملاحظة', render: (r) => r.note || <span className="muted">—</span> },
            {
              key: 'restored',
              header: 'مصدر المحتوى',
              render: (r) => (r.restored_from_version ? <Badge tone="info">استعادة الإصدار {r.restored_from_version}</Badge> : <span className="muted">—</span>),
            },
            {
              key: 'actions',
              header: 'إجراءات',
              className: 'cell-actions',
              render: (r) => (
                <span className="row">
                  <Button size="sm" variant="ghost" aria-label={`عرض المحتوى (الإصدار ${r.version})`} onClick={() => setViewing(r)}>
                    عرض المحتوى
                  </Button>
                  {canManage && r.version !== publishedVersion && (
                    <Button size="sm" aria-label={`التراجع إلى هذا الإصدار (${r.version})`} onClick={() => setRollbackTo(r.version)}>
                      التراجع إلى هذا الإصدار
                    </Button>
                  )}
                </span>
              ),
            },
          ]}
        />
        <LoadMore hasMore={q.hasNextPage} loading={q.isFetchingNextPage} onClick={() => void q.fetchNextPage()} />
      </>
    )

  return (
    <Card title="سجل الإصدارات">
      <p className="muted small">كل نشر أو تراجع ينشئ إصدارًا جديدًا. السجل للإضافة فقط ولا يعدل أو يحذف.</p>
      {body}
      <Dialog open={viewing !== null} title={viewing ? `محتوى الإصدار ${viewing.version}` : ''} onClose={() => setViewing(null)} size="lg">
        {viewing && <SettingsContentView content={isPlainObject(viewing.content) ? viewing.content : {}} />}
      </Dialog>
      <ConfirmDialog
        open={rollbackTo !== null}
        title={rollbackTo !== null ? `التراجع إلى الإصدار ${rollbackTo}` : ''}
        message={
          <>
            <p>
              التراجع لا يعدل الإصدارات السابقة: ينشر <strong>إصدارًا جديدًا</strong> بمحتوى الإصدار {rollbackTo}، ويسري فورًا على التطبيق والموقع وحدود التخزين.
            </p>
            <p className="muted small">المسودة الحالية (إن وجدت) تبقى كما هي. يرفض الخادم المحتوى القديم إن خالف القواعد الحالية.</p>
          </>
        }
        confirmLabel="نشر إصدار بمحتوى قديم"
        noteLabel="ملاحظة (اختيارية)"
        noteHint={`حتى ${NOTE_MAX} حرف. تظهر في سجل الإصدارات وسجل الإجراءات.`}
        noteMax={NOTE_MAX}
        onClose={() => setRollbackTo(null)}
        onConfirm={(note) => (rollbackTo === null ? Promise.resolve() : onRollback(rollbackTo, note))}
      />
    </Card>
  )
}
