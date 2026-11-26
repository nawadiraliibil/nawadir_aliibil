import type { ReactNode } from 'react'
import { Link } from 'react-router'

export interface Crumb {
  label: string
  to?: string
}

export function PageHeader({ title, description, actions, crumbs }: { title: string; description?: ReactNode; actions?: ReactNode; crumbs?: Crumb[] }) {
  return (
    <header className="page-header">
      {crumbs && crumbs.length > 0 && (
        <nav aria-label="مسار التنقل" className="crumbs">
          {crumbs.map((c, i) => (
            <span key={i}>
              {c.to ? <Link to={c.to}>{c.label}</Link> : <span aria-current="page">{c.label}</span>}
              {i < crumbs.length - 1 && <span className="crumb-sep" aria-hidden="true">‹</span>}
            </span>
          ))}
        </nav>
      )}
      <div className="page-header-row">
        <div>
          <h1>{title}</h1>
          {description && <p className="page-desc">{description}</p>}
        </div>
        {actions && <div className="page-actions">{actions}</div>}
      </div>
    </header>
  )
}
