// أنواع الموظفين وسجل الإجراءات (AD-FR-017، AD-FR-021).
// الأعمدة من contracts/generated/database.types.ts، وأشكال الردود من
// supabase/migrations/20261122162332_staff_audit.sql (admin_grant_role، admin_revoke_role).
import type { Database } from '@contracts/generated/database.types'
import type { StaffRole } from '@admin/lib/capabilities'

type Tables = Database['public']['Tables']

export type AdminRoleRow = Tables['admin_roles']['Row']
export type AuditLogRow = Tables['audit_log']['Row']
export type EvidenceAccessRow = Tables['report_evidence_access']['Row']

/** رد admin_grant_role. */
export interface GrantRoleResult {
  user_id: string
  role: StaffRole
  capabilities: string[]
  is_active: true
}

/** رد admin_revoke_role. */
export interface RevokeRoleResult {
  user_id: string
  role: StaffRole
  is_active: false
}

/** مرشحات سجل الإجراءات بعد التطبيق. */
export interface AuditFilters {
  action: string
  resourceType: string
  /** '' الكل، 'me' أنا، 'system' النظام، 'id' معرف محدد. */
  actorMode: '' | 'me' | 'system' | 'id'
  actorId: string
  /** أيام بتوقيت الرياض YYYY-MM-DD. */
  from: string
  to: string
}

export const EMPTY_AUDIT_FILTERS: AuditFilters = {
  action: '',
  resourceType: '',
  actorMode: '',
  actorId: '',
  from: '',
  to: '',
}

export const ADMIN_ROLE_COLUMNS = 'user_id, role, capabilities, is_active, granted_at, granted_by, revoked_at, revoked_by, updated_at'
export const AUDIT_LOG_COLUMNS = 'id, actor_id, action, resource_type, resource_id, reason_code, reason_text, details, created_at'
export const EVIDENCE_ACCESS_COLUMNS = 'id, report_id, actor_id, created_at'
