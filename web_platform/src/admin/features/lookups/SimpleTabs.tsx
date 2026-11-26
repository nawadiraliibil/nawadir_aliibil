import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Badge, Button, Card, ErrorState, Loading } from '@admin/ui'
import { formatDateTime } from '@admin/lib/format'
import { fetchBreeds, fetchRegions, lookupKeys } from './api'
import { LookupList } from './LookupList'
import { BreedDialog, RegionDialog } from './NameLookupDialogs'
import type { Breed, Region } from './types'

type Editing<T> = { value: T | null } | null

export function BreedsTab({ canManage }: { canManage: boolean }) {
  const q = useQuery({ queryKey: lookupKeys.breeds(), queryFn: fetchBreeds })
  const [editing, setEditing] = useState<Editing<Breed>>(null)

  return (
    <Card
      title="السلالات"
      actions={
        canManage && (
          <Button variant="primary" onClick={() => setEditing({ value: null })}>
            إضافة سلالة
          </Button>
        )
      }
    >
      {q.isPending ? (
        <Loading />
      ) : q.isError ? (
        <ErrorState error={q.error} onRetry={() => void q.refetch()} />
      ) : (
        <LookupList<Breed>
          kind="breed"
          rows={q.data}
          idOf={(r) => String(r.id)}
          nameOf={(r) => r.name_ar}
          caption="السلالات بالترتيب"
          canManage={canManage}
          onEdit={(r) => setEditing({ value: r })}
          invalidate={[lookupKeys.breeds()]}
          emptyTitle="لا توجد سلالات بعد."
          columns={[
            { key: 'name', header: 'السلالة', render: (r) => r.name_ar },
            {
              key: 'note',
              header: 'ملاحظة عند الاختيار',
              render: (r) => (r.requires_note ? <Badge tone="info">تتطلب ملاحظة</Badge> : <span className="muted">—</span>),
            },
            { key: 'updated', header: 'آخر تعديل', render: (r) => <span className="small muted">{formatDateTime(r.updated_at)}</span> },
          ]}
        />
      )}
      <BreedDialog open={editing !== null} value={editing?.value ?? null} onClose={() => setEditing(null)} />
    </Card>
  )
}

export function RegionsTab({ canManage }: { canManage: boolean }) {
  const q = useQuery({ queryKey: lookupKeys.regions(), queryFn: fetchRegions })
  const [editing, setEditing] = useState<Editing<Region>>(null)

  return (
    <Card
      title="المناطق"
      actions={
        canManage && (
          <Button variant="primary" onClick={() => setEditing({ value: null })}>
            إضافة منطقة
          </Button>
        )
      }
    >
      {q.isPending ? (
        <Loading />
      ) : q.isError ? (
        <ErrorState error={q.error} onRetry={() => void q.refetch()} />
      ) : (
        <LookupList<Region>
          kind="region"
          rows={q.data}
          idOf={(r) => String(r.id)}
          nameOf={(r) => r.name_ar}
          caption="المناطق بالترتيب"
          canManage={canManage}
          onEdit={(r) => setEditing({ value: r })}
          invalidate={[lookupKeys.regions()]}
          emptyTitle="لا توجد مناطق بعد."
          columns={[
            { key: 'name', header: 'المنطقة', render: (r) => r.name_ar },
            { key: 'updated', header: 'آخر تعديل', render: (r) => <span className="small muted">{formatDateTime(r.updated_at)}</span> },
          ]}
        />
      )}
      <RegionDialog open={editing !== null} value={editing?.value ?? null} onClose={() => setEditing(null)} />
    </Card>
  )
}
