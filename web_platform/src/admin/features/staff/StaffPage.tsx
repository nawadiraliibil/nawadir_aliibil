import { useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuth } from '@admin/auth/AuthContext'
import { CAPABILITY_LABELS, ROLE_LABELS, type Capability } from '@admin/lib/capabilities'
import { toApiError } from '@admin/lib/errors'
import { formatDateTime } from '@admin/lib/format'
import { rpc, unwrap } from '@admin/lib/rpc'
import { getSupabase } from '@admin/lib/supabase'
import { Alert, Badge, Button, ConfirmDialog, DataTable, EmptyState, ErrorState, Loading, PageHeader, useNotify, type Column } from '@admin/ui'
import { RoleDialog, type RoleInput } from './RoleDialog'
import { ActorLabel, CopyableId } from './shared'
import { ADMIN_ROLE_COLUMNS, type AdminRoleRow, type GrantRoleResult } from './types'

const STAFF_KEY = ['admin', 'staff', 'roles'] as const

async function fetchRoles(): Promise<AdminRoleRow[]> {
  const rows = unwrap(
    await getSupabase()
      .from('admin_roles')
      .select(ADMIN_ROLE_COLUMNS)
      .order('is_active', { ascending: false })
      .order('granted_at', { ascending: false })
      .limit(1000),
  )
  return rows as AdminRoleRow[]
}

function CapabilityList({ row }: { row: AdminRoleRow }) {
  if (row.role === 'ADMIN') return <span>كل القدرات</span>
  if (row.capabilities.length === 0) return <span className="muted">لا قدرات</span>
  return (
    <ul className="stack small" style={{ margin: 0, paddingInlineStart: 16 }}>
      {row.capabilities.map((c) => (
        <li key={c}>{CAPABILITY_LABELS[c as Capability] ?? c}</li>
      ))}
    </ul>
  )
}

