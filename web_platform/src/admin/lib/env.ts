// إعداد البيئة: عنوان المشروع والمفتاح العام للعميل فقط (ADMIN-HANDOFF القسم 3).
// ترفض اللوحة التشغيل بمفتاح سري حتى لا يصل إلى المتصفح خطأً.

export interface AdminEnv {
  url: string
  publishableKey: string
}

export type EnvResult = { ok: true; env: AdminEnv } | { ok: false; problem: string }

function decodeJwtRole(key: string): string | null {
  const parts = key.split('.')
  if (parts.length !== 3 || !parts[1]) return null
  try {
    const json = atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'))
    const payload = JSON.parse(json) as { role?: unknown }
    return typeof payload.role === 'string' ? payload.role : null
  } catch {
    return null
  }
}

/** يكشف المفاتيح السرية: sb_secret_ أو JWT بدور service_role. */
export function isSecretKey(key: string): boolean {
  if (key.startsWith('sb_secret_')) return true
  return decodeJwtRole(key) === 'service_role'
}

export function validateEnv(raw: { url?: string; key?: string }): EnvResult {
  const url = raw.url?.trim() ?? ''
  const key = raw.key?.trim() ?? ''
  if (!url || !key) {
    return { ok: false, problem: 'لم تضبط VITE_SUPABASE_URL وVITE_SUPABASE_PUBLISHABLE_KEY. انسخ .env.example إلى .env.local واملأ القيم.' }
  }
  if (!/^https?:\/\//.test(url)) {
    return { ok: false, problem: 'قيمة VITE_SUPABASE_URL يجب أن تبدأ بـ https://' }
  }
  if (isSecretKey(key)) {
    return { ok: false, problem: 'المفتاح المضبوط مفتاح سري (service_role). استخدم المفتاح العام للعميل فقط.' }
  }
  return { ok: true, env: { url, publishableKey: key } }
}

export function readEnv(): EnvResult {
  return validateEnv({
    url: import.meta.env.VITE_SUPABASE_URL,
    key: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY,
  })
}
