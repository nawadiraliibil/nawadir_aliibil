import { useCallback, useId, useRef, useState, type ReactNode } from 'react'
import { useQueryClient, type QueryKey } from '@tanstack/react-query'
import { Alert, Button, Dialog, useNotify } from '@admin/ui'
import { fieldErrorsFrom, lookupErrorMessage, shouldRefetch } from './errors'
import type { FieldErrors } from './types'

export interface FormDialogProps {
  open: boolean
  title: string
  submitLabel: string
  busy: boolean
  error: unknown
  onClose: () => void
  onSubmit: () => void
  children: ReactNode
}

/** نافذة نموذج: Enter يرسل، وتبقى مفتوحة مع رسالة الخطأ عند رفض الخادم. */
export function FormDialog({ open, title, submitLabel, busy, error, onClose, onSubmit, children }: FormDialogProps) {
  const formId = useId()
  return (
    <Dialog
      open={open}
      title={title}
      onClose={onClose}
      busy={busy}
      footer={
        <>
          <Button variant="ghost" onClick={onClose} disabled={busy}>
            إلغاء
          </Button>
          <Button variant="primary" type="submit" form={formId} loading={busy}>
            {submitLabel}
          </Button>
        </>
      }
    >
      <form
        id={formId}
        className="stack"
        noValidate
        onSubmit={(e) => {
          e.preventDefault()
          onSubmit()
        }}
      >
        {children}
      </form>
      {error != null && (
        <Alert tone="danger" title="لم يحفظ التعديل">
          {lookupErrorMessage(error)}
        </Alert>
      )}
    </Dialog>
  )
}

export interface SubmitOptions {
  action: () => Promise<unknown>
  /** حقل الخادم ← حقل النموذج. */
  fieldMap?: Record<string, string>
  duplicateMessage?: string
  invalidate: QueryKey[]
  success: string
  onDone: () => void
}

/**
 * إرسال نموذج دون إعادة محاولة تلقائية. النجاح يعرض بعد تأكيد الخادم وإبطال الاستعلامات.
 * عند الخطأ: أخطاء الحقول من VALIDATION_FAILED، وإعادة تحميل القائمة عند NOT_FOUND/INVALID_STATE.
 */
export function useFormSubmit() {
  const qc = useQueryClient()
  const notify = useNotify()
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<unknown>(null)
  const [serverErrors, setServerErrors] = useState<FieldErrors>({})
  const inFlight = useRef(false)

  const reset = useCallback(() => {
    setError(null)
    setServerErrors({})
  }, [])

  const clearField = useCallback((field: string) => {
    setServerErrors((prev) => {
      if (!(field in prev)) return prev
      const next = { ...prev }
      delete next[field]
      return next
    })
  }, [])

  async function run(opts: SubmitOptions) {
    if (inFlight.current) return
    inFlight.current = true
    setBusy(true)
    setError(null)
    setServerErrors({})
    try {
      await opts.action()
      await Promise.all(opts.invalidate.map((queryKey) => qc.invalidateQueries({ queryKey })))
      notify.success(opts.success)
      opts.onDone()
    } catch (err) {
      setError(err)
      setServerErrors(fieldErrorsFrom(err, opts.fieldMap, opts.duplicateMessage))
      if (shouldRefetch(err)) {
        void Promise.all(opts.invalidate.map((queryKey) => qc.invalidateQueries({ queryKey })))
      }
    } finally {
      inFlight.current = false
      setBusy(false)
    }
  }

  return { busy, error, serverErrors, reset, clearField, run }
}
