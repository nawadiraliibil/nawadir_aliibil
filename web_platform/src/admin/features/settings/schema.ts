// مفاتيح محتوى الإعدادات وقواعد التحقق، مطابقة لـprivate.normalize_settings وprivate.validate_settings
// (supabase/migrations/20261122155438_settings.sql و20261122231000_settings_lookup_admin_rpcs.sql).
// التحقق هنا للتنبيه المبكر فقط؛ الخادم هو المرجع.
import { formatNumber } from '@admin/lib/format'
import type { FormValues, SettingsContent } from './types'

export type FieldKind = 'int' | 'bool' | 'mime'

export interface FieldDef {
  /** مسار الحقل كما يعيده الخادم في details.fields: section.key */
  path: string
  section: string
  key: string
  label: string
  kind: FieldKind
  unit?: string
  /** السقف التقني في validate_settings. */
  ceiling?: number
  /** حد أدنى ثابت (BELOW_HARD_MINIMUM). */
  hardMinimum?: number
  hint?: string
  /** قيمة بالبايت؛ يعرض ما يعادلها بالميجابايت. */
  bytes?: boolean
}

export interface GroupDef {
  id: string
  title: string
  description?: string
  fields: FieldDef[]
}

/** الصيغ المدعومة فعلًا (SRS 10.2)؛ الخادم يرفض غيرها. */
export const SUPPORTED_IMAGE_MIME_TYPES = ['image/jpeg', 'image/png'] as const
export const MIME_LABELS: Record<string, string> = { 'image/jpeg': 'JPEG', 'image/png': 'PNG' }

export const BUMP_HARD_MINIMUM_HOURS = 24
export const NOTE_MAX = 500

function f(section: string, key: string, label: string, kind: FieldKind, extra: Partial<FieldDef> = {}): FieldDef {
  return { path: `${section}.${key}`, section, key, label, kind, ...extra }
}

