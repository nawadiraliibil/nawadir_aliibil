import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import fx from '@contracts/fixtures/published-settings.json'
import { renderAdmin, moderator, ADMIN_WHOAMI } from '@admin/test/render'
import { installFakeSupabase, type FakeSupabase } from '@admin/test/fakeSupabase'
import SettingsPage from './SettingsPage'
import type { AdminSettingsPayload, SettingsContent } from './types'

const PUBLISHED = fx.settings as SettingsContent
const STAFF_ID = ADMIN_WHOAMI.user_id

function clone<T>(v: T): T {
  return JSON.parse(JSON.stringify(v)) as T
}

/** رد بشكل private.settings_admin_json(). */
function payload(over: Partial<AdminSettingsPayload> = {}): AdminSettingsPayload {
  return {
    published_version: 2,
    published: clone(PUBLISHED),
    published_at: '2026-11-23T09:00:00+00:00',
    draft: null,
    draft_updated_by: null,
    draft_updated_at: null,
    ...over,
  }
}

function withListing(content: SettingsContent, patch: Record<string, unknown>): SettingsContent {
  const c = clone(content)
  c.listing = { ...(c.listing as Record<string, unknown>), ...patch }
  return c
}

const VERSION_ROWS = [
  { version: 2, content: withListing(PUBLISHED, { title_max: 80 }), note: 'رفع حد الوصف', restored_from_version: null, published_by: STAFF_ID, published_at: '2026-11-23T09:00:00+00:00' },
  { version: 1, content: clone(PUBLISHED), note: 'قيم البدء — SRS 10.1', restored_from_version: null, published_by: null, published_at: fx.published_at },
]

function setup(initial: AdminSettingsPayload = payload(), whoami = ADMIN_WHOAMI, prepare?: (fake: FakeSupabase) => void) {
  let state = initial
  const fake = installFakeSupabase({
    tables: { settings_versions: clone(VERSION_ROWS) },
    rpc: {
      admin_get_settings: () => state,
      admin_update_settings_draft: (args) => {
        const content = args.p_content as SettingsContent | null
        state = { ...state, draft: content, draft_updated_by: content ? STAFF_ID : null, draft_updated_at: content ? '2026-11-24T08:00:00+00:00' : null }
        return state
      },
      admin_publish_settings: () => {
        state = { ...state, published_version: state.published_version + 1, published: state.draft ?? state.published, draft: null, draft_updated_by: null, draft_updated_at: null, published_at: '2026-11-24T09:00:00+00:00' }
        return state
      },
      admin_rollback_settings: (args) => {
        const row = VERSION_ROWS.find((r) => r.version === args.p_version)
        state = { ...state, published_version: state.published_version + 1, published: clone(row?.content ?? PUBLISHED) }
        return state
      },
    },
  })
  prepare?.(fake)
  const utils = renderAdmin(<SettingsPage />, { route: '/admin/settings', whoami })
  return { fake, ...utils, getState: () => state }
}

async function loaded() {
  return screen.findByRole('heading', { name: 'تعديل الإعدادات' })
}

function field(name: RegExp) {
  return screen.getByLabelText(name) as HTMLInputElement
}

async function setValue(user: ReturnType<typeof userEvent.setup>, input: HTMLInputElement, value: string) {
  await user.clear(input)
  if (value) await user.type(input, value)
}

const DRAFT = withListing(PUBLISHED, { title_max: 90 })

