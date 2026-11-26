import { fireEvent, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import statsFixture from '@contracts/fixtures/admin-stats.json'
import { renderAdmin, moderator, ADMIN_WHOAMI } from '@admin/test/render'
import { installFakeSupabase } from '@admin/test/fakeSupabase'
import { ERROR_MESSAGES_AR } from '@admin/lib/errors'
import { formatDateTime } from '@admin/lib/format'
import type { Whoami } from '@admin/lib/capabilities'
import OverviewPage from './OverviewPage'
import { defaultRange, rangeToArgs } from './dateRange'

function setup(opts: { whoami?: Whoami | null; stats?: unknown; delay?: Promise<void> } = {}) {
  const fake = installFakeSupabase({
    rpc: {
      admin_stats: async () => {
        if (opts.delay) await opts.delay
        return opts.stats ?? statsFixture
      },
    },
  })
  const utils = renderAdmin(<OverviewPage />, { route: '/admin', path: '/admin', whoami: opts.whoami === undefined ? ADMIN_WHOAMI : opts.whoami })
  return { fake, ...utils }
}

const waitForStats = () => screen.findByTestId('stat-accounts.total')

describe('OverviewPage — header and quick links', () => {
  it('shows the role and links to every section for an admin, without the overview itself', async () => {
    setup()
    expect(screen.getByRole('heading', { name: 'الرئيسية' })).toBeInTheDocument()
    expect(screen.getByText('مدير')).toBeInTheDocument()
    const nav = screen.getByRole('navigation', { name: 'الأقسام المتاحة' })
    const links = within(nav).getAllByRole('link')
    expect(links.map((l) => l.getAttribute('href'))).toEqual([
      '/admin/listings',
      '/admin/accounts',
      '/admin/promotions',
      '/admin/reports',
      '/admin/ratings',
      '/admin/lookups',
      '/admin/settings',
      '/admin/staff',
      '/admin/audit',
    ])
    expect(within(nav).getByRole('link', { name: /إدارة الإعلانات/ })).toBeInTheDocument()
    await waitForStats()
  })

  it('filters links by capability and skips stats without stats.read', async () => {
    const { fake } = setup({ whoami: moderator(['reports.handle', 'listings.review']) })
    expect(screen.getByText('مشرف')).toBeInTheDocument()
    const nav = screen.getByRole('navigation', { name: 'الأقسام المتاحة' })
    expect(within(nav).getAllByRole('link').map((l) => l.getAttribute('href'))).toEqual(['/admin/listings', '/admin/reports'])
    expect(screen.getByText(/التقارير متاحة لمن يملك صلاحية «التقارير التجميعية»/)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'تحديث' })).not.toBeInTheDocument()
    expect(screen.queryByLabelText('من يوم')).not.toBeInTheDocument()
    // لا استدعاء للتقارير حتى بعد استقرار الصفحة.
    await new Promise((r) => setTimeout(r, 20))
    expect(fake.rpcCalls('admin_stats')).toHaveLength(0)
  })

  it('shows an empty note when the only capability is stats.read', async () => {
    const { fake } = setup({ whoami: moderator(['stats.read']) })
    expect(screen.getByText('لا توجد أقسام أخرى متاحة لدورك حاليًا.')).toBeInTheDocument()
    await waitForStats()
    expect(fake.rpcCalls('admin_stats')).toHaveLength(1)
  })
})

