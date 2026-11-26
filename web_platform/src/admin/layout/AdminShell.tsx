import { Suspense, useState } from 'react'
import { NavLink, Outlet, useLocation } from 'react-router'
import { useAuth } from '../auth/AuthContext'
import { NAV_GROUP_LABELS, NAV_ITEMS, type NavItem } from '../routes'
import { ROLE_LABELS } from '../lib/capabilities'
import { Badge, Loading } from '../ui'
import { Brand } from './Brand'

/** هيكل اللوحة: شريط جانبي بالقوائم المتاحة لقدرات الموظف، ورأس بالدور والخروج. */
export function AdminShell() {
  const { whoami, email, signOut, can } = useAuth()
  const [menuOpen, setMenuOpen] = useState(false)
  const location = useLocation()
  const visible = NAV_ITEMS.filter((n) => can(n.caps))
  const groups = (Object.keys(NAV_GROUP_LABELS) as NavItem['group'][])
    .map((g) => ({ g, items: visible.filter((n) => n.group === g) }))
    .filter((x) => x.items.length > 0)

  return (
    <div className={menuOpen ? 'shell shell-menu-open' : 'shell'}>
      <a href="#main" className="skip-link">
        انتقل إلى المحتوى
      </a>
      <aside className="sidebar" aria-label="القائمة الرئيسية">
        <Brand />
        <nav>
          {groups.map(({ g, items }) => (
            <div key={g} className="nav-group">
              <p className="nav-group-label">{NAV_GROUP_LABELS[g]}</p>
              <ul>
                {items.map((n) => (
                  <li key={n.to}>
                    <NavLink to={n.to} end={n.to === '/admin'} className={({ isActive }) => (isActive ? 'nav-link active' : 'nav-link')} onClick={() => setMenuOpen(false)}>
                      <span className="nav-icon" aria-hidden="true">
                        {n.icon}
                      </span>
                      {n.label}
                    </NavLink>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </nav>
      </aside>
      <div className="shell-main">
        <header className="topbar">
          <button type="button" className="icon-btn menu-btn" aria-label="القائمة" aria-expanded={menuOpen} onClick={() => setMenuOpen((v) => !v)}>
            ☰
          </button>
          <div className="topbar-spacer" />
          <div className="topbar-user">
            {whoami && <Badge tone="gold">{ROLE_LABELS[whoami.role] ?? whoami.role}</Badge>}
            {email && (
              <span className="muted small" dir="ltr">
                {email}
              </span>
            )}
            <button type="button" className="btn btn-ghost btn-sm" onClick={() => void signOut()}>
              تسجيل الخروج
            </button>
          </div>
        </header>
        <main id="main" className="content" tabIndex={-1}>
          <Suspense fallback={<Loading />} key={location.pathname.split('/')[2] ?? ''}>
            <Outlet />
          </Suspense>
        </main>
      </div>
    </div>
  )
}