export const GROUPS: GroupDef[] = [
  {
    id: 'content',
    title: 'المحتوى',
    description: 'أطوال عنوان الإعلان ووصفه.',
    fields: [
      f('listing', 'title_min', 'أقل طول للعنوان', 'int', { unit: 'حرف', ceiling: 200 }),
      f('listing', 'title_max', 'أقصى طول للعنوان', 'int', { unit: 'حرف', ceiling: 200 }),
      f('listing', 'description_min', 'أقل طول للوصف', 'int', { unit: 'حرف', ceiling: 10000 }),
      f('listing', 'description_max', 'أقصى طول للوصف', 'int', { unit: 'حرف', ceiling: 10000 }),
    ],
  },
  {
    id: 'media',
    title: 'الوسائط',
    description: 'عدد الصور وحجمها وصيغها، والفيديو. حدود الحجم والصيغ تطبق على التخزين عند النشر.',
    fields: [
      f('media', 'images_min', 'أقل عدد للصور', 'int', { unit: 'صورة', ceiling: 20 }),
      f('media', 'images_max', 'أقصى عدد للصور', 'int', { unit: 'صورة', ceiling: 20 }),
      f('media', 'image_max_bytes', 'أقصى حجم للصورة', 'int', { unit: 'بايت', ceiling: 20971520, bytes: true }),
      f('media', 'image_mime_types', 'صيغ الصور المسموحة', 'mime'),
      f('media', 'video_enabled', 'تفعيل رفع الفيديو', 'bool', { hint: 'عند التعطيل يرفض الخادم إضافة فيديو للإعلانات الجديدة.' }),
      f('media', 'video_max_seconds', 'أقصى مدة للفيديو', 'int', { unit: 'ثانية', ceiling: 300 }),
      f('media', 'video_max_bytes', 'أقصى حجم للفيديو', 'int', { unit: 'بايت', ceiling: 524288000, bytes: true }),
    ],
  },
  {
    id: 'interaction',
    title: 'التفاعل',
    description: 'أقصى طول لنصوص المستخدمين.',
    fields: [
      f('interaction', 'message_max', 'أقصى طول للرسالة', 'int', { unit: 'حرف', ceiling: 5000 }),
      f('interaction', 'comment_max', 'أقصى طول للرد العام', 'int', { unit: 'حرف', ceiling: 5000 }),
      f('interaction', 'rating_max', 'أقصى طول لنص التقييم', 'int', { unit: 'حرف', ceiling: 5000 }),
    ],
  },
  {
    id: 'rate_limits',
    title: 'مكافحة الإغراق',
    description: 'حدود الاستخدام لكل مستخدم.',
    fields: [
      f('rate_limits', 'messages_per_minute', 'الرسائل في الدقيقة', 'int', { unit: 'رسالة', ceiling: 1000 }),
      f('rate_limits', 'new_conversations_per_hour', 'المحادثات الجديدة في الساعة', 'int', { unit: 'محادثة', ceiling: 1000 }),
      f('rate_limits', 'comments_per_minute', 'الردود العامة في الدقيقة', 'int', { unit: 'رد', ceiling: 1000 }),
      f('rate_limits', 'reports_per_day', 'البلاغات في اليوم', 'int', { unit: 'بلاغ', ceiling: 1000 }),
    ],
  },
  {
    id: 'publishing',
    title: 'النشر',
    description: 'حدود إنشاء الإعلانات لكل معلن.',
    fields: [
      f('listing', 'daily_new_limit', 'الإعلانات الجديدة خلال 24 ساعة', 'int', { unit: 'إعلان', ceiling: 100 }),
      f('listing', 'open_drafts_max', 'أقصى عدد للمسودات المفتوحة', 'int', { unit: 'مسودة', ceiling: 100 }),
    ],
  },
  {
    id: 'follows',
    title: 'المتابعات',
    fields: [
      f('follows', 'saved_searches_max', 'أقصى عدد لعمليات البحث المحفوظة', 'int', { unit: 'بحث', ceiling: 200 }),
      f('follows', 'followed_sellers_max', 'أقصى عدد للمعلنين المتابَعين', 'int', { unit: 'معلن', ceiling: 1000 }),
    ],
  },
  {
    id: 'bump',
    title: 'تجديد الظهور',
    fields: [
      f('bump', 'interval_hours', 'الفترة بين تجديدين للظهور', 'int', {
        unit: 'ساعة',
        ceiling: 8760,
        hardMinimum: BUMP_HARD_MINIMUM_HOURS,
        hint: 'لا تقل عن 24 ساعة؛ حد ثابت يمكن رفعه (تشديده) ولا يمكن خفضه.',
      }),
    ],
  },
]

export const FIELDS: FieldDef[] = GROUPS.flatMap((g) => g.fields)
export const FIELD_BY_PATH: Record<string, FieldDef> = Object.fromEntries(FIELDS.map((fd) => [fd.path, fd]))
const GROUP_BY_PATH: Record<string, GroupDef> = Object.fromEntries(GROUPS.flatMap((g) => g.fields.map((fd) => [fd.path, g])))

/** أزواج الحد الأدنى والأعلى؛ الخطأ يسند إلى حقل الحد الأدنى كما في الخادم. */
export const MIN_MAX_PAIRS: Array<[string, string]> = [
  ['listing.title_min', 'listing.title_max'],
  ['listing.description_min', 'listing.description_max'],
  ['media.images_min', 'media.images_max'],
]

const KNOWN_KEYS: Record<string, Set<string>> = {}
for (const fd of FIELDS) (KNOWN_KEYS[fd.section] ??= new Set()).add(fd.key)

export function fieldLabel(path: string): string {
  const fd = FIELD_BY_PATH[path]
  if (!fd) return path
  return fd.unit ? `${fd.label} (${fd.unit})` : fd.label
}

