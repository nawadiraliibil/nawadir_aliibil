import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { Whoami } from '@admin/lib/capabilities'
import { installFakeSupabase, type FakeSupabase, type Row } from '@admin/test/fakeSupabase'
import { moderator, renderAdmin } from '@admin/test/render'
import RatingDetailPage from './RatingDetailPage'
import { APPEAL_OPEN, DECIDED_FIXTURE, PROFILES, R1, R2, R3, REASONS, REPLY_BODY, SELLER_ID, appealRow, decidedAppealRow, hiddenRow, ratingRow } from './testData'

interface SetupOpts {
  id?: string
  tables?: Record<string, Row[]>
  whoami?: Whoami | null
  before?: (fake: FakeSupabase) => void
}

function setup({ id = R1, tables = {}, whoami, before }: SetupOpts = {}) {
  const fake = installFakeSupabase({
    tables: {
      seller_ratings: [ratingRow({ edited_at: '2026-11-23T06:00:00+00:00' }), hiddenRow(), ratingRow({ id: R3, score: 5, body: 'ممتاز' })],
      seller_rating_history: [
        { id: 2, rating_id: R1, score: 3, body: 'صيغة ثانية', replaced_at: '2026-11-23T06:00:00+00:00' },
        { id: 1, rating_id: R1, score: 2, body: 'صيغة أولى', replaced_at: '2026-11-23T04:00:00+00:00' },
        { id: 3, rating_id: R2, score: 5, body: 'لتقييم آخر', replaced_at: '2026-11-23T04:00:00+00:00' },
      ],
      rating_replies: [{ rating_id: R1, seller_id: SELLER_ID, body: REPLY_BODY, edited_at: null, created_at: '2026-11-23T03:25:05.418472+00:00' }],
      rating_appeals: [appealRow(), decidedAppealRow()],
      public_profiles: PROFILES,
      moderation_reasons: REASONS,
      ...tables,
    },
    rpc: {
      admin_hide_rating: (a) => ({ rating_id: a.p_rating_id, status: 'HIDDEN' }),
      admin_unhide_rating: (a) => ({ rating_id: a.p_rating_id, status: 'VISIBLE' }),
      admin_decide_rating_appeal: (a) => ({ ...DECIDED_FIXTURE, appeal_id: a.p_appeal_id, status: a.p_decision }),
    },
  })
  before?.(fake)
  const utils = renderAdmin(<RatingDetailPage />, { route: `/admin/ratings/${id}`, path: '/admin/ratings/:ratingId', whoami })
  return { fake, ...utils }
}

async function openDecision() {
  await userEvent.click(await screen.findByRole('button', { name: 'قرار الاعتراض' }))
  return screen.getByRole('dialog', { name: 'قرار الاعتراض' })
}

