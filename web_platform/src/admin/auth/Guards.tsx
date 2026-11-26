import type { ReactNode } from 'react'
import { useAuth } from './AuthContext'
import { LoginPage } from './LoginPage'
import { MfaPage } from './MfaPage'
import { AuthLayout } from './AuthLayout'
import { Alert, Button, ErrorState, PageHeader } from '../ui'
import { SplashGate } from '../splash/SplashGate'
import type { Capability } from '../lib/capabilities'
import { CAPABILITY_LABELS } from '../lib/capabilities'

/** لا يظهر شيء من اللوحة قبل جلسة aal2 ودور فعال من admin_whoami. */
export function RequireStaff({ children }: { children: ReactNode }) {
  const { status } = useAuth()
  // شاشة التحميل تغطي فحص الجلسة الأول فقط (الحالة loading لا تتكرر بعده).
  return (
    <SplashGate ready={status !== 'loading'}>
      <StaffGate>{children}</StaffGate>
    </SplashGate>
  )
}

function StaffGate({ children }: { children: ReactNode }) {
  const { status, error, refresh, signOut, email } = useAuth()
  switch (status) {
    case 'loading':
      return null
    case 'signedOut':
      return <LoginPage />
    case 'mfaEnroll':
      return <MfaPage mode="enroll" />
    case 'mfaVerify':
      return <MfaPage mode="verify" />
    case 'notStaff':
      return (
        <AuthLayout title="لا صلاحية للدخول">
          <Alert tone="danger">
            الحساب {email ? <span dir="ltr">{email}</span> : null} ليس حساب موظف فعالًا. لوحة الإدارة متاحة للموظفين المعتمدين فقط.
          </Alert>
          <Button variant="primary" className="btn-block" onClick={() => void signOut()}>
            تسجيل الخروج
          </Button>
        </AuthLayout>
      )
    case 'error':
      return (
        <AuthLayout title="تعذر التحقق من الحساب">
          <ErrorState error={error} onRetry={() => void refresh()} />
          <Button variant="ghost" className="btn-block" onClick={() => void signOut()}>
            تسجيل الخروج
          </Button>
        </AuthLayout>
      )
    case 'ready':
      return <>{children}</>
  }
}

/** صفحة لا يملك الموظف قدرتها: رسالة بدل المحتوى. الخادم يرفض الاستدعاء على أي حال. */
export function RequireCapability({ caps, children }: { caps: readonly Capability[]; children: ReactNode }) {
  const { can } = useAuth()
  if (can(caps)) return <>{children}</>
  return (
    <div className="page">
      <PageHeader title="لا صلاحية" />
      <Alert tone="warning" title="لا تملك صلاحية هذه الصفحة">
        القدرة المطلوبة: {caps.map((c) => CAPABILITY_LABELS[c]).join(' أو ')}. تواصل مع مدير المنصة.
      </Alert>
    </div>
  )
}
