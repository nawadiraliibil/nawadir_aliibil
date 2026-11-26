import { useState } from 'react'
import { Badge } from '@admin/ui'
import { label } from '@admin/lib/labels'
import { useSignedUrl } from './api'
import { MEDIA_STATUS_LABELS, formatBytes } from './helpers'
import type { ListingMedia, StorageRef } from './types'

function ThumbPlaceholder({ text = 'بلا صورة' }: { text?: string }) {
  return (
    <span className="thumb listing-thumb-empty" role="img" aria-label={text}>
      <span aria-hidden="true">▧</span>
    </span>
  )
}

/** صورة الغلاف المصغرة في القائمة: رابط موقع لكل صف، وبديل عند غيابها أو فشلها. */
export function CoverThumb({ cover, alt }: { cover: StorageRef | null; alt: string }) {
  const signed = useSignedUrl(cover?.bucket, cover?.object_path)
  // الفشل يخص رابطًا بعينه؛ الرابط المجدد يعاد تجربته.
  const [brokenUrl, setBrokenUrl] = useState<string | null>(null)
  const broken = brokenUrl !== null && brokenUrl === signed.data
  if (!cover) return <ThumbPlaceholder />
  if (signed.isError || broken) return <ThumbPlaceholder text="تعذر تحميل الصورة" />
  if (!signed.data) return <span className="thumb" aria-hidden="true" />
  return <img className="thumb" src={signed.data} alt={alt} loading="lazy" onError={() => setBrokenUrl(signed.data ?? null)} />
}

function MediaTile({ media, index }: { media: ListingMedia; index: number }) {
  const signed = useSignedUrl(media.bucket, media.object_path)
  const [brokenUrl, setBrokenUrl] = useState<string | null>(null)
  const broken = brokenUrl !== null && brokenUrl === signed.data
  const isVideo = media.kind === 'VIDEO'
  const name = `${isVideo ? 'فيديو' : 'صورة'} ${index + 1}`
  let body
  if (signed.isError || broken) {
    body = <div className="listing-media-missing">تعذر تحميل الملف</div>
  } else if (!signed.data) {
    body = <div className="listing-media-missing" aria-hidden="true" />
  } else if (isVideo) {
    body = (
      <video controls preload="metadata" src={signed.data} aria-label={name} onError={() => setBrokenUrl(signed.data ?? null)}>
        متصفحك لا يدعم تشغيل الفيديو.
      </video>
    )
  } else {
    body = <img src={signed.data} alt={name} loading="lazy" onError={() => setBrokenUrl(signed.data ?? null)} />
  }
  return (
    <figure className="listing-media-figure">
      <div className="media-tile">{body}</div>
      <figcaption className="row small">
        <span>{name}</span>
        {media.is_cover && <Badge tone="gold">الغلاف</Badge>}
        {media.status !== 'READY' && <Badge tone={media.status === 'FAILED' ? 'danger' : 'warning'}>{label(MEDIA_STATUS_LABELS, media.status)}</Badge>}
        <span className="muted">{formatBytes(media.size_bytes)}</span>
      </figcaption>
    </figure>
  )
}

export function MediaGallery({ media }: { media: ListingMedia[] | null }) {
  const items = [...(media ?? [])].sort((a, b) => a.sort_order - b.sort_order)
  if (items.length === 0) return <p className="muted">لا توجد وسائط في هذه النسخة.</p>
  return (
    <div className="media-grid">
      {items.map((m, i) => (
        <MediaTile key={m.id} media={m} index={i} />
      ))}
    </div>
  )
}
