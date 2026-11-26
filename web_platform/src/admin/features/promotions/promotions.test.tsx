import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import listFx from '@contracts/fixtures/admin-list-promotions.json'
import settingsFx from '@contracts/fixtures/promotion-settings.json'
import { renderAdmin, moderator } from '@admin/test/render'
import { installFakeSupabase, type FakeSupabase } from '@admin/test/fakeSupabase'
import PromotionsPage from './PromotionsPage'
import PromotionEditorPage from './PromotionEditorPage'
import type { Promotion, PromotionDisplaySettings } from './types'

// يفحص بالأنواع أن أمثلة العقد 1.6.0 تطابق أشكال الواجهة.
const FIXTURE_LIST: Promotion[] = listFx as Promotion[]
const FIXTURE_SETTINGS: PromotionDisplaySettings = settingsFx

const DAY = 24 * 60 * 60 * 1000

function promo(over: Partial<Promotion>): Promotion {
  const now = Date.now()
  return {
    ...FIXTURE_LIST[1]!,
    id: crypto.randomUUID(),
    title: 'أعلاف الصحراء',
    advertiser_name: 'مؤسسة الصحراء',
    status: 'ACTIVE',
    starts_at: new Date(now - DAY).toISOString(),
    ends_at: new Date(now + 10 * DAY).toISOString(),
    impression_count: 400,
    click_count: 9,
    updated_at: new Date(now - 2 * DAY).toISOString(),
    ...over,
  }
}

/** خادم دعايات مزيف بسلوك دوال العقد: يخزن ويعيد الصف، ويرفض الفاصل خارج 4..30. */
function setup(initial: Promotion[] = []) {
  const store = new Map(initial.map((p) => [p.id, { ...p }]))
  let settings = { ...FIXTURE_SETTINGS }
  const fake: FakeSupabase = installFakeSupabase({
    tables: {
      regions: [
        { id: 1, name_ar: 'الرياض', is_active: true, sort_order: 1 },
        { id: 2, name_ar: 'القصيم', is_active: true, sort_order: 2 },
        { id: 3, name_ar: 'منطقة معطلة', is_active: false, sort_order: 3 },
      ],
    },
    rpc: {
      admin_list_promotions: () => [...store.values()].sort((a, b) => b.updated_at.localeCompare(a.updated_at)),
      admin_get_promotion: ({ p_id }) => {
        const p = store.get(p_id as string)
        if (!p) throw { code: 'NOT_FOUND' }
        return p
      },
      admin_save_promotion: ({ p_id, p_payload }) => {
        const now = new Date().toISOString()
        const body = p_payload as Partial<Promotion>
        const prev = p_id ? store.get(p_id as string) : undefined
        const row = {
          ...(prev ?? { id: crypto.randomUUID(), status: 'ACTIVE', impression_count: 0, click_count: 0, created_at: now, created_by: null }),
          ...body,
          updated_at: now,
          updated_by: null,
        } as Promotion
        store.set(row.id, row)
        return row
      },
      admin_set_promotion_status: ({ p_id, p_status }) => {
        const p = store.get(p_id as string)!
        const row = { ...p, status: p_status as Promotion['status'], updated_at: new Date().toISOString() }
        store.set(row.id, row)
        return row
      },
      admin_get_promotion_settings: () => settings,
      admin_update_promotion_settings: ({ p_enabled, p_feed_interval }) => {
        const n = p_feed_interval as number
        if (n < 4 || n > 30) throw { code: 'VALIDATION_FAILED', details: { fields: ['p_enabled', 'p_feed_interval'] } }
        settings = { ...settings, enabled: p_enabled as boolean, feed_interval: n }
        return settings
      },
    },
  })
  return { fake, store }
}

const LIST = { route: '/admin/promotions', path: '/admin/promotions' }
const NEW = {
  route: '/admin/promotions/new',
  path: '/admin/promotions/new',
  extraRoutes: [{ path: '/admin/promotions', element: <div>قائمة الدعايات</div> }],
}

