import { useEffect, useId, useRef, type ReactNode } from 'react'

const FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), summary, [tabindex]:not([tabindex="-1"])'

export interface DialogProps {
  open: boolean
  title: string
  onClose: () => void
  children: ReactNode
  footer?: ReactNode
  /** يمنع الإغلاق أثناء الإرسال. */
  busy?: boolean
  size?: 'md' | 'lg'
}

/** نافذة حوار مشروطة بإتاحة لوحة المفاتيح: Escape يغلق، والتركيز ينتقل إليها ويعود عند الإغلاق. */
export function Dialog({ open, title, onClose, children, footer, busy = false, size = 'md' }: DialogProps) {
  const titleId = useId()
  const ref = useRef<HTMLDivElement>(null)
  const returnFocus = useRef<HTMLElement | null>(null)

  useEffect(() => {
    if (!open) return
    returnFocus.current = document.activeElement as HTMLElement | null
    const el = ref.current
    const first = el?.querySelector<HTMLElement>('input, select, textarea, button:not([data-close])')
    ;(first ?? el)?.focus()
    return () => {
      returnFocus.current?.focus?.()
    }
  }, [open])

  if (!open) return null

  return (
    <div
      className="dialog-backdrop"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget && !busy) onClose()
      }}
    >
      <div
        ref={ref}
        className={`dialog dialog-${size}`}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        tabIndex={-1}
        onKeyDown={(e) => {
          if (e.key === 'Escape' && !busy) {
            e.stopPropagation()
            onClose()
            return
          }
          if (e.key === 'Tab') {
            // يبقى التركيز داخل الحوار المشروط (aria-modal).
            const items = Array.from(ref.current?.querySelectorAll<HTMLElement>(FOCUSABLE) ?? []).filter((el) => !el.hasAttribute('disabled'))
            const first = items[0]
            const last = items[items.length - 1]
            if (!first || !last) {
              e.preventDefault()
              return
            }
            const active = document.activeElement
            if (e.shiftKey && (active === first || active === ref.current)) {
              e.preventDefault()
              last.focus()
            } else if (!e.shiftKey && active === last) {
              e.preventDefault()
              first.focus()
            }
          }
        }}
      >
        <div className="dialog-head">
          <h2 id={titleId}>{title}</h2>
          <button type="button" className="icon-btn" data-close aria-label="إغلاق" onClick={onClose} disabled={busy}>
            ×
          </button>
        </div>
        <div className="dialog-body">{children}</div>
        {footer && <div className="dialog-foot">{footer}</div>}
      </div>
    </div>
  )
}
