import { useState } from 'react'
import { useMutation, useQueryClient, type QueryKey } from '@tanstack/react-query'
import { Badge, Button, ConfirmDialog, DataTable, EmptyState, useNotify, type Column } from '@admin/ui'
import { formatNumber } from '@admin/lib/format'
import { reorderLookup, setLookupActive } from './api'
import { lookupErrorMessage, shouldRefetch } from './errors'
import { DEACTIVATE_EXPLAIN, KIND_NOUN } from './labels'
import type { LookupKind } from './types'

interface LookupRowBase {
  is_active: boolean
  sort_order: number
}

export interface LookupListProps<T extends LookupRowBase> {
  kind: LookupKind
  /** الصفوف مرتبة بـsort_order كما يعيدها الخادم. */
  rows: T[]
  idOf: (row: T) => string
  nameOf: (row: T) => string
  columns: Column<T>[]
  caption: string
  canManage: boolean
  onEdit: (row: T) => void
  /** مفاتيح تبطل بعد التفعيل أو الترتيب. */
  invalidate: QueryKey[]
  emptyTitle?: string
}

/**
 * جدول قائمة مرجعية: الترتيب والحالة وأزرار التعديل والتفعيل والنقل.
 * لا زر حذف: القيم تعطل فقط (AD-FR-037، ADMIN-HANDOFF القسم 5).
 */
export function LookupList<T extends LookupRowBase>({ kind, rows, idOf, nameOf, columns, caption, canManage, onEdit, invalidate, emptyTitle = 'لا توجد قيم بعد.' }: LookupListProps<T>) {
  const qc = useQueryClient()
  const notify = useNotify()
  const [toggling, setToggling] = useState<T | null>(null)

  const refresh = () => Promise.all(invalidate.map((queryKey) => qc.invalidateQueries({ queryKey })))

  const toggle = useMutation({
    mutationFn: (v: { id: string; active: boolean }) => setLookupActive(kind, v.id, v.active),
    onError: (err) => {
      if (shouldRefetch(err)) void refresh()
    },
  })

  const reorder = useMutation({
    mutationFn: (ids: string[]) => reorderLookup(kind, ids),
    onSuccess: async () => {
      await refresh()
      notify.success('تم حفظ الترتيب.')
    },
    onError: (err) => {
      notify.error(`لم يحفظ الترتيب: ${lookupErrorMessage(err)}`)
      void refresh()
    },
  })

  function move(index: number, delta: -1 | 1) {
    const target = index + delta
    if (reorder.isPending || target < 0 || target >= rows.length) return
    const ids = rows.map(idOf)
    const a = ids[index]
    const b = ids[target]
    if (a === undefined || b === undefined) return
    ids[index] = b
    ids[target] = a
    reorder.mutate(ids)
  }

  const allColumns: Column<T>[] = [
    { key: 'pos', header: 'الترتيب', className: 'cell-num', render: (r) => formatNumber(rows.indexOf(r) + 1) },
    ...columns,
    {
      key: 'status',
      header: 'الحالة',
      render: (r) => (r.is_active ? <Badge tone="success">فعالة</Badge> : <Badge tone="neutral">معطلة</Badge>),
    },
  ]

  if (canManage) {
    allColumns.push({
      key: 'actions',
      header: <span className="sr-only">الإجراءات</span>,
      className: 'cell-actions',
      render: (r) => {
        const i = rows.indexOf(r)
        const name = nameOf(r)
        return (
          <div className="row" style={{ justifyContent: 'flex-end', gap: 6 }}>
            <Button size="sm" variant="ghost" onClick={() => move(i, -1)} disabled={i === 0 || reorder.isPending} aria-label={`نقل «${name}» إلى أعلى`}>
              أعلى
            </Button>
            <Button size="sm" variant="ghost" onClick={() => move(i, 1)} disabled={i === rows.length - 1 || reorder.isPending} aria-label={`نقل «${name}» إلى أسفل`}>
              أسفل
            </Button>
            <Button size="sm" onClick={() => onEdit(r)} aria-label={`تعديل «${name}»`}>
              تعديل
            </Button>
            <Button size="sm" variant={r.is_active ? 'danger' : 'primary'} onClick={() => setToggling(r)} aria-label={`${r.is_active ? 'تعطيل' : 'تفعيل'} «${name}»`}>
              {r.is_active ? 'تعطيل' : 'تفعيل'}
            </Button>
          </div>
        )
      },
    })
  }

  const noun = KIND_NOUN[kind]
  const willActivate = toggling ? !toggling.is_active : false

  return (
    <>
      <DataTable columns={allColumns} rows={rows} rowKey={idOf} caption={caption} empty={<EmptyState title={emptyTitle} />} />
      {reorder.isPending && (
        <p className="muted small" role="status">
          جارٍ حفظ الترتيب…
        </p>
      )}
      <ConfirmDialog
        open={toggling !== null}
        title={toggling ? `${willActivate ? 'تفعيل' : 'تعطيل'} ${noun} «${nameOf(toggling)}»` : ''}
        message={
          willActivate ? (
            <p>ستعود القيمة متاحة للاختيار في الإعلانات والإجراءات الجديدة.</p>
          ) : (
            <p>{DEACTIVATE_EXPLAIN}</p>
          )
        }
        confirmLabel={willActivate ? 'تفعيل' : 'تعطيل'}
        tone={willActivate ? 'primary' : 'danger'}
        onClose={() => setToggling(null)}
        onConfirm={async () => {
          if (!toggling) return
          const active = !toggling.is_active
          await toggle.mutateAsync({ id: idOf(toggling), active })
          await refresh()
          notify.success(active ? `تم تفعيل ${noun}.` : `تم تعطيل ${noun}.`)
        }}
      />
    </>
  )
}
