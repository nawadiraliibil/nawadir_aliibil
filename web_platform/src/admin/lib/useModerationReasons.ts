import { useQuery } from '@tanstack/react-query'
import { getSupabase } from './supabase'
import { unwrap } from './rpc'
import type { ModerationAction } from './labels'

export interface ModerationReason {
  code: string
  label_ar: string
  applies_to: string[]
  requires_note: boolean
  sort_order: number
  is_active: boolean
}

/** الأسباب الفعالة لإجراء إشراف (TEAM-DEC-011 البند 3). */
export function useModerationReasons(action: ModerationAction, enabled = true) {
  return useQuery({
    queryKey: ['admin', 'moderation-reasons', action],
    enabled,
    staleTime: 5 * 60 * 1000,
    queryFn: async () => {
      const res = await getSupabase()
        .from('moderation_reasons')
        .select('code, label_ar, applies_to, requires_note, sort_order, is_active')
        .eq('is_active', true)
        .contains('applies_to', [action])
        .order('sort_order', { ascending: true })
      return unwrap(res) as ModerationReason[]
    },
  })
}
