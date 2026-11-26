import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router'
import { formatDate, formatNumber } from '@admin/lib/format'
import {
  Alert,
  Badge,
  Button,
  Card,
  CheckboxField,
  ConfirmDialog,
  DataTable,
  EmptyState,
  ErrorState,
  Loading,
  PageHeader,
  SelectField,
  TextField,
  useNotify,
  type Column,
} from '@admin/ui'
import { useDisplaySettings, usePromotions, useSaveDisplaySettings, useSetPromotionStatus, promotionsApi } from './api'
import { ACTION_LABELS, PLACEMENT_LABELS, STATE_LABELS, STATE_TONES, clickRate, effectiveState, validateFeedInterval } from './logic'
import { FEED_INTERVAL_MAX, FEED_INTERVAL_MIN, type EffectiveState, type Promotion, type PromotionStatus } from './types'
import './promotions.css'

/** تنبيه الوضع التجريبي: يظهر ما دامت الطبقة غير متصلة بالخادم (INT-010). */
export function MockModeAlert() {
  if (promotionsApi.mode !== 'mock') return null
  return (
    <Alert tone="warning" title="وضع تجريبي: غير متصل بالتطبيق بعد">
      الدعايات والإعدادات هنا تحفظ في هذا المتصفح فقط ولا تظهر في تطبيق الجوال. تتصل الشاشة بالخادم عند تسليم مطور الجوال
      لطلب التكامل INT-010 (جداول الدعايات ودوالها وعرضها في التطبيق).
    </Alert>
  )
}

const FILTERS = ['CURRENT', 'RUNNING', 'SCHEDULED', 'PAUSED', 'EXPIRED', 'ARCHIVED', 'ALL'] as const
type Filter = (typeof FILTERS)[number]
const FILTER_LABELS: Record<Filter, string> = {
  CURRENT: 'غير المؤرشفة',
  RUNNING: STATE_LABELS.RUNNING,
  SCHEDULED: STATE_LABELS.SCHEDULED,
  PAUSED: STATE_LABELS.PAUSED,
  EXPIRED: STATE_LABELS.EXPIRED,
  ARCHIVED: STATE_LABELS.ARCHIVED,
  ALL: 'الكل',
}

function matches(filter: Filter, state: EffectiveState): boolean {
  if (filter === 'ALL') return true
  if (filter === 'CURRENT') return state !== 'ARCHIVED'
  return filter === state
}

function DisplaySettingsCard() {
  const notify = useNotify()
  const query = useDisplaySettings()
  const save = useSaveDisplaySettings()
  const [enabled, setEnabled] = useState(true)
  const [interval, setIntervalText] = useState('8')
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (query.data) {
      setEnabled(query.data.enabled)
      setIntervalText(String(query.data.feed_interval))
    }
  }, [query.data])

  if (query.isPending) return <Loading />
  if (query.isError) return <ErrorState error={query.error} onRetry={() => void query.refetch()} />

  const dirty = enabled !== query.data.enabled || interval !== String(query.data.feed_interval)

  async function onSave(e: FormEvent) {
    e.preventDefault()
    const n = Number(interval)
    const problem = validateFeedInterval(n)
    setError(problem)
    if (problem) return
    await save.mutateAsync({ enabled, feed_interval: n })
    notify.success('حُفظت إعدادات العرض.')
  }

  return (
    <Card title="العرض في التطبيق">
      <form className="filters" onSubmit={(e) => void onSave(e)} noValidate aria-label="إعدادات عرض الدعايات">
        <TextField
          label="دعاية بعد كل"
          type="number"
          inputMode="numeric"
          min={FEED_INTERVAL_MIN}
          max={FEED_INTERVAL_MAX}
          value={interval}
          onChange={(e) => setIntervalText(e.target.value)}
          hint={`إعلانات من إعلانات المستخدمين (${FEED_INTERVAL_MIN} إلى ${FEED_INTERVAL_MAX}).`}
          error={error}
        />
        <CheckboxField label="عرض الدعايات في التطبيق" checked={enabled} onChange={(e) => setEnabled(e.target.checked)} />
        <Button type="submit" variant="primary" loading={save.isPending} disabled={!dirty}>
          حفظ الإعدادات
        </Button>
      </form>
    </Card>
  )
}

function Period({ p }: { p: Promotion }) {
  return (
    <span className="small">
      {formatDate(p.starts_at)} ← {p.ends_at ? formatDate(new Date(new Date(p.ends_at).getTime() - 1)) : 'بلا نهاية'}
    </span>
  )
}

