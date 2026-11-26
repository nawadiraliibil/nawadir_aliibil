import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ReasonDialog } from './ReasonDialog'
import { installFakeSupabase } from '../test/fakeSupabase'
import { renderAdmin } from '../test/render'

const REASONS = [
  { code: 'FRAUD', label_ar: 'اشتباه احتيال', applies_to: ['LISTING_HIDE', 'ACCOUNT_SUSPEND'], requires_note: false, sort_order: 80, is_active: true },
  { code: 'OTHER', label_ar: 'أخرى', applies_to: ['LISTING_HIDE', 'ACCOUNT_SUSPEND'], requires_note: true, sort_order: 1000, is_active: true },
  { code: 'SPAM', label_ar: 'رد مزعج', applies_to: ['COMMENT_HIDE'], requires_note: false, sort_order: 95, is_active: true },
  { code: 'OLD', label_ar: 'معطل', applies_to: ['LISTING_HIDE'], requires_note: false, sort_order: 5, is_active: false },
]

function setup(onSubmit = vi.fn().mockResolvedValue({})) {
  installFakeSupabase({ tables: { moderation_reasons: REASONS } })
  const onClose = vi.fn()
  renderAdmin(<ReasonDialog open action="LISTING_HIDE" title="إخفاء الإعلان" confirmLabel="إخفاء" onClose={onClose} onSubmit={onSubmit} />)
  return { onSubmit, onClose }
}

describe('ReasonDialog', () => {
  it('lists only active reasons for the action', async () => {
    setup()
    const select = await screen.findByLabelText(/السبب/)
    const options = Array.from((select as HTMLSelectElement).options).map((o) => o.value)
    expect(options).toEqual(['', 'FRAUD', 'OTHER'])
  })

  it('blocks submit without a reason', async () => {
    const { onSubmit } = setup()
    await screen.findByLabelText(/السبب/)
    await userEvent.click(screen.getByRole('button', { name: 'إخفاء' }))
    expect(await screen.findByText('اختر سببًا.')).toBeInTheDocument()
    expect(onSubmit).not.toHaveBeenCalled()
  })

  it('requires text for OTHER', async () => {
    const { onSubmit } = setup()
    await userEvent.selectOptions(await screen.findByLabelText(/السبب/), 'OTHER')
    await userEvent.click(screen.getByRole('button', { name: 'إخفاء' }))
    expect(await screen.findByText('اكتب توضيحًا لهذا السبب.')).toBeInTheDocument()
    expect(onSubmit).not.toHaveBeenCalled()
    await userEvent.type(screen.getByLabelText(/التوضيح/), 'سبب مكتوب')
    await userEvent.click(screen.getByRole('button', { name: 'إخفاء' }))
    await waitFor(() => expect(onSubmit).toHaveBeenCalledWith({ reason_code: 'OTHER', reason_text: 'سبب مكتوب' }))
  })

  it('sends undefined text when empty and closes on success', async () => {
    const { onSubmit, onClose } = setup()
    await userEvent.selectOptions(await screen.findByLabelText(/السبب/), 'FRAUD')
    await userEvent.click(screen.getByRole('button', { name: 'إخفاء' }))
    await waitFor(() => expect(onSubmit).toHaveBeenCalledWith({ reason_code: 'FRAUD', reason_text: undefined }))
    expect(onClose).toHaveBeenCalled()
  })

  it('stays open and shows the server error', async () => {
    const { onClose } = setup(vi.fn().mockRejectedValue({ message: 'INVALID_STATE', details: '{}', code: 'P0001' }))
    await userEvent.selectOptions(await screen.findByLabelText(/السبب/), 'FRAUD')
    await userEvent.click(screen.getByRole('button', { name: 'إخفاء' }))
    expect(await screen.findByText(/لا يسمح بهذا الإجراء في الحالة الحالية/)).toBeInTheDocument()
    expect(onClose).not.toHaveBeenCalled()
  })
})
