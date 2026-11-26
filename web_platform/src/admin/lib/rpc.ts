import type { Database } from '@contracts/generated/database.types'
import { getSupabase } from './supabase'
import { ApiError, toApiError } from './errors'
import { reportAuthError } from './queryClient'

type Fns = Database['public']['Functions']
export type RpcName = keyof Fns
/** مدخلات الدالة كما في الأنواع المولدة (contracts/generated/database.types.ts). */
export type RpcArgs<N extends RpcName> = Fns[N]['Args']
type ArgsTuple<N extends RpcName> = [Fns[N]['Args']] extends [never] ? [] : [args: Fns[N]['Args']]

type RawResult = { data: unknown; error: unknown; status?: number }

/**
 * استدعاء دالة من العقد (contracts/api/rpc.yaml). كل كتابة إدارية تمر من هنا
 * عبر دوال admin_* فقط؛ لا insert/update/delete مباشر على الجداول.
 * المدخلات مفحوصة بالأنواع المولدة. الرد JSON (jsonb) يحدد شكله المستدعي بـas
 * وفق contracts/fixtures: `const rows = (await rpc('admin_list_listings', {...})) as AdminListingItem[]`.
 * الأخطاء ترمى ApiError برمز العقد (VERSION_CHANGED، FORBIDDEN، MFA_REQUIRED، ...).
 */
export async function rpc<N extends RpcName>(name: N, ...args: ArgsTuple<N>): Promise<unknown> {
  let result: RawResult
  try {
    const client = getSupabase()
    const call = client.rpc as unknown as (this: unknown, fn: string, a?: object) => PromiseLike<RawResult>
    result = await call.call(client, name as string, (args[0] as object | undefined) ?? {})
  } catch (err) {
    throw toApiError(err)
  }
  if (result.error) {
    const e = toApiError(result.error, result.status)
    reportAuthError(e)
    throw e
  }
  return result.data
}

/** يفك نتيجة قراءة جدول بـsupabase.from(...) ويرمي ApiError عند الخطأ. */
export function unwrap<T>(result: { data: T | null; error: unknown; status?: number }): T {
  if (result.error) {
    const e = toApiError(result.error, result.status)
    reportAuthError(e)
    throw e
  }
  if (result.data === null) throw new ApiError('NOT_FOUND')
  return result.data
}
