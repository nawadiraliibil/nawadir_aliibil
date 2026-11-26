import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { installFakeSupabase, type FakeSupabase, type Row } from '@admin/test/fakeSupabase'
import { renderAdmin } from '@admin/test/render'
import RatingsPage from './RatingsPage'
import { PAGE_SIZE } from './api'
import { PROFILES, R1, REASONS, appealRow, decidedAppealRow, hiddenRow, ratingRow } from './testData'

function setup(tables: Record<string, Row[]> = {}, route = '/admin/ratings', before?: (fake: FakeSupabase) => void) {
  const fake = installFakeSupabase({
    tables: {
      rating_appeals: [appealRow(), decidedAppealRow()],
      seller_ratings: [ratingRow(), hiddenRow()],
      public_profiles: PROFILES,
      moderation_reasons: REASONS,
      ...tables,
    },
  })
  before?.(fake)
  const utils = renderAdmin(<RatingsPage />, {
    route,
    path: '/admin/ratings',
    extraRoutes: [{ path: '/admin/ratings/:ratingId', element: <div data-testid="detail-route" /> }],
  })
  return { fake, ...utils }
}

describe('RatingsPage', () => {
  it('defaults to the appeals tab with the OPEN filter and real ordering', async () => {
    const { fake } = setup()
    const tabs = screen.getByRole('tablist')
    expect(within(tabs).getByRole('tab', { name: 'الاعتراضات' })).toHaveAttribute('aria-selected', 'true')
    expect(within(tabs).getByRole('tab', { name: 'التقييمات' })).toHaveAttribute('aria-selected', 'false')
    expect(screen.getByRole('status')).toBeInTheDocument()

    expect(await screen.findByText('لم أتعامل مع هذا المقيّم أبدًا')).toBeInTheDocument()
    // الاعتراض المرفوض لا يظهر في المرشح الافتراضي.
    expect(screen.queryByText('اعتراض قديم')).not.toBeInTheDocument()
    expect(screen.getByLabelText('حالة الاعتراض')).toHaveValue('OPEN')

    const call = fake.calls.find((c) => c.kind === 'select' && c.name === 'rating_appeals')
    expect(call?.filters).toEqual([
      ['eq', 'status', 'OPEN'],
      ['order', 'created_at', false],
      ['order', 'id', false],
      ['range', 0, PAGE_SIZE - 1],
    ])
    // اسم المعلن من public_profiles، والدرجة من seller_ratings.
    expect(await screen.findByText('معلن تجريبي')).toBeInTheDocument()
    expect(await screen.findByRole('img', { name: '4 من 5' })).toBeInTheDocument()
    const names = fake.calls.find((c) => c.name === 'public_profiles')
    expect(names?.filters?.[0]?.[0]).toBe('in')
  })

  it('filters appeals by decided status and shows all statuses', async () => {
    const { fake } = setup()
    await screen.findByText('لم أتعامل مع هذا المقيّم أبدًا')
    await userEvent.selectOptions(screen.getByLabelText('حالة الاعتراض'), 'REJECTED')
    expect(await screen.findByText('اعتراض قديم')).toBeInTheDocument()
    expect(screen.queryByText('لم أتعامل مع هذا المقيّم أبدًا')).not.toBeInTheDocument()
    expect(within(screen.getByRole('table')).getByText('مرفوض (أبقي التقييم)')).toBeInTheDocument()

    await userEvent.selectOptions(screen.getByLabelText('حالة الاعتراض'), 'ALL')
    expect(await screen.findByText('لم أتعامل مع هذا المقيّم أبدًا')).toBeInTheDocument()
    expect(screen.getByText('اعتراض قديم')).toBeInTheDocument()
    const last = fake.calls.filter((c) => c.name === 'rating_appeals').at(-1)
    expect(last?.filters?.some((f) => f[0] === 'eq')).toBe(false)
  })

  it('opens the rating detail when an appeal row is clicked', async () => {
    setup()
    await userEvent.click(await screen.findByText('لم أتعامل مع هذا المقيّم أبدًا'))
    expect(await screen.findByTestId('detail-route')).toBeInTheDocument()
  })

  it('shows an empty state when no open appeals', async () => {
    setup({ rating_appeals: [decidedAppealRow()] })
    expect(await screen.findByText('لا اعتراضات مفتوحة')).toBeInTheDocument()
  })

  it('shows an error state with retry', async () => {
    setup({}, '/admin/ratings', (fake) => fake.failTable('rating_appeals', 'FORBIDDEN'))
    expect(await screen.findByRole('alert')).toBeInTheDocument()
    expect(screen.getByText('لا تملك صلاحية تنفيذ هذا الإجراء.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'إعادة المحاولة' })).toBeInTheDocument()
  })

  it('paginates with load more', async () => {
    const many = Array.from({ length: PAGE_SIZE + 3 }, (_, i) =>
      appealRow({
        id: `00000000-0000-4000-8000-${String(i).padStart(12, '0')}`,
        rating_id: R1,
        reason: `اعتراض ${i}`,
        created_at: new Date(Date.UTC(2026, 10, 1, 0, i)).toISOString(),
      }),
    )
    const { fake } = setup({ rating_appeals: many })
    expect(await screen.findByText('اعتراض 27')).toBeInTheDocument()
    expect(screen.queryByText('اعتراض 0')).not.toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'تحميل المزيد' }))
    expect(await screen.findByText('اعتراض 0')).toBeInTheDocument()
    const ranges = fake.calls.filter((c) => c.name === 'rating_appeals').map((c) => c.filters?.find((f) => f[0] === 'range'))
    expect(ranges).toContainEqual(['range', PAGE_SIZE, PAGE_SIZE * 2 - 1])
    await waitFor(() => expect(screen.queryByRole('button', { name: 'تحميل المزيد' })).not.toBeInTheDocument())
  })

  it('ratings tab lists ratings with status filter and hidden reason', async () => {
    const { fake } = setup()
    await userEvent.click(screen.getByRole('tab', { name: 'التقييمات' }))
    expect(screen.getByRole('tab', { name: 'التقييمات' })).toHaveAttribute('aria-selected', 'true')
    expect(await screen.findByText('تعامل محترم وسريع.')).toBeInTheDocument()
    expect(screen.getByText('تقييم مسيء')).toBeInTheDocument()
    expect(await screen.findByText('إساءة')).toBeInTheDocument()
    expect(screen.getByText('ألفاظ مسيئة')).toBeInTheDocument()
    expect(screen.getAllByText('مشتري تجريبي').length).toBeGreaterThan(0)

    await userEvent.selectOptions(screen.getByLabelText('حالة التقييم'), 'HIDDEN')
    await waitFor(() => expect(screen.queryByText('تعامل محترم وسريع.')).not.toBeInTheDocument())
    expect(screen.getByText('تقييم مسيء')).toBeInTheDocument()
    const last = fake.calls.filter((c) => c.name === 'seller_ratings').at(-1)
    expect(last?.filters).toContainEqual(['eq', 'status', 'HIDDEN'])
  })

  it('ratings tab row opens the detail', async () => {
    setup({}, '/admin/ratings?tab=ratings')
    await userEvent.click(await screen.findByText('تقييم مسيء'))
    expect(await screen.findByTestId('detail-route')).toBeInTheDocument()
  })

  it('falls back to a short id when the profile is not public', async () => {
    setup({ public_profiles: [] })
    expect(await screen.findByText('لم أتعامل مع هذا المقيّم أبدًا')).toBeInTheDocument()
    expect(await screen.findByText('ba24f799')).toBeInTheDocument()
  })

  it('moves between tabs with arrow keys', async () => {
    setup()
    const first = screen.getByRole('tab', { name: 'الاعتراضات' })
    first.focus()
    await userEvent.keyboard('{ArrowLeft}')
    expect(screen.getByRole('tab', { name: 'التقييمات' })).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByRole('tab', { name: 'التقييمات' })).toHaveFocus()
  })
})
