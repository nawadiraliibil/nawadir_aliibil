// تجميع مؤشرات admin_stats وتسمياتها (AD-FR-020).
// INT-008 / TEAM-DEC-013: listings.under_review_now وlistings.rejected ميتان ولا يعرضان.
// TEAM-DEC-009: لا مؤشرات توثيق أو شارات.

/** نطاق العدد: داخل الفترة المختارة، أو لقطة حالية، أو إجمالي. */
export type StatScope = 'period' | 'now' | 'total'

export interface StatDef {
  key: string
  label: string
  scope: StatScope
}

export interface StatGroupDef {
  key: string
  title: string
  stats: StatDef[]
  note?: string
}

export const STAT_SCOPE_HINTS: Record<StatScope, string> = {
  period: 'خلال الفترة',
  now: 'حاليًا',
  total: 'الإجمالي حتى الآن',
}

export const INTERACTION_NOTE =
  'أعداد التواصل والتفاعل ليست عمليات بيع. الضغط على الاتصال أو واتساب لا يسجل في الخادم فلا يحسب هنا.'

export const STAT_GROUPS: StatGroupDef[] = [
  {
    key: 'accounts',
    title: 'الحسابات',
    stats: [
      { key: 'total', label: 'إجمالي الحسابات', scope: 'total' },
      { key: 'created', label: 'حسابات جديدة', scope: 'period' },
      { key: 'suspended_now', label: 'حسابات معلقة', scope: 'now' },
    ],
  },
  {
    key: 'listings',
    title: 'الإعلانات',
    stats: [
      { key: 'submitted', label: 'أُرسل/نُشر', scope: 'period' },
      { key: 'approved', label: 'نُشر مباشرة', scope: 'period' },
      { key: 'hidden', label: 'أُخفي إداريًا', scope: 'period' },
      { key: 'published_now', label: 'منشور', scope: 'now' },
    ],
  },
  {
    key: 'reports',
    title: 'البلاغات',
    stats: [
      { key: 'opened', label: 'بلاغات جديدة', scope: 'period' },
      { key: 'closed', label: 'بلاغات أُغلقت', scope: 'period' },
      { key: 'open_now', label: 'بلاغات مفتوحة', scope: 'now' },
    ],
  },
  {
    key: 'ratings',
    title: 'التقييمات والاعتراضات',
    stats: [
      { key: 'created', label: 'تقييمات جديدة', scope: 'period' },
      { key: 'hidden_now', label: 'تقييمات مخفية', scope: 'now' },
      { key: 'appeals_opened', label: 'اعتراضات جديدة', scope: 'period' },
      { key: 'appeals_open_now', label: 'اعتراضات مفتوحة', scope: 'now' },
    ],
  },
  {
    key: 'follows',
    title: 'المتابعة والبحث المحفوظ',
    stats: [
      { key: 'searches_saved', label: 'عمليات بحث محفوظة', scope: 'period' },
      { key: 'sellers_followed', label: 'متابعات معلنين', scope: 'period' },
    ],
  },
  {
    key: 'interaction',
    title: 'التواصل والتفاعل',
    note: INTERACTION_NOTE,
    stats: [
      { key: 'conversations_started', label: 'محادثات بدأت', scope: 'period' },
      { key: 'messages_sent', label: 'رسائل أُرسلت', scope: 'period' },
      { key: 'comments_posted', label: 'ردود عامة نُشرت', scope: 'period' },
      { key: 'favorites_added', label: 'إضافات إلى المفضلة', scope: 'period' },
    ],
  },
]

/** مفاتيح لا تعرض أبدًا (group.key). */
export const HIDDEN_STAT_KEYS: ReadonlySet<string> = new Set(['listings.under_review_now', 'listings.rejected'])

/** مفاتيح الرد التي ليست مجموعات أعداد. */
const META_KEYS: ReadonlySet<string> = new Set(['period', 'generated_at'])

export interface StatTile {
  key: string
  label: string
  value: number
  /** نطاق معروف، أو undefined لمفتاح جديد لم تعرف دلالته. */
  scope?: StatScope
  /** مفتاح غير معروف للوحة يعرض باسمه الخام. */
  raw?: boolean
}

export interface StatGroupView {
  key: string
  title: string
  note?: string
  tiles: StatTile[]
  raw?: boolean
}

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v)
}

function isCount(v: unknown): v is number {
  return typeof v === 'number' && Number.isFinite(v)
}

function buildTiles(groupKey: string, values: Record<string, unknown>, known: StatDef[]): StatTile[] {
  const tiles: StatTile[] = []
  const seen = new Set<string>()
  for (const def of known) {
    seen.add(def.key)
    const v = values[def.key]
    if (HIDDEN_STAT_KEYS.has(`${groupKey}.${def.key}`) || !isCount(v)) continue
    tiles.push({ key: def.key, label: def.label, value: v, scope: def.scope })
  }
  // مفاتيح جديدة من الخادم تعرض باسمها الخام حتى لا تسقط بصمت.
  for (const [k, v] of Object.entries(values).sort(([a], [b]) => a.localeCompare(b))) {
    if (seen.has(k) || HIDDEN_STAT_KEYS.has(`${groupKey}.${k}`) || !isCount(v)) continue
    tiles.push({ key: k, label: k, value: v, raw: true })
  }
  return tiles
}

/** يحول رد admin_stats إلى مجموعات عرض بترتيب ثابت، مع المجموعات والمفاتيح غير المعروفة في آخرها. */
export function buildStatGroups(stats: Record<string, unknown>): StatGroupView[] {
  const groups: StatGroupView[] = []
  const knownKeys = new Set(STAT_GROUPS.map((g) => g.key))
  for (const def of STAT_GROUPS) {
    const values = stats[def.key]
    if (!isRecord(values)) continue
    const tiles = buildTiles(def.key, values, def.stats)
    if (tiles.length === 0) continue
    groups.push({ key: def.key, title: def.title, note: def.note, tiles })
  }
  for (const [k, values] of Object.entries(stats).sort(([a], [b]) => a.localeCompare(b))) {
    if (knownKeys.has(k) || META_KEYS.has(k) || !isRecord(values)) continue
    const tiles = buildTiles(k, values, [])
    if (tiles.length === 0) continue
    groups.push({ key: k, title: k, tiles, raw: true })
  }
  return groups
}