/** الموظفون وأدوارهم (AD-FR-017، AD-FR-021). القدرة: staff.manage. */
export default function StaffPage() {
  const { whoami, can, handleApiError } = useAuth()
  const meId = whoami?.user_id ?? null
  const canManage = can('staff.manage')
  const qc = useQueryClient()
  const notify = useNotify()

  const query = useQuery({ queryKey: STAFF_KEY, queryFn: fetchRoles })

  const [dialog, setDialog] = useState<{ existing: AdminRoleRow | null } | null>(null)
  const [revoking, setRevoking] = useState<AdminRoleRow | null>(null)

  async function refreshAfterWrite() {
    await Promise.all([qc.invalidateQueries({ queryKey: ['admin', 'staff'] }), qc.invalidateQueries({ queryKey: ['admin', 'audit'] })])
  }

  async function grant(input: RoleInput) {
    try {
      const res = (await rpc('admin_grant_role', input)) as GrantRoleResult
      await refreshAfterWrite()
      notify.success(`حفظ دور ${ROLE_LABELS[res.role] ?? res.role} للموظف. يسري في استدعائه التالي.`)
    } catch (err) {
      handleApiError(err)
      throw err
    }
  }

  async function revoke(row: AdminRoleRow, note: string | undefined) {
    try {
      await rpc('admin_revoke_role', { p_user_id: row.user_id, p_reason: note })
      await refreshAfterWrite()
      notify.success('سحب الدور. يسري في الاستدعاء التالي لهذا الموظف.')
    } catch (err) {
      handleApiError(err)
      // الحالة تغيرت في الخادم (لا دور فعال): نعيد التحميل دون إعادة محاولة.
      if (toApiError(err).code === 'INVALID_STATE') void qc.invalidateQueries({ queryKey: ['admin', 'staff'] })
      throw err
    }
  }

  const rows = query.data ?? []
  const activeAdmins = rows.filter((r) => r.is_active && r.role === 'ADMIN').length

  const columns: Column<AdminRoleRow>[] = [
    {
      key: 'user',
      header: 'معرف الموظف',
      render: (r) => (
        <div className="stack" style={{ gap: 4 }}>
          <CopyableId id={r.user_id} />
          {r.user_id === meId && <Badge tone="gold">أنت</Badge>}
        </div>
      ),
    },
    {
      key: 'role',
      header: 'الدور',
      render: (r) => <Badge tone={r.role === 'ADMIN' ? 'info' : 'neutral'}>{ROLE_LABELS[r.role] ?? r.role}</Badge>,
    },
    { key: 'caps', header: 'القدرات', render: (r) => <CapabilityList row={r} /> },
    {
      key: 'status',
      header: 'الحالة',
      render: (r) => (r.is_active ? <Badge tone="success">فعال</Badge> : <Badge tone="danger">مسحوب</Badge>),
    },
    {
      key: 'granted',
      header: 'المنح',
      render: (r) => (
        <div className="stack small" style={{ gap: 2 }}>
          <span>{formatDateTime(r.granted_at)}</span>
          <span className="muted">
            بواسطة: <ActorLabel id={r.granted_by} meId={meId} />
          </span>
        </div>
      ),
    },
    {
      key: 'revoked',
      header: 'السحب',
      render: (r) =>
        r.revoked_at ? (
          <div className="stack small" style={{ gap: 2 }}>
            <span>{formatDateTime(r.revoked_at)}</span>
            <span className="muted">
              بواسطة: <ActorLabel id={r.revoked_by} meId={meId} />
            </span>
          </div>
        ) : (
          <span className="muted">—</span>
        ),
    },
    {
      key: 'actions',
      header: 'الإجراءات',
      className: 'cell-actions',
      render: (r) => {
        if (r.user_id === meId) return <span className="muted small">لا يمكنك تعديل دورك أو سحبه بنفسك.</span>
        if (!canManage) return null
        return (
          <div className="row">
            <Button size="sm" onClick={() => setDialog({ existing: r })} aria-label={`${r.is_active ? 'تعديل دور' : 'إعادة منح دور'} ${r.user_id}`}>
              {r.is_active ? 'تعديل' : 'إعادة منح'}
            </Button>
            {r.is_active && (
              <Button size="sm" variant="danger" onClick={() => setRevoking(r)} aria-label={`سحب دور ${r.user_id}`}>
                سحب الدور
              </Button>
            )}
          </div>
        )
      },
    },
  ]

  return (
    <div className="page">
      <PageHeader
        title="الموظفون والأدوار"
        description="منح أدوار الموظفين وتعديلها وسحبها. الصلاحية تفحص في الخادم في كل استدعاء، فيسري التغيير في الاستدعاء التالي للموظف."
        actions={
          canManage ? (
            <Button variant="primary" onClick={() => setDialog({ existing: null })}>
              منح دور
            </Button>
          ) : undefined
        }
      />

      <Alert tone="info" title="حسابات الموظفين">
        ينشأ حساب الموظف في لوحة Supabase (Authentication) ببريد إلكتروني وكلمة مرور، ثم يمنح الدور هنا بمعرف الحساب. يسجل الموظف التحقق بخطوتين (TOTP) عند أول دخول. لا يظهر البريد أو الاسم هنا لأن العقد لا يتيحهما بعد؛ يعرض معرف الحساب.
      </Alert>

      {query.isPending ? (
        <Loading />
      ) : query.isError ? (
        <ErrorState error={query.error} onRetry={() => void query.refetch()} />
      ) : (
        <>
          {activeAdmins === 1 && <p className="muted small">يوجد مدير فعال واحد؛ لا يمكن سحب دوره أو تخفيضه (آخر مدير).</p>}
          <DataTable
            caption="الموظفون وأدوارهم"
            columns={columns}
            rows={rows}
            rowKey={(r) => r.user_id}
            empty={<EmptyState title="لا موظفين بأدوار بعد">امنح أول دور بزر «منح دور».</EmptyState>}
          />
        </>
      )}

      <RoleDialog
        open={dialog !== null}
        existing={dialog?.existing ?? null}
        meId={meId}
        knownRows={rows}
        onClose={() => setDialog(null)}
        onSubmit={grant}
      />

      <ConfirmDialog
        open={revoking !== null}
        title="سحب الدور"
        tone="danger"
        confirmLabel="سحب الدور"
        message={
          revoking && (
            <div className="stack">
              <p>
                سيسحب دور {ROLE_LABELS[revoking.role] ?? revoking.role} من الحساب{' '}
                <code className="mono ltr" dir="ltr">
                  {revoking.user_id}
                </code>
                .
              </p>
              <p>يسري السحب في الاستدعاء التالي لهذا الموظف، فتغلق عليه اللوحة عند أول طلب. يبقى السجل محفوظًا ويمكن إعادة المنح لاحقًا.</p>
            </div>
          )
        }
        noteLabel="سبب السحب"
        noteHint="يحفظ في سجل الإجراءات."
        noteRequired
        onClose={() => setRevoking(null)}
        onConfirm={(note) => (revoking ? revoke(revoking, note) : Promise.resolve())}
      />
    </div>
  )
}
