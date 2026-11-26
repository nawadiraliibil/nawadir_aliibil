import { useEffect, useState } from 'react'
import { CAPABILITY_LABELS, ROLE_LABELS, type Capability, type StaffRole } from '@admin/lib/capabilities'
import { errorMessage, toApiError } from '@admin/lib/errors'
import { Alert, Button, CheckboxField, Dialog, SelectField, TextField } from '@admin/ui'
import { ADMIN_ONLY_CAPABILITIES, MODERATOR_CAPABILITIES } from './labels'
import { isUuid } from './shared'
import type { AdminRoleRow } from './types'

export interface RoleInput {
  p_user_id: string
  p_role: StaffRole
  p_capabilities: string[]
}

export interface RoleDialogProps {
  open: boolean
  /** صف موجود للتعديل أو إعادة المنح؛ null لمنح جديد. */
  existing: AdminRoleRow | null
  meId: string | null
  /** صفوف الموظفين المحملة، لتنبيه أن المعرف له دور مسبقًا. */
  knownRows: AdminRoleRow[]
  onClose: () => void
  onSubmit: (input: RoleInput) => Promise<unknown>
}

type FieldErrors = Partial<Record<'user_id' | 'role' | 'capabilities', string>>

const SERVER_FIELD_MESSAGES: Record<keyof FieldErrors, string> = {
  user_id: 'المعرف لا يطابق حساب موظف: يلزم حساب في Supabase Auth ببريد إلكتروني، وليس حساب مستخدم في التطبيق.',
  role: 'اختر الدور.',
  capabilities: 'قدرات غير صالحة لمشرف.',
}

