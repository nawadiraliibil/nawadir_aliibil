import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { installFakeSupabase, type Row } from '@admin/test/fakeSupabase'
import { renderAdmin, moderator } from '@admin/test/render'
import type { Whoami } from '@admin/lib/capabilities'
import LookupsPage from './LookupsPage'

// صفوف بشكل Tables[...]['Row'] في contracts/generated/database.types.ts، وقيمها من بذور الترحيلات.
const T = '2026-11-22T09:00:00Z'
const BREEDS: Row[] = [
  { id: 2, name_ar: 'الوضح', requires_note: false, sort_order: 20, is_active: true, created_at: T, updated_at: T },
  { id: 1, name_ar: 'المجاهيم', requires_note: false, sort_order: 10, is_active: true, created_at: T, updated_at: T },
  { id: 3, name_ar: 'الشعل', requires_note: false, sort_order: 30, is_active: false, created_at: T, updated_at: T },
  { id: 13, name_ar: 'أخرى', requires_note: true, sort_order: 130, is_active: true, created_at: T, updated_at: T },
]
const REGIONS: Row[] = [
  { id: 1, name_ar: 'الرياض', sort_order: 10, is_active: true, created_at: T, updated_at: T },
  { id: 2, name_ar: 'مكة المكرمة', sort_order: 20, is_active: true, created_at: T, updated_at: T },
  { id: 13, name_ar: 'الجوف', sort_order: 130, is_active: false, created_at: T, updated_at: T },
]
const CITIES: Row[] = [
  { id: 1, region_id: 1, name_ar: 'الرياض', sort_order: 10, is_active: true, created_at: T, updated_at: T },
  { id: 2, region_id: 1, name_ar: 'الدرعية', sort_order: 20, is_active: true, created_at: T, updated_at: T },
  { id: 3, region_id: 1, name_ar: 'الخرج', sort_order: 30, is_active: false, created_at: T, updated_at: T },
  { id: 24, region_id: 2, name_ar: 'مكة المكرمة', sort_order: 10, is_active: true, created_at: T, updated_at: T },
  { id: 25, region_id: 2, name_ar: 'جدة', sort_order: 20, is_active: true, created_at: T, updated_at: T },
]
const REASONS: Row[] = [
  { code: 'MISSING_INFO', label_ar: 'بيانات ناقصة أو غير واضحة', applies_to: ['LISTING_REJECT'], requires_note: false, sort_order: 10, is_active: true, created_at: T, updated_at: T },
  { code: 'FRAUD', label_ar: 'اشتباه احتيال أو إساءة استخدام', applies_to: ['ACCOUNT_SUSPEND', 'LISTING_HIDE', 'RATING_HIDE'], requires_note: false, sort_order: 80, is_active: true, created_at: T, updated_at: T },
  { code: 'SPAM', label_ar: 'رد مزعج أو دعائي', applies_to: ['COMMENT_HIDE', 'RATING_HIDE'], requires_note: false, sort_order: 95, is_active: false, created_at: T, updated_at: T },
  { code: 'OTHER', label_ar: 'أخرى', applies_to: ['ACCOUNT_SUSPEND', 'COMMENT_HIDE', 'LISTING_HIDE', 'LISTING_REJECT', 'RATING_HIDE'], requires_note: true, sort_order: 1000, is_active: true, created_at: T, updated_at: T },
]

