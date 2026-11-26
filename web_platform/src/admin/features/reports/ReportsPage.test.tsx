import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ADMIN_WHOAMI, renderAdmin } from '@admin/test/render'
import { installFakeSupabase, type FakeSupabase } from '@admin/test/fakeSupabase'
import ReportsPage from './ReportsPage'
import { CLOSED_REPORT, COMMENT_REPORT, LISTING_REPORT, reportRow } from './testData'

function lastReportsFilters(fake: FakeSupabase) {
  const calls = fake.calls.filter((c) => c.kind === 'select' && c.name === 'reports')
  return calls[calls.length - 1]?.filters ?? []
}

const OPEN_MINE = reportRow({ id: 'b0000000-0000-4000-8000-000000000005', ref: 'R-1005', status: 'IN_REVIEW', assigned_to: ADMIN_WHOAMI.user_id, created_at: '2026-11-23T09:00:00+00:00' })

function setup(route = '/admin/reports', rows = [reportRow(), COMMENT_REPORT, LISTING_REPORT, CLOSED_REPORT, OPEN_MINE], failWith?: string) {
  const fake = installFakeSupabase({ tables: { reports: rows } })
  if (failWith) fake.failTable('reports', failWith)
  const r = renderAdmin(<ReportsPage />, { route, path: '/admin/reports', extraRoutes: [{ path: '/admin/reports/:reportId', element: <div data-testid="detail" /> }] })
  return { fake, ...r }
}

describe('ReportsPage', () => {
  it('shows loading then non-closed reports by default with labels', async () => {
    const { fake } = setup()
    expect(screen.getByText('جارٍ تحميل البلاغات…')).toBeInTheDocument()
    expect(await screen.findByText('R-1001')).toBeInTheDocument()
    expect(screen.getByText('R-1002')).toBeInTheDocument()
    expect(screen.queryByText('R-1004')).not.toBeInTheDocument()
    const filters = lastReportsFilters(fake)
    expect(filters).toContainEqual(['in', 'status', ['OPEN', 'IN_REVIEW']])
    expect(filters).toContainEqual(['order', 'created_at', false])
    expect(filters).toContainEqual(['range', 0, 24])
    const row = screen.getByText('R-1005').closest('tr')!
    expect(within(row).getByText('أنت')).toBeInTheDocument()
    expect(within(row).getByText('قيد المراجعة')).toBeInTheDocument()
    const commentRow = screen.getByText('R-1002').closest('tr')!
    expect(within(commentRow).getByText('رد عام')).toBeInTheDocument()
    expect(within(commentRow).getByText('إزعاج أو دعاية')).toBeInTheDocument()
    expect(within(commentRow).getByText('غير مسند')).toBeInTheDocument()
    expect(screen.getByText('عرض 1–4 من 4')).toBeInTheDocument()
  })

  it('applies status, target, reason and assigned-to-me filters', async () => {
    const { fake } = setup()
    await screen.findByText('R-1001')
    await userEvent.selectOptions(screen.getByLabelText('الحالة'), 'CLOSED')
    expect(await screen.findByText('R-1004')).toBeInTheDocument()
    expect(lastReportsFilters(fake)).toContainEqual(['eq', 'status', 'CLOSED'])

    await userEvent.selectOptions(screen.getByLabelText('الحالة'), 'ALL')
    await userEvent.selectOptions(screen.getByLabelText('نوع الهدف'), 'MESSAGE')
    await userEvent.selectOptions(screen.getByLabelText('سبب البلاغ'), 'ABUSE')
    await userEvent.click(screen.getByLabelText('المسندة إليّ'))
    await waitFor(() => {
      const f = lastReportsFilters(fake)
      expect(f).toContainEqual(['eq', 'target_type', 'MESSAGE'])
      expect(f).toContainEqual(['eq', 'reason', 'ABUSE'])
      expect(f).toContainEqual(['eq', 'assigned_to', ADMIN_WHOAMI.user_id])
      expect(f.some((x) => x[1] === 'status')).toBe(false)
    })
    expect(await screen.findByText('R-1004')).toBeInTheDocument()
    expect(screen.queryByText('R-1001')).not.toBeInTheDocument()
  })

  it('reads filters from URL params', async () => {
    const { fake } = setup('/admin/reports?status=OPEN&target=COMMENT&reason=SPAM')
    expect(await screen.findByText('R-1002')).toBeInTheDocument()
    const f = lastReportsFilters(fake)
    expect(f).toContainEqual(['eq', 'status', 'OPEN'])
    expect(f).toContainEqual(['eq', 'target_type', 'COMMENT'])
    expect(f).toContainEqual(['eq', 'reason', 'SPAM'])
    expect(screen.getByLabelText('نوع الهدف')).toHaveValue('COMMENT')
  })

  it('paginates with range', async () => {
    const rows = Array.from({ length: 30 }, (_, i) =>
      reportRow({ id: `b0000000-0000-4000-8000-0000000001${String(i).padStart(2, '0')}`, ref: `R-${2000 + i}`, created_at: new Date(Date.UTC(2026, 10, 1, i)).toISOString() }),
    )
    const { fake } = setup('/admin/reports', rows)
    expect(await screen.findByText('عرض 1–25 من 30')).toBeInTheDocument()
    expect(screen.getByText('R-2029')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'التالية' }))
    expect(await screen.findByText('عرض 26–30 من 30')).toBeInTheDocument()
    expect(lastReportsFilters(fake)).toContainEqual(['range', 25, 49])
    expect(screen.getByText('R-2000')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'التالية' })).toBeDisabled()
  })

  it('shows the empty state', async () => {
    setup('/admin/reports', [CLOSED_REPORT])
    expect(await screen.findByText('لا توجد بلاغات مطابقة')).toBeInTheDocument()
  })

  it('shows the error state with retry', async () => {
    const { fake } = setup('/admin/reports', [], 'FORBIDDEN')
    expect(await screen.findByText('لا تملك صلاحية تنفيذ هذا الإجراء.')).toBeInTheDocument()
    const before = fake.calls.filter((c) => c.name === 'reports').length
    await userEvent.click(screen.getByRole('button', { name: 'إعادة المحاولة' }))
    await waitFor(() => expect(fake.calls.filter((c) => c.name === 'reports').length).toBe(before + 1))
  })

  it('opens the detail page from a row', async () => {
    setup()
    await userEvent.click(await screen.findByText('R-1002'))
    expect(await screen.findByTestId('detail')).toBeInTheDocument()
  })
})
