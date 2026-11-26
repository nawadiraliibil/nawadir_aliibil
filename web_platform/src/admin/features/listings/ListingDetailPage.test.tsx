import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import reviewFx from '@contracts/fixtures/admin-listing-review.json'
import unhiddenFx from '@contracts/fixtures/admin-unhidden-listing.json'
import { renderAdmin, moderator } from '@admin/test/render'
import { installFakeSupabase, type RpcHandler } from '@admin/test/fakeSupabase'
import ListingDetailPage from './ListingDetailPage'
import type { ListingAdmin, ListingReviewPayload, ListingVersion } from './types'

// يفحص بالأنواع أن أمثلة العقد تطابق الواجهات (INT-008 معيار 6).
const FIXTURE: ListingReviewPayload = reviewFx
const UNHIDDEN: ListingAdmin = unhiddenFx
const ID = FIXTURE.listing.id
const ROUTE = { route: `/admin/listings/${ID}`, path: '/admin/listings/:listingId' }

const REASONS = [
  { code: 'FRAUD', label_ar: 'اشتباه احتيال', applies_to: ['LISTING_HIDE', 'ACCOUNT_SUSPEND'], requires_note: false, sort_order: 80, is_active: true },
  { code: 'OTHER', label_ar: 'أخرى', applies_to: ['LISTING_HIDE', 'ACCOUNT_SUSPEND'], requires_note: true, sort_order: 1000, is_active: true },
]

const TABLES = {
  moderation_reasons: REASONS,
  breeds: [{ id: 1, name_ar: 'مجاهيم', is_active: true }],
  regions: [{ id: 1, name_ar: 'الرياض', is_active: true }],
  cities: [{ id: 1, name_ar: 'الرياض المدينة', region_id: 1, is_active: true }],
  listings: [{ id: ID, public_ref: 'k7m2q9xa', comments_closed: false }],
  public_listing_cards: [{ listing_id: ID, view_count: 12, favorite_count: 3 }],
}

const HIDDEN_PAYLOAD: ListingReviewPayload = {
  ...FIXTURE,
  listing: { ...FIXTURE.listing, status: 'HIDDEN', status_changed_at: '2026-11-23T09:00:00+00:00' },
  reviews: [
    {
      id: 2,
      version_id: FIXTURE.version!.id,
      decision: 'HIDDEN',
      reason_code: 'FRAUD',
      reason_text: 'صور منقولة',
      moderator_id: '95002fec-541b-4085-b6db-671b43ea977f',
      created_at: '2026-11-23T09:00:00+00:00',
    },
    ...(FIXTURE.reviews ?? []),
  ],
}

function setup(review: ListingReviewPayload | RpcHandler = FIXTURE, extra: Record<string, RpcHandler> = {}) {
  return installFakeSupabase({
    tables: { ...TABLES },
    rpc: {
      admin_get_listing_review: typeof review === 'function' ? review : () => review,
      admin_hide_listing: () => ({ ...UNHIDDEN, status: 'HIDDEN' }),
      admin_unhide_listing: () => UNHIDDEN,
      ...extra,
    },
  })
}

const FORBIDDEN_WORDS = /اعتماد|رفض|قيد المراجعة/

