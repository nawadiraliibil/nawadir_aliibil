// قراءة القوائم من الجداول (سياسات *_read_staff لمن يملك lookups.manage تشمل المعطلة)
// والكتابة عبر دوال admin_* فقط (contracts/api/rpc.yaml، AD-FR-037).
import { getSupabase } from '@admin/lib/supabase'
import { rpc, unwrap, type RpcArgs } from '@admin/lib/rpc'
import type { Breed, City, LookupKind, ModerationReasonRow, Region } from './types'

export const LOOKUPS_KEY = ['admin', 'lookups'] as const

export const lookupKeys = {
  all: LOOKUPS_KEY,
  breeds: () => [...LOOKUPS_KEY, 'breed'] as const,
  regions: () => [...LOOKUPS_KEY, 'region'] as const,
  citiesAll: () => [...LOOKUPS_KEY, 'city'] as const,
  cities: (regionId: number) => [...LOOKUPS_KEY, 'city', regionId] as const,
  reasons: () => [...LOOKUPS_KEY, 'moderation_reason'] as const,
}

/** مفتاح ذاكرة الأسباب المشتركة (useModerationReasons) يبطل بعد تعديل الأسباب. */
export const SHARED_REASONS_KEY = ['admin', 'moderation-reasons'] as const

export async function fetchBreeds(): Promise<Breed[]> {
  const res = await getSupabase()
    .from('breeds')
    .select('id, name_ar, requires_note, sort_order, is_active, updated_at')
    .order('sort_order', { ascending: true })
    .order('id', { ascending: true })
  return unwrap(res) as Breed[]
}

export async function fetchRegions(): Promise<Region[]> {
  const res = await getSupabase()
    .from('regions')
    .select('id, name_ar, sort_order, is_active, updated_at')
    .order('sort_order', { ascending: true })
    .order('id', { ascending: true })
  return unwrap(res) as Region[]
}

export async function fetchCities(regionId: number): Promise<City[]> {
  const res = await getSupabase()
    .from('cities')
    .select('id, region_id, name_ar, sort_order, is_active, updated_at')
    .eq('region_id', regionId)
    .order('sort_order', { ascending: true })
    .order('id', { ascending: true })
  return unwrap(res) as City[]
}

export async function fetchReasons(): Promise<ModerationReasonRow[]> {
  const res = await getSupabase()
    .from('moderation_reasons')
    .select('code, label_ar, applies_to, requires_note, sort_order, is_active, updated_at')
    .order('sort_order', { ascending: true })
    .order('code', { ascending: true })
  return unwrap(res) as ModerationReasonRow[]
}

/**
 * p_id في admin_upsert_breed/region/city: الأنواع المولدة تجعله `number` إلزاميًا لأن الوسيط
 * بلا DEFAULT في SQL، مع أن الدالة تعامل NULL على أنه «إضافة» (تعليق admin_upsert_region:
 * «إضافة منطقة (p_id فارغ)»). حذف الوسيط لا يصلح: PostgREST لا يجد توقيعًا مطابقًا دون كل
 * الوسائط غير الافتراضية. لذلك نرسل null صراحة عبر هذا التحويل الموضعي الوحيد، وبقية
 * الوسائط مفحوصة بالأنواع المولدة. مسجل فجوةً في العقد (تقرير ADMIN-DASH-20261124).
 */
type NullableId<A> = Omit<A, 'p_id'> & { p_id: number | null }
function withNullableId<A>(args: NullableId<A>): A {
  return args as unknown as A
}

export interface BreedInput {
  id: number | null
  name_ar: string
  requires_note: boolean
  sort_order?: number
}

export async function upsertBreed(input: BreedInput): Promise<Breed> {
  const args = withNullableId<RpcArgs<'admin_upsert_breed'>>({
    p_id: input.id,
    p_name_ar: input.name_ar,
    p_requires_note: input.requires_note,
    p_sort_order: input.sort_order,
  })
  return (await rpc('admin_upsert_breed', args)) as Breed
}

export interface RegionInput {
  id: number | null
  name_ar: string
  sort_order?: number
}

export async function upsertRegion(input: RegionInput): Promise<Region> {
  const args = withNullableId<RpcArgs<'admin_upsert_region'>>({
    p_id: input.id,
    p_name_ar: input.name_ar,
    p_sort_order: input.sort_order,
  })
  return (await rpc('admin_upsert_region', args)) as Region
}

export interface CityInput {
  id: number | null
  region_id: number
  name_ar: string
  sort_order?: number
}

export async function upsertCity(input: CityInput): Promise<City> {
  const args = withNullableId<RpcArgs<'admin_upsert_city'>>({
    p_id: input.id,
    p_region_id: input.region_id,
    p_name_ar: input.name_ar,
    p_sort_order: input.sort_order,
  })
  return (await rpc('admin_upsert_city', args)) as City
}

export interface ReasonInput {
  code: string
  label_ar: string
  applies_to: string[]
  requires_note: boolean
  sort_order?: number
}

export async function upsertReason(input: ReasonInput): Promise<ModerationReasonRow> {
  return (await rpc('admin_upsert_moderation_reason', {
    p_code: input.code,
    p_label_ar: input.label_ar,
    p_applies_to: input.applies_to,
    p_requires_note: input.requires_note,
    p_sort_order: input.sort_order,
  })) as ModerationReasonRow
}

export async function setLookupActive(kind: LookupKind, id: string, isActive: boolean): Promise<unknown> {
  return rpc('admin_set_lookup_active', { p_kind: kind, p_id: id, p_is_active: isActive })
}

/** يرسل الترتيب الكامل للقائمة (أو مدن منطقة واحدة): sort_order = الموضع × 10. */
export async function reorderLookup(kind: LookupKind, ids: string[]): Promise<{ kind: string; updated: number }> {
  return (await rpc('admin_reorder_lookup', { p_kind: kind, p_ids: ids })) as { kind: string; updated: number }
}
