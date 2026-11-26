import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useSearchParams } from 'react-router'
import { Alert, Button, Card, ErrorState, Loading, SelectField } from '@admin/ui'
import { formatDateTime } from '@admin/lib/format'
import { fetchCities, fetchRegions, lookupKeys } from './api'
import { LookupList } from './LookupList'
import { CityDialog } from './NameLookupDialogs'
import type { City, Region } from './types'

/**
 * المدن تعرض وترتب داخل منطقة واحدة: sort_order للمدن يبدأ من 10 في كل منطقة
 * (ترحيل lookups)، وadmin_reorder_lookup('city') يرسل مدن المنطقة المختارة بترتيبها.
 */
export function CitiesTab({ canManage }: { canManage: boolean }) {
  const [params, setParams] = useSearchParams()
  const regionsQ = useQuery({ queryKey: lookupKeys.regions(), queryFn: fetchRegions })
  const regions: Region[] = regionsQ.data ?? []

  const fromUrl = Number(params.get('region'))
  const selected = regions.find((r) => r.id === fromUrl) ?? regions[0] ?? null
  const regionId = selected?.id ?? null

  const citiesQ = useQuery({
    queryKey: lookupKeys.cities(regionId ?? 0),
    queryFn: () => fetchCities(regionId as number),
    enabled: regionId !== null,
  })
  const [editing, setEditing] = useState<{ value: City | null } | null>(null)

  function chooseRegion(id: string) {
    setParams(
      (prev) => {
        const next = new URLSearchParams(prev)
        next.set('region', id)
        return next
      },
      { replace: true },
    )
  }

  let body
  if (regionsQ.isPending) body = <Loading />
  else if (regionsQ.isError) body = <ErrorState error={regionsQ.error} onRetry={() => void regionsQ.refetch()} title="تعذر تحميل المناطق" />
  else if (regions.length === 0) body = <Alert tone="info">أضف منطقة أولًا من تبويب «المناطق»، ثم أضف مدنها هنا.</Alert>
  else
    body = (
      <>
        <div className="filters">
          <SelectField label="المنطقة" value={regionId === null ? '' : String(regionId)} onChange={(e) => chooseRegion(e.target.value)} hint="المدن تعرض وترتب داخل المنطقة المختارة.">
            {regions.map((r) => (
              <option key={r.id} value={String(r.id)}>
                {r.is_active ? r.name_ar : `${r.name_ar} (معطلة)`}
              </option>
            ))}
          </SelectField>
        </div>
        {selected && !selected.is_active && (
          <Alert tone="warning">المنطقة «{selected.name_ar}» معطلة؛ مدنها لا تظهر في الاختيارات الجديدة حتى تفعل المنطقة.</Alert>
        )}
        {citiesQ.isPending ? (
          <Loading />
        ) : citiesQ.isError ? (
          <ErrorState error={citiesQ.error} onRetry={() => void citiesQ.refetch()} title="تعذر تحميل المدن" />
        ) : (
          <LookupList<City>
            kind="city"
            rows={citiesQ.data}
            idOf={(r) => String(r.id)}
            nameOf={(r) => r.name_ar}
            caption={`مدن ${selected?.name_ar ?? ''} بالترتيب`}
            canManage={canManage}
            onEdit={(r) => setEditing({ value: r })}
            invalidate={[lookupKeys.citiesAll()]}
            emptyTitle="لا توجد مدن في هذه المنطقة بعد."
            columns={[
              { key: 'name', header: 'المدينة', render: (r) => r.name_ar },
              { key: 'updated', header: 'آخر تعديل', render: (r) => <span className="small muted">{formatDateTime(r.updated_at)}</span> },
            ]}
          />
        )}
      </>
    )

  return (
    <Card
      title="المدن"
      actions={
        canManage &&
        regions.length > 0 && (
          <Button variant="primary" onClick={() => setEditing({ value: null })}>
            إضافة مدينة
          </Button>
        )
      }
    >
      <div className="stack">{body}</div>
      <CityDialog open={editing !== null} value={editing?.value ?? null} regions={regions} defaultRegionId={regionId} onClose={() => setEditing(null)} />
    </Card>
  )
}
