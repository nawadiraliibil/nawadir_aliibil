import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { installFakeSupabase, type FakeSupabase } from '@admin/test/fakeSupabase'
import { renderAdmin } from '@admin/test/render'
import AccountsPage from './AccountsPage'
import { escapeLike, isUuid } from './api'
import { ACTIVE_ID, PROFILE_ROWS, REASONS, REGIONS, SUSPENDED_ID, manyProfiles } from './testData'

function profileCalls(fake: FakeSupabase) {
  return fake.calls.filter((c) => c.kind === 'select' && c.name === 'profiles')
}

function lastProfileFilters(fake: FakeSupabase) {
  const calls = profileCalls(fake)
  return calls[calls.length - 1]?.filters ?? []
}

function setup(route = '/admin/accounts', tables: Record<string, Array<Record<string, unknown>>> = {}, before?: (fake: FakeSupabase) => void) {
  const fake = installFakeSupabase({
    tables: { profiles: PROFILE_ROWS, regions: REGIONS, moderation_reasons: REASONS, ...tables },
  })
  before?.(fake)
  const utils = renderAdmin(<AccountsPage />, {
    route,
    path: '/admin/accounts',
    extraRoutes: [{ path: '/admin/accounts/:userId', element: <div data-testid="detail-route" /> }],
  })
  return { fake, ...utils }
}

describe('AccountsPage', () => {
  it('shows loading then rows with region, status, reason and total', async () => {
    setup()
    expect(screen.getByRole('status')).toHaveTextContent('جارٍ التحميل')
    const table = await screen.findByRole('table')
    const rows = within(table).getAllByRole('row')
    expect(rows).toHaveLength(4) // رأس + 3
    expect(screen.getByText('معلن تجريبي')).toBeInTheDocument()
    expect(screen.getByText('بدون اسم')).toBeInTheDocument()
    expect(await screen.findByText('الرياض')).toBeInTheDocument()
    expect(screen.getByText('القصيم')).toBeInTheDocument()
    expect(screen.getByText('#99')).toBeInTheDocument()
    expect(screen.getByText(ACTIVE_ID.slice(0, 8))).toBeInTheDocument()
    expect(within(table).getAllByText('فعال')).toHaveLength(2)
    expect(within(table).getByText('معلق')).toBeInTheDocument()
    expect(await screen.findByText('اشتباه احتيال أو إساءة استخدام')).toBeInTheDocument()
    expect(screen.getByText('إجمالي النتائج: 3')).toBeInTheDocument()
  })

  it('orders by created_at desc then id and pages by 50', async () => {
    const { fake } = setup()
    await screen.findByRole('table')
    expect(lastProfileFilters(fake)).toEqual([
      ['order', 'created_at', false],
      ['order', 'id', false],
      ['range', 0, 49],
    ])
  })

  it('filters status from the URL with eq', async () => {
    const { fake } = setup('/admin/accounts?status=SUSPENDED')
    await screen.findByText('حساب معلق')
    expect(screen.queryByText('معلن تجريبي')).not.toBeInTheDocument()
    expect(lastProfileFilters(fake)).toContainEqual(['eq', 'status', 'SUSPENDED'])
    expect((screen.getByLabelText('الحالة') as HTMLSelectElement).value).toBe('SUSPENDED')
  })

  it('changes the status filter from the select', async () => {
    const { fake } = setup()
    await screen.findByRole('table')
    await userEvent.selectOptions(screen.getByLabelText('الحالة'), 'ACTIVE')
    await waitFor(() => expect(lastProfileFilters(fake)).toContainEqual(['eq', 'status', 'ACTIVE']))
    await waitFor(() => expect(screen.queryByText('حساب معلق')).not.toBeInTheDocument())
  })

  it('searches a UUID with eq on id', async () => {
    const { fake } = setup()
    await screen.findByRole('table')
    await userEvent.type(screen.getByLabelText('بحث'), SUSPENDED_ID.toUpperCase())
    await userEvent.click(screen.getByRole('button', { name: 'بحث' }))
    await waitFor(() => expect(lastProfileFilters(fake)).toContainEqual(['eq', 'id', SUSPENDED_ID]))
    expect(lastProfileFilters(fake).some((f) => f[0] === 'ilike')).toBe(false)
    await waitFor(() => expect(screen.queryByText('معلن تجريبي')).not.toBeInTheDocument())
    expect(screen.getByText('حساب معلق')).toBeInTheDocument()
  })

  it('searches text with ilike on display_name', async () => {
    const { fake } = setup()
    await screen.findByRole('table')
    await userEvent.type(screen.getByLabelText('بحث'), 'تجريبي{Enter}')
    await waitFor(() => expect(lastProfileFilters(fake)).toContainEqual(['ilike', 'display_name', '%تجريبي%']))
    await waitFor(() => expect(screen.queryByText('حساب معلق')).not.toBeInTheDocument())
    expect(screen.getByText('معلن تجريبي')).toBeInTheDocument()
  })

  it('reads q and status together from the URL', async () => {
    const { fake } = setup('/admin/accounts?status=ACTIVE&q=%D9%85%D8%B9%D9%84%D9%86')
    await screen.findByText('معلن تجريبي')
    const f = lastProfileFilters(fake)
    expect(f).toContainEqual(['eq', 'status', 'ACTIVE'])
    expect(f).toContainEqual(['ilike', 'display_name', '%معلن%'])
    expect((screen.getByLabelText('بحث') as HTMLInputElement).value).toBe('معلن')
  })

  it('shows an empty state for no matches', async () => {
    setup('/admin/accounts?q=zzz')
    expect(await screen.findByText('لا حسابات مطابقة')).toBeInTheDocument()
  })

  it('shows the error state and retries', async () => {
    const { fake } = setup('/admin/accounts', {}, (f) => f.failTable('profiles', 'FORBIDDEN'))
    expect(await screen.findByText('لا تملك صلاحية تنفيذ هذا الإجراء.')).toBeInTheDocument()
    const before = profileCalls(fake).length
    await userEvent.click(screen.getByRole('button', { name: 'إعادة المحاولة' }))
    await waitFor(() => expect(profileCalls(fake).length).toBeGreaterThan(before))
  })

  it('loads more pages with range', async () => {
    const { fake } = setup('/admin/accounts', { profiles: manyProfiles(60) })
    await screen.findByText('إجمالي النتائج: 60')
    expect(within(screen.getByRole('table')).getAllByRole('row')).toHaveLength(51)
    await userEvent.click(screen.getByRole('button', { name: 'تحميل المزيد' }))
    await waitFor(() => expect(within(screen.getByRole('table')).getAllByRole('row')).toHaveLength(61))
    expect(lastProfileFilters(fake)).toContainEqual(['range', 50, 99])
    expect(screen.queryByRole('button', { name: 'تحميل المزيد' })).not.toBeInTheDocument()
  })

  it('navigates to the detail page from the row', async () => {
    setup()
    await userEvent.click(await screen.findByText('معلن تجريبي'))
    expect(await screen.findByTestId('detail-route')).toBeInTheDocument()
  })
})

describe('accounts helpers', () => {
  it('detects UUIDs and escapes LIKE wildcards', () => {
    expect(isUuid(ACTIVE_ID)).toBe(true)
    expect(isUuid(' ' + ACTIVE_ID.toUpperCase() + ' ')).toBe(true)
    expect(isUuid('ba24f799')).toBe(false)
    expect(escapeLike('50%_a\\b')).toBe('50\\%\\_a\\\\b')
  })
})
