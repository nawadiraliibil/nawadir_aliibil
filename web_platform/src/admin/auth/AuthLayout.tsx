import type { ReactNode } from 'react'
import { Brand } from '../layout/Brand'

export function AuthLayout({ title, subtitle, children }: { title: string; subtitle?: ReactNode; children: ReactNode }) {
  return (
    <main className="auth-page">
      <div className="auth-card">
        <Brand large />
        <h1>{title}</h1>
        {subtitle && <p className="muted">{subtitle}</p>}
        {children}
      </div>
    </main>
  )
}
