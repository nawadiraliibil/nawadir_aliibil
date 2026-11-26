// قراءة الإعدادات وكتابتها. الكتابة عبر دوال admin_* فقط (contracts/api/rpc.yaml)؛
// سجل الإصدارات قراءة من settings_versions (contracts/api/read-surface.md: settings.manage).
import { useInfiniteQuery, useQuery } from '@tanstack/react-query'
import type { Json } from '@contracts/generated/database.types'
import { rpc, unwrap } from '@admin/lib/rpc'
import { getSupabase } from '@admin/lib/supabase'
import { ApiError } from '@admin/lib/errors'
import type { AdminSettingsPayload, SettingsContent, SettingsVersionRow } from './types'
import { NOTE_MAX } from './schema'

export const SETTINGS_KEYS = {
  all: ['admin', 'settings'] as const,
  current: ['admin', 'settings', 'current'] as const,
  versions: ['admin', 'settings', 'versions'] as const,
}

export const VERSIONS_PAGE_SIZE = 20

function asPayload(data: unknown): AdminSettingsPayload {
  const p = data as AdminSettingsPayload | null
  if (!p || typeof p !== 'object' || typeof p.published_version !== 'number') throw new ApiError('UNKNOWN', { reason: 'unexpected_settings_payload' })
  return { ...p, published: p.published ?? {}, draft: p.draft ?? null }
}

export async function fetchAdminSettings(): Promise<AdminSettingsPayload> {
  return asPayload(await rpc('admin_get_settings'))
}

/** حفظ المسودة بالمحتوى الكامل، أو إلغاؤها بـnull. */
export async function saveSettingsDraft(content: SettingsContent | null): Promise<AdminSettingsPayload> {
  return asPayload(await rpc('admin_update_settings_draft', { p_content: content as Json }))
}

function checkNote(note: string | undefined) {
  if (note && note.length > NOTE_MAX) throw new ApiError('VALIDATION_FAILED', { fields: ['note'] })
}

export async function publishSettings(note: string | undefined): Promise<AdminSettingsPayload> {
  checkNote(note)
  return asPayload(await rpc('admin_publish_settings', note ? { p_note: note } : {}))
}

export async function rollbackSettings(version: number, note: string | undefined): Promise<AdminSettingsPayload> {
  checkNote(note)
  return asPayload(await rpc('admin_rollback_settings', note ? { p_version: version, p_note: note } : { p_version: version }))
}

export function useAdminSettings(enabled: boolean) {
  return useQuery({ queryKey: SETTINGS_KEYS.current, queryFn: fetchAdminSettings, enabled })
}

export function useSettingsVersions(enabled: boolean) {
  return useInfiniteQuery({
    queryKey: SETTINGS_KEYS.versions,
    enabled,
    initialPageParam: 0,
    queryFn: async ({ pageParam }): Promise<SettingsVersionRow[]> =>
      unwrap(
        await getSupabase()
          .from('settings_versions')
          .select('version, content, note, restored_from_version, published_by, published_at')
          .order('version', { ascending: false })
          .range(pageParam, pageParam + VERSIONS_PAGE_SIZE - 1),
      ),
    getNextPageParam: (last, all) => (last.length === VERSIONS_PAGE_SIZE ? all.length * VERSIONS_PAGE_SIZE : undefined),
  })
}

/** نص سبب INVALID_STATE من الخادم (details.reason). */
export function invalidStateReason(e: ApiError): string | null {
  if (e.code !== 'INVALID_STATE') return null
  switch (e.details.reason) {
    case 'no_draft':
      return 'لا توجد مسودة للنشر؛ ربما نشرها أو ألغاها موظف آخر.'
    case 'no_changes':
      return 'المسودة مطابقة للإصدار المنشور؛ لا تغييرات للنشر.'
    case 'already_published':
      return 'هذا الإصدار هو المنشور حاليًا.'
    default:
      return null
  }
}