describe('OverviewPage — aggregate report', () => {
  it('goes from loading to the fixture data with Arabic labels', async () => {
    let release: () => void = () => {}
    const delay = new Promise<void>((r) => {
      release = r
    })
    setup({ delay })
    expect(await screen.findByText('جارٍ تحميل التقارير…')).toBeInTheDocument()
    release()
    await waitForStats()

    const expectTile = (id: string, label: string, value: string) => {
      const tile = screen.getByTestId(`stat-${id}`)
      expect(within(tile).getByText(label)).toBeInTheDocument()
      expect(within(tile).getByText(value)).toBeInTheDocument()
    }
    expectTile('accounts.total', 'إجمالي الحسابات', '2')
    expectTile('accounts.created', 'حسابات جديدة', '2')
    expectTile('accounts.suspended_now', 'حسابات معلقة', '0')
    expectTile('listings.submitted', 'أُرسل/نُشر', '1')
    expectTile('listings.approved', 'نُشر مباشرة', '1')
    expectTile('listings.hidden', 'أُخفي إداريًا', '0')
    expectTile('listings.published_now', 'منشور', '1')
    expectTile('reports.opened', 'بلاغات جديدة', '1')
    expectTile('reports.closed', 'بلاغات أُغلقت', '1')
    expectTile('reports.open_now', 'بلاغات مفتوحة', '0')
    expectTile('ratings.created', 'تقييمات جديدة', '1')
    expectTile('ratings.hidden_now', 'تقييمات مخفية', '0')
    expectTile('ratings.appeals_opened', 'اعتراضات جديدة', '1')
    expectTile('ratings.appeals_open_now', 'اعتراضات مفتوحة', '0')
    expectTile('follows.searches_saved', 'عمليات بحث محفوظة', '1')
    expectTile('follows.sellers_followed', 'متابعات معلنين', '1')
    expectTile('interaction.messages_sent', 'رسائل أُرسلت', '2')
    expectTile('interaction.comments_posted', 'ردود عامة نُشرت', '2')
    expectTile('interaction.favorites_added', 'إضافات إلى المفضلة', '0')
    expectTile('interaction.conversations_started', 'محادثات بدأت', '1')

    for (const title of ['الحسابات', 'الإعلانات', 'البلاغات', 'التقييمات والاعتراضات', 'المتابعة والبحث المحفوظ', 'التواصل والتفاعل']) {
      expect(screen.getByRole('heading', { name: title })).toBeInTheDocument()
    }
    // تعريف الفترة ووقت التحديث بتوقيت الرياض.
    const kv = (label: string) => screen.getByText(label).nextElementSibling
    expect(kv('بداية الفترة')).toHaveTextContent(formatDateTime(statsFixture.period.from))
    expect(kv('نهاية الفترة (غير مشمولة)')).toHaveTextContent(formatDateTime(statsFixture.period.to))
    expect(kv('وقت التحديث')).toHaveTextContent(formatDateTime(statsFixture.generated_at))
    // التواصل ليس بيعًا.
    expect(screen.getByText(/أعداد التواصل والتفاعل ليست عمليات بيع\. الضغط على الاتصال/)).toBeInTheDocument()
  })

  it('never renders under_review_now or rejected (INT-008)', async () => {
    setup({ stats: { ...statsFixture, listings: { ...statsFixture.listings, under_review_now: 7, rejected: 9 } } })
    await waitForStats()
    expect(screen.queryByTestId('stat-listings.under_review_now')).not.toBeInTheDocument()
    expect(screen.queryByTestId('stat-listings.rejected')).not.toBeInTheDocument()
    expect(screen.queryByText('under_review_now')).not.toBeInTheDocument()
    expect(screen.queryByText('rejected')).not.toBeInTheDocument()
    expect(screen.queryByText(/قيد المراجعة/)).not.toBeInTheDocument()
    expect(screen.queryByText(/مرفوض|رُفض/)).not.toBeInTheDocument()
    expect(screen.queryByText('7')).not.toBeInTheDocument()
    expect(screen.queryByText('9')).not.toBeInTheDocument()
  })

  it('renders unknown numeric keys and groups with their raw key', async () => {
    setup({
      stats: {
        ...statsFixture,
        listings: { ...statsFixture.listings, views_total: 1234 },
        views: { unique_views: 55, note: 'not a number' },
      },
    })
    await waitForStats()
    const tile = screen.getByTestId('stat-listings.views_total')
    expect(within(tile).getByText('views_total')).toBeInTheDocument()
    expect(within(tile).getByText('1,234')).toBeInTheDocument()
    expect(screen.getByRole('heading', { name: 'views' })).toBeInTheDocument()
    expect(within(screen.getByTestId('stat-views.unique_views')).getByText('55')).toBeInTheDocument()
    expect(screen.queryByTestId('stat-views.note')).not.toBeInTheDocument()
  })

  it('sends the default last-30-days range in Riyadh days', async () => {
    const { fake } = setup()
    await waitForStats()
    const range = defaultRange()
    expect(fake.rpcCalls('admin_stats')).toEqual([rangeToArgs(range)])
    expect(screen.getByLabelText('من يوم')).toHaveValue(range.from)
    expect(screen.getByLabelText('إلى يوم')).toHaveValue(range.to)
  })

  it('sends the exact bounds for a chosen range', async () => {
    const { fake } = setup()
    await waitForStats()
    fireEvent.change(screen.getByLabelText('من يوم'), { target: { value: '2026-01-01' } })
    fireEvent.change(screen.getByLabelText('إلى يوم'), { target: { value: '2026-01-31' } })
    await userEvent.click(screen.getByRole('button', { name: 'عرض التقرير' }))
    await waitFor(() => expect(fake.rpcCalls('admin_stats')).toHaveLength(2))
    expect(fake.rpcCalls('admin_stats')[1]).toEqual({ p_from: '2025-12-31T21:00:00.000Z', p_to: '2026-01-31T21:00:00.000Z' })
  })

  it('accepts a full 366-day range', async () => {
    const { fake } = setup()
    await waitForStats()
    fireEvent.change(screen.getByLabelText('من يوم'), { target: { value: '2025-01-01' } })
    fireEvent.change(screen.getByLabelText('إلى يوم'), { target: { value: '2026-01-01' } })
    await userEvent.click(screen.getByRole('button', { name: 'عرض التقرير' }))
    await waitFor(() => expect(fake.rpcCalls('admin_stats')).toHaveLength(2))
    expect(fake.rpcCalls('admin_stats')[1]).toEqual({ p_from: '2024-12-31T21:00:00.000Z', p_to: '2026-01-01T21:00:00.000Z' })
  })

  it('blocks from > to without calling the server', async () => {
    const { fake } = setup()
    await waitForStats()
    fireEvent.change(screen.getByLabelText('من يوم'), { target: { value: '2026-02-10' } })
    fireEvent.change(screen.getByLabelText('إلى يوم'), { target: { value: '2026-02-01' } })
    await userEvent.click(screen.getByRole('button', { name: 'عرض التقرير' }))
    expect(await screen.findByText('تاريخ النهاية يجب أن يكون في يوم البداية أو بعده.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_stats')).toHaveLength(1)
  })

  it('blocks a span over 366 days and an empty date without calling the server', async () => {
    const { fake } = setup()
    await waitForStats()
    fireEvent.change(screen.getByLabelText('من يوم'), { target: { value: '2025-01-01' } })
    fireEvent.change(screen.getByLabelText('إلى يوم'), { target: { value: '2026-01-02' } })
    await userEvent.click(screen.getByRole('button', { name: 'عرض التقرير' }))
    expect(await screen.findByText('الفترة لا تتجاوز 366 يومًا.')).toBeInTheDocument()

    fireEvent.change(screen.getByLabelText('من يوم'), { target: { value: '' } })
    await userEvent.click(screen.getByRole('button', { name: 'عرض التقرير' }))
    expect(await screen.findByText('أدخل تاريخ البداية.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_stats')).toHaveLength(1)
  })

  it('shows the Arabic message for VALIDATION_FAILED from the server', async () => {
    const fake = installFakeSupabase({ rpc: { admin_stats: () => statsFixture } })
    fake.failRpc('admin_stats', 'VALIDATION_FAILED', { fields: ['p_from', 'p_to'] })
    renderAdmin(<OverviewPage />, { route: '/admin', path: '/admin' })
    expect(await screen.findByText('الفترة غير صالحة')).toBeInTheDocument()
    expect(screen.getByText(ERROR_MESSAGES_AR.VALIDATION_FAILED!)).toBeInTheDocument()
    expect(fake.rpcCalls('admin_stats')).toHaveLength(1)
  })

  it.each(['FORBIDDEN', 'MFA_REQUIRED'] as const)('shows the Arabic message for %s', async (code) => {
    const fake = installFakeSupabase({ rpc: { admin_stats: () => statsFixture } })
    fake.failRpc('admin_stats', code)
    renderAdmin(<OverviewPage />, { route: '/admin', path: '/admin' })
    expect(await screen.findByText('تعذر تحميل التقارير')).toBeInTheDocument()
    expect(screen.getByText(ERROR_MESSAGES_AR[code]!)).toBeInTheDocument()
  })

  it('recovers from an error with retry', async () => {
    const fake = installFakeSupabase({ rpc: { admin_stats: () => statsFixture } })
    fake.failRpc('admin_stats', 'INTERNAL_ERROR', undefined, 1)
    renderAdmin(<OverviewPage />, { route: '/admin', path: '/admin' })
    expect(await screen.findByText(ERROR_MESSAGES_AR.INTERNAL_ERROR!)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'إعادة المحاولة' }))
    await waitForStats()
    expect(fake.rpcCalls('admin_stats')).toHaveLength(2)
  })

  it('refreshes with the same range on demand', async () => {
    const { fake } = setup()
    await waitForStats()
    await userEvent.click(screen.getByRole('button', { name: 'تحديث' }))
    await waitFor(() => expect(fake.rpcCalls('admin_stats')).toHaveLength(2))
    expect(fake.rpcCalls('admin_stats')[1]).toEqual(fake.rpcCalls('admin_stats')[0])
  })
})
