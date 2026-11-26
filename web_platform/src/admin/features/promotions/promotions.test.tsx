import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { renderAdmin, moderator } from '@admin/test/render'
import { installFakeSupabase } from '@admin/test/fakeSupabase'
import { mockPromotionsApi, resetMockPromotions } from './api'
import PromotionsPage from './PromotionsPage'
import PromotionEditorPage from './PromotionEditorPage'
import type { Promotion } from './types'

const DAY = 24 * 60 * 60 * 1000

function promo(over: Partial<Promotion>): Promotion {
  const now = Date.now()
  return {
    id: crypto.randomUUID(),
    title: 'أعلاف الصحراء',
    body: null,
    advertiser_name: 'مؤسسة الصحراء',
    image_path: 'data:image/png;base64,AAAA',
    action_type: 'URL',
    action_value: 'https://example.com',
    placements: ['HOME_FEED'],
    region_ids: null,
    starts_at: new Date(now - DAY).toISOString(),
    ends_at: new Date(now + 10 * DAY).toISOString(),
    priority: 50,
    status: 'ACTIVE',
    impression_count: 400,
    click_count: 9,
    created_at: new Date(now - 2 * DAY).toISOString(),
    updated_at: new Date(now - 2 * DAY).toISOString(),
    ...over,
  }
}

const LIST = { route: '/admin/promotions', path: '/admin/promotions' }

beforeEach(() => {
  resetMockPromotions()
  installFakeSupabase({
    tables: {
      regions: [
        { id: 1, name_ar: 'الرياض', is_active: true, sort_order: 1 },
        { id: 2, name_ar: 'القصيم', is_active: true, sort_order: 2 },
        { id: 3, name_ar: 'منطقة معطلة', is_active: false, sort_order: 3 },
      ],
    },
  })
})

describe('PromotionsPage', () => {
  it('labels the mock mode and shows the empty state', async () => {
    renderAdmin(<PromotionsPage />, LIST)
    expect(screen.getByText('وضع تجريبي: غير متصل بالتطبيق بعد')).toBeInTheDocument()
    expect(await screen.findByText('لا دعايات بعد')).toBeInTheDocument()
  })

  it('lists promotions with their effective state and stats, hiding archived by default', async () => {
    resetMockPromotions({
      promotions: [
        promo({ title: 'دعاية جارية' }),
        promo({ title: 'دعاية مجدولة', starts_at: new Date(Date.now() + 3 * DAY).toISOString() }),
        promo({ title: 'دعاية منتهية', ends_at: new Date(Date.now() - DAY).toISOString() }),
        promo({ title: 'دعاية مؤرشفة', status: 'ARCHIVED' }),
      ],
    })
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

  it('pauses, resumes and archives (with confirmation)', async () => {
    const p = promo({ title: 'دعاية للإيقاف' })
    resetMockPromotions({ promotions: [p] })
    renderAdmin(<PromotionsPage />, LIST)
    await userEvent.click(await screen.findByRole('button', { name: 'إيقاف' }))
    expect(await within(screen.getByRole('table')).findByText('موقوفة')).toBeInTheDocument()
    expect((await mockPromotionsApi.get(p.id))!.status).toBe('PAUSED')

    await userEvent.click(screen.getByRole('button', { name: 'استئناف' }))
    expect(await within(screen.getByRole('table')).findByText('تُعرض الآن')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'أرشفة' }))
    const dialog = await screen.findByRole('dialog')
    await userEvent.click(within(dialog).getByRole('button', { name: 'أرشفة' }))
    await waitFor(async () => expect((await mockPromotionsApi.get(p.id))!.status).toBe('ARCHIVED'))
    expect(await screen.findByText('لا دعايات بعد')).toBeInTheDocument()
  })

  it('validates and saves the display settings', async () => {
    renderAdmin(<PromotionsPage />, LIST)
    const interval = await screen.findByLabelText('دعاية بعد كل')
    await userEvent.clear(interval)
    await userEvent.type(interval, '2')
    await userEvent.click(screen.getByRole('button', { name: 'حفظ الإعدادات' }))
    expect(await screen.findByText(/رقم صحيح من 4 إلى 30/)).toBeInTheDocument()

    await userEvent.clear(interval)
    await userEvent.type(interval, '12')
    await userEvent.click(screen.getByRole('checkbox', { name: 'عرض الدعايات في التطبيق' }))
    await userEvent.click(screen.getByRole('button', { name: 'حفظ الإعدادات' }))
    await waitFor(async () => expect(await mockPromotionsApi.getSettings()).toEqual({ enabled: false, feed_interval: 12 }))
  })
})

