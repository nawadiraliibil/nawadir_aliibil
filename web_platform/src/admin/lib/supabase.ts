import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '@contracts/generated/database.types'
import { readEnv } from './env'

export type AdminSupabase = SupabaseClient<Database>

let client: AdminSupabase | null = null

/** عميل Supabase بالمفتاح العام وجلسة الموظف. لا مفتاح service_role في المتصفح. */
export function getSupabase(): AdminSupabase {
  if (client) return client
  const env = readEnv()
  if (!env.ok) throw new Error(env.problem)
  client = createClient<Database>(env.env.url, env.env.publishableKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      storageKey: 'nawader-admin-auth',
    },
  })
  return client
}

/** للاختبارات فقط. */
export function setSupabaseForTests(fake: unknown): void {
  client = fake as AdminSupabase
}
