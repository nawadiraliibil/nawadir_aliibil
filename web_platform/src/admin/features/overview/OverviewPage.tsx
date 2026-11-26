import { useState, type FormEvent } from 'react'
import { Link } from 'react-router'
import { useQuery } from '@tanstack/react-query'
import { useAuth } from '@admin/auth/AuthContext'
import { ROLE_LABELS, CAPABILITY_LABELS } from '@admin/lib/capabilities'
import { rpc } from '@admin/lib/rpc'
import { toApiError } from '@admin/lib/errors'
import { formatDateTime, formatNumber } from '@admin/lib/format'
import { NAV_ITEMS } from '@admin/routes'
import { Alert, Button, Card, EmptyState, ErrorState, KeyValue, Loading, PageHeader, TextField } from '@admin/ui'
import { defaultRange, MAX_RANGE_DAYS, rangeToArgs, validateRange, type RangeErrors } from './dateRange'
import { buildStatGroups, STAT_SCOPE_HINTS, type StatGroupView, type StatTile } from './statsGroups'
import type { AdminStats, DayRange } from './types'
import './overview.css'

/** الصفحة الرئيسية (/admin): ترحيب وروابط الأقسام المتاحة، والتقارير التجميعية لمن يملك stats.read (AD-FR-020). */
export default function OverviewPage() {
  const { whoami, can } = useAuth()
  const roleLabel = whoami ? ROLE_LABELS[whoami.role] : '—'
  const canStats = can('stats.read')

  return (
    <div className="page">
      <PageHeader
        title="الرئيسية"
        description={
          <>
            مرحبًا بك في لوحة إدارة نوادر الإبل. دورك: <strong>{roleLabel}</strong>
          </>
        }
      />
      <QuickLinks />
      {canStats ? (
        <StatsReport />
      ) : (
        <Alert tone="info" title="التقارير التجميعية">
          التقارير متاحة لمن يملك صلاحية «{CAPABILITY_LABELS['stats.read']}». استخدم الأقسام أعلاه لمتابعة مهامك.
        </Alert>
      )}
    </div>
  )
}

function QuickLinks() {
  const { can } = useAuth()
  const items = NAV_ITEMS.filter((item) => item.to !== '/admin' && can(item.caps))
  return (
    <Card title="الأقسام المتاحة لك">
      {items.length === 0 ? (
        <EmptyState title="لا توجد أقسام أخرى متاحة لدورك حاليًا." />
      ) : (
        <nav aria-label="الأقسام المتاحة">
          <ul className="grid grid-4 overview-links">
            {items.map((item) => (
              <li key={item.to}>
                <Link to={item.to} className="stat overview-link">
                  <span className="overview-link-icon" aria-hidden="true">
                    {item.icon}
                  </span>
                  <span>{item.label}</span>
                </Link>
              </li>
            ))}
          </ul>
        </nav>
      )}
    </Card>
  )
}

function sameRange(a: DayRange, b: DayRange): boolean {
  return a.from === b.from && a.to === b.to
}

function StatsReport() {
  const [draft, setDraft] = useState<DayRange>(() => defaultRange())
  const [applied, setApplied] = useState<DayRange>(draft)
  const [errors, setErrors] = useState<RangeErrors>({})

  const query = useQuery({
    queryKey: ['admin', 'overview', 'stats', applied.from, applied.to],
    queryFn: async () => (await rpc('admin_stats', rangeToArgs(applied))) as AdminStats,
  })

  const onSubmit = (e: FormEvent) => {
    e.preventDefault()
    const found = validateRange(draft)
    setErrors(found)
    if (found.from || found.to) return
    if (sameRange(draft, applied)) void query.refetch()
    else setApplied(draft)
  }

  return (
    <Card
      title="التقارير التجميعية"
      actions={
        <Button onClick={() => void query.refetch()} loading={query.isFetching} disabled={query.isPending && !query.isError}>
          تحديث
        </Button>
      }
    >
      <div className="stack">
        <form className="filters" onSubmit={onSubmit} noValidate aria-label="فترة التقرير">
          <TextField
            label="من يوم"
            type="date"
            value={draft.from}
            error={errors.from}
            onChange={(e) => setDraft((d) => ({ ...d, from: e.target.value }))}
          />
          <TextField
            label="إلى يوم"
            type="date"
            value={draft.to}
            error={errors.to}
            hint={`بتوقيت الرياض، وحتى ${MAX_RANGE_DAYS} يومًا.`}
            onChange={(e) => setDraft((d) => ({ ...d, to: e.target.value }))}
          />
          <Button type="submit" variant="primary" loading={query.isFetching}>
            عرض التقرير
          </Button>
        </form>

        <StatsBody query={query} />

        <p className="muted small">
          أعداد تجميعية فقط، دون نصوص رسائل أو بيانات أشخاص. أعداد التواصل والتفاعل ليست عمليات بيع.
        </p>
      </div>
    </Card>
  )
}

function StatsBody({ query }: { query: { data: AdminStats | undefined; isPending: boolean; isError: boolean; error: unknown; refetch: () => unknown } }) {
  if (query.isError) {
    const code = toApiError(query.error).code
    return (
      <ErrorState
        error={query.error}
        title={code === 'VALIDATION_FAILED' ? 'الفترة غير صالحة' : 'تعذر تحميل التقارير'}
        onRetry={() => void query.refetch()}
      />
    )
  }
  if (query.isPending || !query.data) return <Loading label="جارٍ تحميل التقارير…" />
  const stats = query.data
  const groups = buildStatGroups(stats as Record<string, unknown>)
  return (
    <div className="stack">
      <KeyValue
        items={[
          { label: 'بداية الفترة', value: formatDateTime(stats.period?.from) },
          { label: 'نهاية الفترة (غير مشمولة)', value: formatDateTime(stats.period?.to) },
          { label: 'وقت التحديث', value: formatDateTime(stats.generated_at) },
        ]}
      />
      <p className="muted small">
        «{STAT_SCOPE_HINTS.period}»: ما وقع من بداية الفترة حتى نهايتها. «{STAT_SCOPE_HINTS.now}» و«{STAT_SCOPE_HINTS.total}»: لقطة
        عند وقت التحديث لا تتأثر بالفترة.
      </p>
      {groups.length === 0 ? <EmptyState title="لا توجد مؤشرات في هذا الرد." /> : groups.map((g) => <StatGroup key={g.key} group={g} />)}
    </div>
  )
}

function StatGroup({ group }: { group: StatGroupView }) {
  const headingId = `overview-group-${group.key}`
  return (
    <section aria-labelledby={headingId} className="stack">
      <h3 id={headingId} className={group.raw ? 'ltr mono' : undefined}>
        {group.title}
      </h3>
      <div className="grid grid-4">
        {group.tiles.map((t) => (
          <StatTileView key={t.key} groupKey={group.key} tile={t} />
        ))}
      </div>
      {group.note && <Alert tone="info">{group.note}</Alert>}
    </section>
  )
}

function StatTileView({ groupKey, tile }: { groupKey: string; tile: StatTile }) {
  const testId = `stat-${groupKey}.${tile.key}`
  return (
    <div className={tile.raw ? 'stat overview-stat-raw' : 'stat'} data-testid={testId}>
      <div className="stat-label">{tile.label}</div>
      <div className="stat-value">{formatNumber(tile.value)}</div>
      <div className="stat-hint">{tile.scope ? STAT_SCOPE_HINTS[tile.scope] : 'مؤشر جديد من الخادم'}</div>
    </div>
  )
}
