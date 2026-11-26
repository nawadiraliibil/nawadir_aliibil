import { useEffect, useState } from 'react'
import { errorMessage, toApiError, type ApiError } from '@admin/lib/errors'
import { Alert, Button, Dialog, TextField } from '@admin/ui'
import { isUuid } from './api'

export interface AssignReportDialogProps {
  open: boolean
  onClose: () => void
  onSubmit: (assignee: string) => Promise<unknown>
}

/** إسناد البلاغ إلى موظف آخر بمعرفه. الخادم يتحقق أنه موظف فعال بقدرة البلاغات. */
export function AssignReportDialog({ open, onClose, onSubmit }: AssignReportDialogProps) {
  const [value, setValue] = useState('')
  const [touched, setTouched] = useState(false)
  const [busy, setBusy] = useState(false)
  const [serverError, setServerError] = useState<ApiError | null>(null)

  useEffect(() => {
    if (open) {
      setValue('')
      setTouched(false)
      setServerError(null)
    }
  }, [open])

  const trimmed = value.trim()
  const formatError = touched && !trimmed ? 'أدخل معرف الموظف.' : touched && !isUuid(trimmed) ? 'المعرف غير صالح؛ الصيغة المتوقعة UUID.' : null
  const assigneeRejected = serverError?.code === 'VALIDATION_FAILED' && serverError.fields.includes('p_assignee')
  const fieldError = formatError ?? (assigneeRejected ? 'ليس موظفًا فعالًا بقدرة إدارة البلاغات.' : null)

  async function submit() {
    setTouched(true)
    if (busy || !isUuid(trimmed)) return
    setBusy(true)
    setServerError(null)
    try {
      await onSubmit(trimmed.toLowerCase())
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
      title="إسناد البلاغ إلى موظف"
      onClose={onClose}
      busy={busy}
      footer={
        <>
          <Button variant="ghost" onClick={onClose} disabled={busy}>
            إلغاء
          </Button>
          <Button variant="primary" onClick={() => void submit()} loading={busy}>
            إسناد
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
        <TextField
          label="معرف الموظف"
          required
          dir="ltr"
          className="mono"
          autoComplete="off"
          spellCheck={false}
          value={value}
          onChange={(e) => setValue(e.target.value)}
          placeholder="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
          hint="المعرف الكامل من صفحة «الموظفون». يصير البلاغ «قيد المراجعة» عند إسناده."
          error={fieldError}
        />
      </form>
      {serverError && (
        <Alert tone="danger" title="لم يسند البلاغ">
          {errorMessage(serverError)}
        </Alert>
      )}
    </Dialog>
  )
}
