import { useState } from 'react'
import { Link, useParams } from 'react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useCan } from '@admin/auth/AuthContext'
import { toApiError } from '@admin/lib/errors'
import { formatDateTime, formatNumber } from '@admin/lib/format'
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
import { accountKeys, formatLoginPhone, getAccount, isUuid, listingsSearchHref, reactivateAccount, suspendAccount } from './api'
import { useRegionName, useSuspendReasonLabel } from './hooks'
import type { AdminAccount } from './types'

/** حالات الإعلان المعروضة في العدادات. لا «قيد المراجعة» (TEAM-DEC-013)؛ «مرفوض» القديم عند وجوده فقط. */
const COUNT_STATUSES = ['PUBLISHED', 'HIDDEN', 'DRAFT', 'ARCHIVED'] as const
const LEGACY_COUNT_STATUSES = ['REJECTED'] as const

const LISTINGS_CAPS = ['listings.review', 'listings.hide'] as const

function count(acc: AdminAccount, status: string): number {
  const n = acc.listing_counts?.[status]
  return typeof n === 'number' ? n : 0
}

function displayName(acc: AdminAccount): string | null {
  const n = acc.display_name?.trim()
  return n ? n : null
}

/** تفاصيل حساب مع هاتف الدخول وأعداد إعلاناته، وتعليقه أو إعادة تفعيله (AD-FR-018). */
export default function AccountDetailPage() {
  const { userId = '' } = useParams()
  const validId = isUuid(userId)
  const queryClient = useQueryClient()
  const notify = useNotify()
  const canManage = useCan('accounts.manage')
  const canSeeListings = useCan(LISTINGS_CAPS)
  const regionName = useRegionName()
  const reasonLabel = useSuspendReasonLabel()
  const [dialog, setDialog] = useState<'suspend' | 'reactivate' | null>(null)

  const detail = useQuery({
    queryKey: accountKeys.detail(userId),
    queryFn: () => getAccount(userId),
    enabled: validId,
  })

  function onActionError(err: unknown) {
    // الحالة تغيرت أو الحساب لم يعد موجودًا: نعرض الرسالة (في الحوار) ونحدث التفاصيل دون إعادة المحاولة.
    const code = toApiError(err).code
    if (code === 'INVALID_STATE' || code === 'NOT_FOUND' || code === 'VERSION_CHANGED') {
      void queryClient.invalidateQueries({ queryKey: accountKeys.detail(userId) })
    }
  }

  async function onActionSuccess(acc: AdminAccount) {
    if (acc && typeof acc === 'object' && acc.id) queryClient.setQueryData(accountKeys.detail(userId), acc)
    await Promise.all([
      queryClient.invalidateQueries({ queryKey: accountKeys.all }),
      // التعليق يخفي الإعلانات المنشورة؛ قوائم الإعلانات تحتاج تحديثًا.
      queryClient.invalidateQueries({ queryKey: ['admin', 'listings'] }),
    ])
  }

  const suspend = useMutation({
    mutationFn: (v: { reason_code: string; reason_text: string | undefined }) => suspendAccount(userId, v.reason_code, v.reason_text),
    retry: false,
    onError: onActionError,
    onSuccess: async (acc) => {
      await onActionSuccess(acc)
      notify.success('تم تعليق الحساب وإخفاء إعلاناته المنشورة.')
    },
  })

  const reactivate = useMutation({
    mutationFn: (note: string | undefined) => reactivateAccount(userId, note),
    retry: false,
    onError: onActionError,
    onSuccess: async (acc) => {
      await onActionSuccess(acc)
      notify.success('أعيد تفعيل الحساب. إعلاناته المخفية لم يُعد نشرها؛ كل إعلان يحتاج قرار إعادة إظهار منفصلًا.')
    },
  })

  const crumbs = [{ label: 'الحسابات', to: '/admin/accounts' }, { label: 'تفاصيل الحساب' }]

  if (!validId || (detail.isError && toApiError(detail.error).code === 'NOT_FOUND')) {
    return (
      <div className="page">
        <PageHeader title="تفاصيل الحساب" crumbs={crumbs} />
        <EmptyState title="الحساب غير موجود">
          <p>لا يوجد حساب بهذا المعرف، أو أن الرابط غير صحيح.</p>
          <Link to="/admin/accounts">العودة إلى الحسابات</Link>
        </EmptyState>
      </div>
    )
  }

  if (detail.isPending) {
    return (
      <div className="page">
        <PageHeader title="تفاصيل الحساب" crumbs={crumbs} />
        <Loading />
      </div>
    )
  }

  if (detail.isError) {
    return (
      <div className="page">
        <PageHeader title="تفاصيل الحساب" crumbs={crumbs} />
        <ErrorState error={detail.error} onRetry={() => void detail.refetch()} />
      </div>
    )
  }

  const acc = detail.data
  const name = displayName(acc)
  const phone = formatLoginPhone(acc.phone)
  const suspended = acc.status === 'SUSPENDED'
  const published = count(acc, 'PUBLISHED')
  const hidden = count(acc, 'HIDDEN')
  const total = Object.values(acc.listing_counts ?? {}).reduce<number>((n, v) => n + (typeof v === 'number' ? v : 0), 0)
  const shownStatuses = [...COUNT_STATUSES, ...LEGACY_COUNT_STATUSES.filter((s) => count(acc, s) > 0)]
  const hiddenHref = name ? listingsSearchHref(name, 'HIDDEN') : null
  const allHref = name ? listingsSearchHref(name) : null

  const hiddenLink =
    canSeeListings && hiddenHref ? (
      <Link to={hiddenHref}>عرض الإعلانات المخفية</Link>
    ) : null

  return (
    <div className="page">
      <PageHeader
        title={name ?? 'بدون اسم'}
        description={
          <span className="row">
            <Badge tone={accountStatusTone(acc.status)}>{label(ACCOUNT_STATUS_LABELS, acc.status)}</Badge>
            <span className="ltr mono small">{acc.id}</span>
          </span>
        }
        crumbs={[{ label: 'الحسابات', to: '/admin/accounts' }, { label: name ?? 'بدون اسم' }]}
        actions={
          canManage ? (
            acc.status === 'ACTIVE' ? (
              <Button variant="danger" onClick={() => setDialog('suspend')}>
                تعليق الحساب
              </Button>
            ) : suspended ? (
              <Button variant="primary" onClick={() => setDialog('reactivate')}>
                إعادة التفعيل
              </Button>
            ) : null
          ) : null
        }
      />

      {detail.isFetching && <p className="muted small" role="status">جارٍ تحديث البيانات…</p>}

      {suspended && (
        <Alert tone="danger" title="الحساب معلق">
          <KeyValue
            items={[
              { label: 'سبب التعليق', value: reasonLabel(acc.suspension_reason_code) },
              { label: 'تاريخ التعليق', value: formatDateTime(acc.status_changed_at) },
              { label: 'التوضيح', value: acc.suspension_reason_text, wide: true },
            ]}
          />
          <p className="small">
            إعادة التفعيل لا تعيد نشر الإعلانات المخفية؛ كل إعلان يحتاج قرار إعادة إظهار منفصلًا. {hiddenLink}
          </p>
        </Alert>
      )}

      {!suspended && hidden > 0 && (
        <Alert tone="info" title="إعلانات مخفية">
          <p>
            لهذا الحساب {formatNumber(hidden)} {hidden === 1 ? 'إعلان مخفي' : 'إعلانات مخفية'}. إعادة تفعيل الحساب لا تعيد نشرها؛ كل إعلان
            يحتاج قرار إعادة إظهار منفصلًا من «إدارة الإعلانات». {hiddenLink}
          </p>
        </Alert>
      )}

      <div className="grid grid-2">
        <Card title="بيانات الحساب">
          <KeyValue
            items={[
              { label: 'اسم العرض', value: name ?? 'بدون اسم' },
              { label: 'الحالة', value: <Badge tone={accountStatusTone(acc.status)}>{label(ACCOUNT_STATUS_LABELS, acc.status)}</Badge> },
              { label: 'المنطقة', value: regionName(acc.region_id) },
              { label: 'تاريخ الانضمام', value: formatDateTime(acc.created_at) },
              { label: 'آخر تغيير للحالة', value: formatDateTime(acc.status_changed_at) },
              { label: 'معرف الحساب', value: <span className="ltr mono">{acc.id}</span>, wide: true },
            ]}
          />
        </Card>

        <Card title="هاتف الدخول">
          <div className="stack">
            <p className="ltr mono" aria-label="رقم هاتف الدخول">
              {phone ?? '—'}
            </p>
            <p className="muted small">بيانات خاصة: تظهر لمن يملك صلاحية إدارة الحسابات فقط. لا تنسخها أو تشاركها خارج اللوحة.</p>
          </div>
        </Card>
      </div>

      <Card
        title="إعلانات الحساب"
        actions={
          canSeeListings && allHref ? (
            <Link to={allHref} className="btn btn-secondary btn-sm">
              عرض إعلانات الحساب
            </Link>
          ) : null
        }
      >
        <div className="grid grid-4">
          {shownStatuses.map((s) => (
            <div key={s} className="stat">
              <div className="stat-label">
                <Badge tone={listingStatusTone(s)}>{label(LISTING_STATUS_LABELS, s)}</Badge>
              </div>
              <div className="stat-value" data-testid={`count-${s}`}>
                {formatNumber(count(acc, s))}
              </div>
            </div>
          ))}
          <div className="stat">
            <div className="stat-label">الإجمالي</div>
            <div className="stat-value" data-testid="count-total">
              {formatNumber(total)}
            </div>
            <div className="stat-hint">دون المحذوفة</div>
          </div>
        </div>
        {canSeeListings && (
          <p className="muted small">
            {name
              ? 'روابط الإعلانات تبحث باسم العرض، فقد تظهر معها إعلانات حسابات بأسماء مشابهة أو عناوين تحوي الاسم.'
              : 'لا اسم عرض لهذا الحساب، فلا يمكن البحث عن إعلاناته من «إدارة الإعلانات» حاليًا.'}
          </p>
        )}
      </Card>

      <ReasonDialog
        open={dialog === 'suspend'}
        action="ACCOUNT_SUSPEND"
        title="تعليق الحساب"
        description={`التعليق يخفي كل إعلانات الحساب المنشورة (${formatNumber(published)} حاليًا) ويُشعر صاحبه بالسبب. إعادة التفعيل لاحقًا لا تعيد نشرها تلقائيًا.`}
        confirmLabel="تعليق الحساب"
        tone="danger"
        onClose={() => setDialog(null)}
        onSubmit={(v) => suspend.mutateAsync(v)}
      />

      <ConfirmDialog
        open={dialog === 'reactivate'}
        title="إعادة تفعيل الحساب"
        confirmLabel="إعادة التفعيل"
        tone="primary"
        message={
          <div className="stack">
            <p>يعود الحساب فعالًا ويستطيع صاحبه استخدام التطبيق من جديد.</p>
            <Alert tone="warning" title="لا يعاد نشر الإعلانات">
              إعادة التفعيل لا تعيد نشر إعلانات الحساب المخفية ({formatNumber(hidden)}). كل إعلان مخفي يحتاج قرار إعادة إظهار منفصلًا من «إدارة الإعلانات».{' '}
              {hiddenLink}
            </Alert>
          </div>
        }
        noteLabel="ملاحظة داخلية (اختيارية)"
        noteHint="تحفظ في سجل الإجراءات ولا تصل صاحب الحساب."
        onClose={() => setDialog(null)}
        onConfirm={(note) => reactivate.mutateAsync(note)}
      />
    </div>
  )
}