/** تسمية المسار في الفروقات والعرض: «المجموعة — الحقل». */
export function pathLabel(path: string): string {
  const g = GROUP_BY_PATH[path]
  return g ? `${g.title} — ${fieldLabel(path)}` : path
}

export function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v)
}

export function cloneContent(c: SettingsContent): SettingsContent {
  return JSON.parse(JSON.stringify(c)) as SettingsContent
}

export function getPath(content: SettingsContent, section: string, key: string): unknown {
  const s = content[section]
  return isPlainObject(s) ? s[key] : undefined
}

/** قيم النموذج من محتوى إصدار. */
export function toFormValues(content: SettingsContent): FormValues {
  const out: FormValues = {}
  for (const fd of FIELDS) {
    const v = getPath(content, fd.section, fd.key)
    if (fd.kind === 'int') out[fd.path] = typeof v === 'number' ? String(v) : ''
    else if (fd.kind === 'bool') out[fd.path] = v === true
    else out[fd.path] = Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []
  }
  return out
}

export function sameForm(a: FormValues, b: FormValues): boolean {
  return FIELDS.every((fd) => JSON.stringify(a[fd.path]) === JSON.stringify(b[fd.path]))
}

/**
 * المحتوى الكامل للإرسال: نسخة من الأساس (بما فيه المفاتيح غير المعروفة) مع قيم النموذج.
 * يفترض أن النموذج اجتاز validateForm.
 */
export function buildContent(base: SettingsContent, form: FormValues): SettingsContent {
  const out = cloneContent(base)
  for (const fd of FIELDS) {
    const current = out[fd.section]
    const section: Record<string, unknown> = isPlainObject(current) ? current : {}
    out[fd.section] = section
    const v = form[fd.path]
    if (fd.kind === 'int') section[fd.key] = Number(typeof v === 'string' ? v.trim() : v)
    else if (fd.kind === 'bool') section[fd.key] = v === true
    else {
      const chosen = Array.isArray(v) ? v : []
      // ترتيب ثابت للصيغ المدعومة، ثم أي قيمة أخرى كما هي (يرفضها الخادم).
      section[fd.key] = [...SUPPORTED_IMAGE_MIME_TYPES.filter((m) => chosen.includes(m)), ...chosen.filter((m) => !(SUPPORTED_IMAGE_MIME_TYPES as readonly string[]).includes(m))]
    }
  }
  return out
}

const POSITIVE_INT = /^[1-9][0-9]{0,15}$/

export function hardMinimumMessage(minimum: number | string, unit?: string): string {
  return `لا تقل عن ${minimum}${unit ? ` ${unit}` : ''} — حد ثابت لا يقبل التخفيض.`
}

function intValue(form: FormValues, path: string): number | null {
  const v = form[path]
  if (typeof v !== 'string') return null
  const s = v.trim()
  return POSITIVE_INT.test(s) ? Number(s) : null
}

/** أخطاء النموذج بمسار الحقل، مطابقة لقواعد validate_settings. */
export function validateForm(form: FormValues): Record<string, string> {
  const errors: Record<string, string> = {}
  for (const fd of FIELDS) {
    const v = form[fd.path]
    if (fd.kind === 'int') {
      const s = typeof v === 'string' ? v.trim() : ''
      if (s === '') {
        errors[fd.path] = 'هذا الحقل مطلوب.'
        continue
      }
      if (!POSITIVE_INT.test(s)) {
        errors[fd.path] = 'أدخل عددًا صحيحًا موجبًا (1 فأكثر).'
        continue
      }
      const n = Number(s)
      if (fd.ceiling !== undefined && n > fd.ceiling) {
        errors[fd.path] = `القيمة لا تتجاوز الحد التقني ${formatNumber(fd.ceiling)}.`
        continue
      }
      if (fd.hardMinimum !== undefined && n < fd.hardMinimum) {
        errors[fd.path] = hardMinimumMessage(fd.hardMinimum, fd.unit)
      }
    } else if (fd.kind === 'mime') {
      const arr = Array.isArray(v) ? v : []
      if (arr.length === 0) errors[fd.path] = 'اختر صيغة واحدة على الأقل.'
      else if (arr.some((m) => !(SUPPORTED_IMAGE_MIME_TYPES as readonly string[]).includes(m))) errors[fd.path] = 'صيغة غير مدعومة.'
    }
  }
  for (const [minPath, maxPath] of MIN_MAX_PAIRS) {
    if (errors[minPath] || errors[maxPath]) continue
    const min = intValue(form, minPath)
    const max = intValue(form, maxPath)
    if (min !== null && max !== null && min > max) {
      errors[minPath] = `الحد الأدنى أكبر من «${FIELD_BY_PATH[maxPath]?.label ?? maxPath}».`
    }
  }
  return errors
}

