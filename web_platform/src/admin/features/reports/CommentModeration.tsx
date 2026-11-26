import { useState } from 'react'
import { useAuth } from '@admin/auth/AuthContext'
import { toApiError } from '@admin/lib/errors'
import { label } from '@admin/lib/labels'
import { Alert, Badge, Button, Card, ConfirmDialog, ReasonDialog, useNotify } from '@admin/ui'
import { hideComment, unhideComment } from './api'
import { COMMENT_STATE_LABELS } from './labels'
import type { CommentState } from './types'

/**
 * إشراف الرد العام المبلغ عنه (AD-FR-032): إخفاء بسبب إلزامي (COMMENT_HIDE)
 * وإعادة إظهار بملاحظة. جدول الردود مغلق على أدوار العميل، فلا تعرف حالته
 * الحالية مسبقًا؛ تعرض بعد أول إجراء أو من تفاصيل INVALID_STATE.
 */
export function CommentModeration({ commentId }: { commentId: string }) {
  const { can, handleApiError } = useAuth()
  const notify = useNotify()
  const [dialog, setDialog] = useState<'hide' | 'unhide' | null>(null)
  const [state, setState] = useState<CommentState | null>(null)

  if (!can('comments.moderate')) return null

  function learnFromError(err: unknown): never {
    const e = toApiError(err)
    handleApiError(e)
    // INVALID_STATE يحمل الحالة الحالية: HIDDEN عند الإخفاء المكرر، VISIBLE عند إظهار ظاهر.
    const status = e.details.status
    if (e.code === 'INVALID_STATE' && (status === 'HIDDEN' || status === 'VISIBLE')) setState(status)
    throw e
  }

  return (
    <Card title="إشراف الرد العام">
      <div className="stack">
        <div className="row">
          <span>حالة الرد:</span>
          {state ? (
            <Badge tone={state === 'HIDDEN' ? 'danger' : state === 'VISIBLE' ? 'success' : 'neutral'}>{label(COMMENT_STATE_LABELS, state)}</Badge>
          ) : (
            <span className="muted">غير معروفة</span>
          )}
        </div>
        {!state && (
          <p className="muted small">لا تعرض حالة الرد مسبقًا. إن كان الإجراء لا يناسب حالته الحالية يظهر تنبيه بذلك ولا ينفذ.</p>
        )}
        {state === 'DELETED' && <Alert tone="info">حذف صاحب الرد رده؛ إعادة الإظهار لا تعيده للعرض العام.</Alert>}
        <div className="row">
          {state !== 'HIDDEN' && state !== 'DELETED' && (
            <Button variant="danger" onClick={() => setDialog('hide')}>
              إخفاء الرد
            </Button>
          )}
          {state !== 'VISIBLE' && state !== 'DELETED' && (
            <Button onClick={() => setDialog('unhide')}>إعادة إظهار الرد</Button>
          )}
        </div>
      </div>

      <ReasonDialog
        open={dialog === 'hide'}
        action="COMMENT_HIDE"
        title="إخفاء الرد"
        description="يختفي الرد من العرض العام للإعلان، ويحفظ السبب وتوضيحه في سجل الإجراءات."
        confirmLabel="إخفاء الرد"
        onClose={() => setDialog(null)}
        onSubmit={async ({ reason_code, reason_text }) => {
          const res = await hideComment(commentId, reason_code, reason_text).catch(learnFromError)
          setState(res.state)
          notify.success('أُخفي الرد.')
        }}
      />
      <ConfirmDialog
        open={dialog === 'unhide'}
        title="إعادة إظهار الرد"
        message="يعود الرد إلى العرض العام للإعلان ما لم يكن صاحبه قد حذفه."
        confirmLabel="إعادة الإظهار"
        noteLabel="ملاحظة داخلية (اختيارية)"
        noteHint="تسجل في سجل الإجراءات ولا تظهر لصاحب الرد."
        onClose={() => setDialog(null)}
        onConfirm={async (note) => {
          const res = await unhideComment(commentId, note).catch(learnFromError)
          setState(res.state)
          notify.success(res.state === 'DELETED' ? 'أزيل الإخفاء، والرد محذوف من صاحبه.' : 'أعيد إظهار الرد.')
        }}
      />
    </Card>
  )
}
