import { keepPreviousData, useInfiniteQuery, useQuery } from '@tanstack/react-query'
import { ApiError } from '@admin/lib/errors'
import { unwrap } from '@admin/lib/rpc'
import { getSupabase } from '@admin/lib/supabase'
import type { AppealListItem, RatingDetail, RatingListItem, RatingReplyRow, RatingScoreRef, SellerRatingRow } from './types'

export const PAGE_SIZE = 25

/** مفاتيح الاستعلام: كلها تحت ['admin','ratings'] لتبطل معًا بعد أي إجراء. */
export const ratingKeys = {
  all: ['admin', 'ratings'] as const,
  appeals: (status: string) => ['admin', 'ratings', 'appeals', status] as const,
  ratings: (status: string) => ['admin', 'ratings', 'list', status] as const,
  detail: (id: string) => ['admin', 'ratings', 'detail', id] as const,
  scores: (ids: string[]) => ['admin', 'ratings', 'scores', ids] as const,
  names: (ids: string[]) => ['admin', 'ratings', 'names', ids] as const,
  reasons: (codes: string[]) => ['admin', 'ratings', 'reason-labels', codes] as const,
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export function isUuid(value: string | undefined): value is string {
  return typeof value === 'string' && UUID_RE.test(value)
}

const APPEAL_COLS = 'id, rating_id, seller_id, reason, status, decision_note, decided_by, decided_at, created_at'
const RATING_COLS = 'id, rater_id, seller_id, score, body, status, hidden_reason_code, hidden_reason_text, hidden_at, edited_at, created_at'

function nextOffset<T>(lastPage: T[], pages: T[][]): number | undefined {
  return lastPage.length === PAGE_SIZE ? pages.length * PAGE_SIZE : undefined
}

/** الاعتراضات بالأحدث، مع مرشح حالة اختياري ('' للكل). */
export function useAppeals(status: string) {
  return useInfiniteQuery({
    queryKey: ratingKeys.appeals(status),
    initialPageParam: 0,
    getNextPageParam: nextOffset,
    queryFn: async ({ pageParam }) => {
      let q = getSupabase().from('rating_appeals').select(APPEAL_COLS)
      if (status) q = q.eq('status', status)
      const res = await q
        .order('created_at', { ascending: false })
        .order('id', { ascending: false })
        .range(pageParam, pageParam + PAGE_SIZE - 1)
      return unwrap(res) as AppealListItem[]
    },
  })
}

/** التقييمات بالأحدث، مع مرشح حالة اختياري ('' للكل). */
export function useRatings(status: string) {
  return useInfiniteQuery({
    queryKey: ratingKeys.ratings(status),
    initialPageParam: 0,
    getNextPageParam: nextOffset,
    queryFn: async ({ pageParam }) => {
      let q = getSupabase().from('seller_ratings').select(RATING_COLS)
      if (status) q = q.eq('status', status)
      const res = await q
        .order('created_at', { ascending: false })
        .order('id', { ascending: false })
        .range(pageParam, pageParam + PAGE_SIZE - 1)
      return unwrap(res) as RatingListItem[]
    },
  })
}

function uniqueSorted(ids: Array<string | null | undefined>): string[] {
  return Array.from(new Set(ids.filter((x): x is string => typeof x === 'string' && x !== ''))).sort()
}

/** درجات التقييمات المرتبطة بصفوف الاعتراضات (دفعة واحدة بـin). */
export function useRatingScores(ratingIds: Array<string | null | undefined>) {
  const ids = uniqueSorted(ratingIds)
  return useQuery({
    queryKey: ratingKeys.scores(ids),
    enabled: ids.length > 0,
    placeholderData: keepPreviousData,
    queryFn: async () => {
      const res = await getSupabase().from('seller_ratings').select('id, score, status').in('id', ids)
      const rows = unwrap(res) as RatingScoreRef[]
      return new Map(rows.map((r) => [r.id, r]))
    },
  })
}

/**
 * أسماء العرض من public_profiles (profiles لا يقرأ إلا بـaccounts.manage).
 * الحساب المعلق أو بلا اسم قد لا يظهر؛ يعرض عندها معرف مختصر.
 */
export function useDisplayNames(userIds: Array<string | null | undefined>) {
  const ids = uniqueSorted(userIds)
  return useQuery({
    queryKey: ratingKeys.names(ids),
    enabled: ids.length > 0,
    placeholderData: keepPreviousData,
    staleTime: 60 * 1000,
    queryFn: async () => {
      const res = await getSupabase().from('public_profiles').select('id, display_name').in('id', ids)
      const rows = unwrap(res) as Array<{ id: string | null; display_name: string | null }>
      const map = new Map<string, string>()
      for (const r of rows) if (r.id && r.display_name) map.set(r.id, r.display_name)
      return map
    },
  })
}

/** تسميات أسباب الإخفاء المسجلة (moderation_reasons؛ المعطل قد لا يقرأ فيعرض رمزه). */
export function useReasonLabels(codes: Array<string | null | undefined>) {
  const list = uniqueSorted(codes)
  return useQuery({
    queryKey: ratingKeys.reasons(list),
    enabled: list.length > 0,
    placeholderData: keepPreviousData,
    staleTime: 5 * 60 * 1000,
    queryFn: async () => {
      const res = await getSupabase().from('moderation_reasons').select('code, label_ar').in('code', list)
      const rows = unwrap(res) as Array<{ code: string; label_ar: string }>
      return new Map(rows.map((r) => [r.code, r.label_ar]))
    },
  })
}

/** تفاصيل التقييم مع سجل تعديلاته ورد المعلن واعتراضاته. */
export async function fetchRatingDetail(ratingId: string): Promise<RatingDetail> {
  if (!isUuid(ratingId)) throw new ApiError('NOT_FOUND', { resource: 'rating' })
  const sb = getSupabase()
  const rating = unwrap<SellerRatingRow>(await sb.from('seller_ratings').select('*').eq('id', ratingId).maybeSingle())
  const [history, replyRes, appeals] = await Promise.all([
    sb.from('seller_rating_history').select('*').eq('rating_id', ratingId).order('replaced_at', { ascending: true }),
    sb.from('rating_replies').select('*').eq('rating_id', ratingId).maybeSingle(),
    sb.from('rating_appeals').select('*').eq('rating_id', ratingId).order('created_at', { ascending: false }),
  ])
  if (replyRes.error) unwrap(replyRes)
  return {
    rating,
    history: unwrap(history),
    reply: (replyRes.data as RatingReplyRow | null) ?? null,
    appeals: unwrap(appeals),
  }
}

export function useRatingDetail(ratingId: string) {
  return useQuery({
    queryKey: ratingKeys.detail(ratingId),
    queryFn: () => fetchRatingDetail(ratingId),
  })
}
