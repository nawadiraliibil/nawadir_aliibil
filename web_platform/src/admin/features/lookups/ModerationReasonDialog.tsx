import { useEffect, useId, useState } from 'react'
import { CheckboxField, TextField } from '@admin/ui'
import { MODERATION_ACTION_LABELS, label } from '@admin/lib/labels'
import { SHARED_REASONS_KEY, lookupKeys, upsertReason } from './api'
import { FIELD_MESSAGES, REASON_CODE_PATTERN, cleanName, parseSortOrder, validateName } from './errors'
import { FormDialog, useFormSubmit } from './FormDialog'
import { CURRENT_REASON_ACTIONS, LEGACY_ACTION_HINT, LEGACY_REASON_ACTION } from './labels'
import type { FieldErrors, ModerationReasonRow } from './types'

const LABEL_MAX = 120

export interface ModerationReasonDialogProps {
  open: boolean
  /** null: إضافة سبب جديد. */
  value: ModerationReasonRow | null
  /** الرموز الموجودة (فعالة ومعطلة): الإضافة برمز موجود تعدل السبب القائم في الخادم، فتمنع هنا. */
  existingCodes: string[]
  onClose: () => void
}

export function ModerationReasonDialog({ open, value, existingCodes, onClose }: ModerationReasonDialogProps) {
  const isNew = value === null
  const [code, setCode] = useState('')
  const [labelAr, setLabelAr] = useState('')
  const [appliesTo, setAppliesTo] = useState<string[]>([])
  const [requiresNote, setRequiresNote] = useState(false)
  const [sortOrder, setSortOrder] = useState('')
  const [touched, setTouched] = useState(false)
  const submit = useFormSubmit()
  const { reset } = submit
  const groupId = useId()

  useEffect(() => {
    if (open) {
      setCode(value?.code ?? '')
      setLabelAr(value?.label_ar ?? '')
      setAppliesTo(value?.applies_to ?? [])
      setRequiresNote(value?.requires_note ?? false)
      setSortOrder(value ? String(value.sort_order) : '')
      setTouched(false)
      reset()
    }
  }, [open, value, reset])

  // LISTING_REJECT قديم (TEAM-DEC-013): يظهر فقط إن كان السبب يحمله عند فتح النافذة.
  const showLegacy = value?.applies_to.includes(LEGACY_REASON_ACTION) ?? false
  const options: string[] = [...CURRENT_REASON_ACTIONS, ...(showLegacy ? [LEGACY_REASON_ACTION] : [])]

  const local: FieldErrors = {}
  if (isNew) {
    if (!REASON_CODE_PATTERN.test(code)) local.code = FIELD_MESSAGES.code
    else if (existingCodes.includes(code)) local.code = 'الرمز مستخدم لسبب آخر. اختر رمزًا جديدًا أو عدل السبب الموجود.'
  }
  const labelErr = validateName(labelAr, LABEL_MAX, 'التسمية مطلوبة.')
  if (labelErr) local.label_ar = labelErr
  if (appliesTo.length === 0) local.applies_to = FIELD_MESSAGES.applies_to
  const sort = parseSortOrder(sortOrder)
  if (sort.error) local.sort_order = sort.error
  const errors: FieldErrors = { ...submit.serverErrors, ...(touched ? local : {}) }

  function toggleAction(action: string, checked: boolean) {
    setAppliesTo((prev) => (checked ? (prev.includes(action) ? prev : [...prev, action]) : prev.filter((a) => a !== action)))
    submit.clearField('applies_to')
  }

  function onSubmit() {
    setTouched(true)
    if (Object.keys(local).length > 0) return
    // ترتيب الإجراءات ثابت كما في الخيارات (الخادم يرتبها ويزيل التكرار أيضًا).
    const ordered = options.filter((o) => appliesTo.includes(o))
    void submit.run({
      action: () =>
        upsertReason({
          code: value?.code ?? code,
          label_ar: cleanName(labelAr),
          applies_to: ordered,
          requires_note: requiresNote,
          sort_order: sort.value,
        }),
      // clean_lookup_name يبلغ عن name_ar؛ الحقل هنا التسمية.
      fieldMap: { name_ar: 'label_ar' },
      invalidate: [lookupKeys.reasons(), SHARED_REASONS_KEY],
      success: isNew ? 'تمت إضافة سبب الإشراف.' : 'تم حفظ سبب الإشراف.',
      onDone: onClose,
    })
  }

  return (
    <FormDialog
      open={open}
      title={isNew ? 'إضافة سبب إشراف' : `تعديل سبب الإشراف «${value.label_ar}»`}
      submitLabel={isNew ? 'إضافة' : 'حفظ'}
      busy={submit.busy}
      error={submit.error}
      onClose={onClose}
      onSubmit={onSubmit}
    >
      <TextField
        label="الرمز"
        required={isNew}
        dir="ltr"
        className="mono"
        autoComplete="off"
        spellCheck={false}
        maxLength={40}
        value={isNew ? code : value.code}
        readOnly={!isNew}
        onChange={(e) => {
          setCode(e.target.value.toUpperCase().replace(/\s/g, '_'))
          submit.clearField('code')
        }}
        error={errors.code}
        hint={isNew ? 'أحرف إنجليزية كبيرة وأرقام و_ ، يبدأ بحرف، مثل FAKE_PRICE. لا يتغير بعد الإنشاء.' : 'الرمز ثابت بعد الإنشاء لأنه محفوظ في سجلات الإجراءات.'}
      />
      <TextField
        label="التسمية بالعربية"
        required
        maxLength={LABEL_MAX}
        value={labelAr}
        onChange={(e) => {
          setLabelAr(e.target.value)
          submit.clearField('label_ar')
        }}
        error={errors.label_ar}
        hint={`تظهر للموظف عند اختيار السبب، حتى ${LABEL_MAX} حرفًا.`}
      />
      <fieldset className={errors.applies_to ? 'field field-invalid' : 'field'} style={{ border: 0, padding: 0, margin: 0 }} aria-describedby={errors.applies_to ? `${groupId}-err` : undefined}>
        <legend>
          ينطبق على
          <span className="req" aria-hidden="true">
            {' '}
            *
          </span>
        </legend>
        {options.map((action) => (
          <CheckboxField
            key={action}
            label={label(MODERATION_ACTION_LABELS, action)}
            hint={action === LEGACY_REASON_ACTION ? LEGACY_ACTION_HINT : undefined}
            checked={appliesTo.includes(action)}
            onChange={(e) => toggleAction(action, e.target.checked)}
          />
        ))}
        {errors.applies_to && (
          <p id={`${groupId}-err`} className="field-error" role="alert">
            {errors.applies_to}
          </p>
        )}
      </fieldset>
      <CheckboxField
        label="يتطلب كتابة توضيح عند اختياره"
        hint="مثل «أخرى»: لا يقبل الإجراء دون نص حر من الموظف."
        checked={requiresNote}
        onChange={(e) => setRequiresNote(e.target.checked)}
      />
      <TextField
        label="رقم الترتيب"
        type="number"
        inputMode="numeric"
        step={1}
        value={sortOrder}
        onChange={(e) => {
          setSortOrder(e.target.value)
          submit.clearField('sort_order')
        }}
        error={errors.sort_order}
        hint={isNew ? 'اختياري. اتركه فارغًا لإضافة السبب في آخر القائمة.' : 'الرقم الأصغر يظهر أولًا.'}
      />
    </FormDialog>
  )
}
