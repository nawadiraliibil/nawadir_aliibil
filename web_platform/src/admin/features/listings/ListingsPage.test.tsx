import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import listFx from '@contracts/fixtures/admin-list-listings.json'
import { renderAdmin, moderator, ADMIN_WHOAMI } from '@admin/test/render'
import { installFakeSupabase } from '@admin/test/fakeSupabase'
import ListingsPage from './ListingsPage'
import { LIST_LIMIT } from './api'
import type { AdminListingItem } from './types'

// يفحص بالأنواع أن مثال العقد يطابق الواجهة (INT-008 معيار 6).
const FIXTURE: AdminListingItem[] = listFx
const BASE = FIXTURE[0]!

const REASONS = [
  { code: 'FRAUD', label_ar: 'اشتباه احتيال', applies_to: ['LISTING_HIDE'], requires_note: false, sort_order: 80, is_active: true },
  { code: 'OTHER', label_ar: 'أخرى', applies_to: ['LISTING_HIDE'], requires_note: true, sort_order: 1000, is_active: true },
]

const HIDDEN_ROW: AdminListingItem = {
  ...BASE,
  listing_id: 'b0000000-0000-4000-8000-000000000002',
  public_ref: 'h1dd3nxx',
  title: 'جمل مخفي',
  status: 'HIDDEN',
  owner_status: 'SUSPENDED',
  owner_display_name: 'معلن معلق',
  hide_reason_code: 'FRAUD',
  hide_reason_text: 'صور مكررة',
  hidden_at: '2026-11-23T10:00:00+00:00',
  status_changed_at: '2026-11-23T10:00:00+00:00',
  has_draft: true,
  cover: null,
}

const AUCTION_ROW: AdminListingItem = {
  ...BASE,
  listing_id: 'c0000000-0000-4000-8000-000000000003',
  public_ref: 'auct1onx',
  title: 'مزاد قعدان',
  offer_type: 'IN_PERSON_AUCTION',
  price: null,
  auction_starts_at: '2026-12-01T15:00:00+00:00',
}

function page(n: number, offset = 0): AdminListingItem[] {
  return Array.from({ length: n }, (_, i) => ({
    ...BASE,
    listing_id: `00000000-0000-4000-8000-${String(offset + i).padStart(12, '0')}`,
    public_ref: `ref${offset + i}`,
    title: `إعلان ${offset + i}`,
    status_changed_at: new Date(Date.UTC(2026, 10, 23, 0, 0, 0) - (offset + i) * 60_000).toISOString(),
  }))
}

function setup(rows: AdminListingItem[] | ((args: Record<string, unknown>) => unknown) = FIXTURE) {
  return installFakeSupabase({
    tables: { moderation_reasons: REASONS },
    rpc: { admin_list_listings: typeof rows === 'function' ? rows : () => rows },
  })
}

const FORBIDDEN_WORDS = /اعتماد|رفض|قيد المراجعة/