describe('ListingDetailPage', () => {
  it('renders the contract fixture (loading -> data) with both phone labels', async () => {
    const fake = setup()
    renderAdmin(<ListingDetailPage />, ROUTE)
    expect(screen.getByText('جارٍ تحميل الإعلان…')).toBeInTheDocument()
    expect(await screen.findByRole('heading', { level: 1, name: 'ناقة مجاهيم للبيع' })).toBeInTheDocument()
    expect(fake.rpcCalls('admin_get_listing_review')).toEqual([{ p_listing_id: ID }])

    expect(screen.getByText('رقم الاتصال')).toBeInTheDocument()
    expect(screen.getByText('رقم واتساب')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: '+966500000009' })).toHaveAttribute('href', 'tel:+966500000009')
    expect(screen.getByRole('link', { name: '+966551112222' })).toBeInTheDocument()

    expect(await screen.findByText('مجاهيم')).toBeInTheDocument()
    expect(screen.getByText('أنثى')).toBeInTheDocument()
    expect(screen.getByText('الرياض المدينة')).toBeInTheDocument()
    expect(screen.getByText('25,000 ر.س')).toBeInTheDocument()
    expect(screen.getByText(FIXTURE.version!.content_hash!)).toBeInTheDocument()
    expect(await screen.findByText('k7m2q9xa')).toBeInTheDocument()
    expect(await screen.findByText('12')).toBeInTheDocument()
    expect(screen.getByText('مفتوحة')).toBeInTheDocument()

    // الوسائط بروابط موقعة.
    const imgs = await screen.findAllByRole('img', { name: /^صورة \d$/ })
    expect(imgs).toHaveLength(3)
    expect(imgs[0]).toHaveAttribute('src', expect.stringContaining('https://storage.test/listing-images/'))
    expect(screen.getByText('الغلاف')).toBeInTheDocument()

    // مالك الإعلان مع رابط الحساب للمدير.
    expect(screen.getByRole('link', { name: 'معلن تجريبي' })).toHaveAttribute('href', `/admin/accounts/${FIXTURE.owner!.id}`)
    expect(screen.queryByRole('tablist')).not.toBeInTheDocument()
    expect(screen.getByRole('heading', { name: 'محتوى الإعلان' })).toBeInTheDocument()
  })

  it('AUTO_PUBLISH review renders as «نشر تلقائي» and not as a staff decision', async () => {
    setup()
    renderAdmin(<ListingDetailPage />, ROUTE)
    const history = (await screen.findByRole('heading', { name: 'سجل القرارات' })).closest('section')!
    expect(within(history).getByText('نشر تلقائي')).toBeInTheDocument()
    expect(within(history).getByText(/دون قرار موظف/)).toBeInTheDocument()
    expect(within(history).queryByText(/الموظف:/)).not.toBeInTheDocument()
    expect(within(history).queryByText('AUTO_PUBLISH')).not.toBeInTheDocument()
  })

  it('never shows approve/reject/under-review', async () => {
    setup()
    renderAdmin(<ListingDetailPage />, ROUTE)
    await screen.findByRole('heading', { level: 1, name: 'ناقة مجاهيم للبيع' })
    expect(document.body.textContent).not.toMatch(FORBIDDEN_WORDS)
    await userEvent.click(screen.getByRole('button', { name: 'إخفاء الإعلان' }))
    await screen.findByRole('dialog')
    expect(document.body.textContent).not.toMatch(FORBIDDEN_WORDS)
  })

  it('a moderator with only listings.review sees no hide/unhide buttons', async () => {
    setup()
    renderAdmin(<ListingDetailPage />, { ...ROUTE, whoami: moderator(['listings.review']) })
    await screen.findByRole('heading', { level: 1, name: 'ناقة مجاهيم للبيع' })
    expect(screen.queryByRole('button', { name: 'إخفاء الإعلان' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إعادة الإظهار' })).not.toBeInTheDocument()
    // دون accounts.manage: اسم المعلن نص فقط.
    expect(screen.queryByRole('link', { name: 'معلن تجريبي' })).not.toBeInTheDocument()
  })

  it('hidden listing: moderator without listings.hide cannot unhide', async () => {
    setup(HIDDEN_PAYLOAD)
    renderAdmin(<ListingDetailPage />, { ...ROUTE, whoami: moderator(['listings.review']) })
    await screen.findByText('الإعلان مخفي عن الجمهور')
    expect(screen.queryByRole('button', { name: 'إعادة الإظهار' })).not.toBeInTheDocument()
  })

  it('hide requires a reason and sends exact args', async () => {
    const fake = setup()
    renderAdmin(<ListingDetailPage />, ROUTE)
    await userEvent.click(await screen.findByRole('button', { name: 'إخفاء الإعلان' }))
    const dialog = await screen.findByRole('dialog')
    expect(within(dialog).getByText(/يُشعَر المعلن بالسبب/)).toBeInTheDocument()
    await within(dialog).findByLabelText(/السبب/)

    await userEvent.click(within(dialog).getByRole('button', { name: 'إخفاء الإعلان' }))
    expect(await within(dialog).findByText('اختر سببًا.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_hide_listing')).toHaveLength(0)

    await userEvent.selectOptions(within(dialog).getByLabelText(/السبب/), 'OTHER')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إخفاء الإعلان' }))
    expect(await within(dialog).findByText('اكتب توضيحًا لهذا السبب.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_hide_listing')).toHaveLength(0)

    await userEvent.type(within(dialog).getByLabelText(/التوضيح/), 'إعلان مكرر')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إخفاء الإعلان' }))
    await waitFor(() => expect(fake.rpcCalls('admin_hide_listing')).toEqual([{ p_listing_id: ID, p_reason_code: 'OTHER', p_reason_text: 'إعلان مكرر' }]))
    expect(await screen.findByText('أُخفي الإعلان وأُشعر المعلن بالسبب.')).toBeInTheDocument()
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    // أعيد تحميل التفاصيل بعد النجاح.
    await waitFor(() => expect(fake.rpcCalls('admin_get_listing_review').length).toBeGreaterThanOrEqual(2))
  })

  it('hide without text for a reason that does not require it sends undefined text', async () => {
    const fake = setup()
    renderAdmin(<ListingDetailPage />, ROUTE)
    await userEvent.click(await screen.findByRole('button', { name: 'إخفاء الإعلان' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.selectOptions(await within(dialog).findByLabelText(/السبب/), 'FRAUD')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إخفاء الإعلان' }))
    await waitFor(() => expect(fake.rpcCalls('admin_hide_listing')).toHaveLength(1))
    expect(fake.rpcCalls('admin_hide_listing')[0]).toEqual({ p_listing_id: ID, p_reason_code: 'FRAUD', p_reason_text: undefined })
  })

  it('INVALID_STATE on hide shows the Arabic message, refetches, and does not retry', async () => {
    const fake = setup()
    fake.failRpc('admin_hide_listing', 'INVALID_STATE', { status: 'HIDDEN' })
    renderAdmin(<ListingDetailPage />, ROUTE)
    await userEvent.click(await screen.findByRole('button', { name: 'إخفاء الإعلان' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.selectOptions(await within(dialog).findByLabelText(/السبب/), 'FRAUD')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إخفاء الإعلان' }))
    expect(await within(dialog).findByText(/لا يسمح بهذا الإجراء في الحالة الحالية/)).toBeInTheDocument()
    await waitFor(() => expect(fake.rpcCalls('admin_get_listing_review')).toHaveLength(2))
    expect(fake.rpcCalls('admin_hide_listing')).toHaveLength(1)
    expect(screen.queryByText('أُخفي الإعلان وأُشعر المعلن بالسبب.')).not.toBeInTheDocument()
  })

  it('REASON_REQUIRED and FORBIDDEN from the server show Arabic messages', async () => {
    const fake = setup()
    fake.failRpc('admin_hide_listing', 'REASON_REQUIRED', { field: 'reason_text' }, 1)
    renderAdmin(<ListingDetailPage />, ROUTE)
    await userEvent.click(await screen.findByRole('button', { name: 'إخفاء الإعلان' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.selectOptions(await within(dialog).findByLabelText(/السبب/), 'FRAUD')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إخفاء الإعلان' }))
    expect(await within(dialog).findByText(/السبب إلزامي/)).toBeInTheDocument()

    fake.failRpc('admin_hide_listing', 'FORBIDDEN', {}, 1)
    await userEvent.click(within(dialog).getByRole('button', { name: 'إخفاء الإعلان' }))
    expect(await within(dialog).findByText('لا تملك صلاحية تنفيذ هذا الإجراء.')).toBeInTheDocument()
  })

  it('hidden listing shows the hide reason and unhide sends the internal note', async () => {
    const fake = setup(HIDDEN_PAYLOAD)
    renderAdmin(<ListingDetailPage />, ROUTE)
    const alert = (await screen.findByText('الإعلان مخفي عن الجمهور')).closest('.alert') as HTMLElement
    expect(await within(alert).findByText(/اشتباه احتيال/)).toBeInTheDocument()
    expect(within(alert).getByText(/صور منقولة/)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إخفاء الإعلان' })).not.toBeInTheDocument()
    // سجل القرارات يعرض الإخفاء بموظفه ("أنت" للمدير الحالي).
    const history = screen.getByRole('heading', { name: 'سجل القرارات' }).closest('section')!
    expect(within(history).getByText('إخفاء')).toBeInTheDocument()
    expect(within(history).getByText(/\(أنت\)/)).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'إعادة الإظهار' }))
    const dialog = await screen.findByRole('dialog')
    expect(within(dialog).getByText('للسجل الداخلي فقط ولا تصل إلى المعلن.')).toBeInTheDocument()
    await userEvent.type(within(dialog).getByLabelText(/ملاحظة داخلية/), 'راجعنا الصور')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إعادة الإظهار' }))
    await waitFor(() => expect(fake.rpcCalls('admin_unhide_listing')).toEqual([{ p_listing_id: ID, p_note: 'راجعنا الصور' }]))
    expect(await screen.findByText('أعيد إظهار الإعلان.')).toBeInTheDocument()
  })

  it('unhide without a note sends undefined', async () => {
    const fake = setup(HIDDEN_PAYLOAD)
    renderAdmin(<ListingDetailPage />, ROUTE)
    await userEvent.click(await screen.findByRole('button', { name: 'إعادة الإظهار' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إعادة الإظهار' }))
    await waitFor(() => expect(fake.rpcCalls('admin_unhide_listing')).toEqual([{ p_listing_id: ID, p_note: undefined }]))
  })

  it('suspended owner: warning and disabled unhide button', async () => {
    setup({ ...HIDDEN_PAYLOAD, owner: { ...FIXTURE.owner!, status: 'SUSPENDED' } })
    renderAdmin(<ListingDetailPage />, ROUTE)
    expect(await screen.findByText('حساب المعلن معلق')).toBeInTheDocument()
    expect(screen.getByText(/فعّل الحساب أولًا/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'إعادة الإظهار' })).toBeDisabled()
  })

  it('INVALID_STATE on unhide shows the message', async () => {
    const fake = setup(HIDDEN_PAYLOAD)
    fake.failRpc('admin_unhide_listing', 'INVALID_STATE', { reason: 'owner_suspended' })
    renderAdmin(<ListingDetailPage />, ROUTE)
    await userEvent.click(await screen.findByRole('button', { name: 'إعادة الإظهار' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إعادة الإظهار' }))
    expect(await within(dialog).findByText(/لا يسمح بهذا الإجراء في الحالة الحالية/)).toBeInTheDocument()
    await waitFor(() => expect(fake.rpcCalls('admin_get_listing_review')).toHaveLength(2))
  })

  it('private draft: tabs for the published version and the unpublished edit', async () => {
    const draft: ListingVersion = {
      ...FIXTURE.version!,
      id: 'd0000000-0000-4000-8000-000000000009',
      version_no: 2,
      status: 'DRAFT',
      title: 'ناقة مجاهيم معدلة',
      contact_phone: null,
      contact_whatsapp_phone: '+966559998888',
      submitted_at: null,
      decided_at: null,
    }
    setup({ ...FIXTURE, version: draft, media: [], published_version: FIXTURE.version, published_media: FIXTURE.media })
    renderAdmin(<ListingDetailPage />, ROUTE)
    expect(await screen.findByRole('heading', { level: 1, name: 'ناقة مجاهيم للبيع' })).toBeInTheDocument()
    const tabs = screen.getAllByRole('tab')
    expect(tabs.map((t) => t.textContent)).toEqual(['النسخة المنشورة', 'تعديل غير منشور'])
    expect(tabs[0]).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByText('+966500000009')).toBeInTheDocument()

    await userEvent.click(tabs[1]!)
    expect(tabs[1]).toHaveAttribute('aria-selected', 'true')
    const panel = screen.getByRole('tabpanel')
    expect(within(panel).getByText('ناقة مجاهيم معدلة')).toBeInTheDocument()
    expect(within(panel).getByText('غير متاح')).toBeInTheDocument()
    expect(within(panel).getByText('+966559998888')).toBeInTheDocument()
    expect(within(panel).getByText('لا توجد وسائط في هذه النسخة.')).toBeInTheDocument()
  })

  it('auction with coordinates links to OpenStreetMap; video media uses a player', async () => {
    const version: ListingVersion = {
      ...FIXTURE.version!,
      offer_type: 'IN_PERSON_AUCTION',
      price: null,
      auction_starts_at: '2026-12-01T15:00:00+00:00',
      auction_venue: 'سوق الإبل',
      auction_region_id: 1,
      auction_city_id: 1,
      auction_lat: 24.7136,
      auction_lng: 46.6753,
    }
    const video = { ...FIXTURE.media![0]!, id: 'v1', kind: 'VIDEO', bucket: 'listing-videos', object_path: 'o/l/v1.mp4', status: 'PENDING', is_cover: false, sort_order: 9 }
    setup({ ...FIXTURE, version, media: [...FIXTURE.media!, video] })
    renderAdmin(<ListingDetailPage />, ROUTE)
    const osm = await screen.findByRole('link', { name: 'فتح في OpenStreetMap' })
    expect(osm).toHaveAttribute('href', 'https://www.openstreetmap.org/?mlat=24.7136&mlon=46.6753#map=15/24.7136/46.6753')
    expect(osm).toHaveAttribute('target', '_blank')
    expect(screen.getByText('سوق الإبل')).toBeInTheDocument()
    expect(screen.getByText('مزاد حضوري')).toBeInTheDocument()
    const player = await screen.findByLabelText('فيديو 4')
    expect(player.tagName).toBe('VIDEO')
    expect(player).toHaveAttribute('controls')
    expect(player).toHaveAttribute('preload', 'metadata')
    expect(screen.getByText('قيد التجهيز')).toBeInTheDocument()
  })

  it('unknown breed falls back to #id', async () => {
    setup({ ...FIXTURE, version: { ...FIXTURE.version!, breed_id: 77 } })
    renderAdmin(<ListingDetailPage />, ROUTE)
    expect(await screen.findByText('#77')).toBeInTheDocument()
  })

  it('NOT_FOUND shows a friendly state with a back link', async () => {
    const fake = setup()
    fake.failRpc('admin_get_listing_review', 'NOT_FOUND', { resource: 'listing' })
    renderAdmin(<ListingDetailPage />, ROUTE)
    expect(await screen.findByText('الإعلان غير موجود')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'العودة إلى إدارة الإعلانات' })).toHaveAttribute('href', '/admin/listings')
  })

  it('other errors show ErrorState with retry', async () => {
    const fake = setup()
    fake.failRpc('admin_get_listing_review', 'MFA_REQUIRED', {}, 1)
    renderAdmin(<ListingDetailPage />, ROUTE)
    expect(await screen.findByText(/يلزم إكمال التحقق بخطوتين/)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'إعادة المحاولة' }))
    expect(await screen.findByRole('heading', { level: 1, name: 'ناقة مجاهيم للبيع' })).toBeInTheDocument()
  })

  it('works for archived and draft listings without actions', async () => {
    setup({ ...FIXTURE, listing: { ...FIXTURE.listing, status: 'ARCHIVED' } })
    renderAdmin(<ListingDetailPage />, ROUTE)
    expect(await screen.findByRole('heading', { level: 1, name: 'ناقة مجاهيم للبيع' })).toBeInTheDocument()
    expect(screen.getByText('مؤرشف')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إخفاء الإعلان' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إعادة الإظهار' })).not.toBeInTheDocument()
  })
})
