import { useState, type CSSProperties, type FormEvent, type ReactNode } from 'react'
import { Link } from 'react-router'
import { useQuery } from '@tanstack/react-query'
import { useAuth } from '@admin/auth/AuthContext'
import { ROLE_LABELS, CAPABILITY_LABELS } from '@admin/lib/capabilities'
import { rpc } from '@admin/lib/rpc'
import { toApiError } from '@admin/lib/errors'
import { formatDate, formatDateTime, formatNumber } from '@admin/lib/format'
import { NAV_ITEMS } from '@admin/routes'
import { Alert, Button, Card, EmptyState, ErrorState, Loading, PageHeader, TextField } from '@admin/ui'
import {
  defaultRange,
  MAX_RANGE_DAYS,
  presetRange,
  RANGE_PRESETS,
  rangeToArgs,
  validateRange,
  type RangeErrors,
  type RangePreset,
} from './dateRange'
import { buildReportView, type GroupShare, type PulseTile, type ReportGroupView, type StatTile } from './statsGroups'
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

  const choosePreset = (preset: RangePreset) => {
    const range = presetRange(preset)
    setErrors({})
    setDraft(range)
    if (sameRange(range, applied)) void query.refetch()
    else setApplied(range)
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
      <div className="ov-report">
        <div className="ov-range">
          <div className="ov-presets" role="group" aria-label="فترات جاهزة">
            {RANGE_PRESETS.map(({ preset, label }) => {
              const active = sameRange(presetRange(preset), applied)
              return (
                <button
                  key={String(preset)}
                  type="button"
                  className={active ? 'ov-preset is-active' : 'ov-preset'}
                  aria-pressed={active}
                  onClick={() => choosePreset(preset)}
                >
                  {label}
                </button>
              )
            })}
          </div>
          <form className="filters ov-custom" onSubmit={onSubmit} noValidate aria-label="فترة التقرير">
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
        </div>

        <StatsBody query={query} />

        <p className="muted small ov-footnote">
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
  const view = buildReportView(stats as Record<string, unknown>)
  return (
    <>
      {view.pulse.length > 0 && <PulseBand tiles={view.pulse} generatedAt={stats.generated_at} />}

      <div className="ov-period-head">
        <div>
          <h3 className="ov-period-title">خلال الفترة</h3>
          <PeriodSummary stats={stats} />
        </div>
        <dl className="ov-meta">
          <div>
            <dt>بداية الفترة</dt>
            <dd>{formatDateTime(stats.period?.from)}</dd>
          </div>
          <div>
            <dt>نهاية الفترة (غير مشمولة)</dt>
            <dd>{formatDateTime(stats.period?.to)}</dd>
          </div>
          <div>
            <dt>وقت التحديث</dt>
            <dd>{formatDateTime(stats.generated_at)}</dd>
          </div>
        </dl>
      </div>

      {view.groups.length === 0 && view.pulse.length === 0 ? (
        <EmptyState title="لا توجد مؤشرات في هذا الرد." />
      ) : (
        <div className="ov-groups">
          {view.groups.map((g) => (
            <GroupCard key={g.key} group={g} />
          ))}
        </div>
      )}
    </>
  )
}

/** «28 أكتوبر — 27 نوفمبر · 30 يومًا»: النهاية المعروضة آخر يوم مشمول. */
function PeriodSummary({ stats }: { stats: AdminStats }) {
  const from = stats.period?.from
  const toExclusive = stats.period?.to
  if (!from || !toExclusive) return null
  const lastIncluded = new Date(Date.parse(toExclusive) - 1)
  const days = Math.round((Date.parse(toExclusive) - Date.parse(from)) / 86_400_000)
  return (
    <p className="ov-period-range">
      {formatDate(from)} <span aria-hidden="true">←</span>
      <span className="sr-only">إلى</span> {formatDate(lastIncluded)}
      <span className="ov-days">{days === 1 ? 'يوم واحد' : `${formatNumber(days)} يومًا`}</span>
    </p>
  )
}

