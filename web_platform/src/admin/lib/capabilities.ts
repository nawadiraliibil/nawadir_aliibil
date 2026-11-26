// القدرات والأدوار (ADMIN-HANDOFF القسم 3). الإظهار في الواجهة ليس حماية؛ الخادم يفحص كل استدعاء.

export const CAPABILITIES = [
  'listings.review',
  'listings.hide',
  'accounts.manage',
  'reports.handle',
  'evidence.read',
  'comments.moderate',
  'ratings.moderate',
  'lookups.manage',
  'settings.manage',
  'staff.manage',
  'audit.read',
  'stats.read',
] as const

export type Capability = (typeof CAPABILITIES)[number]
export type StaffRole = 'MODERATOR' | 'ADMIN'

export const CAPABILITY_LABELS: Record<Capability, string> = {
  'listings.review': 'عرض الإعلانات وتفاصيلها',
  'listings.hide': 'إخفاء الإعلانات وإعادة إظهارها',
  'accounts.manage': 'إدارة الحسابات وتعليقها',
  'reports.handle': 'إدارة البلاغات',
  'evidence.read': 'الاطلاع على أدلة البلاغات',
  'comments.moderate': 'إشراف الردود العامة',
  'ratings.moderate': 'إشراف التقييمات والاعتراضات',
  'lookups.manage': 'القوائم وأسباب الإشراف',
  'settings.manage': 'الإعدادات وإصداراتها',
  'staff.manage': 'الموظفون والأدوار',
  'audit.read': 'سجل الإجراءات',
  'stats.read': 'التقارير التجميعية',
}

export const ROLE_LABELS: Record<StaffRole, string> = {
  ADMIN: 'مدير',
  MODERATOR: 'مشرف',
}

export interface Whoami {
  role: StaffRole
  user_id: string
  capabilities: string[]
}

/** هل يملك الموظف واحدة على الأقل من القدرات؟ المدير يملك الكل. */
export function hasAny(who: Whoami | null | undefined, caps: readonly Capability[]): boolean {
  if (!who) return false
  if (who.role === 'ADMIN') return true
  if (caps.length === 0) return true
  return caps.some((c) => who.capabilities.includes(c))
}
