import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Whoami } from '@admin/lib/capabilities'
import { installFakeSupabase, type FakeSupabase } from '@admin/test/fakeSupabase'
import { moderator, renderAdmin } from '@admin/test/render'
import AccountDetailPage from './AccountDetailPage'
import type { AdminAccount } from './types'
import { ACTIVE_ACCOUNT, ACTIVE_ID, REASONS, REGIONS, SUSPENDED_ACCOUNT, SUSPENDED_ID } from './testData'

interface Setup {
  account?: AdminAccount
  whoami?: Whoami | null
  before?: (fake: FakeSupabase) => void
  route?: string
}

/** خادم مزيف بحالة: التعليق والتفعيل يغيران الحساب كما تفعل الدوال الحقيقية. */
function setup({ account = ACTIVE_ACCOUNT, whoami, before, route }: Setup = {}) {
  let state: AdminAccount = { ...account, listing_counts: { ...account.listing_counts } }
  const fake = installFakeSupabase({
    tables: { regions: REGIONS, moderation_reasons: REASONS },
    rpc: {
      admin_get_account: () => state,
      admin_suspend_account: (args) => {
        const c = state.listing_counts
        const hidden = (c.HIDDEN ?? 0) + (c.PUBLISHED ?? 0)
        const { PUBLISHED: _p, ...rest } = c
        state = {
          ...state,
          status: 'SUSPENDED',
          status_changed_at: '2026-11-24T10:00:00+00:00',
          suspension_reason_code: args.p_reason_code as string,
          suspension_reason_text: (args.p_reason_text as string | undefined) ?? null,
          listing_counts: { ...rest, HIDDEN: hidden },
        }
        return state
      },
      admin_reactivate_account: () => {
        state = { ...state, status: 'ACTIVE', status_changed_at: '2026-11-24T11:00:00+00:00', suspension_reason_code: null, suspension_reason_text: null }
        return state
      },
    },
  })
  before?.(fake)
  const utils = renderAdmin(<AccountDetailPage />, {
    route: route ?? `/admin/accounts/${account.id}`,
    path: '/admin/accounts/:userId',
    whoami,
    extraRoutes: [{ path: '/admin/listings', element: <div data-testid="listings-route" /> }],
  })
  return { fake, ...utils }
}

