import type { ReactNode } from 'react'

export function Card({ title, actions, children, className }: { title?: ReactNode; actions?: ReactNode; children: ReactNode; className?: string }) {
  return (
    <section className={['card', className ?? ''].filter(Boolean).join(' ')}>
      {(title || actions) && (
        <div className="card-head">
          {title && <h2 className="card-title">{title}</h2>}
          {actions && <div className="card-actions">{actions}</div>}
        </div>
      )}
      <div className="card-body">{children}</div>
    </section>
  )
}

/** قائمة مفتاح/قيمة للتفاصيل. */
export function KeyValue({ items }: { items: Array<{ label: string; value: ReactNode; wide?: boolean }> }) {
  return (
    <dl className="kv">
      {items.map((it, i) => (
        <div key={i} className={it.wide ? 'kv-item kv-wide' : 'kv-item'}>
          <dt>{it.label}</dt>
          <dd>{it.value === null || it.value === undefined || it.value === '' ? '—' : it.value}</dd>
        </div>
      ))}
    </dl>
  )
}
