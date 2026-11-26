import { useState, type KeyboardEvent } from 'react'
import { Link, useParams } from 'react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuth, useCan } from '@admin/auth/AuthContext'
import { rpc } from '@admin/lib/rpc'
import { toApiError } from '@admin/lib/errors'
import { formatDateTime, formatNumber, shortId } from '@admin/lib/format'
import { ACCOUNT_STATUS_LABELS, LISTING_STATUS_LABELS, label } from '@admin/lib/labels'
import {
  Alert,
  Badge,
  Button,
  Card,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  KeyValue,
  Loading,
  PageHeader,
  ReasonDialog,
  accountStatusTone,
  listingStatusTone,
  useNotify,
} from '@admin/ui'
import { fetchListingExtras, fetchListingReview, listingKeys, useLookupNames, useReasonLabels } from './api'
import { decisionLabel, isAutoPublish, latestHide } from './helpers'
import { VersionContent } from './VersionContent'
import type { ListingAdmin, ListingMedia, ListingReview, ListingVersion, LookupNames } from './types'
import './listings.css'

/** رموز تعني أن الحالة تغيرت على الخادم: تعرض الرسالة ويعاد التحميل دون إعادة المحاولة. */
const STALE_CODES = new Set(['INVALID_STATE', 'VERSION_CHANGED', 'NOT_FOUND'])

interface VersionTab {
  key: string
  title: string
  version: ListingVersion
  media: ListingMedia[] | null
}

function VersionTabs({ tabs, lookups }: { tabs: VersionTab[]; lookups: LookupNames | undefined }) {
  const [active, setActive] = useState(0)
  const current = tabs[Math.min(active, tabs.length - 1)]
  if (!current) return <p className="muted">لا يوجد محتوى لهذا الإعلان.</p>
  if (tabs.length === 1) return <VersionContent version={current.version} media={current.media} lookups={lookups} />

  function onKey(e: KeyboardEvent<HTMLButtonElement>, i: number) {
    // RTL: السهم الأيسر للتالي.
    if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') {
      e.preventDefault()
      const delta = e.key === 'ArrowLeft' ? 1 : -1
      const next = (i + delta + tabs.length) % tabs.length
      setActive(next)
      document.getElementById(`listing-tab-${tabs[next]?.key}`)?.focus()
    }
  }

  return (
    <div>
      <div className="tabs" role="tablist" aria-label="نسخ الإعلان">
        {tabs.map((t, i) => (
          <button
            key={t.key}
            id={`listing-tab-${t.key}`}
            type="button"
            role="tab"
            className="tab"
            aria-selected={i === active}
            aria-controls={`listing-panel-${t.key}`}
            tabIndex={i === active ? 0 : -1}
            onClick={() => setActive(i)}
            onKeyDown={(e) => onKey(e, i)}
          >
            {t.title}
          </button>
        ))}
      </div>
      <div className="listing-tabpanel" role="tabpanel" id={`listing-panel-${current.key}`} aria-labelledby={`listing-tab-${current.key}`}>
        <VersionContent version={current.version} media={current.media} lookups={lookups} />
      </div>
    </div>
  )
}

function History({ reviews, ownerId, myId, reasonLabels }: { reviews: ListingReview[]; ownerId: string; myId: string | undefined; reasonLabels: Map<string, string> | undefined }) {
  if (reviews.length === 0) return <p className="muted">لا توجد قرارات مسجلة.</p>
  return (
    <ol className="timeline">
      {reviews.map((r) => {
        const auto = isAutoPublish(r)
        return (
          <li key={r.id}>
            <div className="row">
              <Badge tone={r.decision === 'HIDDEN' ? 'danger' : r.decision === 'UNHIDDEN' ? 'success' : auto ? 'info' : 'neutral'}>{decisionLabel(r)}</Badge>
              <span className="small">{formatDateTime(r.created_at)}</span>
              {r.version_id && (
                <span className="small muted">
                  النسخة <span className="mono ltr" dir="ltr">{shortId(r.version_id)}</span>
                </span>
              )}
            </div>
            {auto ? (
              <p className="small muted">نشر عند إرسال المعلن دون قرار موظف.</p>
            ) : (
              <>
                <p className="small muted">
                  الموظف:{' '}
                  {r.moderator_id ? (
                    <span className="mono ltr" dir="ltr">
                      {shortId(r.moderator_id)}
                    </span>
                  ) : (
                    '—'
                  )}
                  {r.moderator_id && r.moderator_id === myId && ' (أنت)'}
                  {r.moderator_id && r.moderator_id === ownerId && ' (المعلن)'}
                </p>
                {r.reason_code && <p className="small">السبب: {reasonLabels?.get(r.reason_code) ?? r.reason_code}</p>}
                {r.reason_text && (
                  <p className="small">
                    {r.decision === 'UNHIDDEN' ? 'ملاحظة داخلية: ' : 'التوضيح: '}
                    {r.reason_text}
                  </p>
                )}
              </>
            )}
          </li>
        )
      })}
    </ol>
  )
}

