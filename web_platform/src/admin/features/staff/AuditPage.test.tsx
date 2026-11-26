import { fireEvent, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { renderAdmin, ADMIN_WHOAMI, moderator } from '@admin/test/render'
import { installFakeSupabase, type FakeSupabase } from '@admin/test/fakeSupabase'
import { riyadhDayToIso } from '@admin/lib/format'
import AuditPage from './AuditPage'
import type { AuditLogRow, EvidenceAccessRow } from './types'

const ME = ADMIN_WHOAMI.user_id
const OTHER = '44444444-4444-4444-8444-444444444444'
const LISTING = '55555555-5555-4555-8555-555555555555'
const ACCOUNT = '66666666-6666-4666-8666-666666666666'
const REPORT = '77777777-7777-4777-8777-777777777777'
const RATING = '88888888-8888-4888-8888-888888888888'

function auditRows(): AuditLogRow[] {
  return [
    {
      id: 5,
      actor_id: ME,
      action: 'listing.hidden',
      resource_type: 'listing',
      resource_id: LISTING,
      reason_code: 'PROHIBITED_CONTENT',
      reason_text: 'صور مخالفة',
      details: { version_id: '99999999-9999-4999-8999-999999999999' },
      created_at: '2026-11-24T08:00:00Z',
    },
    {
      id: 4,
      actor_id: OTHER,
      action: 'account.suspended',
      resource_type: 'account',
      resource_id: ACCOUNT,
      reason_code: 'SPAM',
      reason_text: null,
      details: { hidden_listing_ids: [LISTING] },
      created_at: '2026-11-23T08:00:00Z',
    },
    {
      id: 3,
      actor_id: OTHER,
      action: 'report.closed',
      resource_type: 'report',
      resource_id: REPORT,
      reason_code: null,
      reason_text: null,
      details: {},
      created_at: '2026-11-22T08:00:00Z',
    },
    {
      id: 2,
      actor_id: ME,
      action: 'rating.hidden',
      resource_type: 'rating',
      resource_id: RATING,
      reason_code: 'OTHER',
      reason_text: 'إساءة',
      details: {},
      created_at: '2026-11-21T08:00:00Z',
    },
    {
      id: 1,
      actor_id: null,
      action: 'staff.bootstrap_admin',
      resource_type: 'admin_role',
      resource_id: ME,
      reason_code: null,
      reason_text: null,
      details: {},
      created_at: '2026-11-20T08:00:00Z',
    },
  ]
}

function evidenceRows(): EvidenceAccessRow[] {
  return [
    { id: 2, report_id: REPORT, actor_id: ME, created_at: '2026-11-24T09:00:00Z' },
    { id: 1, report_id: REPORT, actor_id: OTHER, created_at: '2026-11-23T09:00:00Z' },
  ]
}

function lastSelect(fake: FakeSupabase, table: string) {
  const calls = fake.calls.filter((c) => c.kind === 'select' && c.name === table)
  return calls[calls.length - 1]
}

function setup(tables: Record<string, Array<Record<string, unknown>>> = { audit_log: auditRows(), report_evidence_access: evidenceRows() }, whoami = ADMIN_WHOAMI) {
  const fake = installFakeSupabase({ tables })
  const user = userEvent.setup()
  const view = renderAdmin(<AuditPage />, { route: '/admin/audit', whoami })
  return { fake, user, ...view }
}

describe('AuditPage — سجل الإجراءات', () => {
  it('loads then renders rows with labels, actors and resource links', async () => {
    const { fake } = setup()
    expect(screen.getByText('جارٍ التحميل…')).toBeInTheDocument()
    const table = within(await screen.findByRole('table'))
    expect(table.getByText('إخفاء إعلان')).toBeInTheDocument()
    expect(table.getByText('تعليق حساب')).toBeInTheDocument()
    expect(table.getByText('إغلاق بلاغ')).toBeInTheDocument()
    expect(table.getByText('تهيئة أول مدير')).toBeInTheDocument()
    expect(table.getAllByText('أنت').length).toBeGreaterThanOrEqual(2)
    expect(table.getByText('النظام')).toBeInTheDocument()
    expect(table.getAllByText('44444444').length).toBeGreaterThanOrEqual(1)

    expect(screen.getByRole('link', { name: `إعلان ${LISTING}` })).toHaveAttribute('href', `/admin/listings/${LISTING}`)
    expect(screen.getByRole('link', { name: `حساب ${ACCOUNT}` })).toHaveAttribute('href', `/admin/accounts/${ACCOUNT}`)
    expect(screen.getByRole('link', { name: `بلاغ ${REPORT}` })).toHaveAttribute('href', `/admin/reports/${REPORT}`)
    expect(screen.getByRole('link', { name: `تقييم ${RATING}` })).toHaveAttribute('href', `/admin/ratings/${RATING}`)

    expect(screen.getByText('PROHIBITED_CONTENT')).toBeInTheDocument()
    expect(screen.getByText('صور مخالفة')).toBeInTheDocument()
    // التفاصيل قابلة للتوسيع وتعرض JSON.
    expect(screen.getAllByText('عرض التفاصيل')).toHaveLength(2)
    expect(screen.getByText(/"hidden_listing_ids"/)).toBeInTheDocument()

    const call = lastSelect(fake, 'audit_log')
    expect(call?.filters).toEqual([
      ['order', 'id', false],
      ['limit', 50],
    ])
  })

  it('has no edit or delete controls at all', async () => {
    setup()
    await screen.findByRole('table')
    expect(screen.queryByRole('button', { name: /تعديل|حذف/ })).not.toBeInTheDocument()
    await userEvent.setup().click(screen.getByRole('tab', { name: 'سجل الاطلاع على الأدلة' }))
    expect(await screen.findAllByRole('link', { name: `البلاغ ${REPORT}` })).toHaveLength(2)
    expect(screen.queryByRole('button', { name: /تعديل|حذف/ })).not.toBeInTheDocument()
  })

  it('shows legacy approve/reject history with an «قديم» label, but not in the action filter', async () => {
    setup({
      audit_log: [
        { ...auditRows()[0]!, id: 9, action: 'listing.approved' },
        { ...auditRows()[0]!, id: 8, action: 'custom.unknown_action' },
      ],
    })
    expect(await screen.findByText('اعتماد إعلان (قديم)')).toBeInTheDocument()
    // الإجراء غير المعروف يعرض كما هو.
    expect(screen.getAllByText('custom.unknown_action').length).toBeGreaterThanOrEqual(1)
    const actionSelect = screen.getByRole('combobox', { name: 'الإجراء' })
    const values = within(actionSelect)
      .getAllByRole('option')
      .map((o) => (o as HTMLOptionElement).value)
    expect(values).not.toContain('listing.approved')
    expect(values).not.toContain('listing.rejected')
    expect(values).toContain('staff.role_granted')
  })

  it('applies filters as exact table filters (action, resource, actor «أنا», Riyadh days)', async () => {
    const { fake, user } = setup()
    await screen.findByRole('table')
    await user.selectOptions(screen.getByRole('combobox', { name: 'الإجراء' }), 'listing.hidden')
    await user.selectOptions(screen.getByRole('combobox', { name: 'نوع المورد' }), 'listing')
    await user.selectOptions(screen.getByRole('combobox', { name: 'الفاعل' }), 'me')
    fireEvent.change(screen.getByLabelText('من يوم'), { target: { value: '2026-11-01' } })
    fireEvent.change(screen.getByLabelText('إلى يوم'), { target: { value: '2026-11-24' } })
    await user.click(screen.getByRole('button', { name: 'تطبيق' }))

    await waitFor(() => expect(lastSelect(fake, 'audit_log')?.filters).toContainEqual(['eq', 'action', 'listing.hidden']))
    const filters = lastSelect(fake, 'audit_log')?.filters
    expect(filters).toEqual([
      ['eq', 'action', 'listing.hidden'],
      ['eq', 'resource_type', 'listing'],
      ['eq', 'actor_id', ME],
      ['gte', 'created_at', riyadhDayToIso('2026-11-01')],
      ['lt', 'created_at', riyadhDayToIso('2026-11-24', true)],
      ['order', 'id', false],
      ['limit', 50],
    ])
    expect(riyadhDayToIso('2026-11-01')).toBe('2026-10-31T21:00:00.000Z')
    await waitFor(() => expect(within(screen.getByRole('table')).queryByText('تعليق حساب')).not.toBeInTheDocument())
    expect(within(screen.getByRole('table')).getByText('إخفاء إعلان')).toBeInTheDocument()
  })

  it('filters by system actor and by a specific actor UUID, validating it', async () => {
    const { fake, user } = setup()
    await screen.findByRole('table')
    await user.selectOptions(screen.getByRole('combobox', { name: 'الفاعل' }), 'system')
    await user.click(screen.getByRole('button', { name: 'تطبيق' }))
    await waitFor(() => expect(lastSelect(fake, 'audit_log')?.filters).toContainEqual(['is', 'actor_id', null]))

    await user.selectOptions(screen.getByRole('combobox', { name: 'الفاعل' }), 'id')
    const before = fake.calls.filter((c) => c.name === 'audit_log').length
    await user.type(screen.getByLabelText(/معرف الفاعل/), 'bad')
    await user.click(screen.getByRole('button', { name: 'تطبيق' }))
    expect(screen.getByText('أدخل معرف UUID صالحًا للفاعل.')).toBeInTheDocument()
    expect(fake.calls.filter((c) => c.name === 'audit_log').length).toBe(before)

    await user.clear(screen.getByLabelText(/معرف الفاعل/))
    await user.type(screen.getByLabelText(/معرف الفاعل/), OTHER)
    await user.click(screen.getByRole('button', { name: 'تطبيق' }))
    await waitFor(() => expect(lastSelect(fake, 'audit_log')?.filters).toContainEqual(['eq', 'actor_id', OTHER]))
  })

  it('rejects an end day before the start day', async () => {
    const { fake, user } = setup()
    await screen.findByRole('table')
    const before = fake.calls.filter((c) => c.name === 'audit_log').length
    fireEvent.change(screen.getByLabelText('من يوم'), { target: { value: '2026-11-20' } })
    fireEvent.change(screen.getByLabelText('إلى يوم'), { target: { value: '2026-11-10' } })
    await user.click(screen.getByRole('button', { name: 'تطبيق' }))
    expect(screen.getByText('تاريخ النهاية قبل تاريخ البداية.')).toBeInTheDocument()
    expect(fake.calls.filter((c) => c.name === 'audit_log').length).toBe(before)
  })

  it('paginates with keyset lt(id) of the last row', async () => {
    const many: AuditLogRow[] = Array.from({ length: 60 }, (_, i) => ({
      id: 100 - i,
      actor_id: OTHER,
      action: 'lookup.upserted',
      resource_type: 'breed',
      resource_id: String(100 - i),
      reason_code: null,
      reason_text: null,
      details: {},
      created_at: '2026-11-24T08:00:00Z',
    }))
    const { fake, user } = setup({ audit_log: many })
    expect(within(await screen.findByRole('table')).getAllByText('إضافة قيمة قائمة أو تعديلها')).toHaveLength(50)
    expect(lastSelect(fake, 'audit_log')?.filters).not.toContainEqual(expect.arrayContaining(['lt', 'id']))
    await user.click(screen.getByRole('button', { name: 'تحميل المزيد' }))
    await waitFor(() => expect(within(screen.getByRole('table')).getAllByText('إضافة قيمة قائمة أو تعديلها')).toHaveLength(60))
    expect(lastSelect(fake, 'audit_log')?.filters).toEqual([
      ['lt', 'id', 51],
      ['order', 'id', false],
      ['limit', 50],
    ])
    expect(screen.queryByRole('button', { name: 'تحميل المزيد' })).not.toBeInTheDocument()
  })

  it('shows the error state with retry', async () => {
    const { fake, user } = setup()
    fake.failTable('audit_log', 'FORBIDDEN')
    expect(await screen.findByText('لا تملك صلاحية تنفيذ هذا الإجراء.')).toBeInTheDocument()
    fake.failTable('audit_log', '')
    await user.click(screen.getByRole('button', { name: 'إعادة المحاولة' }))
    expect(await screen.findByRole('table')).toBeInTheDocument()
  })

  it('shows the empty state', async () => {
    setup({ audit_log: [] }, moderator(['audit.read']))
    expect(await screen.findByText('لا إجراءات مطابقة')).toBeInTheDocument()
  })
})

describe('AuditPage — سجل الاطلاع على الأدلة', () => {
  it('switches tab and renders evidence access rows ordered by id desc', async () => {
    const { fake, user } = setup()
    await screen.findByRole('table')
    const tab = screen.getByRole('tab', { name: 'سجل الاطلاع على الأدلة' })
    expect(tab).toHaveAttribute('aria-selected', 'false')
    await user.click(tab)
    expect(tab).toHaveAttribute('aria-selected', 'true')
    const links = await screen.findAllByRole('link', { name: `البلاغ ${REPORT}` })
    expect(links).toHaveLength(2)
    expect(links[0]).toHaveAttribute('href', `/admin/reports/${REPORT}`)
    expect(screen.getByText('أنت')).toBeInTheDocument()
    expect(screen.getByText('44444444')).toBeInTheDocument()
    expect(lastSelect(fake, 'report_evidence_access')?.filters).toEqual([
      ['order', 'id', false],
      ['limit', 50],
    ])
  })

  it('supports arrow-key tab navigation', async () => {
    const { user } = setup()
    await screen.findByRole('table')
    screen.getByRole('tab', { name: 'سجل الإجراءات' }).focus()
    await user.keyboard('{ArrowLeft}')
    expect(screen.getByRole('tab', { name: 'سجل الاطلاع على الأدلة' })).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByRole('tab', { name: 'سجل الاطلاع على الأدلة' })).toHaveFocus()
  })

  it('paginates evidence access and shows errors', async () => {
    const many: EvidenceAccessRow[] = Array.from({ length: 51 }, (_, i) => ({ id: 200 - i, report_id: REPORT, actor_id: OTHER, created_at: '2026-11-24T09:00:00Z' }))
    const { fake, user } = setup({ audit_log: [], report_evidence_access: many })
    await user.click(screen.getByRole('tab', { name: 'سجل الاطلاع على الأدلة' }))
    expect(await screen.findAllByRole('link', { name: `البلاغ ${REPORT}` })).toHaveLength(50)
    fake.failTable('report_evidence_access', 'INTERNAL_ERROR')
    await user.click(screen.getByRole('button', { name: 'تحميل المزيد' }))
    expect(await screen.findByText('تعذر تحميل المزيد')).toBeInTheDocument()
    fake.failTable('report_evidence_access', '')
    await user.click(within(screen.getByText('تعذر تحميل المزيد').closest('.alert') as HTMLElement).getByRole('button', { name: 'إعادة المحاولة' }))
    await waitFor(() => expect(screen.getAllByRole('link', { name: `البلاغ ${REPORT}` })).toHaveLength(51))
    expect(lastSelect(fake, 'report_evidence_access')?.filters).toContainEqual(['lt', 'id', 151])
  })
})
