import type { ReactNode } from 'react'
import { formatDateTime, formatPrice } from '@admin/lib/format'
import { ANIMAL_SEX_LABELS, OFFER_TYPE_LABELS, label } from '@admin/lib/labels'
import { Badge, KeyValue } from '@admin/ui'
import { MediaGallery } from './media'
import { VERSION_STATUS_LABELS, formatAge, lookupName, osmUrl } from './helpers'
import type { ListingMedia, ListingVersion, LookupNames } from './types'

function Phone({ value }: { value: string | null | undefined }) {
  if (!value) return <span className="muted">غير متاح</span>
  return (
    <a href={`tel:${value}`} className="ltr mono" dir="ltr">
      {value}
    </a>
  )
}

/** محتوى نسخة إعلان بكل حقولها ووسائطها (للقراءة فقط). */
export function VersionContent({ version, media, lookups }: { version: ListingVersion; media: ListingMedia[] | null; lookups: LookupNames | undefined }) {
  const isAuction = version.offer_type === 'IN_PERSON_AUCTION'
  const hasGeo = typeof version.auction_lat === 'number' && typeof version.auction_lng === 'number'
  const breed = version.breed_id !== null ? lookupName(lookups?.breeds, version.breed_id) : '—'

  const items: Array<{ label: string; value: ReactNode; wide?: boolean }> = [
    { label: 'العنوان', value: version.title, wide: true },
    { label: 'الوصف', value: version.description ? <p className="listing-description">{version.description}</p> : null, wide: true },
    { label: 'السلالة', value: version.breed_note ? `${breed} — ${version.breed_note}` : breed },
    { label: 'الجنس', value: label(ANIMAL_SEX_LABELS, version.sex) },
    { label: 'العمر', value: formatAge(version.age_months) },
  ]
  if (version.color !== undefined) items.push({ label: 'اللون', value: version.color })
  if (version.health_notes !== undefined) items.push({ label: 'الحالة الصحية', value: version.health_notes, wide: true })
  items.push(
    { label: 'المنطقة', value: lookupName(lookups?.regions, version.region_id) },
    { label: 'المدينة', value: lookupName(lookups?.cities, version.city_id) },
    { label: 'نوع العرض', value: label(OFFER_TYPE_LABELS, version.offer_type) },
  )
  if (isAuction) {
    items.push(
      { label: 'موعد المزاد', value: formatDateTime(version.auction_starts_at) },
      { label: 'مكان المزاد', value: version.auction_venue, wide: true },
      { label: 'منطقة المزاد', value: lookupName(lookups?.regions, version.auction_region_id) },
      { label: 'مدينة المزاد', value: lookupName(lookups?.cities, version.auction_city_id) },
      {
        label: 'إحداثيات المزاد',
        value: hasGeo ? (
          <span className="row">
            <span className="ltr mono" dir="ltr">
              {version.auction_lat}, {version.auction_lng}
            </span>
            <a href={osmUrl(version.auction_lat as number, version.auction_lng as number)} target="_blank" rel="noopener noreferrer">
              فتح في OpenStreetMap
            </a>
          </span>
        ) : null,
      },
    )
  } else {
    items.push({ label: 'السعر', value: formatPrice(version.price) })
  }
  items.push(
    { label: 'رقم الاتصال', value: <Phone value={version.contact_phone} /> },
    { label: 'رقم واتساب', value: <Phone value={version.contact_whatsapp_phone} /> },
    {
      label: 'رقم النسخة',
      value: (
        <span className="row">
          <span>{version.version_no}</span>
          <Badge tone="neutral">{label(VERSION_STATUS_LABELS, version.status)}</Badge>
        </span>
      ),
    },
    { label: 'أنشئت', value: formatDateTime(version.created_at) },
    { label: 'أرسلت', value: formatDateTime(version.submitted_at) },
  )
  if (version.status === 'APPROVED') items.push({ label: 'نشرت', value: formatDateTime(version.decided_at) })
  items.push(
    {
      label: 'بصمة المحتوى',
      value: version.content_hash ? (
        <span className="small ltr mono" dir="ltr" style={{ overflowWrap: 'anywhere' }}>
          {version.content_hash}
        </span>
      ) : null,
      wide: true,
    },
  )

  return (
    <div className="stack">
      <KeyValue items={items} />
      <h3>الوسائط</h3>
      <MediaGallery media={media} />
    </div>
  )
}
