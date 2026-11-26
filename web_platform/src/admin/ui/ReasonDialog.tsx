import { useEffect, useState } from 'react'
import { ApiError, errorMessage, toApiError } from '../lib/errors'
import type { ModerationAction } from '../lib/labels'
import { useModerationReasons } from '../lib/useModerationReasons'
import { Button } from './Button'
import { Dialog } from './Dialog'
import { SelectField, TextAreaField } from './Field'
import { Alert, Loading } from './States'

export interface ReasonValue {
  reason_code: string
  /** فارغ يرسل undefined (لا null) لأن الأنواع المولدة تعرفه اختياريًا. */
  reason_text: string | undefined
}

export interface ReasonDialogProps {
  open: boolean
  action: ModerationAction
  title: string
  description?: string
  confirmLabel: string
  onClose: () => void
  /** يرمي عند فشل الخادم؛ يبقى الحوار مفتوحًا ويعرض الخطأ. */
  onSubmit: (value: ReasonValue) => Promise<unknown>
  tone?: 'danger' | 'primary'
  /** يستبدل التلميح الافتراضي لحقل التوضيح. */
  textHint?: string
}

/** من يرى السبب: إخفاء الإعلان وتعليق الحساب يشعران صاحبه بالسبب؛ إخفاء الرد والتقييم يسجل فقط. */
function defaultTextHint(action: ModerationAction): string {
  return action === 'LISTING_HIDE' || action === 'ACCOUNT_SUSPEND'
    ? 'يظهر السبب وتوضيحه لصاحب المحتوى.'
    : 'يحفظ السبب وتوضيحه في سجل الإجراءات.'
}

export const REASON_TEXT_MAX = 1000

/**
 * حوار السبب الإلزامي للإخفاء والتعليق (ADMIN-HANDOFF القسم 5):
 * رمز من moderation_reasons للإجراء، ونص حر إلزامي عند requires_note («أخرى»).
 * لا يسمح بالإرسال دون سبب، ولا يرسل مرتين أثناء الانتظار.
 */
export function ReasonDialog({ open, action, title, description, confirmLabel, onClose, onSubmit, tone = 'danger', textHint }: ReasonDialogProps) {
  const reasons = useModerationReasons(action, open)
  const [code, setCode] = useState('')
  const [text, setText] = useState('')
  const [busy, setBusy] = useState(false)
  const [touched, setTouched] = useState(false)
  const [serverError, setServerError] = useState<ApiError | null>(null)

  useEffect(() => {
    if (open) {
      setCode('')
      setText('')
      setTouched(false)
      setServerError(null)
    }
  }, [open])

  const selected = reasons.data?.find((r) => r.code === code)
  const needsText = selected?.requires_note ?? false
  const trimmed = text.trim()
  const codeError = touched && !code ? 'اختر سببًا.' : null
  const textError =
    touched && needsText && !trimmed ? 'اكتب توضيحًا لهذا السبب.' : trimmed.length > REASON_TEXT_MAX ? `الحد ${REASON_TEXT_MAX} حرف.` : null
  const fieldErr = serverError?.fields ?? []

  async function submit() {
    setTouched(true)
    if (busy || !code || (needsText && !trimmed) || trimmed.length > REASON_TEXT_MAX) return
    setBusy(true)
    setServerError(null)
    try {
      await onSubmit({ reason_code: code, reason_text: trimmed || undefined })
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
      title={title}
      onClose={onClose}
      busy={busy}
      footer={
        <>
          <Button variant="ghost" onClick={onClose} disabled={busy}>
            إلغاء
          </Button>
          <Button variant={tone} onClick={() => void submit()} loading={busy} disabled={reasons.isLoading || !reasons.data}>
            {confirmLabel}
          </Button>
        </>
      }
    >
      {description && <p className="muted">{description}</p>}
      {reasons.isLoading && <Loading label="جارٍ تحميل الأسباب…" />}
      {reasons.isError && <Alert tone="danger">{errorMessage(reasons.error)}</Alert>}
      {reasons.data && (
        <form
          onSubmit={(e) => {
            e.preventDefault()
            void submit()
          }}
        >
          <SelectField
            label="السبب"
            required
            value={code}
            onChange={(e) => setCode(e.target.value)}
            error={codeError ?? (fieldErr.includes('reason_code') ? 'السبب غير مقبول لهذا الإجراء.' : null)}
          >
            <option value="">— اختر —</option>
            {reasons.data.map((r) => (
              <option key={r.code} value={r.code}>
                {r.label_ar}
              </option>
            ))}
          </SelectField>
          <TextAreaField
            label={needsText ? 'التوضيح' : 'توضيح (اختياري)'}
            required={needsText}
            value={text}
            onChange={(e) => setText(e.target.value)}
            hint={textHint ?? defaultTextHint(action)}
            error={textError ?? (fieldErr.includes('reason_text') ? 'التوضيح مطلوب أو غير صالح.' : null)}
          />
          {reasons.data.length === 0 && <Alert tone="warning">لا توجد أسباب فعالة لهذا الإجراء. أضفها من «القوائم».</Alert>}
        </form>
      )}
      {serverError && (
        <Alert tone="danger" title="لم ينفذ الإجراء">
          {errorMessage(serverError)}
        </Alert>
      )}
    </Dialog>
  )
}
