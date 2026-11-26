import type { ReactNode } from 'react'
import { errorMessage, toApiError } from '../lib/errors'
import { Button } from './Button'

export function Loading({ label = 'جارٍ التحميل…' }: { label?: string }) {
  return (
    <div className="state state-loading" role="status" aria-live="polite">
      <span className="spinner" aria-hidden="true" />
      <span>{label}</span>
    </div>
  )
}

export function EmptyState({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="state state-empty">
      <p className="state-title">{title}</p>
      {children && <div className="state-body">{children}</div>}
    </div>
  )
}

/** حالة الخطأ مع إعادة المحاولة؛ تعرض النص العربي لرمز العقد. */
export function ErrorState({ error, onRetry, title = 'تعذر تحميل البيانات' }: { error: unknown; onRetry?: () => void; title?: string }) {
  const code = toApiError(error).code
  return (
    <div className="state state-error" role="alert">
      <p className="state-title">{title}</p>
      <p>{errorMessage(error)}</p>
      <p className="muted small" dir="ltr">
        {code}
      </p>
      {onRetry && (
        <Button onClick={onRetry} variant="secondary">
          إعادة المحاولة
        </Button>
      )}
    </div>
  )
}

/** تنبيه داخل الصفحة. */
export function Alert({ tone = 'info', children, title }: { tone?: 'info' | 'warning' | 'danger' | 'success'; children: ReactNode; title?: string }) {
  return (
    <div className={`alert alert-${tone}`} role={tone === 'danger' ? 'alert' : 'status'}>
      {title && <strong className="alert-title">{title}</strong>}
      <div>{children}</div>
    </div>
  )
}
