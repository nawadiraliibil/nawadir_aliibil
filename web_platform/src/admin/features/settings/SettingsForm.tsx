import { CheckboxField, TextField } from '@admin/ui'
import { formatNumber } from '@admin/lib/format'
import type { FormValues } from './types'
import { GROUPS, MIME_LABELS, SUPPORTED_IMAGE_MIME_TYPES, fieldLabel, formatMegabytes, type FieldDef } from './schema'

export interface SettingsFormProps {
  form: FormValues
  errors: Record<string, string>
  disabled?: boolean
  onChange: (path: string, value: string | boolean | string[]) => void
}

function intHint(fd: FieldDef, value: string): string | undefined {
  const parts: string[] = []
  if (fd.hint) parts.push(fd.hint)
  if (fd.bytes && /^[1-9][0-9]*$/.test(value.trim())) parts.push(`يعادل ${formatMegabytes(Number(value.trim()))}.`)
  if (fd.ceiling !== undefined) parts.push(`الحد التقني: ${formatNumber(fd.ceiling)}${fd.bytes ? ` (${formatMegabytes(fd.ceiling)})` : ''}.`)
  return parts.length ? parts.join(' ') : undefined
}

/** نموذج الإعدادات مولد من مفاتيح المحتوى المعروفة، مقسم إلى مجموعات. */
export function SettingsForm({ form, errors, disabled, onChange }: SettingsFormProps) {
  return (
    <div className="stack">
      {GROUPS.map((g) => (
        <fieldset key={g.id} className="settings-group" disabled={disabled}>
          <legend>{g.title}</legend>
          {g.description && <p className="muted small settings-group-desc">{g.description}</p>}
          <div className="grid grid-3">
            {g.fields.map((fd) => {
              const value = form[fd.path]
              const error = errors[fd.path] ?? null
              if (fd.kind === 'int') {
                const s = typeof value === 'string' ? value : ''
                return (
                  <TextField
                    key={fd.path}
                    label={fieldLabel(fd.path)}
                    type="number"
                    inputMode="numeric"
                    min={fd.hardMinimum ?? 1}
                    max={fd.ceiling}
                    step={1}
                    className="ltr"
                    name={fd.path}
                    data-path={fd.path}
                    value={s}
                    error={error}
                    hint={intHint(fd, s)}
                    onChange={(e) => onChange(fd.path, e.target.value)}
                  />
                )
              }
              if (fd.kind === 'bool') {
                return (
                  <div key={fd.path} className={error ? 'field-invalid' : undefined}>
                    <CheckboxField label={fd.label} hint={fd.hint} name={fd.path} checked={value === true} onChange={(e) => onChange(fd.path, e.target.checked)} aria-invalid={error ? true : undefined} />
                    {error && (
                      <p className="field-error" role="alert">
                        {error}
                      </p>
                    )}
                  </div>
                )
              }
              const chosen = Array.isArray(value) ? value : []
              return (
                <fieldset key={fd.path} className={error ? 'settings-subgroup field-invalid' : 'settings-subgroup'} aria-invalid={error ? true : undefined}>
                  <legend>{fd.label}</legend>
                  {SUPPORTED_IMAGE_MIME_TYPES.map((m) => (
                    <CheckboxField
                      key={m}
                      label={MIME_LABELS[m] ?? m}
                      name={`${fd.path}.${m}`}
                      checked={chosen.includes(m)}
                      onChange={(e) => onChange(fd.path, e.target.checked ? [...chosen.filter((x) => x !== m), m] : chosen.filter((x) => x !== m))}
                    />
                  ))}
                  <p className="field-hint">الصيغ المدعومة فعلًا: JPEG وPNG.</p>
                  {error && (
                    <p className="field-error" role="alert">
                      {error}
                    </p>
                  )}
                </fieldset>
              )
            })}
          </div>
        </fieldset>
      ))}
    </div>
  )
}
