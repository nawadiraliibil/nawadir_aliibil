import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import whoamiFixture from '@contracts/fixtures/admin-whoami.json'
import { renderAdmin, moderator, ADMIN_WHOAMI } from '@admin/test/render'
import { installFakeSupabase } from '@admin/test/fakeSupabase'
import type { Whoami } from '@admin/lib/capabilities'
import StaffPage from './StaffPage'
import type { AdminRoleRow } from './types'

const ME = ADMIN_WHOAMI.user_id
const MOD = '22222222-2222-4222-8222-222222222222'
const OLD = '33333333-3333-4333-8333-333333333333'
const NEW = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'

function roles(): AdminRoleRow[] {
  return [
    {
      user_id: ME,
      role: 'ADMIN',
      capabilities: [],
      is_active: true,
      granted_at: '2026-11-22T10:00:00Z',
      granted_by: null,
      revoked_at: null,
      revoked_by: null,
      updated_at: '2026-11-22T10:00:00Z',
    },
    {
      user_id: MOD,
      role: 'MODERATOR',
      capabilities: ['listings.review', 'reports.handle'],
      is_active: true,
      granted_at: '2026-11-23T09:00:00Z',
      granted_by: ME,
      revoked_at: null,
      revoked_by: null,
      updated_at: '2026-11-23T09:00:00Z',
    },
    {
      user_id: OLD,
      role: 'MODERATOR',
      capabilities: ['listings.hide'],
      is_active: false,
      granted_at: '2026-11-21T09:00:00Z',
      granted_by: ME,
      revoked_at: '2026-11-23T12:00:00Z',
      revoked_by: ME,
      updated_at: '2026-11-23T12:00:00Z',
    },
  ]
}

function setup(opts: { whoami?: Whoami | null } = {}) {
  const fake = installFakeSupabase({
    tables: { admin_roles: roles() },
    rpc: {
      admin_grant_role: (a) => ({ user_id: a.p_user_id, role: a.p_role, capabilities: a.p_capabilities, is_active: true }),
      admin_revoke_role: (a) => ({ user_id: a.p_user_id, role: 'MODERATOR', is_active: false }),
    },
  })
  const user = userEvent.setup()
  const view = renderAdmin(<StaffPage />, { route: '/admin/staff', whoami: opts.whoami })
  return { fake, user, ...view }
}

function rowOf(id: string): HTMLElement {
  const cell = screen.getByText(id)
  const tr = cell.closest('tr')
  if (!tr) throw new Error('row not found')
  return tr
}