describe('ListingsPage', () => {
  it('renders the contract fixture (loading -> data)', async () => {
    setup()
    renderAdmin(<ListingsPage />, { route: '/admin/listings', path: '/admin/listings' })
    expect(screen.getByText('جارٍ تحميل الإعلانات…')).toBeInTheDocument()
    expect(await screen.findByRole('link', { name: 'ناقة مجاهيم للبيع' })).toHaveAttribute('href', `/admin/listings/${BASE.listing_id}`)
    expect(screen.getByText('k7m2q9xa')).toBeInTheDocument()
    const table = screen.getByRole('table')
    expect(within(table).getByText('منشور')).toBeInTheDocument()
    expect(within(table).getByText('سعر ثابت')).toBeInTheDocument()
    expect(within(table).getByText('25,000 ر.س')).toBeInTheDocument()
    const img = await screen.findByRole('img', { name: /غلاف/ })
    expect(img).toHaveAttribute('src', `https://storage.test/listing-images/${BASE.cover!.object_path}?token=t`)
    expect(document.body.textContent).not.toMatch(FORBIDDEN_WORDS)
  })

  it('has no under-review filter option', async () => {
    setup()
    renderAdmin(<ListingsPage />, { route: '/admin/listings', path: '/admin/listings' })
    const select = (await screen.findByLabelText('الحالة')) as HTMLSelectElement
    const values = Array.from(select.options).map((o) => o.value)
    expect(values).toEqual(['', 'PUBLISHED', 'HIDDEN', 'ARCHIVED', 'DRAFT', 'REJECTED'])
    expect(Array.from(select.options).map((o) => o.textContent).join(' ')).not.toMatch(FORBIDDEN_WORDS)
    expect(select.options[5]!.textContent).toMatch(/قديم/)
  })

  it('reads filters from the URL and sends exact rpc args', async () => {
    const fake = setup([])
    renderAdmin(<ListingsPage />, { route: '/admin/listings?q=معلن تجريبي&status=HIDDEN', path: '/admin/listings' })
    await screen.findByText('لا توجد إعلانات مطابقة')
    expect(fake.rpcCalls('admin_list_listings')[0]).toEqual({ p_status: 'HIDDEN', p_query: 'معلن تجريبي', p_limit: LIST_LIMIT })
    expect(screen.getByLabelText('الحالة')).toHaveValue('HIDDEN')
    expect(screen.getByLabelText(/بحث/)).toHaveValue('معلن تجريبي')
  })

  it('ignores an unknown status in the URL', async () => {
    const fake = setup()
    renderAdmin(<ListingsPage />, { route: '/admin/listings?status=UNDER_REVIEW', path: '/admin/listings' })
    await screen.findByRole('link', { name: 'ناقة مجاهيم للبيع' })
    expect(fake.rpcCalls('admin_list_listings')[0]).toEqual({ p_limit: LIST_LIMIT })
  })

  it('status filter and search update the query', async () => {
    const fake = setup()
    renderAdmin(<ListingsPage />, { route: '/admin/listings', path: '/admin/listings' })
    await screen.findByRole('link', { name: 'ناقة مجاهيم للبيع' })
    expect(fake.rpcCalls('admin_list_listings')[0]).toEqual({ p_limit: LIST_LIMIT })

    await userEvent.selectOptions(screen.getByLabelText('الحالة'), 'ARCHIVED')
    await waitFor(() => expect(fake.rpcCalls('admin_list_listings').at(-1)).toEqual({ p_status: 'ARCHIVED', p_limit: LIST_LIMIT }))

    await userEvent.type(screen.getByLabelText(/بحث/), '  k7m2q9xa ')
    await userEvent.click(screen.getByRole('button', { name: 'بحث' }))
    await waitFor(() => expect(fake.rpcCalls('admin_list_listings').at(-1)).toEqual({ p_status: 'ARCHIVED', p_query: 'k7m2q9xa', p_limit: LIST_LIMIT }))

    await userEvent.click(screen.getByRole('button', { name: 'مسح التصفية' }))
    await waitFor(() => expect(fake.rpcCalls('admin_list_listings').at(-1)).toEqual({ p_limit: LIST_LIMIT }))
  })

  it('second page passes the cursor of the last item', async () => {
    const first = page(LIST_LIMIT)
    const second = page(3, LIST_LIMIT)
    const fake = setup((args) => (args.p_after_id ? second : first))
    renderAdmin(<ListingsPage />, { route: '/admin/listings?status=PUBLISHED', path: '/admin/listings' })
    // استعلامات النص بدل الأدوار: الجدول هنا أكثر من 100 صف، واستعلام الدور يحسب شجرة الإتاحة
    // كاملة في كل محاولة فيتجاوز المهلة تحت حمل التشغيل المتوازي.
    expect((await screen.findByText('إعلان 0')).closest('a')).not.toBeNull()
    const last = first[first.length - 1]!
    await userEvent.click(screen.getByText('تحميل المزيد').closest('button')!)
    expect((await screen.findByText(`إعلان ${LIST_LIMIT + 2}`)).closest('a')).not.toBeNull()
    expect(fake.rpcCalls('admin_list_listings')[1]).toEqual({
      p_status: 'PUBLISHED',
      p_limit: LIST_LIMIT,
      p_after_changed_at: last.status_changed_at,
      p_after_id: last.listing_id,
    })
    expect(screen.queryByText('تحميل المزيد')).not.toBeInTheDocument()
    expect(document.querySelectorAll('table tr')).toHaveLength(LIST_LIMIT + 3 + 1)
  })

  it('no load-more button when a page is short', async () => {
    setup(page(5))
    renderAdmin(<ListingsPage />, { route: '/admin/listings', path: '/admin/listings' })
    await screen.findByRole('link', { name: 'إعلان 0' })
    expect(screen.queryByRole('button', { name: 'تحميل المزيد' })).not.toBeInTheDocument()
  })

  it('shows hidden reason, draft marker, suspended owner and auction time', async () => {
    setup([HIDDEN_ROW, AUCTION_ROW])
    renderAdmin(<ListingsPage />, { route: '/admin/listings', path: '/admin/listings' })
    await screen.findByRole('link', { name: 'جمل مخفي' })
    expect(await screen.findByText('اشتباه احتيال')).toBeInTheDocument()
    expect(screen.getByText('صور مكررة')).toBeInTheDocument()
    expect(screen.getByText('تعديل غير منشور')).toBeInTheDocument()
    expect(screen.getByText('معلق')).toBeInTheDocument()
    expect(screen.getByText('مزاد حضوري')).toBeInTheDocument()
    expect(screen.getByRole('img', { name: 'بلا صورة' })).toBeInTheDocument()
    // ADMIN يملك accounts.manage: رابط الحساب.
    expect(screen.getByRole('link', { name: 'معلن معلق' })).toHaveAttribute('href', `/admin/accounts/${HIDDEN_ROW.owner_id}`)
  })

  it('owner is plain text without accounts.manage', async () => {
    setup([HIDDEN_ROW])
    renderAdmin(<ListingsPage />, { route: '/admin/listings', path: '/admin/listings', whoami: moderator(['listings.review']) })
    await screen.findByRole('link', { name: 'جمل مخفي' })
    expect(screen.getByText('معلن معلق')).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'معلن معلق' })).not.toBeInTheDocument()
  })

  it('row click opens the detail page', async () => {
    setup()
    renderAdmin(<ListingsPage />, {
      route: '/admin/listings',
      path: '/admin/listings',
      whoami: ADMIN_WHOAMI,
      extraRoutes: [{ path: '/admin/listings/:listingId', element: <div>صفحة التفاصيل</div> }],
    })
    await screen.findByRole('link', { name: 'ناقة مجاهيم للبيع' })
    await userEvent.click(screen.getByText('سعر ثابت'))
    expect(await screen.findByText('صفحة التفاصيل')).toBeInTheDocument()
  })

  it('empty state without filters', async () => {
    setup([])
    renderAdmin(<ListingsPage />, { route: '/admin/listings', path: '/admin/listings' })
    expect(await screen.findByText('لا توجد إعلانات بعد')).toBeInTheDocument()
  })

  it('error state with retry', async () => {
    const fake = setup()
    fake.failRpc('admin_list_listings', 'FORBIDDEN', {}, 1)
    renderAdmin(<ListingsPage />, { route: '/admin/listings', path: '/admin/listings' })
    expect(await screen.findByText('لا تملك صلاحية تنفيذ هذا الإجراء.')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'إعادة المحاولة' }))
    expect(await screen.findByRole('link', { name: 'ناقة مجاهيم للبيع' })).toBeInTheDocument()
  })

  it('shows the Arabic message for VALIDATION_FAILED and MFA_REQUIRED', async () => {
    const fake = setup()
    fake.failRpc('admin_list_listings', 'VALIDATION_FAILED', { fields: ['query'] }, 1)
    renderAdmin(<ListingsPage />, { route: '/admin/listings?q=x', path: '/admin/listings' })
    expect(await screen.findByText('بعض القيم غير صالحة. راجع الحقول المحددة.')).toBeInTheDocument()

    fake.failRpc('admin_list_listings', 'MFA_REQUIRED', {}, 1)
    await userEvent.click(screen.getByRole('button', { name: 'إعادة المحاولة' }))
    expect(await screen.findByText(/يلزم إكمال التحقق بخطوتين/)).toBeInTheDocument()
  })
})