function setup(route = '/admin/lookups', whoami?: Whoami | null) {
  const fake = installFakeSupabase({
    tables: {
      breeds: BREEDS.map((r) => ({ ...r })),
      regions: REGIONS.map((r) => ({ ...r })),
      cities: CITIES.map((r) => ({ ...r })),
      moderation_reasons: REASONS.map((r) => ({ ...r })),
    },
    rpc: {
      admin_upsert_breed: (a) => ({ id: a.p_id ?? 99, name_ar: a.p_name_ar, requires_note: a.p_requires_note, sort_order: a.p_sort_order ?? 140, is_active: true }),
      admin_upsert_region: (a) => ({ id: a.p_id ?? 14, name_ar: a.p_name_ar, sort_order: 140, is_active: true }),
      admin_upsert_city: (a) => ({ id: a.p_id ?? 200, region_id: a.p_region_id, name_ar: a.p_name_ar, sort_order: 40, is_active: true }),
      admin_upsert_moderation_reason: (a) => ({ code: a.p_code, label_ar: a.p_label_ar, applies_to: a.p_applies_to, requires_note: a.p_requires_note, sort_order: 1010, is_active: true }),
      admin_set_lookup_active: (a) => ({ id: a.p_id, is_active: a.p_is_active }),
      admin_reorder_lookup: (a) => ({ kind: a.p_kind, updated: (a.p_ids as string[]).length }),
    },
  })
  const utils = renderAdmin(<LookupsPage />, { route, path: '/admin/lookups', whoami })
  return { fake, ...utils }
}

async function openDialog(buttonName: string | RegExp) {
  await userEvent.click(await screen.findByRole('button', { name: buttonName }))
  return screen.findByRole('dialog')
}

function bodyRows() {
  const table = screen.getByRole('table')
  return within(table).getAllByRole('row').slice(1)
}

