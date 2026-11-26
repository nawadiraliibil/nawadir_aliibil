import type { ReactNode } from 'react'
import { Button } from './Button'

export interface Column<T> {
  key: string
  header: ReactNode
  render: (row: T) => ReactNode
  className?: string
}

export interface DataTableProps<T> {
  columns: Column<T>[]
  rows: T[]
  rowKey: (row: T) => string
  caption?: string
  onRowClick?: (row: T) => void
  empty?: ReactNode
}

/** جدول بيانات بسيط قابل للتمرير أفقيًا على الشاشات الصغيرة. */
export function DataTable<T>({ columns, rows, rowKey, caption, onRowClick, empty }: DataTableProps<T>) {
  if (rows.length === 0 && empty) return <>{empty}</>
  return (
    <div className="table-wrap">
      <table className="table">
        {caption && <caption className="sr-only">{caption}</caption>}
        <thead>
          <tr>
            {columns.map((c) => (
              <th key={c.key} scope="col" className={c.className}>
                {c.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr
              key={rowKey(r)}
              className={onRowClick ? 'row-click' : undefined}
              onClick={onRowClick ? () => onRowClick(r) : undefined}
              tabIndex={onRowClick ? 0 : undefined}
              onKeyDown={
                onRowClick
                  ? (e) => {
                      // الصف قابل للفتح بلوحة المفاتيح؛ لا يعترض أزرار الخلايا وروابطها.
                      if ((e.key === 'Enter' || e.key === ' ') && e.target === e.currentTarget) {
                        e.preventDefault()
                        onRowClick(r)
                      }
                    }
                  : undefined
              }
            >
              {columns.map((c) => (
                <td key={c.key} className={c.className}>
                  {c.render(r)}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

/** زر «تحميل المزيد» للتصفح بمفتاح آخر عنصر. */
export function LoadMore({ hasMore, loading, onClick }: { hasMore: boolean; loading: boolean; onClick: () => void }) {
  if (!hasMore) return null
  return (
    <div className="load-more">
      <Button onClick={onClick} loading={loading}>
        تحميل المزيد
      </Button>
    </div>
  )
}