describe('PromotionsPage', () => {
  it('renders the contract fixture with public image URLs and no mock banner', async () => {
    setup(FIXTURE_LIST)
    renderAdmin(<PromotionsPage />, LIST)
    const table = await screen.findByRole('table')
    expect(within(table).getByText('أعلاف الصحراء — خصم 15٪')).toBeInTheDocument()
    expect(within(table).getByText('عيادة الإبل البيطرية')).toBeInTheDocument()
    // صور زخرفية (alt فارغ) بلا دور img.
    const imgs = Array.from(table.querySelectorAll('img'))
    expect(imgs.map((i) => i.getAttribute('src'))).toContain(
      `https://storage.test/public/promotions/${FIXTURE_LIST[0]!.image_path}`,
    )
    expect(screen.queryByText(/وضع تجريبي/)).not.toBeInTheDocument()
  })

  it('shows effective states and stats, hiding archived by default', async () => {
    setup([
      promo({ title: 'دعاية جارية' }),
      promo({ title: 'دعاية مجدولة', starts_at: new Date(Date.now() + 3 * DAY).toISOString() }),
      promo({ title: 'دعاية منتهية', ends_at: new Date(Date.now() - DAY).toISOString() }),
      promo({ title: 'دعاية مؤرشفة', status: 'ARCHIVED' }),
    ])
    renderAdmin(<PromotionsPage />, LIST)
    const table = await screen.findByRole('table')
    const row = (name: string) => within(table).getByText(name).closest('tr')!
    expect(within(row('دعاية جارية')).getByText('تُعرض الآن')).toBeInTheDocument()
    expect(within(row('دعاية جارية')).getByText(/400 \/ 9/)).toBeInTheDocument()
    expect(within(row('دعاية مجدولة')).getByText('مجدولة')).toBeInTheDocument()
    expect(within(row('دعاية منتهية')).getByText('انتهت')).toBeInTheDocument()
    expect(within(table).queryByText('دعاية مؤرشفة')).not.toBeInTheDocument()

    await userEvent.selectOptions(screen.getByLabelText('الحالة'), 'ARCHIVED')
    expect(await within(screen.getByRole('table')).findByText('دعاية مؤرشفة')).toBeInTheDocument()
  })

  it('pauses, resumes and archives (with confirmation) through admin_set_promotion_status', async () => {
    const p = promo({ title: 'دعاية للإيقاف' })
    const { fake } = setup([p])
    renderAdmin(<PromotionsPage />, LIST)
    await userEvent.click(await screen.findByRole('button', { name: 'إيقاف' }))
    expect(await within(screen.getByRole('table')).findByText('موقوفة')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_set_promotion_status')[0]).toEqual({ p_id: p.id, p_status: 'PAUSED' })

    await userEvent.click(screen.getByRole('button', { name: 'استئناف' }))
    expect(await within(screen.getByRole('table')).findByText('تُعرض الآن')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'أرشفة' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.click(within(dialog).getByRole('button', { name: 'أرشفة' }))
    await waitFor(() => expect(fake.rpcCalls('admin_set_promotion_status').at(-1)).toEqual({ p_id: p.id, p_status: 'ARCHIVED' }))
    expect(await screen.findByText('لا دعايات بعد')).toBeInTheDocument()
  })

  it('validates locally, then saves the display settings', async () => {
    const { fake } = setup()
    renderAdmin(<PromotionsPage />, LIST)
    const interval = await screen.findByLabelText('دعاية بعد كل')
    await waitFor(() => expect(interval).toHaveValue(8))
    await userEvent.clear(interval)
    await userEvent.type(interval, '2')
    await userEvent.click(screen.getByRole('button', { name: 'حفظ الإعدادات' }))
    expect(await screen.findByText(/رقم صحيح من 4 إلى 30/)).toBeInTheDocument()
    expect(fake.rpcCalls('admin_update_promotion_settings')).toHaveLength(0)

    await userEvent.clear(interval)
    await userEvent.type(interval, '12')
    await userEvent.click(screen.getByRole('checkbox', { name: 'عرض الدعايات في التطبيق' }))
    await userEvent.click(screen.getByRole('button', { name: 'حفظ الإعدادات' }))
    await waitFor(() =>
      expect(fake.rpcCalls('admin_update_promotion_settings')).toEqual([{ p_enabled: false, p_feed_interval: 12 }]),
    )
  })
})

describe('PromotionEditorPage', () => {
  it('shows validation errors and calls nothing for an empty form', async () => {
    const { fake } = setup()
    renderAdmin(<PromotionEditorPage />, NEW)
    await userEvent.click(screen.getByRole('button', { name: 'إضافة الدعاية' }))
    expect(await screen.findByText('العنوان مطلوب (حرفان على الأقل).')).toBeInTheDocument()
    expect(screen.getByText('صورة الدعاية مطلوبة.')).toBeInTheDocument()
    expect(screen.getByText('أدخل رابطًا كاملًا يبدأ بـ https://')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_save_promotion')).toHaveLength(0)
    expect(fake.calls.filter((c) => c.kind === 'upload')).toHaveLength(0)
  })

  it('rejects unsupported image files', async () => {
    setup()
    renderAdmin(<PromotionEditorPage />, NEW)
    await userEvent.upload(screen.getByLabelText(/^الصورة/), new File(['x'], 'a.gif', { type: 'image/gif' }), { applyAccept: false })
    expect(await screen.findByText('الصيغ المقبولة: JPEG وPNG وWebP.')).toBeInTheDocument()
  })

  it('uploads the image to promotions, then saves a WhatsApp promotion targeted at a region', async () => {
    const { fake } = setup()
    renderAdmin(<PromotionEditorPage />, NEW)
    await userEvent.type(screen.getByLabelText(/^العنوان/), 'أعلاف الصحراء')
    await userEvent.type(screen.getByLabelText(/^اسم المعلن التجاري/), 'مؤسسة الصحراء')
    await userEvent.upload(screen.getByLabelText(/^الصورة/), new File(['png'], 'a.png', { type: 'image/png' }))
    await userEvent.selectOptions(screen.getByLabelText('الإجراء'), 'WHATSAPP')
    await userEvent.type(screen.getByLabelText(/^رقم واتساب/), '0551234567')
    await userEvent.click(screen.getByRole('checkbox', { name: 'نتائج البحث والتصفية' }))
    await userEvent.click(screen.getByRole('checkbox', { name: 'كل المناطق' }))
    await userEvent.click(await screen.findByRole('checkbox', { name: 'القصيم' }))
    expect(screen.queryByRole('checkbox', { name: 'منطقة معطلة' })).not.toBeInTheDocument()

    const preview = screen.getByRole('figure', { name: 'معاينة البطاقة في التطبيق' })
    expect(within(preview).getByText('إعلان ممول')).toBeInTheDocument()
    expect(within(preview).getByText('تواصل واتساب')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'إضافة الدعاية' }))
    expect(await screen.findByText('قائمة الدعايات')).toBeInTheDocument()

    const uploads = fake.calls.filter((c) => c.kind === 'upload')
    expect(uploads).toHaveLength(1)
    expect(uploads[0]!.name).toBe('promotions')
    const path = uploads[0]!.args!.path as string
    expect(path).toMatch(/^[0-9a-f-]{36}\/[0-9a-f-]{36}\.png$/)

    const [save] = fake.rpcCalls('admin_save_promotion')
    expect(save).toEqual({
      p_payload: {
        title: 'أعلاف الصحراء',
        body: null,
        advertiser_name: 'مؤسسة الصحراء',
        image_path: path,
        action_type: 'WHATSAPP',
        action_value: '+966551234567',
        placements: ['HOME_FEED', 'SEARCH_RESULTS'],
        region_ids: [2],
        starts_at: expect.any(String),
        ends_at: null,
        priority: 50,
      },
    })
  })

  it('edits an existing promotion without re-uploading its image', async () => {
    const p = promo({ title: 'عنوان قديم' })
    const { fake } = setup([p])
    renderAdmin(<PromotionEditorPage />, { route: `/admin/promotions/${p.id}`, path: '/admin/promotions/:promotionId' })
    const title = await screen.findByDisplayValue('عنوان قديم')
    const img = screen.getByRole('figure', { name: 'معاينة البطاقة في التطبيق' }).querySelector('img')
    expect(img).toHaveAttribute('src', `https://storage.test/public/promotions/${p.image_path}`)
    await userEvent.clear(title)
    await userEvent.type(title, 'عنوان جديد')
    await userEvent.click(screen.getByRole('button', { name: 'حفظ التعديلات' }))
    await waitFor(() => expect(fake.rpcCalls('admin_save_promotion')).toHaveLength(1))
    const call = fake.rpcCalls('admin_save_promotion')[0]!
    expect(call.p_id).toBe(p.id)
    expect((call.p_payload as Record<string, unknown>).image_path).toBe(p.image_path)
    expect(fake.calls.filter((c) => c.kind === 'upload')).toHaveLength(0)
  })

  it('maps server VALIDATION_FAILED fields onto the form', async () => {
    const p = promo({ title: 'دعاية' })
    const { fake } = setup([p])
    fake.failRpc('admin_save_promotion', 'VALIDATION_FAILED', { fields: ['image_path', 'action_value'] }, 1)
    renderAdmin(<PromotionEditorPage />, { route: `/admin/promotions/${p.id}`, path: '/admin/promotions/:promotionId' })
    await screen.findByDisplayValue('دعاية')
    await userEvent.click(screen.getByRole('button', { name: 'حفظ التعديلات' }))
    expect(await screen.findByText('تعذر الحفظ')).toBeInTheDocument()
    expect(screen.getAllByText('رفض الخادم هذه القيمة؛ راجعها.')).toHaveLength(2)
  })

  it('a moderator with promotions.manage can use the page', async () => {
    setup()
    renderAdmin(<PromotionsPage />, { ...LIST, whoami: moderator(['promotions.manage']) })
    expect(await screen.findByText('لا دعايات بعد')).toBeInTheDocument()
  })
})