/** مفاتيح لا تعرضها الواجهة؛ تبقى في المحتوى المرسل وتعرض للقراءة فقط. */
export function unknownEntries(content: SettingsContent): Array<{ path: string; value: unknown }> {
  const out: Array<{ path: string; value: unknown }> = []
  for (const [section, value] of Object.entries(content)) {
    const known = KNOWN_KEYS[section]
    if (!known) {
      out.push({ path: section, value })
      continue
    }
    if (!isPlainObject(value)) continue
    for (const [key, v] of Object.entries(value)) {
      if (!known.has(key)) out.push({ path: `${section}.${key}`, value: v })
    }
  }
  return out
}

/** قيم المحتوى بمسارات مسطحة؛ المصفوفات قيم مفردة. */
export function flatten(content: unknown, prefix = ''): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  if (!isPlainObject(content)) {
    if (prefix) out[prefix] = content
    return out
  }
  for (const [k, v] of Object.entries(content)) {
    const p = prefix ? `${prefix}.${k}` : k
    if (isPlainObject(v)) Object.assign(out, flatten(v, p))
    else out[p] = v
  }
  return out
}

export interface DiffEntry {
  path: string
  before: unknown
  after: unknown
}

/** المسارات التي تختلف قيمتها بين محتويين، بترتيب الحقول المعروضة ثم غيرها. */
export function diffContent(before: SettingsContent, after: SettingsContent): DiffEntry[] {
  const a = flatten(before)
  const b = flatten(after)
  const order = FIELDS.map((fd) => fd.path)
  const paths = Array.from(new Set([...Object.keys(a), ...Object.keys(b)]))
  paths.sort((x, y) => {
    const ix = order.indexOf(x)
    const iy = order.indexOf(y)
    if (ix !== -1 || iy !== -1) return (ix === -1 ? Infinity : ix) - (iy === -1 ? Infinity : iy)
    return x.localeCompare(y)
  })
  return paths.filter((p) => JSON.stringify(a[p]) !== JSON.stringify(b[p])).map((p) => ({ path: p, before: a[p], after: b[p] }))
}

export function formatMegabytes(bytes: number): string {
  const mb = bytes / 1048576
  return `${Number.isInteger(mb) ? mb : mb.toFixed(2)} ميجابايت`
}

/** عرض قيمة إعداد للقراءة. */
export function formatSettingValue(path: string, value: unknown): string {
  if (value === undefined || value === null) return '—'
  const fd = FIELD_BY_PATH[path]
  if (typeof value === 'boolean') return value ? 'مفعل' : 'معطل'
  if (typeof value === 'number') {
    const base = fd?.unit ? `${formatNumber(value)} ${fd.unit}` : formatNumber(value)
    return fd?.bytes ? `${base} (${formatMegabytes(value)})` : base
  }
  if (Array.isArray(value)) {
    if (value.length === 0) return '—'
    return value.map((v) => (typeof v === 'string' ? (MIME_LABELS[v] ?? v) : JSON.stringify(v))).join('، ')
  }
  if (typeof value === 'string') return value
  return JSON.stringify(value)
}
