import { Link } from 'react-router'
import { useCan } from '@admin/auth/AuthContext'
import { shortId } from '@admin/lib/format'

/** الدرجة نجومًا مع نص مقروء لقارئ الشاشة. */
export function Stars({ score }: { score: number | null | undefined }) {
  if (score === null || score === undefined) return <span className="muted">—</span>
  const n = Math.max(0, Math.min(5, Math.round(score)))
  return (
    <span className="rating-stars" role="img" aria-label={`${n} من 5`} title={`${n} من 5`}>
      <span aria-hidden="true">
        <span className="rating-stars-on">{'★'.repeat(n)}</span>
        <span className="rating-stars-off">{'☆'.repeat(5 - n)}</span>
      </span>
    </span>
  )
}

/** مقتطف نص بطول محدد. */
export function excerpt(text: string | null | undefined, max = 80): string {
  if (!text) return '—'
  const t = text.replace(/\s+/g, ' ').trim()
  return t.length > max ? `${t.slice(0, max)}…` : t
}

/**
 * اسم العرض أو معرف مختصر. الرابط لصفحة الحساب فقط لمن يملك accounts.manage
 * (`link=false` للأشخاص من الموظفين).
 */
export function PersonName({ id, names, link = true }: { id: string | null | undefined; names: Map<string, string> | undefined; link?: boolean }) {
  const canAccounts = useCan('accounts.manage')
  if (!id) return <span className="muted">—</span>
  const name = names?.get(id)
  const text = name ?? <span className="mono ltr">{shortId(id)}</span>
  if (link && canAccounts) {
    return (
      <Link to={`/admin/accounts/${id}`} title={id} onClick={(e) => e.stopPropagation()}>
        {text}
      </Link>
    )
  }
  return <span title={id}>{text}</span>
}
