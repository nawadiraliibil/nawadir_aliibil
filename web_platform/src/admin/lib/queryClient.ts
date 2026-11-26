import { MutationCache, QueryCache, QueryClient } from '@tanstack/react-query'
import { toApiError } from './errors'

type Handler = (error: unknown) => void
let globalHandler: Handler | null = null

/** يسجله AuthProvider ليعالج انتهاء الجلسة وMFA وسحب الدور من أي استدعاء. */
export function setGlobalApiErrorHandler(fn: Handler | null): void {
  globalHandler = fn
}

const AUTH_CODES = new Set(['AUTH_REQUIRED', 'MFA_REQUIRED', 'FORBIDDEN'])

/**
 * يبلغ معالج الجلسة بأخطاء الجلسة وMFA والصلاحية من أي استدعاء، حتى الكتابة
 * التي لا تمر بـuseMutation، فينتقل الموظف إلى الدخول أو التحقق أو «لا صلاحية».
 */
export function reportAuthError(error: unknown): void {
  if (AUTH_CODES.has(toApiError(error).code)) globalHandler?.(error)
}

const NO_RETRY = new Set(['FORBIDDEN', 'MFA_REQUIRED', 'AUTH_REQUIRED', 'NOT_FOUND', 'VALIDATION_FAILED', 'INVALID_STATE'])

export function createAdminQueryClient(): QueryClient {
  return new QueryClient({
    queryCache: new QueryCache({ onError: (e) => globalHandler?.(e) }),
    mutationCache: new MutationCache({ onError: (e) => globalHandler?.(e) }),
    defaultOptions: {
      queries: {
        staleTime: 15_000,
        refetchOnWindowFocus: false,
        retry: (count, error) => !NO_RETRY.has(toApiError(error).code) && count < 2,
      },
      // لا إعادة تلقائية للكتابة: VERSION_CHANGED وغيره يعرض ولا يعاد (ADMIN-HANDOFF القسم 5).
      mutations: { retry: false },
    },
  })
}