describe('SettingsPage', () => {
  it('shows loading then the published version from a payload matching the SQL, with «لا توجد مسودة»', async () => {
    setup()
    expect(screen.getByRole('status')).toHaveTextContent('جارٍ التحميل')
    await loaded()
    expect(screen.getByText('لا توجد مسودة')).toBeInTheDocument()
    const published = screen.getByRole('heading', { name: 'الإصدار المنشور' }).closest('section')!
    expect(within(published).getByText('2')).toBeInTheDocument()
    // الناشر والملاحظة من صف settings_versions المطابق.
    expect(await within(published).findByText('رفع حد الوصف')).toBeInTheDocument()
    expect(field(/أقصى طول للعنوان/).value).toBe('80')
    expect(field(/الفترة بين تجديدين للظهور/).value).toBe('24')
    expect((screen.getByLabelText('تفعيل رفع الفيديو') as HTMLInputElement).checked).toBe(false)
    expect((screen.getByLabelText('JPEG') as HTMLInputElement).checked).toBe(true)
    expect(screen.queryByRole('button', { name: 'نشر المسودة' })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'حفظ المسودة' })).toBeDisabled()
  })

  it('shows the unpublished draft banner, the draft values and the diff', async () => {
    setup(payload({ draft: DRAFT, draft_updated_by: STAFF_ID, draft_updated_at: '2026-11-24T08:00:00+00:00' }))
    await loaded()
    expect(screen.getByText('مسودة غير منشورة')).toBeInTheDocument()
    expect(field(/أقصى طول للعنوان/).value).toBe('90')
    const diff = screen.getByRole('heading', { name: 'التغييرات في المسودة (1)' }).closest('section')!
    expect(within(diff).getByText('المحتوى — أقصى طول للعنوان (حرف)')).toBeInTheDocument()
    expect(within(diff).getByText('80 حرف')).toBeInTheDocument()
    expect(within(diff).getByText('90 حرف')).toBeInTheDocument()
  })

  it('saves the full content object including unknown keys', async () => {
    const user = userEvent.setup()
    const base = { ...clone(PUBLISHED), experimental: { flag: true }, listing: { ...(PUBLISHED.listing as object), legacy_key: 7 } }
    const { fake } = setup(payload({ published: base }))
    await loaded()
    expect(screen.getByRole('heading', { name: 'مفاتيح أخرى (للقراءة فقط)' })).toBeInTheDocument()
    expect(screen.getByText(/"experimental"/)).toBeInTheDocument()
    await setValue(user, field(/أقصى طول للعنوان/), '95')
    await user.click(screen.getByLabelText('تفعيل رفع الفيديو'))
    await user.click(screen.getByRole('button', { name: 'حفظ المسودة' }))
    await screen.findByText('حفظت المسودة. لا تسري التعديلات حتى تنشر.')
    const calls = fake.rpcCalls('admin_update_settings_draft')
    expect(calls).toHaveLength(1)
    const expected = clone(base) as Record<string, Record<string, unknown>>
    expected.listing!.title_max = 95
    expected.media!.video_enabled = true
    expect(calls[0]).toEqual({ p_content: expected })
    expect(screen.getByText('مسودة غير منشورة')).toBeInTheDocument()
  })

  it('blocks a bump interval below 24 hours on the client', async () => {
    const user = userEvent.setup()
    const { fake } = setup()
    await loaded()
    const bump = field(/الفترة بين تجديدين للظهور/)
    await setValue(user, bump, '12')
    expect(bump).toHaveAttribute('aria-invalid', 'true')
    expect(screen.getByText('لا تقل عن 24 ساعة — حد ثابت لا يقبل التخفيض.')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'حفظ المسودة' }))
    expect(await screen.findByText('صحح الحقول المحددة قبل الحفظ.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_update_settings_draft')).toHaveLength(0)
  })

  it('blocks min > max and non-integers on the client', async () => {
    const user = userEvent.setup()
    const { fake } = setup()
    await loaded()
    await setValue(user, field(/أقل عدد للصور/), '15')
    expect(field(/أقل عدد للصور/)).toHaveAttribute('aria-invalid', 'true')
    await setValue(user, field(/أقصى طول للرسالة/), '')
    expect(screen.getByText('هذا الحقل مطلوب.')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'حفظ المسودة' }))
    expect(fake.rpcCalls('admin_update_settings_draft')).toHaveLength(0)
  })

  it('highlights the field from BELOW_HARD_MINIMUM returned by the server', async () => {
    const user = userEvent.setup()
    const { fake } = setup()
    fake.failRpc('admin_update_settings_draft', 'BELOW_HARD_MINIMUM', { field: 'bump.interval_hours', minimum: 24 }, 1)
    await loaded()
    await setValue(user, field(/أقصى طول للعنوان/), '70')
    await user.click(screen.getByRole('button', { name: 'حفظ المسودة' }))
    expect(await screen.findByText('القيمة أقل من الحد الأدنى الثابت (تجديد الظهور لا يقل عن 24 ساعة).')).toBeInTheDocument()
    const bump = field(/الفترة بين تجديدين للظهور/)
    expect(bump).toHaveAttribute('aria-invalid', 'true')
    expect(screen.getByText('لا تقل عن 24 ساعة — حد ثابت لا يقبل التخفيض.')).toBeInTheDocument()
    expect(screen.queryByText('حفظت المسودة. لا تسري التعديلات حتى تنشر.')).not.toBeInTheDocument()
  })

  it('highlights VALIDATION_FAILED field paths from the server', async () => {
    const user = userEvent.setup()
    const { fake } = setup()
    fake.failRpc('admin_update_settings_draft', 'VALIDATION_FAILED', { fields: ['listing.description_min', 'media.image_max_bytes'] }, 1)
    await loaded()
    await setValue(user, field(/أقصى طول للعنوان/), '70')
    await user.click(screen.getByRole('button', { name: 'حفظ المسودة' }))
    expect(await screen.findByText('بعض القيم غير صالحة. راجع الحقول المحددة.')).toBeInTheDocument()
    expect(field(/أقل طول للوصف/)).toHaveAttribute('aria-invalid', 'true')
    expect(field(/أقصى حجم للصورة/)).toHaveAttribute('aria-invalid', 'true')
    expect(field(/أقصى طول للعنوان/)).not.toHaveAttribute('aria-invalid')
    // تعديل الحقل يزيل تمييز الخادم عنه.
    await setValue(user, field(/أقل طول للوصف/), '30')
    expect(field(/أقل طول للوصف/)).not.toHaveAttribute('aria-invalid')
  })

  it('discards the draft with p_content null after confirmation', async () => {
    const user = userEvent.setup()
    const { fake } = setup(payload({ draft: DRAFT, draft_updated_by: STAFF_ID, draft_updated_at: '2026-11-24T08:00:00+00:00' }))
    await loaded()
    await user.click(screen.getByRole('button', { name: 'إلغاء المسودة' }))
    const dialog = screen.getByRole('dialog', { name: 'إلغاء المسودة' })
    expect(fake.rpcCalls('admin_update_settings_draft')).toHaveLength(0)
    await user.click(within(dialog).getByRole('button', { name: 'إلغاء المسودة' }))
    await screen.findByText('ألغيت المسودة. الإصدار المنشور لم يتغير.')
    expect(fake.rpcCalls('admin_update_settings_draft')).toEqual([{ p_content: null }])
    expect(screen.getByText('لا توجد مسودة')).toBeInTheDocument()
    expect(field(/أقصى طول للعنوان/).value).toBe('80')
  })

  it('publishes the draft with the note, and notifies only after the server returns', async () => {
    const user = userEvent.setup()
    const { fake } = setup(payload({ draft: DRAFT, draft_updated_by: STAFF_ID, draft_updated_at: '2026-11-24T08:00:00+00:00' }))
    await loaded()
    await user.click(screen.getByRole('button', { name: 'نشر المسودة' }))
    const dialog = screen.getByRole('dialog', { name: 'نشر المسودة' })
    await user.type(within(dialog).getByLabelText(/ملاحظة الإصدار/), 'رفع حد العنوان')
    expect(screen.queryByText(/نشر الإصدار 3/)).not.toBeInTheDocument()
    await user.click(within(dialog).getByRole('button', { name: 'نشر' }))
    await screen.findByText('نشر الإصدار 3. تسري الحدود الجديدة الآن.')
    expect(fake.rpcCalls('admin_publish_settings')).toEqual([{ p_note: 'رفع حد العنوان' }])
    expect(screen.getByText('لا توجد مسودة')).toBeInTheDocument()
  })

  it('publishes without a note by omitting p_note', async () => {
    const user = userEvent.setup()
    const { fake } = setup(payload({ draft: DRAFT, draft_updated_by: STAFF_ID, draft_updated_at: '2026-11-24T08:00:00+00:00' }))
    await loaded()
    await user.click(screen.getByRole('button', { name: 'نشر المسودة' }))
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'نشر' }))
    await screen.findByText('نشر الإصدار 3. تسري الحدود الجديدة الآن.')
    expect(fake.rpcCalls('admin_publish_settings')).toEqual([{}])
  })

  it('shows INVALID_STATE (no_draft) on publish, keeps the dialog open and refetches without retrying', async () => {
    const user = userEvent.setup()
    const { fake } = setup(payload({ draft: DRAFT, draft_updated_by: STAFF_ID, draft_updated_at: '2026-11-24T08:00:00+00:00' }))
    fake.failRpc('admin_publish_settings', 'INVALID_STATE', { reason: 'no_draft' })
    await loaded()
    const getsBefore = fake.rpcCalls('admin_get_settings').length
    await user.click(screen.getByRole('button', { name: 'نشر المسودة' }))
    const dialog = screen.getByRole('dialog', { name: 'نشر المسودة' })
    await user.click(within(dialog).getByRole('button', { name: 'نشر' }))
    expect(await within(dialog).findByText('لا يسمح بهذا الإجراء في الحالة الحالية. حدّث الصفحة لرؤية آخر حالة.')).toBeInTheDocument()
    expect(await screen.findByText('لا توجد مسودة للنشر؛ ربما نشرها أو ألغاها موظف آخر.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_publish_settings')).toHaveLength(1)
    await waitFor(() => expect(fake.rpcCalls('admin_get_settings').length).toBeGreaterThan(getsBefore))
  })

  it('disables publishing while there are unsaved edits', async () => {
    const user = userEvent.setup()
    setup(payload({ draft: DRAFT, draft_updated_by: STAFF_ID, draft_updated_at: '2026-11-24T08:00:00+00:00' }))
    await loaded()
    expect(screen.getByRole('button', { name: 'نشر المسودة' })).toBeEnabled()
    await setValue(user, field(/أقصى طول للعنوان/), '100')
    expect(screen.getByRole('button', { name: 'نشر المسودة' })).toBeDisabled()
  })

  it('lists versions from the settings_versions table in descending order', async () => {
    const { fake } = setup()
    await loaded()
    const card = screen.getByRole('heading', { name: 'سجل الإصدارات' }).closest('section')!
    expect(await within(card).findByText('قيم البدء — SRS 10.1')).toBeInTheDocument()
    expect(within(card).getByText('المنشور حاليًا')).toBeInTheDocument()
    expect(within(card).getByText('النظام (قيم البدء)')).toBeInTheDocument()
    const sel = fake.calls.find((c) => c.kind === 'select' && c.name === 'settings_versions')
    expect(sel?.filters).toContainEqual(['order', 'version', false])
    expect(sel?.filters).toContainEqual(['range', 0, 19])
    const rows = within(card).getAllByRole('row')
    expect(rows[1]).toHaveTextContent('2')
    expect(rows[2]).toHaveTextContent('1')
    // لا تراجع إلى الإصدار المنشور نفسه.
    expect(within(card).queryByRole('button', { name: 'التراجع إلى هذا الإصدار (2)' })).not.toBeInTheDocument()
  })

  it('views a version content', async () => {
    const user = userEvent.setup()
    setup()
    await loaded()
    await user.click(await screen.findByRole('button', { name: 'عرض المحتوى (الإصدار 1)' }))
    const dialog = screen.getByRole('dialog', { name: 'محتوى الإصدار 1' })
    expect(within(dialog).getByText('10,485,760 بايت (10 ميجابايت)')).toBeInTheDocument()
    expect(within(dialog).getByText('JPEG، PNG')).toBeInTheDocument()
  })

  it('rolls back to a version with p_version and the note', async () => {
    const user = userEvent.setup()
    const { fake } = setup()
    await loaded()
    await user.click(await screen.findByRole('button', { name: 'التراجع إلى هذا الإصدار (1)' }))
    const dialog = screen.getByRole('dialog', { name: 'التراجع إلى الإصدار 1' })
    expect(within(dialog).getByText(/إصدارًا جديدًا/)).toBeInTheDocument()
    await user.type(within(dialog).getByLabelText(/ملاحظة/), 'عودة لقيم البدء')
    await user.click(within(dialog).getByRole('button', { name: 'نشر إصدار بمحتوى قديم' }))
    await screen.findByText('نشر الإصدار 3 بمحتوى الإصدار 1.')
    expect(fake.rpcCalls('admin_rollback_settings')).toEqual([{ p_version: 1, p_note: 'عودة لقيم البدء' }])
  })

  it('shows the Arabic message when rollback content violates current rules', async () => {
    const user = userEvent.setup()
    const { fake } = setup()
    fake.failRpc('admin_rollback_settings', 'BELOW_HARD_MINIMUM', { field: 'bump.interval_hours', minimum: 24 })
    await loaded()
    await user.click(await screen.findByRole('button', { name: 'التراجع إلى هذا الإصدار (1)' }))
    const dialog = screen.getByRole('dialog')
    await user.click(within(dialog).getByRole('button', { name: 'نشر إصدار بمحتوى قديم' }))
    expect(await within(dialog).findByText('القيمة أقل من الحد الأدنى الثابت (تجديد الظهور لا يقل عن 24 ساعة).')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_rollback_settings')).toEqual([{ p_version: 1 }])
  })

  it('shows an error state with retry', async () => {
    const user = userEvent.setup()
    setup(payload(), ADMIN_WHOAMI, (fake) => fake.failRpc('admin_get_settings', 'INTERNAL_ERROR', undefined, 1))
    expect(await screen.findByText('تعذر تحميل الإعدادات')).toBeInTheDocument()
    expect(screen.getByText('حدث خطأ في الخادم. أعد المحاولة لاحقًا.')).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'إعادة المحاولة' }))
    await loaded()
  })

  it('shows FORBIDDEN in Arabic', async () => {
    setup(payload(), ADMIN_WHOAMI, (fake) => fake.failRpc('admin_get_settings', 'FORBIDDEN'))
    expect(await screen.findByText('لا تملك صلاحية تنفيذ هذا الإجراء.')).toBeInTheDocument()
  })

  it('shows an error inside the versions card when the table read fails', async () => {
    setup(payload(), ADMIN_WHOAMI, (fake) => fake.failTable('settings_versions', 'FORBIDDEN'))
    await loaded()
    expect(await screen.findByText('تعذر تحميل سجل الإصدارات')).toBeInTheDocument()
  })

  it('hides all actions and makes no calls without settings.manage', async () => {
    const { fake } = setup(payload(), moderator(['listings.review', 'lookups.manage']))
    expect(screen.getByText('لا تملك صلاحية')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'حفظ المسودة' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /التراجع/ })).not.toBeInTheDocument()
    expect(fake.calls).toHaveLength(0)
  })

  it('a moderator with settings.manage gets the editor and actions', async () => {
    setup(payload({ draft: DRAFT, draft_updated_by: STAFF_ID, draft_updated_at: '2026-11-24T08:00:00+00:00' }), moderator(['settings.manage']))
    await loaded()
    expect(screen.getByRole('button', { name: 'حفظ المسودة' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'نشر المسودة' })).toBeInTheDocument()
    expect(await screen.findByRole('button', { name: 'التراجع إلى هذا الإصدار (1)' })).toBeInTheDocument()
  })
})