/** نافذة منح دور أو تعديله عبر admin_grant_role. */
export function RoleDialog({ open, existing, meId, knownRows, onClose, onSubmit }: RoleDialogProps) {
  const [userId, setUserId] = useState('')
  const [role, setRole] = useState<StaffRole>('MODERATOR')
  const [caps, setCaps] = useState<Capability[]>([])
  const [errors, setErrors] = useState<FieldErrors>({})
  const [serverError, setServerError] = useState<unknown>(null)
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    if (!open) return
    setUserId(existing?.user_id ?? '')
    setRole(existing?.role ?? 'MODERATOR')
    setCaps(existing && existing.role === 'MODERATOR' ? MODERATOR_CAPABILITIES.filter((c) => existing.capabilities.includes(c)) : [])
    setErrors({})
    setServerError(null)
    setBusy(false)
  }, [open, existing])

  const editing = existing !== null
  const trimmedId = userId.trim().toLowerCase()
  const known = !editing && isUuid(trimmedId) ? knownRows.find((r) => r.user_id.toLowerCase() === trimmedId) : undefined

  function validate(): FieldErrors {
    const e: FieldErrors = {}
    if (!trimmedId) e.user_id = 'معرف الحساب مطلوب.'
    else if (!isUuid(trimmedId)) e.user_id = 'المعرف يجب أن يكون UUID صالحًا، مثل 2f1c…-…'
    else if (meId && trimmedId === meId.toLowerCase()) e.user_id = 'لا يمكنك تعديل دورك أو سحبه بنفسك.'
    if (role === 'MODERATOR' && caps.length === 0) e.capabilities = 'اختر قدرة واحدة على الأقل للمشرف.'
    return e
  }

  async function submit() {
    if (busy) return
    const e = validate()
    setErrors(e)
    if (Object.keys(e).length > 0) return
    setBusy(true)
    setServerError(null)
    try {
      await onSubmit({
        p_user_id: trimmedId,
        p_role: role,
        // للمدير تهمل القدرات في الخادم (validate_role_input) فترسل فارغة.
        p_capabilities: role === 'ADMIN' ? [] : MODERATOR_CAPABILITIES.filter((c) => caps.includes(c)),
      })
      onClose()
    } catch (err) {
      const apiErr = toApiError(err)
      if (apiErr.code === 'VALIDATION_FAILED') {
        const fe: FieldErrors = {}
        for (const f of apiErr.fields) {
          if (f === 'user_id' || f === 'role' || f === 'capabilities') fe[f] = SERVER_FIELD_MESSAGES[f]
        }
        setErrors(fe)
      }
      setServerError(err)
    } finally {
      setBusy(false)
    }
  }

  function toggle(cap: Capability, on: boolean) {
    setCaps((prev) => (on ? [...prev.filter((c) => c !== cap), cap] : prev.filter((c) => c !== cap)))
  }

  const title = editing ? (existing.is_active ? 'تعديل دور الموظف' : 'إعادة منح دور') : 'منح دور'

  return (
    <Dialog
      open={open}
      title={title}
      onClose={onClose}
      busy={busy}
      size="lg"
      footer={
        <>
          <Button variant="ghost" onClick={onClose} disabled={busy}>
            إلغاء
          </Button>
          <Button variant="primary" onClick={() => void submit()} loading={busy}>
            {editing ? 'حفظ الدور' : 'منح الدور'}
          </Button>
        </>
      }
    >
      <form
        className="stack"
        noValidate
        onSubmit={(ev) => {
          ev.preventDefault()
          void submit()
        }}
      >
        {!editing && (
          <Alert tone="info" title="قبل المنح">
            أنشئ حساب الموظف أولًا في لوحة Supabase (Authentication ‹ Users) ببريد إلكتروني وكلمة مرور، ثم انسخ معرفه (UUID) هنا. لا تمنح الأدوار لحسابات مستخدمي التطبيق. عند أول دخول يسجل الموظف التحقق بخطوتين (TOTP) قبل استخدام اللوحة.
          </Alert>
        )}
        <TextField
          label="معرف حساب الموظف (UUID)"
          dir="ltr"
          className="input ltr mono"
          value={userId}
          readOnly={editing}
          required
          autoComplete="off"
          spellCheck={false}
          placeholder="00000000-0000-0000-0000-000000000000"
          onChange={(e) => setUserId(e.target.value)}
          error={errors.user_id}
          hint={known ? `لهذا الحساب دور مسبق (${ROLE_LABELS[known.role]}${known.is_active ? '' : '، مسحوب'})؛ سيحدّث بالقيم الجديدة.` : undefined}
        />
        <SelectField label="الدور" value={role} required onChange={(e) => setRole(e.target.value as StaffRole)} error={errors.role}>
          <option value="MODERATOR">{ROLE_LABELS.MODERATOR} (MODERATOR) — قدرات محددة</option>
          <option value="ADMIN">{ROLE_LABELS.ADMIN} (ADMIN) — كل القدرات</option>
        </SelectField>
        {role === 'ADMIN' ? (
          <Alert tone="warning" title="كل القدرات">
            المدير يملك كل القدرات تلقائيًا، بما فيها إدارة الموظفين وسجل الإجراءات والتقارير، فلا تختار له قدرات.
          </Alert>
        ) : (
          <fieldset className="stack" aria-describedby={errors.capabilities ? 'role-caps-error' : undefined}>
            <legend>قدرات المشرف</legend>
            {MODERATOR_CAPABILITIES.map((c) => (
              <CheckboxField
                key={c}
                label={
                  <>
                    {CAPABILITY_LABELS[c]}{' '}
                    <span className="muted small ltr" dir="ltr">
                      ({c})
                    </span>
                  </>
                }
                checked={caps.includes(c)}
                onChange={(e) => toggle(c, e.target.checked)}
              />
            ))}
            <p className="field-hint">للمدير وحده: {ADMIN_ONLY_CAPABILITIES.map((c) => CAPABILITY_LABELS[c]).join('، ')}.</p>
            {errors.capabilities && (
              <p id="role-caps-error" className="field-error" role="alert">
                {errors.capabilities}
              </p>
            )}
          </fieldset>
        )}
        {editing && existing.is_active && <p className="muted small">يسري التغيير في الاستدعاء التالي لهذا الموظف.</p>}
        {serverError != null && (
          <Alert tone="danger" title="لم يحفظ الدور">
            {errorMessage(serverError)}
          </Alert>
        )}
      </form>
    </Dialog>
  )
}
