import { useEffect, useState } from 'react'
import { errorMessage, toApiError, type ApiError } from '@admin/lib/errors'
import { REPORT_CLOSE_REASON_LABELS } from '@admin/lib/labels'
import { Alert, Button, Dialog, SelectField, TextAreaField } from '@admin/ui'
import type { CloseReportInput } from './api'
import type { ReportCloseReason } from './types'

export const RESPONSE_MAX = 1000
export const INTERNAL_NOTE_MAX = 2000

const CLOSE_REASONS = Object.keys(REPORT_CLOSE_REASON_LABELS) as ReportCloseReason[]

export interface CloseReportDialogProps {
  open: boolean
  onClose: () => void
  /** يرمي عند فشل الخادم؛ يبقى الحوار مفتوحًا ويعرض الخطأ. */
  onSubmit: (input: CloseReportInput) => Promise<unknown>
}

/**
 * إغلاق البلاغ: سبب الإغلاق إلزامي، والرد يرسل للمبلغ في إشعار الإغلاق،
 * والملاحظة الداخلية للموظفين فقط. لا إرسال دون سبب ولا إرسال مكرر أثناء الانتظار.
 */
export function CloseReportDialog({ open, onClose, onSubmit }: CloseReportDialogProps) {
  const [reason, setReason] = useState('')
  const [response, setResponse] = useState('')
  const [note, setNote] = useState('')
  const [touched, setTouched] = useState(false)
  const [busy, setBusy] = useState(false)
  const [serverError, setServerError] = useState<ApiError | null>(null)

  useEffect(() => {
    if (open) {
      setReason('')
      setResponse('')
      setNote('')
      setTouched(false)
      setServerError(null)
    }
  }, [open])

  const responseTrim = response.trim()
  const noteTrim = note.trim()
  const serverFields = serverError?.fields ?? []
  const reasonError =
    touched && !reason ? 'اختر سبب الإغلاق.' : serverFields.includes('close_reason') || serverFields.includes('p_close_reason') ? 'سبب الإغلاق مطلوب أو غير مقبول.' : null
  const responseError = responseTrim.length > RESPONSE_MAX ? `الحد ${RESPONSE_MAX} حرف.` : null
  const noteError = noteTrim.length > INTERNAL_NOTE_MAX ? `الحد ${INTERNAL_NOTE_MAX} حرف.` : null

  async function submit() {
    setTouched(true)
    if (busy || !reason || responseError || noteError) return
    setBusy(true)
    setServerError(null)
    try {
      await onSubmit({
        closeReason: reason as ReportCloseReason,
        responseText: responseTrim || undefined,
        internalNote: noteTrim || undefined,
      })
      onClose()
    } catch (err) {
      setServerError(toApiError(err))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog
      open={open}
      title="إغلاق البلاغ"
      onClose={onClose}
      busy={busy}
      size="lg"
      footer={
        <>
          <Button variant="ghost" onClick={onClose} disabled={busy}>
            إلغاء
          </Button>
          <Button variant="primary" onClick={() => void submit()} loading={busy}>
            إغلاق البلاغ
          </Button>
        </>
      }
    >
      <form
        onSubmit={(e) => {
          e.preventDefault()
          void submit()
        }}
      >
        <SelectField label="سبب الإغلاق" required value={reason} onChange={(e) => setReason(e.target.value)} error={reasonError}>
          <option value="">— اختر —</option>
          {CLOSE_REASONS.map((r) => (
            <option key={r} value={r}>
              {REPORT_CLOSE_REASON_LABELS[r]}
            </option>
          ))}
        </SelectField>
        <TextAreaField
          label="الرد على المبلغ (اختياري)"
          value={response}
          onChange={(e) => setResponse(e.target.value)}
          maxLength={RESPONSE_MAX}
          hint="يرسل إلى مقدم البلاغ في إشعار الإغلاق ويظهر له في حالة بلاغه. لا تذكر فيه بيانات خاصة."
          error={responseError}
        />
        <TextAreaField
          label="ملاحظة داخلية (اختيارية)"
          value={note}
          onChange={(e) => setNote(e.target.value)}
          maxLength={INTERNAL_NOTE_MAX}
          hint="للموظفين فقط ولا تظهر للمبلغ. إن تركت فارغة تبقى الملاحظة الداخلية الحالية."
          error={noteError}
        />
      </form>
      {serverError && (
        <Alert tone="danger" title="لم يغلق البلاغ">
          {errorMessage(serverError)}
        </Alert>
      )}
    </Dialog>
  )
}
