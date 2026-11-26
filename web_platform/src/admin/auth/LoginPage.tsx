import { useState, type FormEvent } from 'react'
import { useAuth } from './AuthContext'
import { Button, TextField, Alert } from '../ui'
import { AuthLayout } from './AuthLayout'

function loginErrorText(err: unknown): string {
  const msg = err && typeof err === 'object' && 'message' in err ? String((err as { message: unknown }).message) : ''
  if (/invalid login credentials/i.test(msg)) return 'البريد أو كلمة المرور غير صحيحة.'
  if (/email not confirmed/i.test(msg)) return 'البريد غير مؤكد. تواصل مع مدير المنصة.'
  if (/rate limit|too many/i.test(msg)) return 'محاولات كثيرة. انتظر قليلًا ثم أعد المحاولة.'
  if (/fetch|network/i.test(msg)) return 'تعذر الاتصال بالخادم. تحقق من الاتصال ثم أعد المحاولة.'
  return 'تعذر تسجيل الدخول. أعد المحاولة.'
}

/** دخول الموظف ببريد وكلمة مرور؛ لا تسجيل ذاتي للموظفين. */
export function LoginPage() {
  const { signIn } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (busy) return
    if (!email.trim() || !password) {
      setError('أدخل البريد وكلمة المرور.')
      return
    }
    setBusy(true)
    setError(null)
    try {
      await signIn(email, password)
    } catch (err) {
      setError(loginErrorText(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <AuthLayout title="دخول لوحة الإدارة" subtitle="للموظفين المعتمدين فقط. يلزم بعد الدخول رمز من تطبيق المصادقة.">
      <form onSubmit={onSubmit} noValidate>
        <TextField label="البريد الإلكتروني" type="email" autoComplete="username" dir="ltr" value={email} onChange={(e) => setEmail(e.target.value)} required />
        <TextField label="كلمة المرور" type="password" autoComplete="current-password" dir="ltr" value={password} onChange={(e) => setPassword(e.target.value)} required />
        {error && <Alert tone="danger">{error}</Alert>}
        <Button type="submit" variant="primary" loading={busy} className="btn-block">
          دخول
        </Button>
      </form>
    </AuthLayout>
  )
}
