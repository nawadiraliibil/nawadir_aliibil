import { useQuery } from '@tanstack/react-query'
import { rpc, unwrap } from '@admin/lib/rpc'
import { getSupabase } from '@admin/lib/supabase'
import { LISTING_FILTER_STATUSES } from '@admin/lib/labels'
import type { AdminListingItem, ListCursor, ListFilters, ListingExtras, ListingReviewPayload, LookupNames } from './types'

export const LIST_LIMIT = 50
/** مدة الرابط الموقع بالثواني؛ لا تخزن روابط دائمة (contracts/api/storage.md). */
export const SIGNED_URL_TTL = 300

export const listingKeys = {
  all: ['admin', 'listings'] as const,
  lists: ['admin', 'listings', 'list'] as const,
  list: (f: ListFilters) => ['admin', 'listings', 'list', f] as const,
  details: ['admin', 'listings', 'detail'] as const,
  detail: (id: string) => ['admin', 'listings', 'detail', id] as const,
  extras: (id: string) => ['admin', 'listings', 'extras', id] as const,
  lookups: ['admin', 'listings', 'lookups'] as const,
  reasonLabels: ['admin', 'listings', 'reason-labels'] as const,
  signed: (bucket: string, path: string) => ['admin', 'listings', 'signed', bucket, path] as const,
}

/** يقبل من رابط الصفحة الحالات المسموحة في المرشح فقط (لا UNDER_REVIEW). */
export function sanitizeStatus(value: string | null): string {
  return value && (LISTING_FILTER_STATUSES as readonly string[]).includes(value) ? value : ''
}

export async function fetchListingsPage(filters: ListFilters, cursor: ListCursor | null): Promise<AdminListingItem[]> {
  const args: {
    p_status?: string
    p_query?: string
    p_limit: number
    p_after_changed_at?: string
    p_after_id?: string
  } = { p_limit: LIST_LIMIT }
  if (filters.status) args.p_status = filters.status
  const q = filters.q.trim()
  if (q) args.p_query = q
  if (cursor) {
    args.p_after_changed_at = cursor.changed_at
    args.p_after_id = cursor.id
  }
  const rows = (await rpc('admin_list_listings', args)) as AdminListingItem[] | null
  return rows ?? []
}

export function nextCursor(lastPage: AdminListingItem[]): ListCursor | undefined {
  if (lastPage.length < LIST_LIMIT) return undefined
  const last = lastPage[lastPage.length - 1]
  return last ? { changed_at: last.status_changed_at, id: last.listing_id } : undefined
}

export async function fetchListingReview(listingId: string): Promise<ListingReviewPayload> {
  return (await rpc('admin_get_listing_review', { p_listing_id: listingId })) as ListingReviewPayload
}

/**
 * قراءات تكميلية غير موجودة في رد admin_get_listing_review: المعرف العام وإغلاق الردود
 * من listings (مسموح لقدرتي الإعلانات)، والمشاهدات والمفضلة من public_listing_cards للمنشور فقط.
 * فشلها لا يمنع عرض الصفحة.
 */
export async function fetchListingExtras(listingId: string, published: boolean): Promise<ListingExtras> {
  const sb = getSupabase()
  const extras: ListingExtras = { public_ref: null, comments_closed: null, view_count: null, favorite_count: null }
  const base = await sb.from('listings').select('public_ref, comments_closed').eq('id', listingId).maybeSingle()
  if (!base.error && base.data) {
    extras.public_ref = base.data.public_ref ?? null
    extras.comments_closed = base.data.comments_closed ?? null
  }
  if (published) {
    const card = await sb.from('public_listing_cards').select('view_count, favorite_count').eq('listing_id', listingId).maybeSingle()
    if (!card.error && card.data) {
      extras.view_count = card.data.view_count ?? null
      extras.favorite_count = card.data.favorite_count ?? null
    }
  }
  return extras
}

/** أسماء السلالات والمناطق والمدن. القيم المعطلة تظهر لمن يملك lookups.manage فقط؛ غيرها يعرض #id. */
export function useLookupNames() {
  return useQuery({
    queryKey: listingKeys.lookups,
    staleTime: 10 * 60 * 1000,
    queryFn: async (): Promise<LookupNames> => {
      const sb = getSupabase()
      const [breeds, regions, cities] = await Promise.all([
        sb.from('breeds').select('id, name_ar'),
        sb.from('regions').select('id, name_ar'),
        sb.from('cities').select('id, name_ar'),
      ])
      const toMap = (rows: Array<{ id: number; name_ar: string }>) => new Map(rows.map((r) => [r.id, r.name_ar]))
      return {
        breeds: toMap(unwrap(breeds)),
        regions: toMap(unwrap(regions)),
        cities: toMap(unwrap(cities)),
      }
    },
  })
}

/** تسميات أسباب الإشراف بكل ما يقرؤه الموظف (ومنها المعطلة لمن يملك lookups.manage). */
export function useReasonLabels() {
  return useQuery({
    queryKey: listingKeys.reasonLabels,
    staleTime: 10 * 60 * 1000,
    queryFn: async () => {
      const rows = unwrap(await getSupabase().from('moderation_reasons').select('code, label_ar'))
      return new Map(rows.map((r) => [r.code, r.label_ar]))
    },
  })
}

/** رابط موقع قصير الأجل لملف في bucket خاص. يجدد قبل انتهائه. */
export function useSignedUrl(bucket: string | null | undefined, path: string | null | undefined) {
  return useQuery({
    queryKey: listingKeys.signed(bucket ?? '', path ?? ''),
    enabled: Boolean(bucket && path),
    staleTime: (SIGNED_URL_TTL - 60) * 1000,
    // يجدد الرابط قبل انتهاء صلاحيته ما دامت الصفحة مفتوحة (روابط قصيرة الأجل، storage.md).
    refetchInterval: (SIGNED_URL_TTL - 60) * 1000,
    refetchIntervalInBackground: false,
    gcTime: SIGNED_URL_TTL * 1000,
    retry: false,
    queryFn: async () => {
      const res = await getSupabase().storage.from(bucket as string).createSignedUrl(path as string, SIGNED_URL_TTL)
      if (res.error || !res.data?.signedUrl) throw res.error ?? new Error('no signed url')
      return res.data.signedUrl
    },
  })
}
