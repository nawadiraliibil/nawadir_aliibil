import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { AuthProvider } from './AuthContext'
import { RequireStaff } from './Guards'
import { installFakeSupabase, type FakeSupabase } from '../test/fakeSupabase'
import { NotifyProvider } from '../ui'
import whoamiFixture from '@contracts/fixtures/admin-whoami.json'

type Aal = { currentLevel: string; nextLevel: string }

function withSession(fake: FakeSupabase, aal: Aal, factors: { all: unknown[]; totp: unknown[] } = { all: [], totp: [] }) {
  const auth = (fake.client as { auth: Record<string, unknown> & { mfa: Record<string, unknown> } }).auth
  auth.getSession = async () => ({ data: { session: { user: { email: 'staff@example.test' } } }, error: null })
  auth.mfa.getAuthenticatorAssuranceLevel = async () => ({ data: aal, error: null })
  auth.mfa.listFactors = async () => ({ data: { ...factors, phone: [] }, error: null })
}

function mount() {
  return render(
    <NotifyProvider>
      <AuthProvider>
        <RequireStaff>
          <p>محتوى اللوحة</p>
        </RequireStaff>
      </AuthProvider>
    </NotifyProvider>,
  )
}

describe('RequireStaff', () => {
  it('shows the login form when signed out', async () => {
    installFakeSupabase()
    mount()
    expect(await screen.findByRole('heading', { name: 'دخول لوحة الإدارة' })).toBeInTheDocument()
    expect(screen.queryByText('محتوى اللوحة')).not.toBeInTheDocument()
  })

  it('asks for TOTP enrollment when the session is aal1 with no factor', async () => {
    const fake = installFakeSupabase()
    withSession(fake, { currentLevel: 'aal1', nextLevel: 'aal1' })
    mount()
    expect(await screen.findByRole('heading', { name: 'تفعيل التحقق بخطوتين' })).toBeInTheDocument()
    expect(await screen.findByAltText(/رمز QR/)).toBeInTheDocument()
    expect(fake.rpcCalls('admin_whoami')).toHaveLength(0)
  })

  it('asks for the TOTP code when a verified factor exists, then enters', async () => {
    const fake = installFakeSupabase({ rpc: { admin_whoami: () => whoamiFixture } })
    withSession(fake, { currentLevel: 'aal1', nextLevel: 'aal2' }, { all: [{ id: 'f1', factor_type: 'totp', status: 'verified' }], totp: [{ id: 'f1' }] })
    const auth = (fake.client as { auth: Record<string, unknown> & { mfa: Record<string, unknown> } }).auth
    auth.mfa.challengeAndVerify = async () => {
      auth.mfa.getAuthenticatorAssuranceLevel = async () => ({ data: { currentLevel: 'aal2', nextLevel: 'aal2' }, error: null })
      return { data: {}, error: null }
    }
    mount()
    expect(await screen.findByRole('heading', { name: 'التحقق بخطوتين' })).toBeInTheDocument()
    await userEvent.type(await screen.findByLabelText(/رمز التحقق/), '123456')
    await userEvent.click(screen.getByRole('button', { name: 'تحقق' }))
    expect(await screen.findByText('محتوى اللوحة')).toBeInTheDocument()
  })

  it('rejects a normal (non-staff) account: FORBIDDEN from admin_whoami', async () => {
    const fake = installFakeSupabase()
    fake.failRpc('admin_whoami', 'FORBIDDEN')
    withSession(fake, { currentLevel: 'aal2', nextLevel: 'aal2' })
    mount()
    expect(await screen.findByRole('heading', { name: 'لا صلاحية للدخول' })).toBeInTheDocument()
    expect(screen.queryByText('محتوى اللوحة')).not.toBeInTheDocument()
  })

  it('routes MFA_REQUIRED from the server back to verification', async () => {
    const fake = installFakeSupabase()
    fake.failRpc('admin_whoami', 'MFA_REQUIRED')
    withSession(fake, { currentLevel: 'aal2', nextLevel: 'aal2' }, { all: [], totp: [{ id: 'f1' }] })
    mount()
    expect(await screen.findByRole('heading', { name: 'التحقق بخطوتين' })).toBeInTheDocument()
  })

  it('enters the panel for an aal2 staff session', async () => {
    const fake = installFakeSupabase({ rpc: { admin_whoami: () => whoamiFixture } })
    withSession(fake, { currentLevel: 'aal2', nextLevel: 'aal2' })
    mount()
    await waitFor(() => expect(screen.getByText('محتوى اللوحة')).toBeInTheDocument())
  })
})
