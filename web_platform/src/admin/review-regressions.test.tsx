// اختبارات انحدار لملاحظات المراجعة المستقلة (ADMIN-DASH-20261124).
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import listFx from '@contracts/fixtures/admin-list-listings.json'
import whoamiFixture from '@contracts/fixtures/admin-whoami.json'
import { AuthProvider, useAuth } from './auth/AuthContext'
import { installFakeSupabase } from './test/fakeSupabase'
import { renderAdmin } from './test/render'
import { rpc } from './lib/rpc'
import { setGlobalApiErrorHandler } from './lib/queryClient'
import { Dialog, NotifyProvider } from './ui'
import ListingsPage from './features/listings/ListingsPage'
import ReportDetailPage from './features/reports/ReportDetailPage'
import { reportRow } from './features/reports/testData'
import type { AdminListingItem } from './features/listings/types'

type FakeAuth = Record<string, unknown> & { mfa: Record<string, unknown> }

describe('sign-out', () => {
  it('falls back to a local sign-out when the server sign-out fails', async () => {
    const fake = installFakeSupabase({ rpc: { admin_whoami: () => whoamiFixture } })
    const auth = (fake.client as { auth: FakeAuth }).auth
    auth.getSession = async () => ({ data: { session: { user: { email: 's@example.test' } } }, error: null })
    const scopes: Array<string | undefined> = []
    auth.signOut = async (opts?: { scope?: string }) => {
      scopes.push(opts?.scope)
      return opts?.scope === 'local' ? { error: null } : { error: { message: 'network down' } }
    }
    function Probe() {
      const { status, signOut } = useAuth()
      return (
        <>
          <p>{status}</p>
          <button onClick={() => void signOut()}>out</button>
        </>
      )
    }
    render(
      <NotifyProvider>
        <AuthProvider>
          <Probe />
        </AuthProvider>
      </NotifyProvider>,
    )
    expect(await screen.findByText('ready')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'out' }))
    expect(await screen.findByText('signedOut')).toBeInTheDocument()
    expect(scopes).toEqual([undefined, 'local'])
  })
})

describe('background whoami re-check', () => {
  it('keeps the panel on a transient error but leaves on FORBIDDEN', async () => {
    const fake = installFakeSupabase({ rpc: { admin_whoami: () => whoamiFixture } })
    const auth = (fake.client as { auth: FakeAuth }).auth
    auth.getSession = async () => ({ data: { session: { user: { email: 's@example.test' } } }, error: null })
    let refresh: (() => Promise<void>) | null = null
    function Probe() {
      const ctx = useAuth()
      refresh = ctx.refresh
      return <p>{ctx.status}</p>
    }
    render(
      <AuthProvider>
        <Probe />
      </AuthProvider>,
    )
    expect(await screen.findByText('ready')).toBeInTheDocument()
    fake.failRpc('admin_whoami', 'INTERNAL_ERROR', {}, 1)
    await refresh!()
    expect(screen.getByText('ready')).toBeInTheDocument()
    fake.failRpc('admin_whoami', 'FORBIDDEN')
    await refresh!()
    await waitFor(() => expect(screen.getByText('notStaff')).toBeInTheDocument())
  })
})

describe('rpc auth error reporting', () => {
  it('reports session/MFA/permission errors to the auth handler, not business errors', async () => {
    const fake = installFakeSupabase()
    const seen: string[] = []
    setGlobalApiErrorHandler((e) => seen.push((e as { code: string }).code))
    fake.failRpc('admin_hide_listing', 'MFA_REQUIRED', {}, 1)
    await rpc('admin_hide_listing', { p_listing_id: 'x', p_reason_code: 'FRAUD' }).catch(() => undefined)
    fake.failRpc('admin_hide_listing', 'INVALID_STATE', {}, 1)
    await rpc('admin_hide_listing', { p_listing_id: 'x', p_reason_code: 'FRAUD' }).catch(() => undefined)
    setGlobalApiErrorHandler(null)
    expect(seen).toEqual(['MFA_REQUIRED'])
  })
})

describe('listings list draft badge', () => {
  it('does not mark a never-published draft as an unpublished edit', async () => {
    const base = (listFx as AdminListingItem[])[0]!
    const draft: AdminListingItem = { ...base, listing_id: 'd0000000-0000-4000-8000-0000000000aa', status: 'DRAFT', has_draft: true, published_version_id: null, title: 'مسودة جديدة', cover: null }
    installFakeSupabase({ rpc: { admin_list_listings: () => [draft] } })
    renderAdmin(<ListingsPage />, { route: '/admin/listings', path: '/admin/listings' })
    expect(await screen.findByText('مسودة جديدة')).toBeInTheDocument()
    expect(screen.queryByText('تعديل غير منشور')).not.toBeInTheDocument()
  })
})

describe('rating reports', () => {
  it('labels the RATING target and links to the rating', async () => {
    const ratingId = 'e0000000-0000-4000-8000-0000000000bb'
    const row = reportRow({ target_type: 'RATING', target_id: ratingId, listing_id: null })
    installFakeSupabase({ tables: { reports: [{ ...row }] } })
    renderAdmin(<ReportDetailPage />, { route: `/admin/reports/${row.id}`, path: '/admin/reports/:reportId' })
    expect((await screen.findAllByText(/تقييم/)).length).toBeGreaterThan(0)
    const links = screen.getAllByRole('link').map((a) => a.getAttribute('href'))
    expect(links).toContain(`/admin/ratings/${ratingId}`)
  })
})

describe('dialog focus trap', () => {
  it('wraps Tab focus inside the modal', async () => {
    render(
      <Dialog open title="حوار" onClose={() => {}} footer={<button>تأكيد</button>}>
        <input aria-label="حقل" />
      </Dialog>,
    )
    const close = screen.getByRole('button', { name: 'إغلاق' })
    const confirm = screen.getByRole('button', { name: 'تأكيد' })
    confirm.focus()
    await userEvent.tab()
    expect(document.activeElement).toBe(close)
    await userEvent.tab({ shift: true })
    expect(document.activeElement).toBe(confirm)
  })
})