describe('AccountDetailPage', () => {
  it('shows loading then the account payload (function shape) with phone and counts', async () => {
    const { fake } = setup()
    expect(screen.getByRole('status')).toHaveTextContent('جارٍ التحميل')
    expect(await screen.findByRole('heading', { level: 1, name: 'معلن تجريبي' })).toBeInTheDocument()
    expect(fake.rpcCalls('admin_get_account')).toEqual([{ p_user_id: ACTIVE_ID }])
    expect(screen.getByLabelText('رقم هاتف الدخول')).toHaveTextContent('+966500000001')
    expect(screen.getByText(/بيانات خاصة/)).toBeInTheDocument()
    expect(screen.getByTestId('count-PUBLISHED')).toHaveTextContent('3')
    expect(screen.getByTestId('count-HIDDEN')).toHaveTextContent('0')
    expect(screen.getByTestId('count-DRAFT')).toHaveTextContent('1')
    expect(screen.getByTestId('count-ARCHIVED')).toHaveTextContent('2')
    expect(screen.getByTestId('count-total')).toHaveTextContent('6')
    expect(screen.queryByText(/قيد المراجعة/)).not.toBeInTheDocument()
    expect(await screen.findByText('الرياض')).toBeInTheDocument()
    const link = screen.getByRole('link', { name: 'عرض إعلانات الحساب' })
    expect(link).toHaveAttribute('href', `/admin/listings?q=${encodeURIComponent('معلن تجريبي').replace(/%20/g, '+')}`)
    expect(screen.getByRole('button', { name: 'تعليق الحساب' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إعادة التفعيل' })).not.toBeInTheDocument()
  })

  it('shows the current suspension reason, text, date and hidden link', async () => {
    setup({ account: SUSPENDED_ACCOUNT })
    expect(await screen.findByRole('heading', { level: 1, name: 'حساب معلق' })).toBeInTheDocument()
    expect(await screen.findByText('اشتباه احتيال أو إساءة استخدام')).toBeInTheDocument()
    expect(screen.getByText('تكرار إعلانات مضللة')).toBeInTheDocument()
    expect(screen.getAllByText(/2026/).length).toBeGreaterThan(0)
    const hidden = screen.getAllByRole('link', { name: 'عرض الإعلانات المخفية' })[0]!
    expect(hidden.getAttribute('href')).toContain('status=HIDDEN')
    expect(hidden.getAttribute('href')).toContain(`q=${encodeURIComponent('حساب').replace(/%20/g, '+')}`)
    expect(screen.getByRole('button', { name: 'إعادة التفعيل' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'تعليق الحساب' })).not.toBeInTheDocument()
  })

  it('falls back to the reason code when the label is unknown', async () => {
    setup({ account: { ...SUSPENDED_ACCOUNT, suspension_reason_code: 'OLD_REASON' } })
    expect(await screen.findByText('OLD_REASON')).toBeInTheDocument()
  })

  it('shows not found for NOT_FOUND', async () => {
    setup({ before: (f) => f.failRpc('admin_get_account', 'NOT_FOUND', { resource: 'account' }) })
    expect(await screen.findByText('الحساب غير موجود')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'العودة إلى الحسابات' })).toHaveAttribute('href', '/admin/accounts')
  })

  it('shows not found for a malformed id without calling the server', async () => {
    const { fake } = setup({ route: '/admin/accounts/not-a-uuid' })
    expect(await screen.findByText('الحساب غير موجود')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_get_account')).toHaveLength(0)
  })

  it('shows the error state with retry', async () => {
    const { fake } = setup({ before: (f) => f.failRpc('admin_get_account', 'MFA_REQUIRED', {}, 1) })
    expect(await screen.findByText(/يلزم إكمال التحقق بخطوتين/)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'إعادة المحاولة' }))
    expect(await screen.findByRole('heading', { level: 1, name: 'معلن تجريبي' })).toBeInTheDocument()
    expect(fake.rpcCalls('admin_get_account')).toHaveLength(2)
  })

  it('blocks suspension without a reason, requires text for OTHER, and sends exact args', async () => {
    const { fake } = setup()
    await userEvent.click(await screen.findByRole('button', { name: 'تعليق الحساب' }))
    const dialog = await screen.findByRole('dialog')
    expect(within(dialog).getByText(/يخفي كل إعلانات الحساب المنشورة \(3 حاليًا\)/)).toBeInTheDocument()
    const select = await within(dialog).findByLabelText(/السبب/)
    expect(Array.from((select as HTMLSelectElement).options).map((o) => o.value)).toEqual(['', 'FRAUD', 'ABUSE', 'OTHER'])
    const confirm = within(dialog).getByRole('button', { name: 'تعليق الحساب' })

    await userEvent.click(confirm)
    expect(await within(dialog).findByText('اختر سببًا.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_suspend_account')).toHaveLength(0)

    await userEvent.selectOptions(select, 'OTHER')
    await userEvent.click(confirm)
    expect(await within(dialog).findByText('اكتب توضيحًا لهذا السبب.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_suspend_account')).toHaveLength(0)

    await userEvent.type(within(dialog).getByLabelText(/التوضيح/), '  مخالفة متكررة  ')
    await userEvent.click(confirm)
    await waitFor(() =>
      expect(fake.rpcCalls('admin_suspend_account')).toEqual([{ p_user_id: ACTIVE_ID, p_reason_code: 'OTHER', p_reason_text: 'مخالفة متكررة' }]),
    )
    expect(await screen.findByText('تم تعليق الحساب وإخفاء إعلاناته المنشورة.')).toBeInTheDocument()
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(await screen.findByRole('button', { name: 'إعادة التفعيل' })).toBeInTheDocument()
    expect(screen.getByText('مخالفة متكررة')).toBeInTheDocument()
    expect(screen.getByTestId('count-HIDDEN')).toHaveTextContent('3')
  })

  it('omits p_reason_text when the optional text is empty', async () => {
    const { fake } = setup()
    await userEvent.click(await screen.findByRole('button', { name: 'تعليق الحساب' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.selectOptions(await within(dialog).findByLabelText(/السبب/), 'FRAUD')
    await userEvent.click(within(dialog).getByRole('button', { name: 'تعليق الحساب' }))
    await waitFor(() => expect(fake.rpcCalls('admin_suspend_account')).toHaveLength(1))
    expect(fake.rpcCalls('admin_suspend_account')[0]).toStrictEqual({ p_user_id: ACTIVE_ID, p_reason_code: 'FRAUD' })
  })

  it('shows INVALID_STATE in Arabic, keeps the dialog open and refetches without retrying', async () => {
    const { fake } = setup({ before: (f) => f.failRpc('admin_suspend_account', 'INVALID_STATE', { status: 'SUSPENDED' }) })
    await userEvent.click(await screen.findByRole('button', { name: 'تعليق الحساب' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.selectOptions(await within(dialog).findByLabelText(/السبب/), 'ABUSE')
    await userEvent.click(within(dialog).getByRole('button', { name: 'تعليق الحساب' }))
    expect(await within(dialog).findByText(/لا يسمح بهذا الإجراء في الحالة الحالية/)).toBeInTheDocument()
    await waitFor(() => expect(fake.rpcCalls('admin_get_account').length).toBe(2))
    expect(fake.rpcCalls('admin_suspend_account')).toHaveLength(1)
    expect(screen.queryByText('تم تعليق الحساب وإخفاء إعلاناته المنشورة.')).not.toBeInTheDocument()
  })

  it('shows REASON_REQUIRED from the server in Arabic', async () => {
    const { fake } = setup({ before: (f) => f.failRpc('admin_suspend_account', 'REASON_REQUIRED', { field: 'reason_text' }) })
    await userEvent.click(await screen.findByRole('button', { name: 'تعليق الحساب' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.selectOptions(await within(dialog).findByLabelText(/السبب/), 'FRAUD')
    await userEvent.click(within(dialog).getByRole('button', { name: 'تعليق الحساب' }))
    expect(await within(dialog).findByText(/السبب إلزامي/)).toBeInTheDocument()
    expect(fake.rpcCalls('admin_suspend_account')).toHaveLength(1)
  })

  it('reactivates with a note and shows the no-republish notice', async () => {
    const { fake } = setup({ account: SUSPENDED_ACCOUNT })
    await userEvent.click(await screen.findByRole('button', { name: 'إعادة التفعيل' }))
    const dialog = await screen.findByRole('dialog')
    expect(within(dialog).getByText(/لا تعيد نشر إعلانات الحساب المخفية \(4\)/)).toBeInTheDocument()
    expect(within(dialog).getByRole('link', { name: 'عرض الإعلانات المخفية' }).getAttribute('href')).toContain('status=HIDDEN')
    await userEvent.type(within(dialog).getByLabelText(/ملاحظة داخلية/), 'راجعت الحالة')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إعادة التفعيل' }))
    await waitFor(() => expect(fake.rpcCalls('admin_reactivate_account')).toEqual([{ p_user_id: SUSPENDED_ID, p_note: 'راجعت الحالة' }]))
    expect(await screen.findByText(/أعيد تفعيل الحساب\. إعلاناته المخفية لم يُعد نشرها/)).toBeInTheDocument()
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(await screen.findByRole('button', { name: 'تعليق الحساب' })).toBeInTheDocument()
    // بعد التفعيل يبقى تنبيه الإعلانات المخفية مع رابطها.
    expect(screen.getByText(/لهذا الحساب 4 إعلانات مخفية/)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'عرض الإعلانات المخفية' }).getAttribute('href')).toContain('status=HIDDEN')
  })

  it('reactivates without a note by omitting p_note', async () => {
    const { fake } = setup({ account: SUSPENDED_ACCOUNT })
    await userEvent.click(await screen.findByRole('button', { name: 'إعادة التفعيل' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إعادة التفعيل' }))
    await waitFor(() => expect(fake.rpcCalls('admin_reactivate_account')).toHaveLength(1))
    expect(fake.rpcCalls('admin_reactivate_account')[0]).toStrictEqual({ p_user_id: SUSPENDED_ID })
  })

  it('shows INVALID_STATE on reactivate and refetches', async () => {
    const { fake } = setup({ account: SUSPENDED_ACCOUNT, before: (f) => f.failRpc('admin_reactivate_account', 'INVALID_STATE', { status: 'ACTIVE' }) })
    await userEvent.click(await screen.findByRole('button', { name: 'إعادة التفعيل' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إعادة التفعيل' }))
    expect(await within(dialog).findByText(/لا يسمح بهذا الإجراء في الحالة الحالية/)).toBeInTheDocument()
    await waitFor(() => expect(fake.rpcCalls('admin_get_account').length).toBe(2))
  })

  it('hides actions and listing links for a moderator without accounts.manage or listings caps', async () => {
    setup({ whoami: moderator([]) })
    expect(await screen.findByRole('heading', { level: 1, name: 'معلن تجريبي' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'تعليق الحساب' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إعادة التفعيل' })).not.toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'عرض إعلانات الحساب' })).not.toBeInTheDocument()
  })

  it('hides reactivate for a moderator without accounts.manage on a suspended account', async () => {
    setup({ account: SUSPENDED_ACCOUNT, whoami: moderator(['listings.review']) })
    expect(await screen.findByRole('heading', { level: 1, name: 'حساب معلق' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إعادة التفعيل' })).not.toBeInTheDocument()
    expect(screen.getAllByRole('link', { name: 'عرض الإعلانات المخفية' }).length).toBeGreaterThan(0)
  })

  it('shows actions but no listing links for accounts.manage only', async () => {
    setup({ whoami: moderator(['accounts.manage']) })
    expect(await screen.findByRole('button', { name: 'تعليق الحساب' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'عرض إعلانات الحساب' })).not.toBeInTheDocument()
  })

  it('handles an account without a name or phone', async () => {
    setup({ account: { ...ACTIVE_ACCOUNT, display_name: null, phone: null, region_id: null, listing_counts: {} } })
    expect(await screen.findByRole('heading', { level: 1, name: 'بدون اسم' })).toBeInTheDocument()
    expect(screen.getByLabelText('رقم هاتف الدخول')).toHaveTextContent('—')
    expect(screen.getByTestId('count-total')).toHaveTextContent('0')
    expect(screen.queryByRole('link', { name: 'عرض إعلانات الحساب' })).not.toBeInTheDocument()
    expect(screen.getByText(/لا اسم عرض لهذا الحساب/)).toBeInTheDocument()
  })
})
