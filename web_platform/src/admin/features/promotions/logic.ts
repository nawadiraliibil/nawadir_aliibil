import type { Tone } from '@admin/ui'
import {
  FEED_INTERVAL_MAX,
  FEED_INTERVAL_MIN,
  type ActionType,
  type EffectiveState,
  type Placement,
  type Promotion,
  type PromotionInput,
} from './types'

export const LIMITS = {
  title: 60,
  body: 140,
  advertiser: 60,
  url: 500,
  imageBytes: 1024 * 1024,
} as const

export const IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const
/** نسبة الصورة المطلوبة: مثل صورة البطاقة الكبيرة في التطبيق (16:10). */
export const IMAGE_RATIO = 16 / 10

export const STATE_LABELS: Record<EffectiveState, string> = {
  RUNNING: 'تُعرض الآن',
  SCHEDULED: 'مجدولة',
  EXPIRED: 'انتهت',
  PAUSED: 'موقوفة',
  ARCHIVED: 'مؤرشفة',
}

export const STATE_TONES: Record<EffectiveState, Tone> = {
  RUNNING: 'success',
  SCHEDULED: 'info',
  EXPIRED: 'neutral',
  PAUSED: 'warning',
  ARCHIVED: 'neutral',
}

export const PLACEMENT_LABELS: Record<Placement, string> = {
  HOME_FEED: 'الصفحة الرئيسية',
  SEARCH_RESULTS: 'نتائج البحث والتصفية',
}

export const ACTION_LABELS: Record<ActionType, string> = {
  URL: 'فتح رابط',
  WHATSAPP: 'واتساب',
  CALL: 'اتصال',
  NONE: 'عرض فقط',
}

export const ACTION_CTA: Record<ActionType, string | null> = {
  URL: 'زيارة الموقع',
  WHATSAPP: 'تواصل واتساب',
  CALL: 'اتصل الآن',
  NONE: null,
}

export function effectiveState(p: Pick<Promotion, 'status' | 'starts_at' | 'ends_at'>, now: Date = new Date()): EffectiveState {
  if (p.status === 'ARCHIVED') return 'ARCHIVED'
  if (p.status === 'PAUSED') return 'PAUSED'
  const t = now.getTime()
  if (new Date(p.starts_at).getTime() > t) return 'SCHEDULED'
  if (p.ends_at && new Date(p.ends_at).getTime() <= t) return 'EXPIRED'
  return 'RUNNING'
}

/** نسبة النقر إلى الظهور بنسبة مئوية بمنزلة عشرية واحدة، أو null بلا ظهور. */
export function clickRate(p: Pick<Promotion, 'impression_count' | 'click_count'>): number | null {
  if (p.impression_count <= 0) return null
  return Math.round((p.click_count / p.impression_count) * 1000) / 10
}

const SAUDI_MOBILE = /^\+9665\d{8}$/

/** يقبل 05XXXXXXXX و5XXXXXXXX و9665XXXXXXXX و+9665XXXXXXXX (بمسافات أو شرطات) ويعيد +9665XXXXXXXX. */
export function normalizeSaudiMobile(raw: string): string | null {
  const digits = raw.replace(/[\s-]/g, '').replace(/^\+/, '')
  let local: string | null = null
  if (/^05\d{8}$/.test(digits)) local = digits.slice(1)
  else if (/^5\d{8}$/.test(digits)) local = digits
  else if (/^9665\d{8}$/.test(digits)) local = digits.slice(3)
  if (!local) return null
  const e164 = `+966${local}`
  return SAUDI_MOBILE.test(e164) ? e164 : null
}

export function isHttpsUrl(raw: string): boolean {
  try {
    const u = new URL(raw.trim())
    return u.protocol === 'https:' && Boolean(u.hostname) && u.hostname.includes('.')
  } catch {
    return false
  }
}

export type PromotionErrors = Partial<Record<keyof PromotionInput | 'image', string>>