describe('LookupsPage — السلالات', () => {
  it('shows loading then all breeds ordered by sort_order, including inactive', async () => {
    const { fake } = setup()
    expect(screen.getByText('جارٍ التحميل…')).toBeInTheDocument()
    await screen.findByText('المجاهيم')
    const rows = bodyRows()
    expect(rows.map((r) => within(r).getAllByRole('cell')[1]?.textContent)).toEqual(['المجاهيم', 'الوضح', 'الشعل', 'أخرى'])
    expect(within(rows[2]!).getByText('معطلة')).toBeInTheDocument()
    expect(within(rows[0]!).getByText('فعالة')).toBeInTheDocument()
    expect(within(rows[3]!).getByText('تتطلب ملاحظة')).toBeInTheDocument()
    // لا مرشح is_active: من يملك lookups.manage يرى المعطلة.
    const select = fake.calls.find((c) => c.kind === 'select' && c.name === 'breeds')
    expect(select?.filters).toEqual([
      ['order', 'sort_order', true],
      ['order', 'id', true],
    ])
    expect(screen.getByRole('tab', { name: 'السلالات' })).toHaveAttribute('aria-selected', 'true')
  })

  it('shows an error state with retry', async () => {
    const fake = installFakeSupabase({ tables: { breeds: BREEDS.map((r) => ({ ...r })) } })
    fake.failTable('breeds', 'INTERNAL_ERROR')
    renderAdmin(<LookupsPage />, { route: '/admin/lookups', path: '/admin/lookups' })
    expect(await screen.findByText('حدث خطأ في الخادم. أعد المحاولة لاحقًا.')).toBeInTheDocument()
    fake.failTable('breeds', '')
    await userEvent.click(screen.getByRole('button', { name: 'إعادة المحاولة' }))
    expect(await screen.findByText('المجاهيم')).toBeInTheDocument()
  })

  it('has no delete control anywhere', async () => {
    setup()
    await screen.findByText('المجاهيم')
    expect(screen.queryByRole('button', { name: /حذف/ })).not.toBeInTheDocument()
    await userEvent.click(screen.getByRole('tab', { name: 'أسباب الإشراف' }))
    await screen.findByText('بيانات ناقصة أو غير واضحة')
    expect(screen.queryByRole('button', { name: /حذف/ })).not.toBeInTheDocument()
  })

  it('adds a breed with exact args (p_id null for new) and shows success after the server confirms', async () => {
    const { fake } = setup()
    const dialog = await openDialog('إضافة سلالة')
    await userEvent.type(within(dialog).getByLabelText(/اسم السلالة/), '  الحمر   الأصيلة ')
    await userEvent.click(within(dialog).getByLabelText('يتطلب ملاحظة عند الاختيار'))
    await userEvent.click(within(dialog).getByRole('button', { name: 'إضافة' }))
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(fake.rpcCalls('admin_upsert_breed')).toEqual([{ p_id: null, p_name_ar: 'الحمر الأصيلة', p_requires_note: true, p_sort_order: undefined }])
    expect(await screen.findByText('تمت إضافة السلالة.')).toBeInTheDocument()
  })

  it('edits a breed with its id and sort order', async () => {
    const { fake } = setup()
    const dialog = await openDialog('تعديل «الوضح»')
    const name = within(dialog).getByLabelText(/اسم السلالة/)
    expect(name).toHaveValue('الوضح')
    await userEvent.clear(name)
    await userEvent.type(name, 'الوضح الأصيلة')
    const sort = within(dialog).getByLabelText('رقم الترتيب')
    expect(sort).toHaveValue(20)
    await userEvent.clear(sort)
    await userEvent.type(sort, '15')
    await userEvent.click(within(dialog).getByRole('button', { name: 'حفظ' }))
    await waitFor(() => expect(fake.rpcCalls('admin_upsert_breed')).toHaveLength(1))
    expect(fake.rpcCalls('admin_upsert_breed')[0]).toEqual({ p_id: 2, p_name_ar: 'الوضح الأصيلة', p_requires_note: false, p_sort_order: 15 })
    expect(await screen.findByText('تم حفظ السلالة.')).toBeInTheDocument()
  })

  it('blocks submit with an empty name', async () => {
    const { fake } = setup()
    const dialog = await openDialog('إضافة سلالة')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إضافة' }))
    expect(await within(dialog).findByText('الاسم مطلوب.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_upsert_breed')).toHaveLength(0)
  })

  it('maps duplicate VALIDATION_FAILED to «الاسم مكرر» and keeps the dialog open', async () => {
    const { fake } = setup()
    fake.failRpc('admin_upsert_breed', 'VALIDATION_FAILED', { fields: ['name_ar'], reason: 'duplicate' })
    const dialog = await openDialog('إضافة سلالة')
    await userEvent.type(within(dialog).getByLabelText(/اسم السلالة/), 'المجاهيم')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إضافة' }))
    expect(await within(dialog).findByText('الاسم مكرر')).toBeInTheDocument()
    expect(within(dialog).getByLabelText(/اسم السلالة/)).toHaveAttribute('aria-invalid', 'true')
    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(screen.queryByText('تمت إضافة السلالة.')).not.toBeInTheDocument()
    // لا إعادة محاولة تلقائية.
    expect(fake.rpcCalls('admin_upsert_breed')).toHaveLength(1)
  })

  it('shows the Arabic FORBIDDEN message from the server', async () => {
    const { fake } = setup()
    fake.failRpc('admin_upsert_breed', 'FORBIDDEN')
    const dialog = await openDialog('إضافة سلالة')
    await userEvent.type(within(dialog).getByLabelText(/اسم السلالة/), 'سلالة')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إضافة' }))
    expect(await within(dialog).findByText('لا تملك صلاحية تنفيذ هذا الإجراء.')).toBeInTheDocument()
  })

  it('deactivates with confirmation and exact args', async () => {
    const { fake } = setup()
    await userEvent.click(await screen.findByRole('button', { name: 'تعطيل «المجاهيم»' }))
    const dialog = await screen.findByRole('dialog')
    expect(dialog).toHaveTextContent('تبقى ظاهرة في الإعلانات والسجلات السابقة')
    expect(fake.rpcCalls('admin_set_lookup_active')).toHaveLength(0)
    await userEvent.click(within(dialog).getByRole('button', { name: 'تعطيل' }))
    await waitFor(() => expect(fake.rpcCalls('admin_set_lookup_active')).toEqual([{ p_kind: 'breed', p_id: '1', p_is_active: false }]))
    expect(await screen.findByText('تم تعطيل السلالة.')).toBeInTheDocument()
  })

  it('activates an inactive value', async () => {
    const { fake } = setup()
    await userEvent.click(await screen.findByRole('button', { name: 'تفعيل «الشعل»' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.click(within(dialog).getByRole('button', { name: 'تفعيل' }))
    await waitFor(() => expect(fake.rpcCalls('admin_set_lookup_active')).toEqual([{ p_kind: 'breed', p_id: '3', p_is_active: true }]))
  })

  it('keeps the confirm dialog open with the Arabic NOT_FOUND message', async () => {
    const { fake } = setup()
    fake.failRpc('admin_set_lookup_active', 'NOT_FOUND', { resource: 'breed' })
    await userEvent.click(await screen.findByRole('button', { name: 'تعطيل «الوضح»' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.click(within(dialog).getByRole('button', { name: 'تعطيل' }))
    expect(await within(dialog).findByText('العنصر غير موجود أو حذف.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_set_lookup_active')).toHaveLength(1)
  })

  it('reorders by sending the full ordered id list', async () => {
    const { fake } = setup()
    expect(await screen.findByRole('button', { name: 'نقل «المجاهيم» إلى أعلى' })).toBeDisabled()
    await userEvent.click(screen.getByRole('button', { name: 'نقل «الوضح» إلى أسفل' }))
    await waitFor(() => expect(fake.rpcCalls('admin_reorder_lookup')).toEqual([{ p_kind: 'breed', p_ids: ['1', '3', '2', '13'] }]))
    expect(await screen.findByText('تم حفظ الترتيب.')).toBeInTheDocument()
  })

  it('shows reorder errors in Arabic without retrying', async () => {
    const { fake } = setup()
    fake.failRpc('admin_reorder_lookup', 'NOT_FOUND', { resource: 'breed' })
    await userEvent.click(await screen.findByRole('button', { name: 'نقل «أخرى» إلى أعلى' }))
    expect(await screen.findByText(/لم يحفظ الترتيب: لم تعد هذه القيمة موجودة/)).toBeInTheDocument()
    expect(fake.rpcCalls('admin_reorder_lookup')).toEqual([{ p_kind: 'breed', p_ids: ['1', '2', '13', '3'] }])
  })
})

describe('LookupsPage — capability gating', () => {
  it('hides all write controls without lookups.manage', async () => {
    setup('/admin/lookups', moderator(['listings.review']))
    await screen.findByText('المجاهيم')
    expect(screen.queryByRole('button', { name: 'إضافة سلالة' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /^تعديل/ })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /^تعطيل/ })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /^نقل/ })).not.toBeInTheDocument()
    expect(screen.getByText(/العرض للاطلاع فقط/)).toBeInTheDocument()
  })

  it('shows write controls to a moderator with lookups.manage', async () => {
    setup('/admin/lookups', moderator(['lookups.manage']))
    expect(await screen.findByRole('button', { name: 'إضافة سلالة' })).toBeInTheDocument()
    expect(await screen.findByRole('button', { name: 'تعديل «المجاهيم»' })).toBeInTheDocument()
  })
})

describe('LookupsPage — المناطق', () => {
  it('lists regions incl. inactive and adds one with exact args', async () => {
    const { fake } = setup('/admin/lookups?tab=regions')
    await screen.findByText('مكة المكرمة')
    expect(within(bodyRows()[2]!).getByText('معطلة')).toBeInTheDocument()
    const dialog = await openDialog('إضافة منطقة')
    await userEvent.type(within(dialog).getByLabelText(/اسم المنطقة/), 'منطقة تجريبية')
    await userEvent.type(within(dialog).getByLabelText('رقم الترتيب'), '140')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إضافة' }))
    await waitFor(() => expect(fake.rpcCalls('admin_upsert_region')).toEqual([{ p_id: null, p_name_ar: 'منطقة تجريبية', p_sort_order: 140 }]))
    expect(await screen.findByText('تمت إضافة المنطقة.')).toBeInTheDocument()
  })

  it('rejects a non-integer sort order locally', async () => {
    const { fake } = setup('/admin/lookups?tab=regions')
    const dialog = await openDialog('تعديل «الرياض»')
    const sort = within(dialog).getByLabelText('رقم الترتيب')
    await userEvent.clear(sort)
    await userEvent.type(sort, '1.5')
    await userEvent.click(within(dialog).getByRole('button', { name: 'حفظ' }))
    expect(await within(dialog).findByText('أدخل رقمًا صحيحًا.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_upsert_region')).toHaveLength(0)
  })

  it('deactivates a region with p_kind region', async () => {
    const { fake } = setup('/admin/lookups?tab=regions')
    await userEvent.click(await screen.findByRole('button', { name: 'تعطيل «مكة المكرمة»' }))
    await userEvent.click(within(await screen.findByRole('dialog')).getByRole('button', { name: 'تعطيل' }))
    await waitFor(() => expect(fake.rpcCalls('admin_set_lookup_active')).toEqual([{ p_kind: 'region', p_id: '2', p_is_active: false }]))
  })
})

describe('LookupsPage — المدن', () => {
  it('filters by region and shows inactive cities', async () => {
    const { fake } = setup('/admin/lookups?tab=cities')
    await screen.findByText('الدرعية')
    expect(screen.queryByText('جدة')).not.toBeInTheDocument()
    expect(within(bodyRows()[2]!).getByText('معطلة')).toBeInTheDocument()
    const select = screen.getByLabelText('المنطقة')
    expect(Array.from((select as HTMLSelectElement).options).map((o) => o.textContent)).toEqual(['الرياض', 'مكة المكرمة', 'الجوف (معطلة)'])
    await userEvent.selectOptions(select, '2')
    expect(await screen.findByText('جدة')).toBeInTheDocument()
    expect(screen.queryByText('الدرعية')).not.toBeInTheDocument()
    const cityCalls = fake.calls.filter((c) => c.kind === 'select' && c.name === 'cities')
    expect(cityCalls.at(-1)?.filters?.[0]).toEqual(['eq', 'region_id', 2])
  })

  it('warns when the selected region is inactive', async () => {
    setup('/admin/lookups?tab=cities&region=13')
    expect(await screen.findByText(/المنطقة «الجوف» معطلة/)).toBeInTheDocument()
    expect(await screen.findByText('لا توجد مدن في هذه المنطقة بعد.')).toBeInTheDocument()
  })

  it('reorders cities within the selected region only', async () => {
    const { fake } = setup('/admin/lookups?tab=cities&region=2')
    await userEvent.click(await screen.findByRole('button', { name: 'نقل «جدة» إلى أعلى' }))
    await waitFor(() => expect(fake.rpcCalls('admin_reorder_lookup')).toEqual([{ p_kind: 'city', p_ids: ['25', '24'] }]))
  })

  it('adds a city in the selected region with exact args', async () => {
    const { fake } = setup('/admin/lookups?tab=cities&region=2')
    await screen.findByText('جدة')
    const dialog = await openDialog('إضافة مدينة')
    expect(within(dialog).getByLabelText(/^المنطقة/)).toHaveValue('2')
    await userEvent.type(within(dialog).getByLabelText(/اسم المدينة/), 'الطائف')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إضافة' }))
    await waitFor(() => expect(fake.rpcCalls('admin_upsert_city')).toEqual([{ p_id: null, p_region_id: 2, p_name_ar: 'الطائف', p_sort_order: undefined }]))
    expect(await screen.findByText('تمت إضافة المدينة.')).toBeInTheDocument()
  })

  it('shows the duplicate-in-region message', async () => {
    const { fake } = setup('/admin/lookups?tab=cities')
    fake.failRpc('admin_upsert_city', 'VALIDATION_FAILED', { fields: ['name_ar'], reason: 'duplicate' })
    await screen.findByText('الدرعية')
    const dialog = await openDialog('إضافة مدينة')
    await userEvent.type(within(dialog).getByLabelText(/اسم المدينة/), 'الدرعية')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إضافة' }))
    expect(await within(dialog).findByText('الاسم مكرر في هذه المنطقة')).toBeInTheDocument()
  })

  it('shows INVALID_STATE in_use when moving a used city and refetches', async () => {
    const { fake } = setup('/admin/lookups?tab=cities')
    fake.failRpc('admin_upsert_city', 'INVALID_STATE', { reason: 'in_use' })
    const dialog = await openDialog('تعديل «الدرعية»')
    await userEvent.selectOptions(within(dialog).getByLabelText(/^المنطقة/), '2')
    expect(within(dialog).getByText(/نقل مدينة مستخدمة في إعلانات/)).toBeInTheDocument()
    const before = fake.calls.filter((c) => c.kind === 'select' && c.name === 'cities').length
    await userEvent.click(within(dialog).getByRole('button', { name: 'حفظ' }))
    expect(await within(dialog).findByText(/المدينة مستخدمة في إعلانات، فلا يمكن نقلها/)).toBeInTheDocument()
    expect(fake.rpcCalls('admin_upsert_city')).toEqual([{ p_id: 2, p_region_id: 2, p_name_ar: 'الدرعية', p_sort_order: 20 }])
    await waitFor(() => expect(fake.calls.filter((c) => c.kind === 'select' && c.name === 'cities').length).toBeGreaterThan(before))
  })
})

describe('LookupsPage — أسباب الإشراف', () => {
  it('lists all reasons incl. inactive with applies_to labels and legacy note', async () => {
    setup('/admin/lookups?tab=reasons')
    await screen.findByText('بيانات ناقصة أو غير واضحة')
    const rows = bodyRows()
    expect(rows).toHaveLength(4)
    expect(within(rows[2]!).getByText('معطلة')).toBeInTheDocument()
    expect(within(rows[0]!).getByText('رفض إعلان (قديم)')).toBeInTheDocument()
    expect(within(rows[1]!).getByText('إخفاء تقييم')).toBeInTheDocument()
    expect(within(rows[3]!).getByText('يتطلب نصًا')).toBeInTheDocument()
    expect(screen.getByText(/لم يعد مستخدمًا بعد إلغاء المراجعة المسبقة/)).toBeInTheDocument()
  })

  it('adds a reason with exact args; code is uppercased and LISTING_REJECT is not offered', async () => {
    const { fake } = setup('/admin/lookups?tab=reasons')
    const dialog = await openDialog('إضافة سبب')
    expect(within(dialog).queryByLabelText('رفض إعلان (قديم)')).not.toBeInTheDocument()
    await userEvent.type(within(dialog).getByLabelText(/^الرمز/), 'fake_price')
    expect(within(dialog).getByLabelText(/^الرمز/)).toHaveValue('FAKE_PRICE')
    await userEvent.type(within(dialog).getByLabelText(/التسمية بالعربية/), 'سعر وهمي')
    await userEvent.click(within(dialog).getByLabelText('إخفاء تقييم'))
    await userEvent.click(within(dialog).getByLabelText('إخفاء إعلان'))
    await userEvent.click(within(dialog).getByLabelText('يتطلب كتابة توضيح عند اختياره'))
    await userEvent.click(within(dialog).getByRole('button', { name: 'إضافة' }))
    await waitFor(() =>
      expect(fake.rpcCalls('admin_upsert_moderation_reason')).toEqual([
        { p_code: 'FAKE_PRICE', p_label_ar: 'سعر وهمي', p_applies_to: ['LISTING_HIDE', 'RATING_HIDE'], p_requires_note: true, p_sort_order: undefined },
      ]),
    )
    expect(await screen.findByText('تمت إضافة سبب الإشراف.')).toBeInTheDocument()
  })

  it('validates code, existing code and empty applies_to locally', async () => {
    const { fake } = setup('/admin/lookups?tab=reasons')
    const dialog = await openDialog('إضافة سبب')
    await userEvent.type(within(dialog).getByLabelText(/التسمية بالعربية/), 'سبب')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إضافة' }))
    expect(await within(dialog).findByText(/الرمز يبدأ بحرف إنجليزي كبير/)).toBeInTheDocument()
    expect(within(dialog).getByText('اختر إجراءً واحدًا على الأقل.')).toBeInTheDocument()
    await userEvent.type(within(dialog).getByLabelText(/^الرمز/), 'FRAUD')
    expect(await within(dialog).findByText(/الرمز مستخدم لسبب آخر/)).toBeInTheDocument()
    expect(fake.rpcCalls('admin_upsert_moderation_reason')).toHaveLength(0)
  })

  it('edits a legacy reason: code read-only, LISTING_REJECT shown with explanation and removable', async () => {
    const { fake } = setup('/admin/lookups?tab=reasons')
    const dialog = await openDialog('تعديل «بيانات ناقصة أو غير واضحة»')
    const code = within(dialog).getByLabelText(/^الرمز/)
    expect(code).toHaveValue('MISSING_INFO')
    expect(code).toHaveAttribute('readonly')
    const legacy = within(dialog).getByLabelText('رفض إعلان (قديم)')
    expect(legacy).toBeChecked()
    expect(within(dialog).getByText(/إجراء قديم غير مستخدم/)).toBeInTheDocument()
    await userEvent.click(legacy)
    await userEvent.click(within(dialog).getByLabelText('إخفاء إعلان'))
    await userEvent.click(within(dialog).getByRole('button', { name: 'حفظ' }))
    await waitFor(() =>
      expect(fake.rpcCalls('admin_upsert_moderation_reason')).toEqual([
        { p_code: 'MISSING_INFO', p_label_ar: 'بيانات ناقصة أو غير واضحة', p_applies_to: ['LISTING_HIDE'], p_requires_note: false, p_sort_order: 10 },
      ]),
    )
  })

  it('maps server name_ar/applies_to field errors onto the reason form', async () => {
    const { fake } = setup('/admin/lookups?tab=reasons')
    fake.failRpc('admin_upsert_moderation_reason', 'VALIDATION_FAILED', { fields: ['name_ar', 'applies_to'] })
    const dialog = await openDialog('تعديل «أخرى»')
    await userEvent.click(within(dialog).getByRole('button', { name: 'حفظ' }))
    expect(await within(dialog).findByText('التسمية مطلوبة ولا تتجاوز 120 حرفًا.')).toBeInTheDocument()
    expect(within(dialog).getByText('اختر إجراءً واحدًا على الأقل.')).toBeInTheDocument()
    expect(within(dialog).getByText('بعض القيم غير صالحة. راجع الحقول المحددة.')).toBeInTheDocument()
  })

  it('deactivates a reason by code', async () => {
    const { fake } = setup('/admin/lookups?tab=reasons')
    await userEvent.click(await screen.findByRole('button', { name: 'تعطيل «أخرى»' }))
    await userEvent.click(within(await screen.findByRole('dialog')).getByRole('button', { name: 'تعطيل' }))
    await waitFor(() => expect(fake.rpcCalls('admin_set_lookup_active')).toEqual([{ p_kind: 'moderation_reason', p_id: 'OTHER', p_is_active: false }]))
    expect(await screen.findByText('تم تعطيل سبب الإشراف.')).toBeInTheDocument()
  })

  it('reorders reasons by code', async () => {
    const { fake } = setup('/admin/lookups?tab=reasons')
    await userEvent.click(await screen.findByRole('button', { name: 'نقل «بيانات ناقصة أو غير واضحة» إلى أسفل' }))
    await waitFor(() =>
      expect(fake.rpcCalls('admin_reorder_lookup')).toEqual([{ p_kind: 'moderation_reason', p_ids: ['FRAUD', 'MISSING_INFO', 'SPAM', 'OTHER'] }]),
    )
  })
})