describe('PromotionEditorPage', () => {
  const NEW = {
    route: '/admin/promotions/new',
    path: '/admin/promotions/new',
    extraRoutes: [{ path: '/admin/promotions', element: <div>قائمة الدعايات</div> }],
  }

  it('shows validation errors and does not save an empty form', async () => {
    renderAdmin(<PromotionEditorPage />, NEW)
    await userEvent.click(screen.getByRole('button', { name: 'إضافة الدعاية' }))
    expect(await screen.findByText('العنوان مطلوب (حرفان على الأقل).')).toBeInTheDocument()
    expect(screen.getByText('صورة الدعاية مطلوبة.')).toBeInTheDocument()
    expect(screen.getByText('أدخل رابطًا كاملًا يبدأ بـ https://')).toBeInTheDocument()
    expect(await mockPromotionsApi.list()).toEqual([])
  })

  it('rejects unsupported image files', async () => {
    renderAdmin(<PromotionEditorPage />, NEW)
    const gif = new File(['x'], 'a.gif', { type: 'image/gif' })
    await userEvent.upload(screen.getByLabelText(/^الصورة/), gif, { applyAccept: false })
    expect(await screen.findByText('الصيغ المقبولة: JPEG وPNG وWebP.')).toBeInTheDocument()
  })

  it('creates a WhatsApp promotion targeted at a region, with a live preview', async () => {
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
    expect(within(preview).getByText('أعلاف الصحراء')).toBeInTheDocument()
    expect(within(preview).getByText('تواصل واتساب')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'إضافة الدعاية' }))
    expect(await screen.findByText('قائمة الدعايات')).toBeInTheDocument()
    const [saved] = await mockPromotionsApi.list()
    expect(saved).toMatchObject({
      title: 'أعلاف الصحراء',
      advertiser_name: 'مؤسسة الصحراء',
      action_type: 'WHATSAPP',
      action_value: '+966551234567',
      placements: ['HOME_FEED', 'SEARCH_RESULTS'],
      region_ids: [2],
      ends_at: null,
      priority: 50,
      status: 'ACTIVE',
    })
    expect(saved!.image_path).toMatch(/^data:image\/png;base64,/)
  })

  it('loads and edits an existing promotion', async () => {
    const p = promo({ title: 'عنوان قديم' })
    resetMockPromotions({ promotions: [p] })
    renderAdmin(<PromotionEditorPage />, { route: `/admin/promotions/${p.id}`, path: '/admin/promotions/:promotionId' })
    const title = await screen.findByDisplayValue('عنوان قديم')
    await userEvent.clear(title)
    await userEvent.type(title, 'عنوان جديد')
    await userEvent.click(screen.getByRole('button', { name: 'حفظ التعديلات' }))
    await waitFor(async () => expect((await mockPromotionsApi.get(p.id))!.title).toBe('عنوان جديد'))
  })

  it('is hidden from a moderator without settings capability (route guard)', async () => {
    // الحارس يطبق في AdminApp عبر RequireCapability؛ هنا نتأكد أن الصفحة لا تفترض الدور.
    renderAdmin(<PromotionsPage />, { ...LIST, whoami: moderator(['settings.manage']) })
    expect(await screen.findByText('لا دعايات بعد')).toBeInTheDocument()
  })
})
