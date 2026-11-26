import { useRef, useState, type KeyboardEvent } from 'react'
import { PageHeader } from '@admin/ui'
import { AuditLogTab } from './AuditLogTab'
import { EvidenceAccessTab } from './EvidenceAccessTab'

type TabKey = 'log' | 'evidence'
const TABS: Array<{ key: TabKey; label: string }> = [
  { key: 'log', label: 'سجل الإجراءات' },
  { key: 'evidence', label: 'سجل الاطلاع على الأدلة' },
]

/** سجل الإجراءات الإدارية وسجل الاطلاع على الأدلة (AD-FR-021). القدرة: audit.read. قراءة فقط. */
export default function AuditPage() {
  const [tab, setTab] = useState<TabKey>('log')
  const refs = useRef<Record<TabKey, HTMLButtonElement | null>>({ log: null, evidence: null })

  function onKey(e: KeyboardEvent<HTMLDivElement>) {
    if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(e.key)) return
    e.preventDefault()
    const i = TABS.findIndex((t) => t.key === tab)
    // RTL: السهم الأيسر للتالي.
    let next = i
    if (e.key === 'ArrowLeft') next = (i + 1) % TABS.length
    else if (e.key === 'ArrowRight') next = (i - 1 + TABS.length) % TABS.length
    else if (e.key === 'Home') next = 0
    else next = TABS.length - 1
    const key = TABS[next]?.key ?? 'log'
    setTab(key)
    refs.current[key]?.focus()
  }

  return (
    <div className="page">
      <PageHeader title="سجل الإجراءات" description="سجل للقراءة فقط تكتبه دوال الخادم نفسها؛ لا يعدل ولا يحذف. الأوقات بتوقيت الرياض." />
      <div className="tabs" role="tablist" aria-label="أقسام السجل" onKeyDown={onKey}>
        {TABS.map((t) => (
          <button
            key={t.key}
            ref={(el) => {
              refs.current[t.key] = el
            }}
            type="button"
            role="tab"
            id={`audit-tab-${t.key}`}
            className="tab"
            aria-selected={tab === t.key}
            aria-controls={`audit-panel-${t.key}`}
            tabIndex={tab === t.key ? 0 : -1}
            onClick={() => setTab(t.key)}
          >
            {t.label}
          </button>
        ))}
      </div>
      <div role="tabpanel" id={`audit-panel-${tab}`} aria-labelledby={`audit-tab-${tab}`}>
        {tab === 'log' ? <AuditLogTab /> : <EvidenceAccessTab />}
      </div>
    </div>
  )
}
