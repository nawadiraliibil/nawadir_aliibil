import { useCallback } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useModerationReasons } from '@admin/lib/useModerationReasons'
import { accountKeys, fetchRegions } from './api'

/** اسم المنطقة من جدول regions، أو «#id» إن لم تظهر (معطلة أو لم تحمل). */
export function useRegionName(): (id: number | null | undefined) => string {
  const regions = useQuery({ queryKey: accountKeys.regions, queryFn: fetchRegions, staleTime: 10 * 60 * 1000 })
  const data = regions.data
  return useCallback(
    (id) => {
      if (id === null || id === undefined) return '—'
      return data?.find((r) => r.id === id)?.name_ar ?? `#${id}`
    },
    [data],
  )
}

/** تسمية سبب التعليق من moderation_reasons (الفعالة)، أو الرمز نفسه إن لم توجد. */
export function useSuspendReasonLabel(enabled = true): (code: string | null | undefined) => string {
  const reasons = useModerationReasons('ACCOUNT_SUSPEND', enabled)
  const data = reasons.data
  return useCallback(
    (code) => {
      if (!code) return '—'
      return data?.find((r) => r.code === code)?.label_ar ?? code
    },
    [data],
  )
}