describe('StaffPage', () => {
  it('shows loading then the staff list, active first, with «أنت» and revoked badge', async () => {
    const { fake } = setup()
    expect(screen.getByText('جارٍ التحميل…')).toBeInTheDocument()
    expect(await screen.findByText(MOD)).toBeInTheDocument()
    expect(within(rowOf(ME)).getByText('أنت')).toBeInTheDocument()
    expect(within(rowOf(OLD)).getByText('مسحوب')).toBeInTheDocument()
    expect(within(rowOf(MOD)).getByText('عرض الإعلانات وتفاصيلها')).toBeInTheDocument()
    expect(within(rowOf(ME)).getByText('كل القدرات')).toBeInTheDocument()
    const call = fake.calls.find((c) => c.kind === 'select' && c.name === 'admin_roles')
    expect(call?.filters).toContainEqual(['order', 'is_active', false])
    // الصف المسحوب بعد الفعالين.
    const order = screen.getAllByRole('row').slice(1).map((r) => r.textContent ?? '')
    expect(order.findIndex((t) => t.includes(OLD))).toBe(order.length - 1)
  })

  it('renders with the admin-whoami contract fixture as the session', async () => {
    setup({ whoami: whoamiFixture as Whoami })
    expect(await screen.findByText(MOD)).toBeInTheDocument()
    expect(within(rowOf(whoamiFixture.user_id)).getByText('أنت')).toBeInTheDocument()
  })

  it('has no edit or revoke buttons on the self row, with a hint', async () => {
    setup()
    await screen.findByText(MOD)
    const self = rowOf(ME)
    expect(within(self).queryByRole('button', { name: /تعديل|سحب/ })).not.toBeInTheDocument()
    expect(within(self).getByText('لا يمكنك تعديل دورك أو سحبه بنفسك.')).toBeInTheDocument()
    expect(within(rowOf(MOD)).getByRole('button', { name: `تعديل دور ${MOD}` })).toBeInTheDocument()
    expect(within(rowOf(MOD)).getByRole('button', { name: `سحب دور ${MOD}` })).toBeInTheDocument()
    expect(within(rowOf(OLD)).getByRole('button', { name: `إعادة منح دور ${OLD}` })).toBeInTheDocument()
    expect(within(rowOf(OLD)).queryByRole('button', { name: /سحب دور/ })).not.toBeInTheDocument()
  })

  it('shows the error state and retries', async () => {
    const { fake, user } = setup()
    fake.failTable('admin_roles', 'FORBIDDEN')
    expect(await screen.findByText('لا تملك صلاحية تنفيذ هذا الإجراء.')).toBeInTheDocument()
    fake.failTable('admin_roles', '')
    await user.click(screen.getByRole('button', { name: 'إعادة المحاولة' }))
    expect(await screen.findByText(MOD)).toBeInTheDocument()
  })

  it('validates the UUID before calling, then grants a moderator with exact args', async () => {
    const { fake, user } = setup()
    await screen.findByText(MOD)
    await user.click(screen.getByRole('button', { name: 'منح دور' }))
    const dialog = screen.getByRole('dialog', { name: 'منح دور' })
    expect(within(dialog).getByText(/Supabase/)).toBeInTheDocument()
    expect(within(dialog).getByText(/TOTP/)).toBeInTheDocument()

    const idInput = within(dialog).getByLabelText(/معرف حساب الموظف/)
    await user.type(idInput, 'not-a-uuid')
    await user.click(within(dialog).getByRole('button', { name: 'منح الدور' }))
    expect(within(dialog).getByText(/UUID صالحًا/)).toBeInTheDocument()
    expect(fake.rpcCalls('admin_grant_role')).toHaveLength(0)

    await user.clear(idInput)
    await user.type(idInput, ` ${NEW.toUpperCase()} `)
    await user.click(within(dialog).getByRole('button', { name: 'منح الدور' }))
    expect(within(dialog).getByText('اختر قدرة واحدة على الأقل للمشرف.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_grant_role')).toHaveLength(0)

    await user.click(within(dialog).getByRole('checkbox', { name: /reports\.handle/ }))
    await user.click(within(dialog).getByRole('checkbox', { name: /listings\.hide/ }))
    // قدرات المدير وحده لا تعرض للمشرف.
    expect(within(dialog).queryByRole('checkbox', { name: /staff\.manage/ })).not.toBeInTheDocument()
    await user.click(within(dialog).getByRole('button', { name: 'منح الدور' }))

    await waitFor(() => expect(fake.rpcCalls('admin_grant_role')).toHaveLength(1))
    expect(fake.rpcCalls('admin_grant_role')[0]).toEqual({
      p_user_id: NEW,
      p_role: 'MODERATOR',
      p_capabilities: ['listings.hide', 'reports.handle'],
    })
    expect(await screen.findByText(/حفظ دور مشرف للموظف/)).toBeInTheDocument()
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('grants ADMIN with empty capabilities (ignored by the server)', async () => {
    const { fake, user } = setup()
    await screen.findByText(MOD)
    await user.click(screen.getByRole('button', { name: 'منح دور' }))
    const dialog = screen.getByRole('dialog')
    await user.type(within(dialog).getByLabelText(/معرف حساب الموظف/), NEW)
    await user.selectOptions(within(dialog).getByRole('combobox', { name: /الدور/ }), 'ADMIN')
    expect(within(dialog).getByText(/يملك كل القدرات تلقائيًا/)).toBeInTheDocument()
    expect(within(dialog).queryByRole('checkbox')).not.toBeInTheDocument()
    await user.click(within(dialog).getByRole('button', { name: 'منح الدور' }))
    await waitFor(() => expect(fake.rpcCalls('admin_grant_role')).toEqual([{ p_user_id: NEW, p_role: 'ADMIN', p_capabilities: [] }]))
  })

  it('blocks granting to self on the client', async () => {
    const { fake, user } = setup()
    await screen.findByText(MOD)
    await user.click(screen.getByRole('button', { name: 'منح دور' }))
    const dialog = screen.getByRole('dialog')
    await user.type(within(dialog).getByLabelText(/معرف حساب الموظف/), ME)
    await user.click(within(dialog).getByRole('button', { name: 'منح الدور' }))
    expect(within(dialog).getByText('لا يمكنك تعديل دورك أو سحبه بنفسك.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_grant_role')).toHaveLength(0)
  })

  it('edits an existing member prefilled with its capabilities', async () => {
    const { fake, user } = setup()
    await screen.findByText(MOD)
    await user.click(screen.getByRole('button', { name: `تعديل دور ${MOD}` }))
    const dialog = screen.getByRole('dialog', { name: 'تعديل دور الموظف' })
    const idInput = within(dialog).getByLabelText(/معرف حساب الموظف/) as HTMLInputElement
    expect(idInput.value).toBe(MOD)
    expect(idInput.readOnly).toBe(true)
    expect(within(dialog).getByRole('checkbox', { name: /listings\.review/ })).toBeChecked()
    expect(within(dialog).getByRole('checkbox', { name: /reports\.handle/ })).toBeChecked()
    expect(within(dialog).getByRole('checkbox', { name: /listings\.hide/ })).not.toBeChecked()
    await user.click(within(dialog).getByRole('checkbox', { name: /listings\.review/ }))
    await user.click(within(dialog).getByRole('checkbox', { name: /ratings\.moderate/ }))
    await user.click(within(dialog).getByRole('button', { name: 'حفظ الدور' }))
    await waitFor(() =>
      expect(fake.rpcCalls('admin_grant_role')).toEqual([{ p_user_id: MOD, p_role: 'MODERATOR', p_capabilities: ['reports.handle', 'ratings.moderate'] }]),
    )
  })

  it('shows the LAST_ADMIN message from the server and keeps the dialog open', async () => {
    const { fake, user } = setup()
    fake.failRpc('admin_grant_role', 'LAST_ADMIN')
    await screen.findByText(MOD)
    await user.click(screen.getByRole('button', { name: `تعديل دور ${MOD}` }))
    const dialog = screen.getByRole('dialog')
    await user.click(within(dialog).getByRole('button', { name: 'حفظ الدور' }))
    expect(await within(dialog).findByText('لا يمكن سحب أو تخفيض دور آخر مدير فعال.')).toBeInTheDocument()
    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_grant_role')).toHaveLength(1)
  })

  it('shows CANNOT_MODIFY_SELF and maps VALIDATION_FAILED fields from the server', async () => {
    const { fake, user } = setup()
    fake.failRpc('admin_grant_role', 'CANNOT_MODIFY_SELF', {}, 1)
    await screen.findByText(MOD)
    await user.click(screen.getByRole('button', { name: 'منح دور' }))
    const dialog = screen.getByRole('dialog')
    await user.type(within(dialog).getByLabelText(/معرف حساب الموظف/), NEW)
    await user.click(within(dialog).getByRole('checkbox', { name: /reports\.handle/ }))
    await user.click(within(dialog).getByRole('button', { name: 'منح الدور' }))
    expect(await within(dialog).findByText('لا يمكنك تعديل دورك أو سحبه بنفسك.')).toBeInTheDocument()

    fake.failRpc('admin_grant_role', 'VALIDATION_FAILED', { fields: ['user_id'] }, 1)
    await user.click(within(dialog).getByRole('button', { name: 'منح الدور' }))
    expect(await within(dialog).findByText(/المعرف لا يطابق حساب موظف/)).toBeInTheDocument()
    expect(within(dialog).getByText('بعض القيم غير صالحة. راجع الحقول المحددة.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_grant_role')).toHaveLength(2)
  })

  it('revokes with a mandatory reason and sends exact args', async () => {
    const { fake, user } = setup()
    await screen.findByText(MOD)
    await user.click(screen.getByRole('button', { name: `سحب دور ${MOD}` }))
    const dialog = screen.getByRole('dialog', { name: 'سحب الدور' })
    expect(within(dialog).getByText(/الاستدعاء التالي لهذا الموظف/)).toBeInTheDocument()
    await user.click(within(dialog).getByRole('button', { name: 'سحب الدور' }))
    expect(within(dialog).getByText('هذا الحقل مطلوب.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_revoke_role')).toHaveLength(0)

    await user.type(within(dialog).getByLabelText(/سبب السحب/), '  انتهاء التكليف  ')
    await user.click(within(dialog).getByRole('button', { name: 'سحب الدور' }))
    await waitFor(() => expect(fake.rpcCalls('admin_revoke_role')).toEqual([{ p_user_id: MOD, p_reason: 'انتهاء التكليف' }]))
    expect(await screen.findByText(/سحب الدور\. يسري في الاستدعاء التالي/)).toBeInTheDocument()
  })

  it('shows LAST_ADMIN on revoke, and refetches on INVALID_STATE without retrying', async () => {
    const { fake, user } = setup()
    await screen.findByText(MOD)
    fake.failRpc('admin_revoke_role', 'LAST_ADMIN', {}, 1)
    await user.click(screen.getByRole('button', { name: `سحب دور ${MOD}` }))
    let dialog = screen.getByRole('dialog')
    await user.type(within(dialog).getByLabelText(/سبب السحب/), 'سبب')
    await user.click(within(dialog).getByRole('button', { name: 'سحب الدور' }))
    expect(await within(dialog).findByText('لا يمكن سحب أو تخفيض دور آخر مدير فعال.')).toBeInTheDocument()

    fake.failRpc('admin_revoke_role', 'INVALID_STATE', { reason: 'no_active_role' }, 1)
    const before = fake.calls.filter((c) => c.name === 'admin_roles').length
    dialog = screen.getByRole('dialog')
    await user.click(within(dialog).getByRole('button', { name: 'سحب الدور' }))
    expect(await within(dialog).findByText(/لا يسمح بهذا الإجراء في الحالة الحالية/)).toBeInTheDocument()
    await waitFor(() => expect(fake.calls.filter((c) => c.name === 'admin_roles').length).toBeGreaterThan(before))
    expect(fake.rpcCalls('admin_revoke_role')).toHaveLength(2)
  })

  it('hides grant/edit/revoke actions without staff.manage', async () => {
    setup({ whoami: moderator(['listings.review']) })
    await screen.findByText(MOD)
    expect(screen.queryByRole('button', { name: 'منح دور' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /تعديل دور|سحب دور|إعادة منح/ })).not.toBeInTheDocument()
  })

  it('shows the empty state', async () => {
    installFakeSupabase({ tables: { admin_roles: [] } })
    renderAdmin(<StaffPage />, { route: '/admin/staff' })
    expect(await screen.findByText('لا موظفين بأدوار بعد')).toBeInTheDocument()
  })
})
