// رموز أخطاء العقد (contracts/api/errors.json) ونصوصها العربية في اللوحة.
// الرمز في حقل message من رد PostgREST، والتفاصيل JSON في details (SQLSTATE P0001).

export const ERROR_MESSAGES_AR: Record<string, string> = {
  VALIDATION_FAILED: 'بعض القيم غير صالحة. راجع الحقول المحددة.',
  BELOW_HARD_MINIMUM: 'القيمة أقل من الحد الأدنى الثابت (تجديد الظهور لا يقل عن 24 ساعة).',
  APPEND_ONLY: 'هذا السجل للإضافة فقط ولا يعدل أو يحذف.',
  INTERNAL_ERROR: 'حدث خطأ في الخادم. أعد المحاولة لاحقًا.',
  AUTH_REQUIRED: 'انتهت الجلسة. سجل الدخول من جديد.',
  FORBIDDEN: 'لا تملك صلاحية تنفيذ هذا الإجراء.',
  ACCOUNT_SUSPENDED: 'الحساب معلق.',
  PROFILE_INCOMPLETE: 'بيانات الملف الشخصي ناقصة.',
  POLICIES_NOT_ACCEPTED: 'لم يوافق المستخدم على النصوص السارية.',
  MFA_REQUIRED: 'يلزم إكمال التحقق بخطوتين (رمز التطبيق) قبل استخدام اللوحة.',
  INVALID_STATE: 'لا يسمح بهذا الإجراء في الحالة الحالية. حدّث الصفحة لرؤية آخر حالة.',
  CANNOT_MODIFY_SELF: 'لا يمكنك تعديل دورك أو سحبه بنفسك.',
  LAST_ADMIN: 'لا يمكن سحب أو تخفيض دور آخر مدير فعال.',
  VERSION_IMMUTABLE: 'لا يمكن تعديل هذه النسخة.',
  NOT_FOUND: 'العنصر غير موجود أو حذف.',
  DRAFT_LIMIT_REACHED: 'بلغ الحساب حد المسودات المفتوحة.',
  MEDIA_LIMIT_REACHED: 'بلغت المسودة حد الوسائط.',
  MEDIA_NOT_READY: 'الوسائط لم يكتمل تجهيزها.',
  VIDEO_DISABLED: 'الفيديو معطل في الإعدادات المنشورة.',
  RATE_LIMITED: 'تجاوزت حد الاستخدام. انتظر قليلًا ثم أعد المحاولة.',
  BUMP_TOO_EARLY: 'لم تكتمل مهلة تجديد الظهور.',
  AUCTION_TIME_PASSED: 'مضى موعد المزاد الحضوري.',
  VERSION_CHANGED: 'تغيرت نسخة الإعلان منذ فتحها. أعد تحميل التفاصيل ثم قرر من جديد.',
  REASON_REQUIRED: 'السبب إلزامي. اختر سببًا، واكتب توضيحًا عند اختيار «أخرى».',
  MEDIA_NOT_UPLOADED: 'الملف لم يرفع بعد.',
  MEDIA_PROCESSING_FAILED: 'تعذرت معالجة الوسائط. أعد المحاولة.',
  METHOD_NOT_ALLOWED: 'طريقة الطلب غير مدعومة.',
  CANNOT_MESSAGE_SELF: 'لا محادثة مع النفس.',
  CONVERSATION_READ_ONLY: 'المحادثة للقراءة فقط.',
  COMMENTS_CLOSED: 'الردود مغلقة على هذا الإعلان.',
  FOLLOW_LIMIT_REACHED: 'بلغ الحساب حد المتابعات.',
  RATING_NOT_ELIGIBLE: 'لا يحق التقييم.',
  RATING_EXISTS: 'التقييم موجود مسبقًا.',
  // رموز اللوحة نفسها (ليست من الخادم).
  NETWORK: 'تعذر الاتصال بالخادم. تحقق من الاتصال ثم أعد المحاولة.',
  UNKNOWN: 'حدث خطأ غير متوقع. أعد المحاولة.',
}

export class ApiError extends Error {
  readonly code: string
  readonly details: Record<string, unknown>
  readonly status: number | undefined

  constructor(code: string, details: Record<string, unknown> = {}, status?: number, raw?: string) {
    super(raw ?? code)
    this.name = 'ApiError'
    this.code = code
    this.details = details
    this.status = status
  }

  /** أسماء الحقول المرفوضة من VALIDATION_FAILED أو REASON_REQUIRED. */
  get fields(): string[] {
    const f = this.details.fields
    if (Array.isArray(f)) return f.filter((x): x is string => typeof x === 'string')
    const one = this.details.field
    return typeof one === 'string' ? [one] : []
  }
}

const KNOWN = new Set(Object.keys(ERROR_MESSAGES_AR))

function parseDetails(details: unknown): Record<string, unknown> {
  if (details && typeof details === 'object') return details as Record<string, unknown>
  if (typeof details !== 'string' || details.trim() === '') return {}
  try {
    const parsed: unknown = JSON.parse(details)
    return parsed && typeof parsed === 'object' ? (parsed as Record<string, unknown>) : {}
  } catch {
    return { text: details }
  }
}

interface PostgrestLikeError {
  message?: string
  details?: unknown
  code?: string
  hint?: string | null
}

/** يحول خطأ PostgREST أو الشبكة إلى ApiError برمز العقد. */
export function toApiError(error: unknown, status?: number): ApiError {
  if (error instanceof ApiError) return error
  if (error && typeof error === 'object') {
    const e = error as PostgrestLikeError
    const message = typeof e.message === 'string' ? e.message.trim() : ''
    if (KNOWN.has(message)) return new ApiError(message, parseDetails(e.details), status, message)
    // انتهاء الجلسة أو JWT غير صالح من PostgREST.
    if (e.code === 'PGRST301' || e.code === 'PGRST302' || status === 401) {
      return new ApiError('AUTH_REQUIRED', {}, status, message)
    }
    if (e.code === '42501') return new ApiError('FORBIDDEN', {}, status, message)
    if (/fetch|network|Failed to fetch|NetworkError|Load failed/i.test(message)) {
      return new ApiError('NETWORK', {}, status, message)
    }
    return new ApiError('UNKNOWN', parseDetails(e.details), status, message || undefined)
  }
  return new ApiError('UNKNOWN', {}, status, String(error))
}

/** نص عربي للعرض من أي خطأ. */
export function errorMessage(error: unknown): string {
  const e = toApiError(error)
  return ERROR_MESSAGES_AR[e.code] ?? ERROR_MESSAGES_AR.UNKNOWN!
}
