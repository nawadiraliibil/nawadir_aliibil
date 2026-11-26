// قراءات الحسابات وكتاباتها. القراءة من profiles بصلاحية الموظف، والكتابة عبر دوال admin_* فقط.
import { rpc, unwrap } from '@admin/lib/rpc'
import { getSupabase } from '@admin/lib/supabase'
import type { AccountStatus, AdminAccount, ProfilesPage, RegionName } from './types'

export const PAGE_SIZE = 50

export const ACCOUNT_STATUSES: readonly AccountStatus[] = ['ACTIVE', 'SUSPENDED']

export const accountKeys = {
  all: ['admin', 'accounts'] as const,
  list: (status: AccountStatus | null, q: string) => ['admin', 'accounts', 'list', { status, q }] as const,
  detail: (userId: string) => ['admin', 'accounts', 'detail', userId] as const,
  regions: ['admin', 'accounts', 'regions'] as const,
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export function isUuid(value: string): boolean {
  return UUID_RE.test(value.trim())
}

/** يهرب محارف LIKE حتى يبحث النص حرفيًا. */
export function escapeLike(value: string): string {
  return value.replace(/[\\%_]/g, (m) => `\\${m}`)
}

export function parseStatus(value: string | null): AccountStatus | null {
  return value === 'ACTIVE' || value === 'SUSPENDED' ? value : null
}

const PROFILE_COLUMNS = 'id, display_name, region_id, status, status_changed_at, suspension_reason_code, suspension_reason_text, created_at'

/**
 * صفحة من الحسابات: معرف UUID يطابق id حرفيًا، وغيره جزء من اسم العرض.
 * الترتيب الأحدث انضمامًا ثم المعرف، بصفحات من 50 وعدد كلي.
 */
export async function fetchProfilesPage(status: AccountStatus | null, q: string, page: number): Promise<ProfilesPage> {
  let query = getSupabase().from('profiles').select(PROFILE_COLUMNS, { count: 'exact' })
  if (status) query = query.eq('status', status)
  const text = q.trim()
  if (text) query = isUuid(text) ? query.eq('id', text.toLowerCase()) : query.ilike('display_name', `%${escapeLike(text)}%`)
  const from = page * PAGE_SIZE
  const res = await query
    .order('created_at', { ascending: false })
    .order('id', { ascending: false })
    .range(from, from + PAGE_SIZE - 1)
  const rows = unwrap(res)
  return { rows, total: typeof res.count === 'number' ? res.count : null }
}

/** أسماء المناطق (الفعالة للعامة، وكلها لمن يملك lookups.manage). */
export async function fetchRegions(): Promise<RegionName[]> {
  const res = await getSupabase().from('regions').select('id, name_ar').order('sort_order', { ascending: true })
  return unwrap(res)
}

export async function getAccount(userId: string): Promise<AdminAccount> {
  return (await rpc('admin_get_account', { p_user_id: userId })) as AdminAccount
}

export async function suspendAccount(userId: string, reasonCode: string, reasonText: string | undefined): Promise<AdminAccount> {
  return (await rpc('admin_suspend_account', {
    p_user_id: userId,
    p_reason_code: reasonCode,
    ...(reasonText ? { p_reason_text: reasonText } : {}),
  })) as AdminAccount
}

export async function reactivateAccount(userId: string, note: string | undefined): Promise<AdminAccount> {
  return (await rpc('admin_reactivate_account', { p_user_id: userId, ...(note ? { p_note: note } : {}) })) as AdminAccount
}

/** هاتف الدخول كما في auth.users (أرقام دون «+» عادة)؛ يضاف «+» للعرض فقط. */
export function formatLoginPhone(phone: string | null | undefined): string | null {
  if (!phone) return null
  const p = phone.trim()
  if (!p) return null
  return /^\d+$/.test(p) ? `+${p}` : p
}

/** رابط قائمة الإعلانات بالبحث النصي باسم المعلن (لا مرشح مالك في admin_list_listings). */
export function listingsSearchHref(displayName: string, status?: 'HIDDEN'): string {
  const params = new URLSearchParams({ q: displayName })
  if (status) params.set('status', status)
  return `/admin/listings?${params.toString()}`
}
