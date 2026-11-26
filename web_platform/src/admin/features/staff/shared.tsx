import type { ReactNode } from 'react'
import { Link } from 'react-router'
import { shortId } from '@admin/lib/format'
import { Badge, useNotify } from '@admin/ui'
import { resourceTypeLabel } from './labels'

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export function isUuid(value: string): boolean {
  return UUID_RE.test(value.trim())
}

/** الفاعل: «أنت» لصاحب الجلسة، «النظام» للقيمة الفارغة، وإلا معرف مختصر. */
export function ActorLabel({ id, meId }: { id: string | null | undefined; meId: string | null | undefined }) {
  if (!id) return <span className="muted">النظام</span>
  if (meId && id === meId) return <Badge tone="gold">أنت</Badge>
  return (
    <span className="mono ltr" dir="ltr" title={id}>
      {shortId(id)}
    </span>
  )
}

/** معرف كامل قابل للنسخ (اتجاه LTR). */
export function CopyableId({ id }: { id: string }) {
  const notify = useNotify()
  async function copy() {
    try {
      if (!navigator.clipboard) throw new Error('no clipboard')
      await navigator.clipboard.writeText(id)
      notify.info('نسخ المعرف.')
    } catch {
      notify.error('تعذر النسخ. حدد المعرف وانسخه يدويًا.')
    }
  }
  return (
    <span className="row">
      <code className="mono ltr small" dir="ltr">
        {id}
      </code>
      <button type="button" className="btn btn-ghost btn-sm" onClick={() => void copy()} aria-label={`نسخ المعرف ${id}`}>
        <span>نسخ</span>
      </button>
    </span>
  )
}

function str(v: unknown): string | null {
  return typeof v === 'string' && v !== '' ? v : null
}

/** نوع المورد ومعرفه مع رابط إلى صفحته في اللوحة إن وجدت. */
export function ResourceCell({ type, id, details }: { type: string; id: string | null; details: unknown }) {
  const d = details && typeof details === 'object' && !Array.isArray(details) ? (details as Record<string, unknown>) : {}
  const label = resourceTypeLabel(type)
  const idText = id ? (
    <span className="mono ltr" dir="ltr" title={id}>
      {id.length > 12 ? shortId(id) : id}
    </span>
  ) : null

  let main: ReactNode = idText
  let extra: ReactNode = null
  const direct: Record<string, string> = {
    listing: '/admin/listings/',
    account: '/admin/accounts/',
    profile: '/admin/accounts/',
    report: '/admin/reports/',
    rating: '/admin/ratings/',
  }
  const base = direct[type]
  if (base && id) {
    main = (
      <Link to={`${base}${id}`} aria-label={`${label} ${id}`}>
        {idText}
      </Link>
    )
  } else if (type === 'rating_appeal') {
    const ratingId = str(d.rating_id)
    if (ratingId) extra = <Link to={`/admin/ratings/${ratingId}`}>التقييم</Link>
  } else if (type === 'comment') {
    const listingId = str(d.listing_id)
    if (listingId) extra = <Link to={`/admin/listings/${listingId}`}>الإعلان</Link>
  } else if (type === 'admin_role' && id) {
    extra = <Link to="/admin/staff">الموظفون</Link>
  } else if (type === 'settings_version') {
    extra = <Link to="/admin/settings">الإعدادات</Link>
  } else if (['region', 'city', 'breed', 'moderation_reason'].includes(type)) {
    extra = <Link to="/admin/lookups">القوائم</Link>
  }

  return (
    <div className="stack" style={{ gap: 2 }}>
      <span>{label}</span>
      {main}
      {extra && <span className="small">{extra}</span>}
    </div>
  )
}