/** تحقق الواجهة. الخادم يعيد التحقق نفسه عند تسليم INT-010 (VALIDATION_FAILED بالحقول). */
export function validatePromotion(input: PromotionInput): PromotionErrors {
  const e: PromotionErrors = {}
  const title = input.title.trim()
  if (title.length < 2) e.title = 'العنوان مطلوب (حرفان على الأقل).'
  else if (title.length > LIMITS.title) e.title = `العنوان ${LIMITS.title} حرفًا كحد أقصى.`
  if (input.body && input.body.trim().length > LIMITS.body) e.body = `النص ${LIMITS.body} حرفًا كحد أقصى.`
  const adv = input.advertiser_name.trim()
  if (adv.length < 2) e.advertiser_name = 'اسم المعلن التجاري مطلوب.'
  else if (adv.length > LIMITS.advertiser) e.advertiser_name = `الاسم ${LIMITS.advertiser} حرفًا كحد أقصى.`
  if (!input.image_path) e.image = 'صورة الدعاية مطلوبة.'

  const value = (input.action_value ?? '').trim()
  if (input.action_type === 'URL') {
    if (!isHttpsUrl(value)) e.action_value = 'أدخل رابطًا كاملًا يبدأ بـ https://'
    else if (value.length > LIMITS.url) e.action_value = `الرابط ${LIMITS.url} حرف كحد أقصى.`
  } else if (input.action_type === 'WHATSAPP' || input.action_type === 'CALL') {
    if (!normalizeSaudiMobile(value)) e.action_value = 'أدخل رقم جوال سعوديًا مثل 05XXXXXXXX.'
  }

  if (input.placements.length === 0) e.placements = 'اختر موضع عرض واحدًا على الأقل.'
  if (input.region_ids !== null && input.region_ids.length === 0) e.region_ids = 'اختر منطقة واحدة على الأقل أو «كل المناطق».'

  const start = Date.parse(input.starts_at)
  if (Number.isNaN(start)) e.starts_at = 'تاريخ البداية مطلوب.'
  if (input.ends_at) {
    const end = Date.parse(input.ends_at)
    if (Number.isNaN(end)) e.ends_at = 'تاريخ النهاية غير صالح.'
    else if (!Number.isNaN(start) && end <= start) e.ends_at = 'تاريخ النهاية بعد تاريخ البداية.'
  }
  if (!Number.isInteger(input.priority) || input.priority < 0 || input.priority > 100) e.priority = 'الأولوية رقم صحيح من 0 إلى 100.'
  return e
}

/** يوحد القيم قبل الحفظ: مسافات، رقم الجوال، وقيمة الإجراء الفارغة. */
export function normalizePromotion(input: PromotionInput): PromotionInput {
  const value = (input.action_value ?? '').trim()
  let action_value: string | null = null
  if (input.action_type === 'URL') action_value = value
  else if (input.action_type === 'WHATSAPP' || input.action_type === 'CALL') action_value = normalizeSaudiMobile(value)
  return {
    ...input,
    title: input.title.trim(),
    body: input.body?.trim() ? input.body.trim() : null,
    advertiser_name: input.advertiser_name.trim(),
    action_value,
    region_ids: input.region_ids === null ? null : [...new Set(input.region_ids)].sort((a, b) => a - b),
  }
}

export function validateFeedInterval(n: number): string | null {
  if (!Number.isInteger(n) || n < FEED_INTERVAL_MIN || n > FEED_INTERVAL_MAX)
    return `رقم صحيح من ${FEED_INTERVAL_MIN} إلى ${FEED_INTERVAL_MAX}.`
  return null
}

/** فحص ملف الصورة قبل الرفع. */
export function validateImageFile(file: Pick<File, 'type' | 'size'>): string | null {
  if (!(IMAGE_TYPES as readonly string[]).includes(file.type)) return 'الصيغ المقبولة: JPEG وPNG وWebP.'
  if (file.size > LIMITS.imageBytes) return 'حجم الصورة 1 ميغابايت كحد أقصى.'
  return null
}
