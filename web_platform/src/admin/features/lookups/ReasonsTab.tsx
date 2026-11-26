import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Badge, Button, Card, ErrorState, Loading } from '@admin/ui'
import { MODERATION_ACTION_LABELS, label } from '@admin/lib/labels'
import { SHARED_REASONS_KEY, fetchReasons, lookupKeys } from './api'
import { LookupList } from './LookupList'
import { ModerationReasonDialog } from './ModerationReasonDialog'
import { CURRENT_REASON_ACTIONS, LEGACY_REASON_ACTION } from './labels'
import type { ModerationReasonRow } from './types'

const ACTION_ORDER: string[] = [...CURRENT_REASON_ACTIONS, LEGACY_REASON_ACTION]

function sortedActions(actions: string[]): string[] {
  return [...actions].sort((a, b) => {
    const ia = ACTION_ORDER.indexOf(a)
    const ib = ACTION_ORDER.indexOf(b)
    return (ia === -1 ? 99 : ia) - (ib === -1 ? 99 : ib)
  })
}

export function ReasonsTab({ canManage }: { canManage: boolean }) {
  const q = useQuery({ queryKey: lookupKeys.reasons(), queryFn: fetchReasons })
  const [editing, setEditing] = useState<{ value: ModerationReasonRow | null } | null>(null)
  const hasLegacy = (q.data ?? []).some((r) => r.applies_to.includes(LEGACY_REASON_ACTION))

  return (
    <Card
      title="أسباب الإشراف"
      actions={
        canManage && (
          <Button variant="primary" onClick={() => setEditing({ value: null })}>
            إضافة سبب
          </Button>
        )
      }
    >
      <div className="stack">
        <p className="muted small">
          تظهر الأسباب الفعالة للموظف عند إخفاء إعلان أو رد أو تقييم، أو تعليق حساب. السبب الذي يتطلب توضيحًا (مثل «أخرى») لا يقبل دون نص حر.
          {hasLegacy && ' الإجراء «رفض إعلان (قديم)» لم يعد مستخدمًا بعد إلغاء المراجعة المسبقة (TEAM-DEC-013)، ويبقى ظاهرًا فقط على الأسباب التي تحمله.'}
        </p>
        {q.isPending ? (
          <Loading />
        ) : q.isError ? (
          <ErrorState error={q.error} onRetry={() => void q.refetch()} />
        ) : (
          <LookupList<ModerationReasonRow>
            kind="moderation_reason"
            rows={q.data}
            idOf={(r) => r.code}
            nameOf={(r) => r.label_ar}
            caption="أسباب الإشراف بالترتيب"
            canManage={canManage}
            onEdit={(r) => setEditing({ value: r })}
            invalidate={[lookupKeys.reasons(), SHARED_REASONS_KEY]}
            emptyTitle="لا توجد أسباب إشراف بعد."
            columns={[
              { key: 'label', header: 'السبب', render: (r) => r.label_ar },
              {
                key: 'code',
                header: 'الرمز',
                render: (r) => (
                  <span className="mono ltr" dir="ltr">
                    {r.code}
                  </span>
                ),
              },
              {
                key: 'applies',
                header: 'ينطبق على',
                render: (r) => (
                  <span className="row" style={{ gap: 4 }}>
                    {sortedActions(r.applies_to).map((a) => (
                      <Badge key={a} tone={a === LEGACY_REASON_ACTION ? 'neutral' : 'info'} title={a === LEGACY_REASON_ACTION ? 'إجراء قديم غير مستخدم (TEAM-DEC-013)' : undefined}>
                        {label(MODERATION_ACTION_LABELS, a)}
                      </Badge>
                    ))}
                  </span>
                ),
              },
              {
                key: 'note',
                header: 'توضيح إلزامي',
                render: (r) => (r.requires_note ? <Badge tone="warning">يتطلب نصًا</Badge> : <span className="muted">—</span>),
              },
            ]}
          />
        )}
      </div>
      <ModerationReasonDialog
        open={editing !== null}
        value={editing?.value ?? null}
        existingCodes={(q.data ?? []).map((r) => r.code)}
        onClose={() => setEditing(null)}
      />
    </Card>
  )
}
