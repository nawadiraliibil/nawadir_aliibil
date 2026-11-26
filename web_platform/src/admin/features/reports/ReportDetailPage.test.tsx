import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import assignedFx from '@contracts/fixtures/admin-report-assigned.json'
import closedFx from '@contracts/fixtures/admin-report-closed.json'
import { ADMIN_WHOAMI, moderator, renderAdmin } from '@admin/test/render'
import { installFakeSupabase, type FakeSupabase } from '@admin/test/fakeSupabase'
import type { Whoami } from '@admin/lib/capabilities'
import ReportDetailPage from './ReportDetailPage'
import {
  CLOSED_REPORT,
  COMMENT_EVIDENCE,
  COMMENT_ID,
  COMMENT_REASONS,
  COMMENT_REPORT,
  LISTING_ID,
  LISTING_REPORT,
  MESSAGE_EVIDENCE,
  OTHER_STAFF,
  reportRow,
} from './testData'
import type { ReportRow } from './types'

const OPEN_REPORT = reportRow()

function setup(report: ReportRow = OPEN_REPORT, opts: { whoami?: Whoami; rows?: ReportRow[]; failTable?: string } = {}) {
  const fake = installFakeSupabase({
    tables: { reports: (opts.rows ?? [report]).map((r) => ({ ...r })), moderation_reasons: COMMENT_REASONS },
    rpc: {
      admin_assign_report: (args) => {
        const row = fake.tables.reports!.find((r) => r.id === args.p_report_id)!
        row.status = 'IN_REVIEW'
        row.assigned_to = (args.p_assignee as string | undefined) ?? ADMIN_WHOAMI.user_id
        return { ...assignedFx, report_id: args.p_report_id, assigned_to: row.assigned_to }
      },
      admin_set_report_status: (args) => {
        const row = fake.tables.reports!.find((r) => r.id === args.p_report_id)!
        row.status = args.p_status
        return { report_id: args.p_report_id, status: args.p_status }
      },
      admin_close_report: (args) => {
        const row = fake.tables.reports!.find((r) => r.id === args.p_report_id)!
        Object.assign(row, { status: 'CLOSED', close_reason: args.p_close_reason, closed_by: ADMIN_WHOAMI.user_id, closed_at: '2026-11-24T08:00:00+00:00', response_text: args.p_response_text ?? null })
        return { ...closedFx, report_id: args.p_report_id, close_reason: args.p_close_reason }
      },
      admin_get_report_evidence: (args) => (args.p_report_id === COMMENT_REPORT.id ? COMMENT_EVIDENCE : MESSAGE_EVIDENCE),
      admin_hide_comment: (args) => ({ comment_id: args.p_comment_id, state: 'HIDDEN' }),
      admin_unhide_comment: (args) => ({ comment_id: args.p_comment_id, state: 'VISIBLE' }),
    },
  })
  if (opts.failTable) fake.failTable('reports', opts.failTable)
  const r = renderAdmin(<ReportDetailPage />, { route: `/admin/reports/${report.id}`, path: '/admin/reports/:reportId', whoami: opts.whoami })
  return { fake, ...r }
}

function reportSelects(fake: FakeSupabase) {
  return fake.calls.filter((c) => c.kind === 'select' && c.name === 'reports').length
}

const dialog = () => screen.getByRole('dialog')