describe('RatingDetailPage', () => {
  it('renders rating, history, reply and the open appeal', async () => {
    const { fake } = setup()
    expect(screen.getByRole('status')).toBeInTheDocument()
    expect(await screen.findByText('تعامل محترم وسريع.')).toBeInTheDocument()
    expect(screen.getByText('ظاهر')).toBeInTheDocument()
    expect(screen.getByRole('img', { name: '4 من 5' })).toBeInTheDocument()
    expect(await screen.findByText('مشتري تجريبي')).toBeInTheDocument()
    expect(screen.getByText('معلن تجريبي')).toBeInTheDocument()
    // الرد من public-ratings.json.
    expect(screen.getByText(REPLY_BODY)).toBeInTheDocument()
    // السجل بترتيب replaced_at تصاعديًا، ولا يخلط تقييمًا آخر.
    const history = screen.getByRole('list', { name: 'الصيغ السابقة' })
    const items = within(history).getAllByRole('listitem')
    expect(items).toHaveLength(2)
    expect(items[0]).toHaveTextContent('صيغة أولى')
    expect(items[1]).toHaveTextContent('صيغة ثانية')
    expect(screen.queryByText('لتقييم آخر')).not.toBeInTheDocument()
    // الاعتراض المفتوح.
    expect(screen.getByText('اعتراض مفتوح')).toBeInTheDocument()
    expect(screen.getByText('لم أتعامل مع هذا المقيّم أبدًا')).toBeInTheDocument()
    const historyCall = fake.calls.find((c) => c.name === 'seller_rating_history')
    expect(historyCall?.filters).toEqual([
      ['eq', 'rating_id', R1],
      ['order', 'replaced_at', true],
    ])
    expect(fake.calls.find((c) => c.name === 'rating_appeals')?.filters).toContainEqual(['eq', 'rating_id', R1])
  })

  it('shows decided appeal details', async () => {
    setup({ id: R3, tables: { rating_appeals: [decidedAppealRow()] } })
    expect(await screen.findByText('اعتراض قديم')).toBeInTheDocument()
    const appeals = screen.getByRole('list', { name: 'اعتراضات التقييم' })
    expect(within(appeals).getAllByText('مرفوض (أبقي التقييم)').length).toBeGreaterThan(0)
    expect(within(appeals).getByText('التقييم مبني على تعامل فعلي')).toBeInTheDocument()
    expect(within(appeals).getByText('تاريخ القرار')).toBeInTheDocument()
    expect(within(appeals).getByText('بواسطة')).toBeInTheDocument()
    expect(within(appeals).queryByRole('button', { name: 'قرار الاعتراض' })).not.toBeInTheDocument()
  })

  it('shows hidden info for a hidden rating', async () => {
    setup({ id: R2, tables: { rating_appeals: [] } })
    expect(await screen.findByText('تقييم مسيء')).toBeInTheDocument()
    expect(await screen.findByText('إساءة')).toBeInTheDocument()
    expect(screen.getByText('ألفاظ مسيئة')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'إعادة إظهار التقييم' })).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إخفاء التقييم' })).not.toBeInTheDocument()
    expect(screen.getByText('لا اعتراض على هذا التقييم')).toBeInTheDocument()
  })

  it('shows NOT_FOUND for a missing or malformed id', async () => {
    setup({ id: '7079a95b-fa35-4df3-9c96-000000000000' })
    expect(await screen.findByText('التقييم غير موجود')).toBeInTheDocument()
  })

  it('shows NOT_FOUND without querying for a non-uuid id', async () => {
    const { fake } = setup({ id: 'abc' })
    expect(await screen.findByText('التقييم غير موجود')).toBeInTheDocument()
    expect(fake.calls).toHaveLength(0)
  })

  it('shows an error state with retry', async () => {
    setup({ before: (f) => f.failTable('seller_ratings', 'MFA_REQUIRED') })
    expect(await screen.findByText(/يلزم إكمال التحقق بخطوتين/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'إعادة المحاولة' })).toBeInTheDocument()
  })

  it('hide requires a RATING_HIDE reason and sends exact args', async () => {
    const { fake } = setup()
    await userEvent.click(await screen.findByRole('button', { name: 'إخفاء التقييم' }))
    const dialog = screen.getByRole('dialog', { name: 'إخفاء التقييم' })
    const select = await within(dialog).findByLabelText(/السبب/)
    // أسباب RATING_HIDE فقط.
    expect(Array.from((select as HTMLSelectElement).options).map((o) => o.value)).toEqual(['', 'ABUSE', 'UNFAIR_RATING', 'OTHER'])
    await userEvent.click(within(dialog).getByRole('button', { name: 'إخفاء' }))
    expect(await within(dialog).findByText('اختر سببًا.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_hide_rating')).toHaveLength(0)

    await userEvent.selectOptions(select, 'OTHER')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إخفاء' }))
    expect(await within(dialog).findByText('اكتب توضيحًا لهذا السبب.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_hide_rating')).toHaveLength(0)

    await userEvent.type(within(dialog).getByLabelText(/التوضيح/), '  تقييم انتقامي  ')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إخفاء' }))
    await waitFor(() => expect(fake.rpcCalls('admin_hide_rating')).toHaveLength(1))
    expect(fake.rpcCalls('admin_hide_rating')[0]).toStrictEqual({ p_rating_id: R1, p_reason_code: 'OTHER', p_reason_text: 'تقييم انتقامي' })
    expect(await screen.findByText(/أُخفي التقييم/)).toBeInTheDocument()
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('hide shows the Arabic INVALID_STATE message, refetches and does not retry', async () => {
    const { fake } = setup({ before: (f) => f.failRpc('admin_hide_rating', 'INVALID_STATE', { status: 'HIDDEN' }) })
    await userEvent.click(await screen.findByRole('button', { name: 'إخفاء التقييم' }))
    const dialog = screen.getByRole('dialog', { name: 'إخفاء التقييم' })
    await userEvent.selectOptions(await within(dialog).findByLabelText(/السبب/), 'UNFAIR_RATING')
    const before = fake.calls.filter((c) => c.name === 'seller_ratings').length
    await userEvent.click(within(dialog).getByRole('button', { name: 'إخفاء' }))
    expect(await within(dialog).findByText(/لا يسمح بهذا الإجراء في الحالة الحالية/)).toBeInTheDocument()
    expect(fake.rpcCalls('admin_hide_rating')).toHaveLength(1)
    expect(fake.rpcCalls('admin_hide_rating')[0]).toEqual({ p_rating_id: R1, p_reason_code: 'UNFAIR_RATING', p_reason_text: undefined })
    await waitFor(() => expect(fake.calls.filter((c) => c.name === 'seller_ratings').length).toBeGreaterThan(before))
    expect(screen.queryByText(/أُخفي التقييم/)).not.toBeInTheDocument()
  })

  it('unhide sends the optional note', async () => {
    const { fake } = setup({ id: R2, tables: { rating_appeals: [] } })
    await userEvent.click(await screen.findByRole('button', { name: 'إعادة إظهار التقييم' }))
    const dialog = screen.getByRole('dialog', { name: 'إعادة إظهار التقييم' })
    await userEvent.type(within(dialog).getByLabelText(/ملاحظة داخلية/), 'أخفي خطأ')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إعادة الإظهار' }))
    await waitFor(() => expect(fake.rpcCalls('admin_unhide_rating')).toEqual([{ p_rating_id: R2, p_note: 'أخفي خطأ' }]))
    expect(await screen.findByText('أُعيد إظهار التقييم.')).toBeInTheDocument()
  })

  it('accepting an appeal requires a reason and sends exact args', async () => {
    const { fake } = setup()
    const dialog = await openDecision()
    await userEvent.click(within(dialog).getByRole('button', { name: 'تأكيد القرار' }))
    expect(await within(dialog).findByText('اختر القرار.')).toBeInTheDocument()

    await userEvent.click(within(dialog).getByRole('radio', { name: 'قبول: إخفاء التقييم' }))
    const select = await within(dialog).findByLabelText(/سبب الإخفاء/)
    await userEvent.click(within(dialog).getByRole('button', { name: 'تأكيد القرار' }))
    expect(await within(dialog).findByText('اختر سبب الإخفاء.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_decide_rating_appeal')).toHaveLength(0)

    await userEvent.selectOptions(select, 'OTHER')
    await userEvent.click(within(dialog).getByRole('button', { name: 'تأكيد القرار' }))
    expect(await within(dialog).findByText('اكتب توضيحًا لهذا السبب.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_decide_rating_appeal')).toHaveLength(0)

    await userEvent.type(within(dialog).getByLabelText(/التوضيح/), 'لا تعامل فعلي')
    await userEvent.click(within(dialog).getByRole('button', { name: 'تأكيد القرار' }))
    await waitFor(() => expect(fake.rpcCalls('admin_decide_rating_appeal')).toHaveLength(1))
    expect(fake.rpcCalls('admin_decide_rating_appeal')[0]).toStrictEqual({
      p_appeal_id: APPEAL_OPEN,
      p_decision: 'ACCEPTED',
      p_reason_code: 'OTHER',
      p_note: 'لا تعامل فعلي',
    })
    expect(await screen.findByText('قُبل الاعتراض والتقييم مخفي الآن.')).toBeInTheDocument()
  })

  it('rejecting an appeal needs no reason and sends no reason code', async () => {
    const { fake } = setup()
    const dialog = await openDecision()
    await userEvent.click(within(dialog).getByRole('radio', { name: 'رفض: إبقاء التقييم' }))
    expect(within(dialog).queryByLabelText(/سبب الإخفاء/)).not.toBeInTheDocument()
    await userEvent.click(within(dialog).getByRole('button', { name: 'تأكيد القرار' }))
    await waitFor(() => expect(fake.rpcCalls('admin_decide_rating_appeal')).toHaveLength(1))
    expect(fake.rpcCalls('admin_decide_rating_appeal')[0]).toEqual({ p_appeal_id: APPEAL_OPEN, p_decision: 'REJECTED' })
    expect(fake.rpcCalls('admin_decide_rating_appeal')[0]?.p_reason_code).toBeUndefined()
    expect(await screen.findByText('رُفض الاعتراض وبقي التقييم ظاهرًا.')).toBeInTheDocument()
  })

  it('rejecting with a note sends p_note', async () => {
    const { fake } = setup()
    const dialog = await openDecision()
    await userEvent.click(within(dialog).getByRole('radio', { name: 'رفض: إبقاء التقييم' }))
    await userEvent.type(within(dialog).getByLabelText(/ملاحظة القرار/), 'تعامل ثابت')
    await userEvent.click(within(dialog).getByRole('button', { name: 'تأكيد القرار' }))
    await waitFor(() =>
      expect(fake.rpcCalls('admin_decide_rating_appeal')).toEqual([{ p_appeal_id: APPEAL_OPEN, p_decision: 'REJECTED', p_reason_code: undefined, p_note: 'تعامل ثابت' }]),
    )
  })

  it('decision shows INVALID_STATE for an already decided appeal and stays open', async () => {
    const { fake } = setup({ before: (f) => f.failRpc('admin_decide_rating_appeal', 'INVALID_STATE', { status: 'REJECTED' }) })
    const dialog = await openDecision()
    await userEvent.click(within(dialog).getByRole('radio', { name: 'رفض: إبقاء التقييم' }))
    await userEvent.click(within(dialog).getByRole('button', { name: 'تأكيد القرار' }))
    expect(await within(dialog).findByText(/لا يسمح بهذا الإجراء في الحالة الحالية/)).toBeInTheDocument()
    expect(fake.rpcCalls('admin_decide_rating_appeal')).toHaveLength(1)
    expect(screen.getByRole('dialog', { name: 'قرار الاعتراض' })).toBeInTheDocument()
  })

  it('decision maps REASON_REQUIRED from the server', async () => {
    setup({ before: (f) => f.failRpc('admin_decide_rating_appeal', 'REASON_REQUIRED', { field: 'reason_text' }) })
    const dialog = await openDecision()
    await userEvent.click(within(dialog).getByRole('radio', { name: 'قبول: إخفاء التقييم' }))
    await userEvent.selectOptions(await within(dialog).findByLabelText(/سبب الإخفاء/), 'UNFAIR_RATING')
    await userEvent.click(within(dialog).getByRole('button', { name: 'تأكيد القرار' }))
    expect(await within(dialog).findByText(/السبب إلزامي/)).toBeInTheDocument()
    expect(within(dialog).getByText('التوضيح مطلوب أو غير صالح.')).toBeInTheDocument()
  })

  it('FORBIDDEN on hide shows the Arabic message', async () => {
    setup({ before: (f) => f.failRpc('admin_hide_rating', 'FORBIDDEN') })
    await userEvent.click(await screen.findByRole('button', { name: 'إخفاء التقييم' }))
    const dialog = screen.getByRole('dialog', { name: 'إخفاء التقييم' })
    await userEvent.selectOptions(await within(dialog).findByLabelText(/السبب/), 'ABUSE')
    await userEvent.click(within(dialog).getByRole('button', { name: 'إخفاء' }))
    expect(await within(dialog).findByText('لا تملك صلاحية تنفيذ هذا الإجراء.')).toBeInTheDocument()
  })

  it('hides all action buttons for a moderator without ratings.moderate', async () => {
    setup({ whoami: moderator(['listings.review', 'listings.hide']) })
    expect(await screen.findByText('تعامل محترم وسريع.')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إخفاء التقييم' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إعادة إظهار التقييم' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'قرار الاعتراض' })).not.toBeInTheDocument()
  })

  it('shows action buttons for a moderator with ratings.moderate, without account links', async () => {
    setup({ whoami: moderator(['ratings.moderate']) })
    expect(await screen.findByRole('button', { name: 'إخفاء التقييم' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'قرار الاعتراض' })).toBeInTheDocument()
    expect(await screen.findByText('مشتري تجريبي')).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'مشتري تجريبي' })).not.toBeInTheDocument()
  })
})
