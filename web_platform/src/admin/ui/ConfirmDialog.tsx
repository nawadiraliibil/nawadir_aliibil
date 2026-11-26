import { useEffect, useState, type ReactNode } from 'react'
import { errorMessage, toApiError } from '../lib/errors'
import { Button } from './Button'
import { Dialog } from './Dialog'
import { TextAreaField } from './Field'
import { Alert } from './States'

export interface ConfirmDialogProps {
  open: boolean
  title: string
  message?: ReactNode
  confirmLabel: string
  tone?: 'primary' | 'danger'
  /** حقل ملاحظة اختياري (مثل ملاحظة إعادة الإظهار الداخلية). */
  noteLabel?: string
  noteHint?: string
  noteRequired?: boolean
  /** حد طول الملاحظة (الافتراضي 1000)؛ يطابق حد الخادم للدالة. */
  noteMax?: number
  onClose: () => void
  onConfirm: (note: string | undefined) => Promise<unknown>
}

/** تأكيد إجراء مع ملاحظة اختيارية؛ يبقى مفتوحًا عند فشل الخادم. */
export function ConfirmDialog({ open, title, message, confirmLabel, tone = 'primary', noteLabel, noteHint, noteRequired, noteMax = 1000, onClose, onConfirm }: ConfirmDialogProps) {
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [touched, setTouched] = useState(false)
  const [error, setError] = useState<unknown>(null)

  useEffect(() => {
    if (open) {
      setNote('')
      setError(null)
      setTouched(false)
    }
  }, [open])

  const trimmed = note.trim()
  const serverNoteError = error != null && toApiError(error).fields.some((f) => f === 'note' || f === 'p_note' || f === 'reason' || f === 'p_reason')
  const noteError =
    touched && noteRequired && !trimmed
      ? 'هذا الحقل مطلوب.'
      : trimmed.length > noteMax
        ? `الملاحظة أطول من الحد المسموح (${noteMax} حرف).`
        : serverNoteError
          ? 'الملاحظة غير مقبولة أو أطول من الحد المسموح.'
          : null

  async function confirm() {
    setTouched(true)
    if (busy || (noteRequired && !trimmed) || trimmed.length > noteMax) return
    setBusy(true)
    setError(null)
    try {
      await onConfirm(trimmed || undefined)
      onClose()
    } catch (err) {
      setError(err)
    } finally {
      setBusy(false)
    }
  }

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
          <Button variant={tone} onClick={() => void confirm()} loading={busy}>
            {confirmLabel}
          </Button>
        </>
      }
    >
      {message && <div className="dialog-message">{message}</div>}
      {noteLabel && (
        <TextAreaField label={noteLabel} hint={noteHint} required={noteRequired} value={note} onChange={(e) => setNote(e.target.value)} error={noteError} maxLength={noteMax} />
      )}
      {error != null && (
        <Alert tone="danger" title="لم ينفذ الإجراء">
          {errorMessage(error)}
        </Alert>
      )}
    </Dialog>
  )
}