describe('ReportDetailPage — details', () => {
  it('loads the report and shows its fields and links', async () => {
    const { fake } = setup(LISTING_REPORT)
    expect(screen.getByText('جارٍ تحميل البلاغ…')).toBeInTheDocument()
    expect(await screen.findByRole('heading', { name: 'بلاغ R-1003' })).toBeInTheDocument()
    expect(fake.calls.find((c) => c.name === 'reports')?.filters).toContainEqual(['eq', 'id', LISTING_REPORT.id])
    expect(screen.getByText('رسالة مسيئة بعد الاتفاق.')).toBeInTheDocument()
    expect(screen.getByText('احتيال')).toBeInTheDocument()
    const listingLinks = screen.getAllByRole('link', { name: LISTING_ID.slice(0, 8) })
    expect(listingLinks[0]).toHaveAttribute('href', `/admin/listings/${LISTING_ID}`)
    expect(screen.getByRole('link', { name: LISTING_REPORT.reporter_id.slice(0, 8) })).toHaveAttribute('href', `/admin/accounts/${LISTING_REPORT.reporter_id}`)
    // لا دليل للإعلان.
    expect(screen.queryByRole('button', { name: 'عرض الدليل' })).not.toBeInTheDocument()
  })

  it('links an ACCOUNT target to the account page and hides links without capabilities', async () => {
    const account = reportRow({ target_type: 'ACCOUNT', target_id: OPEN_REPORT.target_user_id, listing_id: null })
    setup(account, { whoami: moderator(['reports.handle']) })
    await screen.findByRole('heading', { name: 'بلاغ R-1001' })
    expect(screen.queryByRole('link', { name: OPEN_REPORT.target_user_id.slice(0, 8) })).not.toBeInTheDocument()
    expect(screen.getAllByText(OPEN_REPORT.target_user_id.slice(0, 8)).length).toBeGreaterThan(0)
  })

  it('shows NOT_FOUND for a missing report', async () => {
    setup(OPEN_REPORT, { rows: [] })
    expect(await screen.findByText('البلاغ غير موجود')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'العودة إلى البلاغات' })).toHaveAttribute('href', '/admin/reports')
  })

  it('shows the error state with retry', async () => {
    setup(OPEN_REPORT, { failTable: 'INTERNAL_ERROR' })
    expect(await screen.findByText('حدث خطأ في الخادم. أعد المحاولة لاحقًا.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'إعادة المحاولة' })).toBeInTheDocument()
  })

  it('closed report shows the decision and no actions', async () => {
    setup(CLOSED_REPORT)
    expect(await screen.findByText('قرار الإغلاق')).toBeInTheDocument()
    expect(screen.getByText('لا مخالفة')).toBeInTheDocument()
    expect(screen.getByText('راجعنا البلاغ ولم نجد مخالفة.')).toBeInTheDocument()
    expect(screen.getByText('محادثة عادية.')).toBeInTheDocument()
    expect(screen.getByText('البلاغ مغلق ولا يقبل إسنادًا أو تغيير حالة.')).toBeInTheDocument()
    for (const name of ['إسناد إليّ', 'إسناد إلى موظف آخر', 'إغلاق البلاغ', 'إعادة فتح البلاغ', 'تحويل إلى قيد المراجعة']) {
      expect(screen.queryByRole('button', { name })).not.toBeInTheDocument()
    }
  })
})