/** شريط «الوضع الآن»: لقطة عند وقت التحديث، لا تتأثر بالفترة. */
function PulseBand({ tiles, generatedAt }: { tiles: PulseTile[]; generatedAt: string }) {
  const hero = tiles.find((t) => t.hero)
  const rest = tiles.filter((t) => !t.hero)
  return (
    <section className="ov-pulse" aria-labelledby="ov-pulse-title">
      <svg className="ov-dunes" viewBox="0 0 800 220" preserveAspectRatio="none" aria-hidden="true" focusable="false">
        <path d="M0 150 C 120 110, 220 120, 330 150 S 560 200, 800 130" />
        <path d="M0 180 C 160 140, 300 150, 420 175 S 650 215, 800 165" />
        <path d="M0 205 C 140 185, 280 190, 400 205 S 640 225, 800 198" />
      </svg>
      <header className="ov-pulse-head">
        <span className="ov-live" aria-hidden="true" />
        <h3 id="ov-pulse-title">الوضع الآن</h3>
        <span className="ov-pulse-time">لقطة عند {formatDateTime(generatedAt)} · لا تتأثر بالفترة</span>
      </header>
      <div className="ov-pulse-grid">
        {hero && (
          <PulseLink tile={hero} className="ov-hero">
            <span className="ov-hero-label">{hero.label}</span>
            <span className="ov-hero-value">{formatNumber(hero.value)}</span>
            {hero.caption && <span className="ov-hero-caption">{hero.caption}</span>}
          </PulseLink>
        )}
        <div className="ov-pulse-cells">
          {rest.map((t) => (
            <PulseLink key={`${t.groupKey}.${t.key}`} tile={t} className={t.attention ? 'ov-cell ov-cell-attn' : 'ov-cell'}>
              <span className="ov-cell-label">{t.label}</span>
              <span className="ov-cell-value">{formatNumber(t.value)}</span>
              {t.attention && <AttentionState pending={t.value > 0} />}
            </PulseLink>
          ))}
        </div>
      </div>
    </section>
  )
}

function AttentionState({ pending }: { pending: boolean }) {
  return pending ? (
    <span className="ov-attn ov-attn-pending">
      <span aria-hidden="true">●</span> بانتظار المعالجة
    </span>
  ) : (
    <span className="ov-attn ov-attn-clear">
      <span aria-hidden="true">✓</span> لا شيء معلق
    </span>
  )
}

/** خلية اللقطة: رابط لقسمها لمن يملك قدرته، وإلا نص فقط. */
function PulseLink({ tile, className, children }: { tile: PulseTile; className: string; children: ReactNode }) {
  const { can } = useAuth()
  const testId = `stat-${tile.groupKey}.${tile.key}`
  if (can(tile.caps)) {
    return (
      <Link to={tile.to} className={`${className} ov-linked`} data-testid={testId}>
        {children}
        <span className="ov-go" aria-hidden="true">
          ←
        </span>
      </Link>
    )
  }
  return (
    <div className={className} data-testid={testId}>
      {children}
    </div>
  )
}

function GroupCard({ group }: { group: ReportGroupView }) {
  const headingId = `overview-group-${group.key}`
  // شريط نسبي فقط حين تقارن المجموعة عددين أو أكثر؛ الشريط الوحيد يملأ نفسه بلا معنى.
  const showBars = group.tiles.length > 1
  return (
    <section aria-labelledby={headingId} className={`ov-group ov-group-${group.key}`}>
      <header className="ov-group-head">
        <span className="ov-medal" aria-hidden="true">
          {group.icon ?? '◆'}
        </span>
        <h3 id={headingId} className={group.raw ? 'ltr mono' : undefined}>
          {group.title}
        </h3>
      </header>
      <ul className="ov-rows">
        {group.tiles.map((t) => (
          <StatRow key={t.key} groupKey={group.key} tile={t} max={group.max} showBar={showBars} />
        ))}
      </ul>
      {group.share && <ShareMeter share={group.share} />}
      {group.note && (
        <p className="ov-note">
          <span aria-hidden="true">ⓘ</span> {group.note}
        </p>
      )}
    </section>
  )
}

function StatRow({ groupKey, tile, max, showBar }: { groupKey: string; tile: StatTile; max: number; showBar: boolean }) {
  const ratio = max > 0 ? tile.value / max : 0
  return (
    <li className={tile.raw ? 'ov-row overview-stat-raw' : 'ov-row'} data-testid={`stat-${groupKey}.${tile.key}`}>
      <span className="ov-row-label stat-label">{tile.label}</span>
      <span className="ov-row-value">{formatNumber(tile.value)}</span>
      {showBar && (
        <span className="ov-track" aria-hidden="true">
          <span className="ov-fill" style={{ '--ov-w': ratio } as CSSProperties} />
        </span>
      )}
      {tile.raw && <span className="ov-row-hint">مؤشر جديد من الخادم</span>}
    </li>
  )
}

function ShareMeter({ share }: { share: GroupShare }) {
  const pct = Math.round(share.ratio * 100)
  const text = `${share.ratio > 0 && pct === 0 ? 'أقل من 1' : formatNumber(pct)}٪ ${share.label}`
  return (
    <div className="ov-share">
      <div className="ov-meter" role="meter" aria-valuemin={0} aria-valuemax={100} aria-valuenow={pct} aria-label={text}>
        <span className="ov-meter-fill" style={{ '--ov-w': share.ratio } as CSSProperties} />
      </div>
      <p className="ov-share-text">{text}</p>
    </div>
  )
}
