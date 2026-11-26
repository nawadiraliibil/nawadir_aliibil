import { useId, useRef, type KeyboardEvent } from 'react'
import { useSearchParams } from 'react-router'
import { Alert, PageHeader } from '@admin/ui'
import { useCan } from '@admin/auth/AuthContext'
import { CitiesTab } from './CitiesTab'
import { DEACTIVATE_EXPLAIN, TAB_LABELS, TAB_ORDER } from './labels'
import { ReasonsTab } from './ReasonsTab'
import { BreedsTab, RegionsTab } from './SimpleTabs'
import type { LookupTab } from './types'

function isTab(v: string | null): v is LookupTab {
  return v !== null && (TAB_ORDER as string[]).includes(v)
}

/**
 * القوائم وأسباب الإشراف (AD-FR-037، القدرة lookups.manage).
 * القراءة من الجداول (تشمل المعطلة لمن يملك القدرة)، والكتابة عبر admin_upsert_*،
 * admin_set_lookup_active، admin_reorder_lookup. لا حذف لأي قيمة.
 */
export default function LookupsPage() {
  const [params, setParams] = useSearchParams()
  const raw = params.get('tab')
  const tab: LookupTab = isTab(raw) ? raw : 'breeds'
  const canManage = useCan('lookups.manage')
  const baseId = useId()
  const tabRefs = useRef<Partial<Record<LookupTab, HTMLButtonElement | null>>>({})

  function select(next: LookupTab, focus = false) {
    setParams(
      (prev) => {
        const p = new URLSearchParams(prev)
        p.set('tab', next)
        if (next !== 'cities') p.delete('region')
        return p
      },
      { replace: true },
    )
    if (focus) tabRefs.current[next]?.focus()
  }

  // أسهم لوحة المفاتيح بين التبويبات؛ في RTL السهم الأيسر للتالي.
  function onKeyDown(e: KeyboardEvent<HTMLDivElement>) {
    const i = TAB_ORDER.indexOf(tab)
    let next: number | null = null
    if (e.key === 'ArrowLeft') next = (i + 1) % TAB_ORDER.length
    else if (e.key === 'ArrowRight') next = (i - 1 + TAB_ORDER.length) % TAB_ORDER.length
    else if (e.key === 'Home') next = 0
    else if (e.key === 'End') next = TAB_ORDER.length - 1
    if (next === null) return
    e.preventDefault()
    const t = TAB_ORDER[next]
    if (t) select(t, true)
  }

  return (
    <div className="page">
      <PageHeader
        title="القوائم وأسباب الإشراف"
        description="السلالات والمناطق والمدن وأسباب الإشراف التي تظهر في التطبيق ولوحة الإدارة. القيم مرتبة بالترتيب المعروض للمستخدمين."
      />
      <Alert tone="info">{DEACTIVATE_EXPLAIN}</Alert>
      {!canManage && <Alert tone="warning">لا تملك صلاحية تعديل القوائم؛ العرض للاطلاع فقط.</Alert>}
      <div className="tabs" role="tablist" aria-label="القوائم" onKeyDown={onKeyDown}>
        {TAB_ORDER.map((t) => (
          <button
            key={t}
            ref={(el) => {
              tabRefs.current[t] = el
            }}
            type="button"
            role="tab"
            id={`${baseId}-tab-${t}`}
            aria-controls={`${baseId}-panel-${t}`}
            aria-selected={tab === t}
            tabIndex={tab === t ? 0 : -1}
            className="tab"
            onClick={() => select(t)}
          >
            {TAB_LABELS[t]}
          </button>
        ))}
      </div>
      <div role="tabpanel" id={`${baseId}-panel-${tab}`} aria-labelledby={`${baseId}-tab-${tab}`}>
        {tab === 'breeds' && <BreedsTab canManage={canManage} />}
        {tab === 'regions' && <RegionsTab canManage={canManage} />}
        {tab === 'cities' && <CitiesTab canManage={canManage} />}
        {tab === 'reasons' && <ReasonsTab canManage={canManage} />}
      </div>
    </div>
  )
}
