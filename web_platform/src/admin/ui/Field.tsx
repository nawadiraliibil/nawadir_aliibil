import { useId, type InputHTMLAttributes, type ReactNode, type SelectHTMLAttributes, type TextareaHTMLAttributes } from 'react'

interface FieldShellProps {
  label: string
  hint?: ReactNode
  error?: string | null
  required?: boolean
  children: (id: string, describedBy: string | undefined) => ReactNode
}

function FieldShell({ label, hint, error, required, children }: FieldShellProps) {
  const id = useId()
  const hintId = hint ? `${id}-hint` : undefined
  const errId = error ? `${id}-err` : undefined
  const describedBy = [hintId, errId].filter(Boolean).join(' ') || undefined
  return (
    <div className={error ? 'field field-invalid' : 'field'}>
      <label htmlFor={id}>
        {label}
        {required && (
          <span className="req" aria-hidden="true">
            {' '}
            *
          </span>
        )}
      </label>
      {children(id, describedBy)}
      {hint && (
        <p id={hintId} className="field-hint">
          {hint}
        </p>
      )}
      {error && (
        <p id={errId} className="field-error" role="alert">
          {error}
        </p>
      )}
    </div>
  )
}

type Common = { label: string; hint?: ReactNode; error?: string | null }

export function TextField({ label, hint, error, required, ...rest }: Common & InputHTMLAttributes<HTMLInputElement>) {
  return (
    <FieldShell label={label} hint={hint} error={error} required={required}>
      {(id, describedBy) => <input id={id} aria-describedby={describedBy} aria-invalid={error ? true : undefined} required={required} {...rest} />}
    </FieldShell>
  )
}

export function TextAreaField({ label, hint, error, required, ...rest }: Common & TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return (
    <FieldShell label={label} hint={hint} error={error} required={required}>
      {(id, describedBy) => <textarea id={id} aria-describedby={describedBy} aria-invalid={error ? true : undefined} required={required} rows={3} {...rest} />}
    </FieldShell>
  )
}

export function SelectField({ label, hint, error, required, children, ...rest }: Common & SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <FieldShell label={label} hint={hint} error={error} required={required}>
      {(id, describedBy) => (
        <select id={id} aria-describedby={describedBy} aria-invalid={error ? true : undefined} required={required} {...rest}>
          {children}
        </select>
      )}
    </FieldShell>
  )
}

export function CheckboxField({ label, hint, ...rest }: { label: ReactNode; hint?: ReactNode } & InputHTMLAttributes<HTMLInputElement>) {
  const id = useId()
  return (
    <div className="field field-check">
      <input id={id} type="checkbox" {...rest} />
      <label htmlFor={id}>{label}</label>
      {hint && <p className="field-hint">{hint}</p>}
    </div>
  )
}
