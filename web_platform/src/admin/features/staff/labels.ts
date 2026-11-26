// تسميات سجل الإجراءات. أسماء الإجراءات وأنواع الموارد مأخوذة من استدعاءات
// private.audit في supabase/migrations/*.sql. القيمة غير المعروفة تعرض كما هي.
import { CAPABILITIES, type Capability } from '@admin/lib/capabilities'

export const AUDIT_ACTION_LABELS: Record<string, string> = {
  'staff.role_granted': 'منح دور أو تعديله',
  'staff.role_revoked': 'سحب دور',
  'staff.bootstrap_admin': 'تهيئة أول مدير',
  'listing.hidden': 'إخفاء إعلان',
  'listing.unhidden': 'إعادة إظهار إعلان',
  // سجلات تاريخية قبل النشر المباشر (TEAM-DEC-013)؛ لا تعرض في المرشحات.
  'listing.approved': 'اعتماد إعلان (قديم)',
  'listing.rejected': 'رفض إعلان (قديم)',
  'account.suspended': 'تعليق حساب',
  'account.reactivated': 'تفعيل حساب',
  'comment.hidden': 'إخفاء رد',
  'comment.unhidden': 'إعادة إظهار رد',
  'rating.hidden': 'إخفاء تقييم',
  'rating.unhidden': 'إعادة إظهار تقييم',
  'rating.appeal_decided': 'قرار اعتراض على تقييم',
  'report.assigned': 'إسناد بلاغ',
  'report.status_changed': 'تغيير حالة بلاغ',
  'report.closed': 'إغلاق بلاغ',
  'report.evidence_read': 'الاطلاع على أدلة بلاغ',
  'lookup.upserted': 'إضافة قيمة قائمة أو تعديلها',
  'lookup.activated': 'تفعيل قيمة قائمة',
  'lookup.deactivated': 'تعطيل قيمة قائمة',
  'lookup.reordered': 'إعادة ترتيب قائمة',
  'settings.published': 'نشر إصدار إعدادات',
  'settings.rolled_back': 'التراجع إلى إصدار إعدادات',
  'promotion.created': 'إنشاء دعاية تجارية',
  'promotion.updated': 'تعديل دعاية تجارية',
  'promotion.status_changed': 'تغيير حالة دعاية تجارية',
  'promotion.settings_updated': 'تغيير إعدادات عرض الدعايات',
}

const LEGACY_ACTIONS = new Set(['listing.approved', 'listing.rejected'])

/** الإجراءات المعروضة في مرشح السجل. */
export const AUDIT_FILTER_ACTIONS = Object.keys(AUDIT_ACTION_LABELS).filter((a) => !LEGACY_ACTIONS.has(a))

export const AUDIT_RESOURCE_LABELS: Record<string, string> = {
  listing: 'إعلان',
  account: 'حساب',
  comment: 'رد',
  rating: 'تقييم',
  rating_appeal: 'اعتراض تقييم',
  report: 'بلاغ',
  admin_role: 'دور موظف',
  region: 'منطقة',
  city: 'مدينة',
  breed: 'سلالة',
  moderation_reason: 'سبب إشراف',
  settings_version: 'إصدار إعدادات',
  promotion: 'دعاية تجارية',
  promotion_settings: 'إعدادات الدعايات',
}

export const AUDIT_RESOURCE_TYPES = Object.keys(AUDIT_RESOURCE_LABELS)

export function auditActionLabel(action: string): string {
  return AUDIT_ACTION_LABELS[action] ?? action
}

export function resourceTypeLabel(type: string): string {
  return AUDIT_RESOURCE_LABELS[type] ?? type
}

/** قدرات يملكها المدير وحده (private.admin_only_capabilities): لا تمنح لمشرف. */
export const ADMIN_ONLY_CAPABILITIES: readonly Capability[] = ['staff.manage', 'audit.read', 'stats.read']

/** القدرات القابلة للمنح لمشرف. */
export const MODERATOR_CAPABILITIES: readonly Capability[] = CAPABILITIES.filter((c) => !ADMIN_ONLY_CAPABILITIES.includes(c))
