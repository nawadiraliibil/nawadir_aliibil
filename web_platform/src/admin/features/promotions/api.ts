import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import type { Json } from '@contracts/generated/database.types'
import { rpc, unwrap } from '@admin/lib/rpc'
import { toApiError } from '@admin/lib/errors'
import { getSupabase } from '@admin/lib/supabase'
import { normalizePromotion } from './logic'
import type { Promotion, PromotionDisplaySettings, PromotionInput, PromotionStatus } from './types'

/**
 * طبقة بيانات الدعايات عبر دوال العقد 1.6.0 (contracts/api/rpc.yaml، TEAM-DEC-017):
 * admin_list_promotions وadmin_get_promotion وadmin_save_promotion وadmin_set_promotion_status
 * وadmin_get_promotion_settings وadmin_update_promotion_settings، والصور في bucket ‏promotions العام.
 */
export const PROMOTIONS_BUCKET = 'promotions'
const PAGE = 200

const EXT: Record<string, string> = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' }

/** يجلب كل الدعايات بالصفحات (عددها صغير؛ المرشحات بالحالة الفعلية تجري في الواجهة). */
export async function fetchAllPromotions(): Promise<Promotion[]> {
  const out: Promotion[] = []
  let cursor: { p_after_updated_at: string; p_after_id: string } | null = null
  for (;;) {
    const page = ((await rpc('admin_list_promotions', { p_limit: PAGE, ...(cursor ?? {}) })) ?? []) as Promotion[]
    out.push(...page)
    if (page.length < PAGE) return out
    const last = page[page.length - 1]!
    cursor = { p_after_updated_at: last.updated_at, p_after_id: last.id }
  }
}

export async function fetchPromotion(id: string): Promise<Promotion> {
  return (await rpc('admin_get_promotion', { p_id: id })) as Promotion
}

/** يحفظ الحمولة كما يتوقعها الخادم (schemas/promotion-input)؛ الخادم يعيد التحقق والتوحيد. */
export async function savePromotion(id: string | null, input: PromotionInput): Promise<Promotion> {
  const payload = normalizePromotion(input) as unknown as Json
  return (await rpc('admin_save_promotion', id ? { p_id: id, p_payload: payload } : { p_payload: payload })) as Promotion
}

export async function setPromotionStatus(id: string, status: PromotionStatus, note?: string): Promise<Promotion> {
  return (await rpc('admin_set_promotion_status', { p_id: id, p_status: status, ...(note ? { p_note: note } : {}) })) as Promotion
}

export async function fetchDisplaySettings(): Promise<PromotionDisplaySettings> {
  const s = (await rpc('admin_get_promotion_settings')) as PromotionDisplaySettings & { updated_at: string }
  return { enabled: s.enabled, feed_interval: s.feed_interval }
}

export async function saveDisplaySettings(s: PromotionDisplaySettings): Promise<PromotionDisplaySettings> {
  const r = (await rpc('admin_update_promotion_settings', {
    p_enabled: s.enabled,
    p_feed_interval: s.feed_interval,
  })) as PromotionDisplaySettings
  return { enabled: r.enabled, feed_interval: r.feed_interval }
}

/** يرفع الصورة باسم جديد `{uuid}/{uuid}.{ext}` ويعيد مسارها لـimage_path. */
export async function uploadPromotionImage(file: File): Promise<string> {
  const ext = EXT[file.type] ?? 'jpg'
  const path = `${crypto.randomUUID()}/${crypto.randomUUID()}.${ext}`
  const { error } = await getSupabase()
    .storage.from(PROMOTIONS_BUCKET)
    .upload(path, file, { contentType: file.type, upsert: false })
  if (error) throw toApiError(error)
  return path
}

/** رابط الصورة العام (bucket عام؛ لا روابط موقعة). */
export function promotionImageUrl(path: string): string {
  return getSupabase().storage.from(PROMOTIONS_BUCKET).getPublicUrl(path).data.publicUrl
}

export const promotionKeys = {
  all: ['admin', 'promotions'] as const,
  list: ['admin', 'promotions', 'list'] as const,
  detail: (id: string) => ['admin', 'promotions', 'detail', id] as const,
  settings: ['admin', 'promotions', 'settings'] as const,
  regions: ['admin', 'promotions', 'regions'] as const,
}

export function usePromotions() {
  return useQuery({ queryKey: promotionKeys.list, queryFn: fetchAllPromotions })
}

export function usePromotion(id: string | undefined) {
  return useQuery({ queryKey: promotionKeys.detail(id ?? ''), enabled: Boolean(id), queryFn: () => fetchPromotion(id!) })
}

export function useDisplaySettings() {
  return useQuery({ queryKey: promotionKeys.settings, queryFn: fetchDisplaySettings })
}

function useInvalidateAll() {
  const qc = useQueryClient()
  return () => qc.invalidateQueries({ queryKey: promotionKeys.all })
}

/** يرفع الصورة الجديدة (إن وجدت) ثم يحفظ. */
export function useSavePromotion() {
  const invalidate = useInvalidateAll()
  return useMutation({
    mutationFn: async ({ id, input, imageFile }: { id: string | null; input: PromotionInput; imageFile: File | null }) => {
      const image_path = imageFile ? await uploadPromotionImage(imageFile) : input.image_path
      return savePromotion(id, { ...input, image_path })
    },
    onSuccess: () => invalidate(),
  })
}

export function useSetPromotionStatus() {
  const invalidate = useInvalidateAll()
  return useMutation({
    mutationFn: ({ id, status }: { id: string; status: PromotionStatus }) => setPromotionStatus(id, status),
    onSuccess: () => invalidate(),
  })
}

export function useSaveDisplaySettings() {
  const invalidate = useInvalidateAll()
  return useMutation({
    mutationFn: (s: PromotionDisplaySettings) => saveDisplaySettings(s),
    onSuccess: () => invalidate(),
  })
}

/** المناطق الفعالة للاستهداف من جدول regions. */
export function useActiveRegions() {
  return useQuery({
    queryKey: promotionKeys.regions,
    staleTime: 10 * 60 * 1000,
    queryFn: async () =>
      unwrap(
        await getSupabase().from('regions').select('id, name_ar, is_active').eq('is_active', true).order('sort_order', { ascending: true }),
      ) as Array<{ id: number; name_ar: string }>,
  })
}