/** تفاصيل إعلان بأي حالة مع الإخفاء وإعادة الإظهار (INT-008، INT-007، AD-FR-018). */
export default function ListingDetailPage() {
  const { listingId = '' } = useParams()
  const { whoami } = useAuth()
  const canHide = useCan('listings.hide')
  const canAccounts = useCan('accounts.manage')
  const notify = useNotify()
  const qc = useQueryClient()
  const [dialog, setDialog] = useState<'hide' | 'unhide' | null>(null)

  const detail = useQuery({
    queryKey: listingKeys.detail(listingId),
    queryFn: () => fetchListingReview(listingId),
    enabled: Boolean(listingId),
  })
  const status = detail.data?.listing.status
  const extras = useQuery({
    queryKey: [...listingKeys.extras(listingId), status ?? ''],
    queryFn: () => fetchListingExtras(listingId, status === 'PUBLISHED'),
    enabled: Boolean(detail.data),
  })
  const lookups = useLookupNames()
  const reasonLabels = useReasonLabels()

  async function refreshAll() {
    await Promise.all([
      qc.invalidateQueries({ queryKey: listingKeys.detail(listingId) }),
      qc.invalidateQueries({ queryKey: listingKeys.extras(listingId) }),
      qc.invalidateQueries({ queryKey: listingKeys.lists }),
    ])
  }

  async function handleFailure(err: unknown): Promise<never> {
    const e = toApiError(err)
    if (STALE_CODES.has(e.code)) void refreshAll()
    throw e
  }

  const hide = useMutation({
    mutationFn: (v: { reason_code: string; reason_text: string | undefined }) =>
      rpc('admin_hide_listing', { p_listing_id: listingId, p_reason_code: v.reason_code, p_reason_text: v.reason_text }) as Promise<ListingAdmin>,
    onSuccess: async () => {
      await refreshAll()
      notify.success('أُخفي الإعلان وأُشعر المعلن بالسبب.')
    },
  })

  const unhide = useMutation({
    mutationFn: (note: string | undefined) => rpc('admin_unhide_listing', { p_listing_id: listingId, p_note: note }) as Promise<ListingAdmin>,
    onSuccess: async () => {
      await refreshAll()
      notify.success('أعيد إظهار الإعلان.')
    },
  })

  if (detail.isPending) {
    return (
      <div className="page">
        <PageHeader title="تفاصيل الإعلان" crumbs={[{ label: 'إدارة الإعلانات', to: '/admin/listings' }, { label: 'تفاصيل الإعلان' }]} />
        <Loading label="جارٍ تحميل الإعلان…" />
      </div>
    )
  }

  if (detail.isError) {
    const notFound = toApiError(detail.error).code === 'NOT_FOUND'
    return (
      <div className="page">
        <PageHeader title="تفاصيل الإعلان" crumbs={[{ label: 'إدارة الإعلانات', to: '/admin/listings' }, { label: 'تفاصيل الإعلان' }]} />
        {notFound ? (
          <EmptyState title="الإعلان غير موجود">
            <p>ربما أدخل رابط غير صحيح أو أزيل الإعلان.</p>
            <Link to="/admin/listings">العودة إلى إدارة الإعلانات</Link>
          </EmptyState>
        ) : (
          <ErrorState error={detail.error} onRetry={() => void detail.refetch()} />
        )}
      </div>
    )
  }

  const data = detail.data
  const { listing, owner } = data
  const reviews = data.reviews ?? []
  const lastHide = listing.status === 'HIDDEN' ? latestHide(reviews) : null
  const ownerSuspended = owner?.status === 'SUSPENDED'
  const deleted = Boolean(listing.deleted_at)
  const publicRef = extras.data?.public_ref ?? null

  // «منشورة» و«تعديل غير منشور» لا يصدقان إلا لإعلان منشور أو مخفي؛ المسودة والمؤرشف والمرفوض القديم
  // قد يحملون published_version_id من نشر سابق دون أن يرى الجمهور شيئًا.
  const live = listing.status === 'PUBLISHED' || listing.status === 'HIDDEN'
  const tabs: VersionTab[] = []
  if (data.published_version) {
    tabs.push({ key: 'published', title: live ? 'النسخة المنشورة' : 'آخر نسخة نُشرت', version: data.published_version, media: data.published_media })
    if (data.version) tabs.push({ key: 'draft', title: live ? 'تعديل غير منشور' : 'النسخة الحالية', version: data.version, media: data.media })
  } else if (data.version) {
    const isPublished = live && data.version.id === listing.published_version_id
    tabs.push({ key: 'current', title: isPublished ? 'النسخة المنشورة' : 'النسخة الحالية', version: data.version, media: data.media })
  }
  const title = (data.published_version ?? data.version)?.title || 'بلا عنوان'
  const hasDraft = live && Boolean(data.published_version && data.version)

  const actions =
    canHide && (listing.status === 'PUBLISHED' || listing.status === 'HIDDEN') ? (
      <>
        {listing.status === 'PUBLISHED' && (
          <Button variant="danger" onClick={() => setDialog('hide')}>
            إخفاء الإعلان
          </Button>
        )}
        {listing.status === 'HIDDEN' && (
          <Button
            variant="primary"
            onClick={() => setDialog('unhide')}
            disabled={ownerSuspended || deleted}
            title={ownerSuspended ? 'فعّل حساب المعلن أولًا' : deleted ? 'الإعلان محذوف من المعلن' : undefined}
          >
            إعادة الإظهار
          </Button>
        )}
      </>
    ) : undefined

  const listingItems = [
    {
      label: 'الحالة',
      value: (
        <span className="row">
          <Badge tone={listingStatusTone(listing.status)}>{label(LISTING_STATUS_LABELS, listing.status)}</Badge>
          {hasDraft && <Badge tone="info">تعديل غير منشور</Badge>}
          {deleted && <Badge tone="neutral">حذفه المعلن</Badge>}
        </span>
      ),
    },
    {
      label: 'المعرف العام',
      value: publicRef ? (
        <span className="ltr mono" dir="ltr">
          {publicRef}
        </span>
      ) : null,
    },
    {
      label: 'معرف الإعلان',
      value: (
        <span className="ltr mono small" dir="ltr">
          {listing.id}
        </span>
      ),
    },
    { label: 'أنشئ', value: formatDateTime(listing.created_at) },
    { label: 'أول نشر', value: formatDateTime(listing.first_published_at) },
    { label: 'آخر نشر', value: formatDateTime(listing.last_published_at) },
    { label: 'آخر تجديد للظهور', value: formatDateTime(listing.last_bumped_at) },
    { label: 'آخر تغيير للحالة', value: formatDateTime(listing.status_changed_at) },
  ]
  if (deleted) listingItems.push({ label: 'حذف في', value: formatDateTime(listing.deleted_at) })
  if (extras.data?.comments_closed !== null && extras.data?.comments_closed !== undefined) {
    listingItems.push({ label: 'الردود العامة', value: extras.data.comments_closed ? 'مغلقة' : 'مفتوحة' })
  }
  if (extras.data?.view_count !== null && extras.data?.view_count !== undefined) {
    listingItems.push({ label: 'المشاهدات', value: formatNumber(extras.data.view_count) })
  }
  if (extras.data?.favorite_count !== null && extras.data?.favorite_count !== undefined) {
    listingItems.push({ label: 'مرات الحفظ في المفضلة', value: formatNumber(extras.data.favorite_count) })
  }

  const ownerName = owner?.display_name || 'بلا اسم'

  return (
    <div className="page">
      <PageHeader title={title} crumbs={[{ label: 'إدارة الإعلانات', to: '/admin/listings' }, { label: title }]} actions={actions} />

      {listing.status === 'HIDDEN' && (
        <Alert tone="warning" title="الإعلان مخفي عن الجمهور">
          {lastHide ? (
            <div className="stack">
              <span>السبب: {lastHide.reason_code ? (reasonLabels.data?.get(lastHide.reason_code) ?? lastHide.reason_code) : '—'}</span>
              {lastHide.reason_text && <span>التوضيح: {lastHide.reason_text}</span>}
              <span className="small">أخفي في {formatDateTime(lastHide.created_at)}</span>
            </div>
          ) : (
            <span>لا يوجد سبب مسجل (ربما أخفي بتعليق حساب المعلن).</span>
          )}
        </Alert>
      )}
      {listing.status === 'HIDDEN' && ownerSuspended && (
        <Alert tone="danger" title="حساب المعلن معلق">
          لا تقبل إعادة إظهار الإعلان ما دام حساب المعلن معلقًا. فعّل الحساب أولًا ثم أعد إظهار الإعلان بقرار منفصل.
        </Alert>
      )}
      {listing.status === 'HIDDEN' && deleted && <Alert tone="info">حذف المعلن هذا الإعلان، فلا يمكن إعادة إظهاره.</Alert>}

      <div className="grid grid-2">
        <Card title="بيانات الإعلان">
          <KeyValue items={listingItems} />
        </Card>
        <Card title="المعلن">
          {owner ? (
            <KeyValue
              items={[
                {
                  label: 'الاسم',
                  value: canAccounts ? <Link to={`/admin/accounts/${owner.id}`}>{ownerName}</Link> : ownerName,
                },
                { label: 'حالة الحساب', value: <Badge tone={accountStatusTone(owner.status)}>{label(ACCOUNT_STATUS_LABELS, owner.status)}</Badge> },
                { label: 'منطقة المعلن', value: owner.region_id !== null ? (lookups.data?.regions.get(owner.region_id) ?? `#${owner.region_id}`) : null },
                { label: 'انضم', value: formatDateTime(owner.created_at) },
              ]}
            />
          ) : (
            <p className="muted">لا تتوفر بيانات المعلن.</p>
          )}
        </Card>
      </div>

      <Card title="محتوى الإعلان">
        {hasDraft && (
          <Alert tone="info">
            {listing.status === 'HIDDEN'
              ? 'لدى المعلن تعديل خاص لم يرسل بعد. الإعلان مخفي حاليًا فلا يرى الجمهور أيًا من النسختين.'
              : 'لدى المعلن تعديل خاص لم يرسل بعد؛ الجمهور يرى النسخة المنشورة فقط.'}
          </Alert>
        )}
        <VersionTabs key={tabs.map((t) => t.version.id).join(':')} tabs={tabs} lookups={lookups.data} />
      </Card>

      <Card title="سجل القرارات">
        <History reviews={reviews} ownerId={listing.owner_id} myId={whoami?.user_id} reasonLabels={reasonLabels.data} />
      </Card>

      <ReasonDialog
        open={dialog === 'hide'}
        action="LISTING_HIDE"
        title="إخفاء الإعلان"
        description="سيختفي الإعلان عن الجمهور فورًا، ويُشعَر المعلن بالسبب والتوضيح."
        confirmLabel="إخفاء الإعلان"
        tone="danger"
        onClose={() => setDialog(null)}
        onSubmit={(v) => hide.mutateAsync(v).catch(handleFailure)}
      />
      <ConfirmDialog
        open={dialog === 'unhide'}
        title="إعادة إظهار الإعلان"
        message="سيعود الإعلان منشورًا ويظهر للجمهور."
        confirmLabel="إعادة الإظهار"
        noteLabel="ملاحظة داخلية (اختيارية)"
        noteHint="للسجل الداخلي فقط ولا تصل إلى المعلن."
        onClose={() => setDialog(null)}
        onConfirm={(note) => unhide.mutateAsync(note).catch(handleFailure)}
      />
    </div>
  )
}
