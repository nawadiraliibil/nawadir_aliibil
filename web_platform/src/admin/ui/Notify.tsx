import { createContext, useCallback, useContext, useMemo, useRef, useState, type ReactNode } from 'react'

type NoticeTone = 'success' | 'danger' | 'info'
interface Notice {
  id: number
  tone: NoticeTone
  text: string
}

export interface NotifyApi {
  success: (text: string) => void
  error: (text: string) => void
  info: (text: string) => void
}

const NotifyContext = createContext<NotifyApi | null>(null)

/** إشعارات قصيرة أعلى الصفحة. النجاح يعرض فقط بعد تأكيد الخادم. */
export function NotifyProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<Notice[]>([])
  const seq = useRef(0)
  const push = useCallback((tone: NoticeTone, text: string) => {
    seq.current += 1
    const id = seq.current
    setItems((prev) => [...prev.slice(-3), { id, tone, text }])
    window.setTimeout(() => setItems((prev) => prev.filter((n) => n.id !== id)), tone === 'danger' ? 8000 : 4500)
  }, [])
  const api = useMemo<NotifyApi>(
    () => ({
      success: (t) => push('success', t),
      error: (t) => push('danger', t),
      info: (t) => push('info', t),
    }),
    [push],
  )
  return (
    <NotifyContext.Provider value={api}>
      {children}
      <div className="toasts" aria-live="polite">
        {items.map((n) => (
          <div key={n.id} className={`toast toast-${n.tone}`} role={n.tone === 'danger' ? 'alert' : 'status'}>
            <span>{n.text}</span>
            <button type="button" className="icon-btn" aria-label="إغلاق" onClick={() => setItems((p) => p.filter((x) => x.id !== n.id))}>
              ×
            </button>
          </div>
        ))}
      </div>
    </NotifyContext.Provider>
  )
}

export function useNotify(): NotifyApi {
  const ctx = useContext(NotifyContext)
  if (!ctx) throw new Error('useNotify outside NotifyProvider')
  return ctx
}