describe('ReportDetailPage — handling', () => {
  it('assigns to self with exact args and shows the confirmed state', async () => {
    const { fake } = setup()
    await userEvent.click(await screen.findByRole('button', { name: 'إسناد إليّ' }))
    expect(await screen.findByText('أسند البلاغ إليك وصار قيد المراجعة.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_assign_report')).toEqual([{ p_report_id: OPEN_REPORT.id }])
    expect(await screen.findByText('البلاغ مسند إلى: أنت.')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إسناد إليّ' })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'إعادة فتح البلاغ' })).toBeInTheDocument()
  })

  it('assign INVALID_STATE shows the Arabic message and refetches without retrying', async () => {
    const { fake } = setup()
    fake.failRpc('admin_assign_report', 'INVALID_STATE', { status: 'CLOSED' })
    await userEvent.click(await screen.findByRole('button', { name: 'إسناد إليّ' }))
    expect(await screen.findByText(/لا يسمح بهذا الإجراء في الحالة الحالية/)).toBeInTheDocument()
    await waitFor(() => expect(reportSelects(fake)).toBe(2))
    expect(fake.rpcCalls('admin_assign_report')).toHaveLength(1)
  })

  it('assigns to another staff member after validating the UUID', async () => {
    const { fake } = setup()
    await userEvent.click(await screen.findByRole('button', { name: 'إسناد إلى موظف آخر' }))
    const input = within(dialog()).getByLabelText(/معرف الموظف/)
    await userEvent.type(input, 'not-a-uuid')
    await userEvent.click(within(dialog()).getByRole('button', { name: 'إسناد' }))
    expect(await within(dialog()).findByText('المعرف غير صالح؛ الصيغة المتوقعة UUID.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_assign_report')).toHaveLength(0)

    fake.failRpc('admin_assign_report', 'VALIDATION_FAILED', { fields: ['p_assignee'] }, 1)
    await userEvent.clear(input)
    await userEvent.type(input, OTHER_STAFF)
    await userEvent.click(within(dialog()).getByRole('button', { name: 'إسناد' }))
    expect(await within(dialog()).findByText('ليس موظفًا فعالًا بقدرة إدارة البلاغات.')).toBeInTheDocument()

    await userEvent.click(within(dialog()).getByRole('button', { name: 'إسناد' }))
    await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
    expect(fake.rpcCalls('admin_assign_report')).toEqual([
      { p_report_id: OPEN_REPORT.id, p_assignee: OTHER_STAFF },
      { p_report_id: OPEN_REPORT.id, p_assignee: OTHER_STAFF },
    ])
    expect(await screen.findByText('أسند البلاغ وصار قيد المراجعة.')).toBeInTheDocument()
  })

  it('changes status with a note', async () => {
    const { fake } = setup()
    await userEvent.click(await screen.findByRole('button', { name: 'تحويل إلى قيد المراجعة' }))
    await userEvent.type(within(dialog()).getByLabelText(/ملاحظة داخلية/), ' تحقق أولي ')
    await userEvent.click(within(dialog()).getByRole('button', { name: 'تحويل' }))
    expect(await screen.findByText('صار البلاغ قيد المراجعة.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_set_report_status')).toEqual([{ p_report_id: OPEN_REPORT.id, p_status: 'IN_REVIEW', p_note: 'تحقق أولي' }])
  })

  it('reopens an IN_REVIEW report without a note', async () => {
    const { fake } = setup(reportRow({ status: 'IN_REVIEW', assigned_to: OTHER_STAFF }))
    await userEvent.click(await screen.findByRole('button', { name: 'إعادة فتح البلاغ' }))
    await userEvent.click(within(dialog()).getByRole('button', { name: 'إعادة الفتح' }))
    await waitFor(() => expect(fake.rpcCalls('admin_set_report_status')).toHaveLength(1))
    const [args] = fake.rpcCalls('admin_set_report_status')
    expect(args).toEqual({ p_report_id: OPEN_REPORT.id, p_status: 'OPEN', p_note: undefined })
    expect(await screen.findByText('أعيد فتح البلاغ.')).toBeInTheDocument()
  })

  it('blocks closing without a reason, then sends exact args', async () => {
    const { fake } = setup()
    await userEvent.click(await screen.findByRole('button', { name: 'إغلاق البلاغ' }))
    await userEvent.click(within(dialog()).getByRole('button', { name: 'إغلاق البلاغ' }))
    expect(await within(dialog()).findByText('اختر سبب الإغلاق.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_close_report')).toHaveLength(0)

    await userEvent.selectOptions(within(dialog()).getByLabelText(/سبب الإغلاق/), 'NO_VIOLATION')
    await userEvent.type(within(dialog()).getByLabelText(/الرد على المبلغ/), 'لم نجد مخالفة.')
    await userEvent.type(within(dialog()).getByLabelText(/ملاحظة داخلية/), 'محادثة عادية')
    await userEvent.click(within(dialog()).getByRole('button', { name: 'إغلاق البلاغ' }))
    expect(await screen.findByText('أغلق البلاغ وأُشعر المبلغ.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_close_report')).toEqual([
      { p_report_id: OPEN_REPORT.id, p_close_reason: 'NO_VIOLATION', p_response_text: 'لم نجد مخالفة.', p_internal_note: 'محادثة عادية' },
    ])
    expect(await screen.findByText('قرار الإغلاق')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إغلاق البلاغ' })).not.toBeInTheDocument()
  })

  it('sends undefined for empty optional close fields', async () => {
    const { fake } = setup()
    await userEvent.click(await screen.findByRole('button', { name: 'إغلاق البلاغ' }))
    await userEvent.selectOptions(within(dialog()).getByLabelText(/سبب الإغلاق/), 'DUPLICATE')
    await userEvent.type(within(dialog()).getByLabelText(/الرد على المبلغ/), '   ')
    await userEvent.click(within(dialog()).getByRole('button', { name: 'إغلاق البلاغ' }))
    await waitFor(() => expect(fake.rpcCalls('admin_close_report')).toHaveLength(1))
    expect(fake.rpcCalls('admin_close_report')[0]).toEqual({ p_report_id: OPEN_REPORT.id, p_close_reason: 'DUPLICATE', p_response_text: undefined, p_internal_note: undefined })
  })

  it('close REASON_REQUIRED from the server keeps the dialog open with the Arabic message', async () => {
    const { fake } = setup()
    fake.failRpc('admin_close_report', 'REASON_REQUIRED', { field: 'close_reason' })
    await userEvent.click(await screen.findByRole('button', { name: 'إغلاق البلاغ' }))
    await userEvent.selectOptions(within(dialog()).getByLabelText(/سبب الإغلاق/), 'INVALID')
    await userEvent.click(within(dialog()).getByRole('button', { name: 'إغلاق البلاغ' }))
    expect(await within(dialog()).findByText(/السبب إلزامي/)).toBeInTheDocument()
    expect(within(dialog()).getByText('سبب الإغلاق مطلوب أو غير مقبول.')).toBeInTheDocument()
    expect(screen.queryByText('أغلق البلاغ وأُشعر المبلغ.')).not.toBeInTheDocument()
  })

  it('close INVALID_STATE shows the message and refetches', async () => {
    const { fake } = setup()
    fake.failRpc('admin_close_report', 'INVALID_STATE', { status: 'CLOSED' })
    await userEvent.click(await screen.findByRole('button', { name: 'إغلاق البلاغ' }))
    await userEvent.selectOptions(within(dialog()).getByLabelText(/سبب الإغلاق/), 'INVALID')
    await userEvent.click(within(dialog()).getByRole('button', { name: 'إغلاق البلاغ' }))
    expect(await within(dialog()).findByText(/لا يسمح بهذا الإجراء في الحالة الحالية/)).toBeInTheDocument()
    await waitFor(() => expect(reportSelects(fake)).toBe(2))
    expect(fake.rpcCalls('admin_close_report')).toHaveLength(1)
  })

  it('hides report actions from a moderator without reports.handle', async () => {
    setup(OPEN_REPORT, { whoami: moderator(['evidence.read']) })
    await screen.findByRole('heading', { name: 'بلاغ R-1001' })
    expect(screen.queryByRole('button', { name: 'إسناد إليّ' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إغلاق البلاغ' })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'عرض الدليل' })).toBeInTheDocument()
  })
})

describe('ReportDetailPage — evidence', () => {
  it('does not request evidence until clicked, then renders the fixture', async () => {
    const { fake } = setup()
    await screen.findByRole('heading', { name: 'بلاغ R-1001' })
    expect(screen.getByText(/كل اطلاع يسجل باسمك/)).toBeInTheDocument()
    expect(fake.rpcCalls('admin_get_report_evidence')).toHaveLength(0)
    await userEvent.click(screen.getByRole('button', { name: 'عرض الدليل' }))
    expect(await screen.findByText(MESSAGE_EVIDENCE.items[1]!.body)).toBeInTheDocument()
    expect(screen.getByText(MESSAGE_EVIDENCE.items[0]!.body)).toBeInTheDocument()
    expect(fake.rpcCalls('admin_get_report_evidence')).toEqual([{ p_report_id: OPEN_REPORT.id }])
    const reported = screen.getByText(MESSAGE_EVIDENCE.items[1]!.body).closest('li')!
    expect(within(reported).getByText('المبلغ عنه')).toBeInTheDocument()
    expect(within(reported).getByText(/صاحب المحتوى المبلغ عنه/)).toBeInTheDocument()
    expect(within(screen.getByText(MESSAGE_EVIDENCE.items[0]!.body).closest('li')!).getByText(/مقدم البلاغ/)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'إخفاء الدليل' }))
    expect(screen.queryByText(MESSAGE_EVIDENCE.items[1]!.body)).not.toBeInTheDocument()
  })

  it('has no evidence button without evidence.read', async () => {
    const { fake } = setup(OPEN_REPORT, { whoami: moderator(['reports.handle']) })
    await screen.findByRole('heading', { name: 'بلاغ R-1001' })
    expect(screen.queryByRole('button', { name: 'عرض الدليل' })).not.toBeInTheDocument()
    expect(screen.getByText(/يتطلب قدرة «الاطلاع على أدلة البلاغات»/)).toBeInTheDocument()
    expect(fake.rpcCalls('admin_get_report_evidence')).toHaveLength(0)
  })

  it('shows the Arabic message when evidence access is refused', async () => {
    const { fake } = setup()
    fake.failRpc('admin_get_report_evidence', 'FORBIDDEN', {}, 1)
    await userEvent.click(await screen.findByRole('button', { name: 'عرض الدليل' }))
    expect(await screen.findByText('لا تملك صلاحية تنفيذ هذا الإجراء.')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'إعادة المحاولة' }))
    expect(await screen.findByText(MESSAGE_EVIDENCE.items[1]!.body)).toBeInTheDocument()
    expect(fake.rpcCalls('admin_get_report_evidence')).toHaveLength(2)
  })

  it('renders comment evidence', async () => {
    setup(COMMENT_REPORT)
    await userEvent.click(await screen.findByRole('button', { name: 'عرض الدليل' }))
    expect(await screen.findByText('رد دعائي مكرر')).toBeInTheDocument()
    expect(screen.getByText(/الكاتب:/)).toBeInTheDocument()
  })
})

describe('ReportDetailPage — comment moderation', () => {
  it('hide requires a reason and sends exact args', async () => {
    const { fake } = setup(COMMENT_REPORT)
    await userEvent.click(await screen.findByRole('button', { name: 'إخفاء الرد' }))
    await within(dialog()).findByLabelText(/السبب/)
    await userEvent.click(within(dialog()).getByRole('button', { name: 'إخفاء الرد' }))
    expect(await within(dialog()).findByText('اختر سببًا.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_hide_comment')).toHaveLength(0)

    await userEvent.selectOptions(within(dialog()).getByLabelText(/السبب/), 'OTHER')
    await userEvent.click(within(dialog()).getByRole('button', { name: 'إخفاء الرد' }))
    expect(await within(dialog()).findByText('اكتب توضيحًا لهذا السبب.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_hide_comment')).toHaveLength(0)

    await userEvent.selectOptions(within(dialog()).getByLabelText(/السبب/), 'SPAM')
    await userEvent.click(within(dialog()).getByRole('button', { name: 'إخفاء الرد' }))
    expect(await screen.findByText('أُخفي الرد.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_hide_comment')).toEqual([{ p_comment_id: COMMENT_ID, p_reason_code: 'SPAM', p_reason_text: undefined }])
    expect(screen.getByText('مخفي إداريًا')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إخفاء الرد' })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'إعادة إظهار الرد' })).toBeInTheDocument()
  })

  it('hide INVALID_STATE shows the message and learns the hidden state', async () => {
    const { fake } = setup(COMMENT_REPORT)
    fake.failRpc('admin_hide_comment', 'INVALID_STATE', { status: 'HIDDEN' })
    await userEvent.click(await screen.findByRole('button', { name: 'إخفاء الرد' }))
    await userEvent.selectOptions(await within(dialog()).findByLabelText(/السبب/), 'SPAM')
    await userEvent.click(within(dialog()).getByRole('button', { name: 'إخفاء الرد' }))
    expect(await within(dialog()).findByText(/لا يسمح بهذا الإجراء في الحالة الحالية/)).toBeInTheDocument()
    expect(screen.getByText('مخفي إداريًا')).toBeInTheDocument()
  })

  it('unhide sends the note', async () => {
    const { fake } = setup(COMMENT_REPORT)
    await userEvent.click(await screen.findByRole('button', { name: 'إعادة إظهار الرد' }))
    await userEvent.type(within(dialog()).getByLabelText(/ملاحظة داخلية/), 'أخفي بالخطأ')
    await userEvent.click(within(dialog()).getByRole('button', { name: 'إعادة الإظهار' }))
    expect(await screen.findByText('أعيد إظهار الرد.')).toBeInTheDocument()
    expect(fake.rpcCalls('admin_unhide_comment')).toEqual([{ p_comment_id: COMMENT_ID, p_note: 'أخفي بالخطأ' }])
    expect(screen.getByText('ظاهر')).toBeInTheDocument()
  })

  it('unhide INVALID_STATE on a visible comment shows the message', async () => {
    const { fake } = setup(COMMENT_REPORT)
    fake.failRpc('admin_unhide_comment', 'INVALID_STATE', { status: 'VISIBLE' })
    await userEvent.click(await screen.findByRole('button', { name: 'إعادة إظهار الرد' }))
    await userEvent.click(within(dialog()).getByRole('button', { name: 'إعادة الإظهار' }))
    expect(await within(dialog()).findByText(/لا يسمح بهذا الإجراء في الحالة الحالية/)).toBeInTheDocument()
    expect(screen.queryByText('أعيد إظهار الرد.')).not.toBeInTheDocument()
  })

  it('hides comment moderation without comments.moderate', async () => {
    setup(COMMENT_REPORT, { whoami: moderator(['reports.handle']) })
    await screen.findByRole('heading', { name: 'بلاغ R-1002' })
    expect(screen.queryByRole('button', { name: 'إخفاء الرد' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إعادة إظهار الرد' })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'إسناد إليّ' })).toBeInTheDocument()
  })

  it('keeps comment moderation on a closed COMMENT report but no report actions', async () => {
    setup({ ...COMMENT_REPORT, status: 'CLOSED', close_reason: 'ACTION_TAKEN', closed_by: ADMIN_WHOAMI.user_id, closed_at: '2026-11-24T08:00:00+00:00' })
    expect(await screen.findByText('قرار الإغلاق')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'إغلاق البلاغ' })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'إعادة إظهار الرد' })).toBeInTheDocument()
  })

  it('shows no comment moderation for non-comment targets', async () => {
    setup()
    await screen.findByRole('heading', { name: 'بلاغ R-1001' })
    expect(screen.queryByRole('button', { name: 'إخفاء الرد' })).not.toBeInTheDocument()
  })
})
