import type { ButtonHTMLAttributes, ReactNode } from 'react'

type Variant = 'primary' | 'secondary' | 'danger' | 'ghost'

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  size?: 'sm' | 'md'
  loading?: boolean
  icon?: ReactNode
}

/** زر موحد. أثناء التحميل يعطل لمنع تكرار الإرسال (SRS القسم 7). */
export function Button({ variant = 'secondary', size = 'md', loading = false, icon, disabled, children, className, type, ...rest }: ButtonProps) {
  const cls = ['btn', `btn-${variant}`, size === 'sm' ? 'btn-sm' : '', className ?? ''].filter(Boolean).join(' ')
  return (
    <button type={type ?? 'button'} className={cls} disabled={disabled || loading} aria-busy={loading || undefined} {...rest}>
      {loading ? <span className="spinner" aria-hidden="true" /> : icon}
      <span>{children}</span>
    </button>
  )
}
