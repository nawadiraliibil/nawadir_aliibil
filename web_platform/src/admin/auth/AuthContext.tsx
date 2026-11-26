import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { QueryClientContext } from '@tanstack/react-query'
import type { Session } from '@supabase/supabase-js'
import { getSupabase } from '../lib/supabase'
import { rpc } from '../lib/rpc'
import { ApiError, toApiError } from '../lib/errors'
import { hasAny, type Capability, type Whoami } from '../lib/capabilities'

/**
 * حالة دخول الموظف (AD-FR-017، ADMIN-HANDOFF القسم 3):
 * signedOut ← mfaEnroll/mfaVerify (جلسة aal1) ← ready (aal2 وadmin_whoami ناجحة).
 * notStaff: حساب بلا دور فعال (FORBIDDEN). الإظهار في الواجهة ليس حماية؛ الخادم يفحص كل استدعاء.
 */
export type AuthStatus = 'loading' | 'signedOut' | 'mfaEnroll' | 'mfaVerify' | 'ready' | 'notStaff' | 'error'

export interface AuthValue {
  status: AuthStatus
  email: string | null
  whoami: Whoami | null
  error: ApiError | null
  can: (caps: Capability | readonly Capability[]) => boolean
  signIn: (email: string, password: string) => Promise<void>
  signOut: () => Promise<void>
  /** يعيد حساب الحالة بعد إكمال التحقق أو عند خطأ جلسة. */
  refresh: () => Promise<void>
  /** يعالج أخطاء الاستدعاءات: انتهاء الجلسة، MFA، أو سحب الدور. */
  handleApiError: (error: unknown) => void
}

export const AuthContext = createContext<AuthValue | null>(null)

const WHOAMI_REFRESH_MS = 60_000

export function AuthProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<AuthStatus>('loading')
  const [email, setEmail] = useState<string | null>(null)
  const [whoami, setWhoami] = useState<Whoami | null>(null)
  const [error, setError] = useState<ApiError | null>(null)
  const running = useRef<Promise<void> | null>(null)
  const statusRef = useRef<AuthStatus>('loading')
  statusRef.current = status
  const queryClient = useContext(QueryClientContext)

  const evaluate = useCallback(async (session: Session | null) => {
    if (!session) {
      setEmail(null)
      setWhoami(null)
      setStatus('signedOut')
      return
    }
    setEmail(session.user.email ?? null)
    const supabase = getSupabase()
    // إعادة الفحص الدورية لجلسة جاهزة لا تهدم اللوحة لخطأ عابر (شبكة أو خادم)؛
    // تبقى الحالة ويعاد الفحص في الدورة التالية. السحب وانتهاء الجلسة وMFA تسري فورًا.
    const background = statusRef.current === 'ready'
    const aal = await supabase.auth.mfa.getAuthenticatorAssuranceLevel()
    if (aal.error) {
      if (background) return
      setError(toApiError(aal.error))
      setStatus('error')
      return
    }
    if (aal.data.currentLevel !== 'aal2') {
      setWhoami(null)
      setStatus(aal.data.nextLevel === 'aal2' ? 'mfaVerify' : 'mfaEnroll')
      return
    }
    try {
      const who = (await rpc('admin_whoami')) as Whoami
      setWhoami(who)
      setError(null)
      setStatus('ready')
    } catch (err) {
      const e = toApiError(err)
      const transient = !['FORBIDDEN', 'MFA_REQUIRED', 'AUTH_REQUIRED'].includes(e.code)
      if (!(background && transient)) setWhoami(null)
      if (e.code === 'FORBIDDEN') setStatus('notStaff')
      else if (e.code === 'MFA_REQUIRED') setStatus('mfaVerify')
      else if (e.code === 'AUTH_REQUIRED') setStatus('signedOut')
      else if (background) {
        // يبقى whoami السابق؛ الخادم يفحص الصلاحية في كل استدعاء على أي حال.
        return
      } else {
        setError(e)
        setStatus('error')
      }
    }
  }, [])

  const refresh = useCallback(async () => {
    if (running.current) return running.current
    const p = (async () => {
      const { data } = await getSupabase().auth.getSession()
      await evaluate(data.session)
    })().finally(() => {
      running.current = null
    })
    running.current = p
    return p
  }, [evaluate])

  useEffect(() => {
    void refresh()
    const { data } = getSupabase().auth.onAuthStateChange((event) => {
      // التحديث الدوري للرمز لا يغير الدور؛ بقية الأحداث تعيد التقييم.
      if (event === 'TOKEN_REFRESHED') return
      // يؤجل حتى لا يستدعي Supabase من داخل مستمع الحدث نفسه.
      window.setTimeout(() => void refresh(), 0)
    })
    return () => data.subscription.unsubscribe()
  }, [refresh])

  // سحب الدور يسري من الخادم فورًا؛ التحديث الدوري يخفي القوائم أيضًا.
  useEffect(() => {
    if (status !== 'ready') return
    const id = window.setInterval(() => void refresh(), WHOAMI_REFRESH_MS)
    const onFocus = () => void refresh()
    window.addEventListener('focus', onFocus)
    return () => {
      window.clearInterval(id)
      window.removeEventListener('focus', onFocus)
    }
  }, [status, refresh])

  const signIn = useCallback(async (mail: string, password: string) => {
    const { error: err } = await getSupabase().auth.signInWithPassword({ email: mail.trim(), password })
    if (err) throw err
    await refresh()
  }, [refresh])

  const signOut = useCallback(async () => {
    const auth = getSupabase().auth
    // إن فشل الخروج من الخادم (انقطاع مثلًا) تحذف الجلسة المحلية على الأقل حتى لا تعود بإعادة التحميل.
    let failed = false
    try {
      const res = await auth.signOut()
      failed = Boolean(res.error)
    } catch {
      failed = true
    }
    if (failed) await auth.signOut({ scope: 'local' }).catch(() => undefined)
    queryClient?.clear()
    setWhoami(null)
    setEmail(null)
    setStatus('signedOut')
  }, [queryClient])

  const handleApiError = useCallback(
    (err: unknown) => {
      const code = toApiError(err).code
      if (code === 'AUTH_REQUIRED' || code === 'MFA_REQUIRED' || code === 'FORBIDDEN') void refresh()
    },
    [refresh],
  )

  const can = useCallback((caps: Capability | readonly Capability[]) => hasAny(whoami, typeof caps === 'string' ? [caps] : caps), [whoami])

  const value = useMemo<AuthValue>(
    () => ({ status, email, whoami, error, can, signIn, signOut, refresh, handleApiError }),
    [status, email, whoami, error, can, signIn, signOut, refresh, handleApiError],
  )
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthValue {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth outside AuthProvider')
  return ctx
}

/** هل يملك الموظف الحالي القدرة؟ للإظهار فقط. */
export function useCan(caps: Capability | readonly Capability[]): boolean {
  return useAuth().can(caps)
}
