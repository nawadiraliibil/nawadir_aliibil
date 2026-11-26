import { useEffect, useId, useState } from 'react'
import { errorMessage, toApiError, type ApiError } from '@admin/lib/errors'
import { useModerationReasons } from '@admin/lib/useModerationReasons'
import { Alert, Button, Dialog, Loading, SelectField, TextAreaField } from '@admin/ui'
import { APPEAL_DECISION_LABELS } from './labels'
import type { AppealDecision } from './types'

/** حد نص السبب في require_moderation_reason (القبول يمرر p_note نصًا لسبب الإخفاء). */
export const ACCEPT_NOTE_MAX = 1000
/** حد decision_note في rating_appeals (للرفض). */
export const REJECT_NOTE_MAX = 2000

export interface AppealDecisionValue {
  decision: AppealDecision
  /** رمز RATING_HIDE عند القبول فقط. */
  reason_code: string | undefined
  /** p_note: عند القبول توضيح سبب الإخفاء وملاحظة القرار معًا؛ عند الرفض ملاحظة القرار. */
  note: string | undefined
}

export interface AppealDecisionDialogProps {
  open: boolean
  /** التقييم مخفي مسبقًا: القبول يبقيه مخفيًا بسببه الأول. */
  ratingHidden: boolean
  onClose: () => void
  /** يرمي عند فشل الخادم؛ يبقى الحوار مفتوحًا ويعرض الخطأ. */
  onSubmit: (value: AppealDecisionValue) => Promise<unknown>
}

/**
 * قرار اعتراض المعلن (admin_decide_rating_appeal): القبول يخفي التقييم ويلزمه سبب
 * من أسباب RATING_HIDE (ونص عند requires_note)، والرفض يبقيه بملاحظة اختيارية.
 */
export function AppealDecisionDialog({ open, ratingHidden, onClose, onSubmit }: AppealDecisionDialogProps) {
  const groupName = useId()
  const [decision, setDecision] = useState<AppealDecision | ''>('')
  const [code, setCode] = useState('')
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [touched, setTouched] = useState(false)
  const [serverError, setServerError] = useState<ApiError | null>(null)
  const accepting = decision === 'ACCEPTED'
  const reasons = useModerationReasons('RATING_HIDE', open && accepting)

  useEffect(() => {
    if (open) {
      setDecision('')
      setCode('')
      setNote('')
      setTouched(false)
      setServerError(null)
    }
  }, [open])

  const selected = accepting ? reasons.data?.find((r) => r.code === code) : undefined
  const needsText = accepting && (selected?.requires_note ?? false)
  const trimmed = note.trim()
  const max = accepting ? ACCEPT_NOTE_MAX : REJECT_NOTE_MAX
  const fieldErr = serverError?.fields ?? []

  const decisionError = touched && !decision ? 'اختر القرار.' : null
  const codeError = touched && accepting && !code ? 'اختر سبب الإخفاء.' : fieldErr.includes('reason_code') ? 'السبب غير مقبول لهذا الإجراء.' : null
  const noteError =
    touched && needsText && !trimmed
      ? 'اكتب توضيحًا لهذا السبب.'
      : trimmed.length > max
        ? `الحد ${max} حرف.`
        : fieldErr.includes('reason_text')
          ? 'التوضيح مطلوب أو غير صالح.'
          : null

  async function submit() {
    setTouched(true)
    if (busy || !decision) return
    if (accepting && (!code || (needsText && !trimmed))) return
    if (trimmed.length > max) return
    setBusy(true)
    setServerError(null)
    try {
      await onSubmit({
        decision,
        reason_code: accepting ? code : undefined,
        note: trimmed || undefined,
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
      title="قرار الاعتراض"
      onClose={onClose}
      busy={busy}
      footer={
        <>
          <Button variant="ghost" onClick={onClose} disabled={busy}>
            إلغاء
          </Button>
          <Button
            variant={accepting ? 'danger' : 'primary'}
            onClick={() => void submit()}
            loading={busy}
            disabled={accepting && (reasons.isLoading || !reasons.data)}
          >
            تأكيد القرار
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
        <fieldset className="rating-decision" aria-describedby={decisionError ? `${groupName}-err` : undefined}>
          <legend>
            القرار{' '}
            <span className="req" aria-hidden="true">
              *
            </span>
          </legend>
          {(['ACCEPTED', 'REJECTED'] as const).map((d) => (
            <label key={d}>
              <input
                type="radio"
                name={groupName}
                value={d}
                checked={decision === d}
                onChange={() => {
                  setDecision(d)
                  setServerError(null)
                }}
              />
              {APPEAL_DECISION_LABELS[d]}
            </label>
          ))}
          {decisionError && (
            <p id={`${groupName}-err`} className="field-error" role="alert">
              {decisionError}
            </p>
          )}
        </fieldset>

        {accepting && (
          <>
            {ratingHidden && <Alert tone="info">التقييم مخفي حاليًا؛ القبول يبقيه مخفيًا بسببه المسجل ويغلق الاعتراض.</Alert>}
            {reasons.isLoading && <Loading label="جارٍ تحميل الأسباب…" />}
            {reasons.isError && <Alert tone="danger">{errorMessage(reasons.error)}</Alert>}
            {reasons.data && (
              <>
                <SelectField label="سبب الإخفاء" required value={code} onChange={(e) => setCode(e.target.value)} error={codeError}>
                  <option value="">— اختر —</option>
                  {reasons.data.map((r) => (
                    <option key={r.code} value={r.code}>
                      {r.label_ar}
                    </option>
                  ))}
                </SelectField>
                {reasons.data.length === 0 && <Alert tone="warning">لا توجد أسباب فعالة لإخفاء التقييمات. أضفها من «القوائم».</Alert>}
              </>
            )}
            <TextAreaField
              label={needsText ? 'التوضيح' : 'توضيح (اختياري)'}
              required={needsText}
              value={note}
              onChange={(e) => setNote(e.target.value)}
              hint="يحفظ توضيحًا لسبب الإخفاء وملاحظةً على القرار."
              error={noteError}
            />
          </>
        )}

        {decision === 'REJECTED' && (
          <TextAreaField
            label="ملاحظة القرار (اختياري)"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            hint={ratingHidden ? 'يبقى التقييم مخفيًا كما هو.' : 'يبقى التقييم ظاهرًا كما هو.'}
            error={noteError}
          />
        )}
      </form>
      {serverError && (
        <Alert tone="danger" title="لم ينفذ القرار">
          {errorMessage(serverError)}
        </Alert>
      )}
    </Dialog>
  )
}