/** قائمة الدعايات التجارية (TEAM-DEC-017، INT-010). */
export default function PromotionsPage() {
  const navigate = useNavigate()
  const notify = useNotify()
  const [params, setParams] = useSearchParams()
  const raw = params.get('state')
  const filter: Filter = raw && (FILTERS as readonly string[]).includes(raw) ? (raw as Filter) : 'CURRENT'
  const query = usePromotions()
  const setStatus = useSetPromotionStatus()
  const [archiving, setArchiving] = useState<Promotion | null>(null)
  const now = useMemo(() => new Date(), [query.dataUpdatedAt])

  async function changeStatus(p: Promotion, status: PromotionStatus, message: string) {
    await setStatus.mutateAsync({ id: p.id, status })
    notify.success(message)
  }

  const rows = (query.data ?? []).filter((p) => matches(filter, effectiveState(p, now)))

  const columns: Column<Promotion>[] = [
    {
      key: 'image',
      header: 'الصورة',
      render: (p) => <img className="promo-thumb" src={p.image_path} alt="" loading="lazy" />,
    },
    {
      key: 'title',
      header: 'الدعاية',
      render: (p) => (
        <div className="stack" style={{ gap: 2 }}>
          <Link to={`/admin/promotions/${p.id}`} onClick={(e) => e.stopPropagation()}>
            {p.title}
          </Link>
          <span className="muted small">
            {p.advertiser_name} · {ACTION_LABELS[p.action_type]}
          </span>
        </div>
      ),
    },
    {
      key: 'state',
      header: 'الحالة',
      render: (p) => {
        const s = effectiveState(p, now)
        return <Badge tone={STATE_TONES[s]}>{STATE_LABELS[s]}</Badge>
      },
    },
    { key: 'period', header: 'فترة العرض', render: (p) => <Period p={p} /> },
    {
      key: 'placements',
      header: 'المواضع',
      render: (p) => <span className="small">{p.placements.map((x) => PLACEMENT_LABELS[x]).join('، ')}</span>,
    },
    {
      key: 'stats',
      header: 'الظهور / النقر',
      render: (p) => {
        const rate = clickRate(p)
        return (
          <span className="small">
            {formatNumber(p.impression_count)} / {formatNumber(p.click_count)}
            {rate !== null && <span className="muted"> ({rate}٪)</span>}
          </span>
        )
      },
    },
    {
      key: 'actions',
      header: <span className="sr-only">إجراءات</span>,
      render: (p) => (
        <div className="row" onClick={(e) => e.stopPropagation()}>
          {p.status === 'ACTIVE' && (
            <Button size="sm" onClick={() => void changeStatus(p, 'PAUSED', 'أوقفت الدعاية.')}>
              إيقاف
            </Button>
          )}
          {p.status === 'PAUSED' && (
            <Button size="sm" onClick={() => void changeStatus(p, 'ACTIVE', 'استؤنفت الدعاية.')}>
              استئناف
            </Button>
          )}
          {p.status !== 'ARCHIVED' ? (
            <Button size="sm" variant="ghost" onClick={() => setArchiving(p)}>
              أرشفة
            </Button>
          ) : (
            <Button size="sm" variant="ghost" onClick={() => void changeStatus(p, 'PAUSED', 'أعيدت الدعاية موقوفة.')}>
              إلغاء الأرشفة
            </Button>
          )}
        </div>
      ),
    },
  ]

  return (
    <div className="page">
      <PageHeader
        title="الدعايات التجارية"
        description="دعايات المعلنين التجاريين التي تظهر في التطبيق بين إعلانات المستخدمين، بشارة «إعلان ممول» ظاهرة دائمًا."
        actions={
          <Button variant="primary" onClick={() => navigate('/admin/promotions/new')}>
            دعاية جديدة
          </Button>
        }
      />
      <MockModeAlert />
      <DisplaySettingsCard />

      <div className="filters">
        <SelectField
          label="الحالة"
          value={filter}
          onChange={(e) => setParams(e.target.value === 'CURRENT' ? {} : { state: e.target.value }, { replace: true })}
        >
          {FILTERS.map((f) => (
            <option key={f} value={f}>
              {FILTER_LABELS[f]}
            </option>
          ))}
        </SelectField>
      </div>

      {query.isPending ? (
        <Loading label="جارٍ تحميل الدعايات…" />
      ) : query.isError ? (
        <ErrorState error={query.error} onRetry={() => void query.refetch()} />
      ) : (
        <DataTable
          caption="الدعايات التجارية"
          columns={columns}
          rows={rows}
          rowKey={(p) => p.id}
          onRowClick={(p) => navigate(`/admin/promotions/${p.id}`)}
          empty={
            <EmptyState title={filter === 'CURRENT' ? 'لا دعايات بعد' : 'لا دعايات مطابقة'}>
              {filter === 'CURRENT' ? 'أضف أول دعاية من زر «دعاية جديدة».' : 'غيّر مرشح الحالة.'}
            </EmptyState>
          }
        />
      )}

      <ConfirmDialog
        open={archiving !== null}
        title="أرشفة الدعاية"
        message={
          <>
            تتوقف «{archiving?.title}» عن الظهور وتنتقل إلى الأرشيف مع إحصاءاتها. يمكن إلغاء الأرشفة لاحقًا.
          </>
        }
        confirmLabel="أرشفة"
        tone="danger"
        onClose={() => setArchiving(null)}
        onConfirm={async () => {
          if (archiving) await changeStatus(archiving, 'ARCHIVED', 'أرشفت الدعاية.')
          setArchiving(null)
        }}
      />
    </div>
  )
}
