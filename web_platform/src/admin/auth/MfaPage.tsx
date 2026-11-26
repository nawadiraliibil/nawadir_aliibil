import { useEffect, useState, type FormEvent } from 'react'
import { getSupabase } from '../lib/supabase'
import { useAuth } from './AuthContext'
import { Alert, Button, Loading, TextField } from '../ui'
import { AuthLayout } from './AuthLayout'

interface Enrollment {
  factorId: string
  qr: string
  secret: string
}

function mfaErrorText(err: unknown): string {
  const msg = err && typeof err === 'object' && 'message' in err ? String((err as { message: unknown }).message) : ''
  if (/invalid|expired|code/i.test(msg)) return 'الرمز غير صحيح أو انتهت صلاحيته. أدخل الرمز الحالي من التطبيق.'
  if (/rate limit|too many/i.test(msg)) return 'محاولات كثيرة. انتظر قليلًا ثم أعد المحاولة.'
  return 'تعذر التحقق. أعد المحاولة.'
}

/**
 * التحقق بخطوتين TOTP (AD-FR-017): تسجيل عامل جديد بأول دخول، أو إدخال الرمز لرفع الجلسة إلى aal2.
 * دوال الإدارة ترفض أي جلسة دون aal2 بـMFA_REQUIRED.
 */
export function MfaPage({ mode }: { mode: 'enroll' | 'verify' }) {
  const { refresh, signOut, email } = useAuth()
  const [factorId, setFactorId] = useState<string | null>(null)
  const [enrollment, setEnrollment] = useState<Enrollment | null>(null)
  const [preparing, setPreparing] = useState(true)
  const [code, setCode] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    async function prepare() {
      setPreparing(true)
      setError(null)
      const mfa = getSupabase().auth.mfa
      try {
        const factors = await mfa.listFactors()
        if (factors.error) throw factors.error
        if (mode === 'verify') {
          const verified = factors.data.totp[0]
          if (!verified) throw new Error('no verified factor')
          if (!cancelled) setFactorId(verified.id)
        } else {
          // عوامل غير مؤكدة من محاولات سابقة تمنع التسجيل باسم مكرر.
          for (const f of factors.data.all) {
            if (f.factor_type === 'totp' && f.status !== 'verified') await mfa.unenroll({ factorId: f.id })
          }
          const res = await mfa.enroll({ factorType: 'totp', friendlyName: `nawader-admin-${new Date().toISOString().slice(0, 10)}` })
          if (res.error) throw res.error
          if (!cancelled) {
            setFactorId(res.data.id)
            setEnrollment({ factorId: res.data.id, qr: res.data.totp.qr_code, secret: res.data.totp.secret })
          }
        }
      } catch {
        if (!cancelled) setError('تعذر تجهيز التحقق بخطوتين. أعد تحميل الصفحة أو سجل الخروج ثم الدخول.')
      } finally {
        if (!cancelled) setPreparing(false)
      }
    }
    void prepare()
    return () => {
      cancelled = true
    }
  }, [mode])

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (busy || !factorId) return
    const clean = code.replace(/\s/g, '')
    if (!/^\d{6}$/.test(clean)) {
      setError('أدخل رمزًا من 6 أرقام.')
      return
    }
    setBusy(true)
    setError(null)
    try {
      const res = await getSupabase().auth.mfa.challengeAndVerify({ factorId, code: clean })
      if (res.error) throw res.error
      await refresh()
    } catch (err) {
      setError(mfaErrorText(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <AuthLayout
      title={mode === 'enroll' ? 'تفعيل التحقق بخطوتين' : 'التحقق بخطوتين'}
      subtitle={
        mode === 'enroll'
          ? 'امسح الرمز بتطبيق مصادقة (مثل Google Authenticator أو Microsoft Authenticator) ثم أدخل الرمز المكون من 6 أرقام.'
          : 'أدخل الرمز المكون من 6 أرقام من تطبيق المصادقة.'
      }
    >
      {email && (
        <p className="muted small">
          الحساب: <span dir="ltr">{email}</span>
        </p>
      )}
      {preparing && <Loading label="جارٍ التجهيز…" />}
      {enrollment && (
        <div className="mfa-enroll">
          <img src={enrollment.qr} alt="رمز QR لتسجيل تطبيق المصادقة" width={180} height={180} />
          <p className="small">
            أو أدخل المفتاح يدويًا:{' '}
            <code dir="ltr" className="secret">
              {enrollment.secret}
            </code>
          </p>
        </div>
      )}
      {!preparing && factorId && (
        <form onSubmit={onSubmit} noValidate>
          <TextField
            label="رمز التحقق"
            inputMode="numeric"
            autoComplete="one-time-code"
            dir="ltr"
            maxLength={7}
            value={code}
            onChange={(e) => setCode(e.target.value)}
            required
          />
          <Button type="submit" variant="primary" loading={busy} className="btn-block">
            تحقق
          </Button>
        </form>
      )}
      {error && <Alert tone="danger">{error}</Alert>}
      <Button variant="ghost" onClick={() => void signOut()} className="btn-block">
        تسجيل الخروج
      </Button>
    </AuthLayout>
  )
}
