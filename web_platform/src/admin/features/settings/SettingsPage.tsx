// الإعدادات والحدود (AD-FR-037، DEC-02، SRS 10.1 و10.2). القدرة: settings.manage.
// التعديل على مسودة، والنشر ذري بإصدار جديد، والتراجع ينشر إصدارًا جديدًا بمحتوى إصدار سابق.
import { useMemo, useState, type FormEvent } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { Alert, Button, Card, ConfirmDialog, ErrorState, KeyValue, Loading, PageHeader, useNotify } from '@admin/ui'
import { useCan } from '@admin/auth/AuthContext'
import { errorMessage, toApiError, type ApiError } from '@admin/lib/errors'
import { formatDateTime } from '@admin/lib/format'
import type { AdminSettingsPayload, FormValues, SettingsContent } from './types'
import { buildContent, diffContent, FIELD_BY_PATH, hardMinimumMessage, NOTE_MAX, sameForm, toFormValues, unknownEntries, validateForm } from './schema'
import { invalidStateReason, publishSettings, rollbackSettings, saveSettingsDraft, SETTINGS_KEYS, useAdminSettings, useSettingsVersions } from './api'
import { SettingsForm } from './SettingsForm'
import { SettingsDiff, UnknownKeys } from './SettingsView'
import { publisherLabel, VersionsCard } from './VersionsCard'
import './settings.css'

interface EditorState {
  /** مفتاح نسخة الخادم التي حمل منها النموذج. */
  key: string
  base: SettingsContent
  form: FormValues
}

function dataKey(d: AdminSettingsPayload): string {
  return `${d.published_version}|${d.draft ? 'draft' : 'none'}|${d.draft_updated_at ?? ''}`
}

function editorFrom(d: AdminSettingsPayload): EditorState {
  const base = d.draft ?? d.published
  return { key: dataKey(d), base, form: toFormValues(base) }
}

/** أخطاء الخادم على الحقول: VALIDATION_FAILED (details.fields) وBELOW_HARD_MINIMUM (details.field، minimum). */
function serverFieldErrors(e: ApiError): Record<string, string> {
  const out: Record<string, string> = {}
  if (e.code === 'VALIDATION_FAILED') {
    for (const f of e.fields) if (FIELD_BY_PATH[f]) out[f] = 'رفض الخادم هذه القيمة. راجعها.'
  } else if (e.code === 'BELOW_HARD_MINIMUM') {
    const field = e.fields[0]
    const min = e.details.minimum
    if (field) out[field] = hardMinimumMessage(typeof min === 'number' || typeof min === 'string' ? min : 24, FIELD_BY_PATH[field]?.unit)
  }
  return out
}

export default function SettingsPage() {
  const canManage = useCan('settings.manage')
  const qc = useQueryClient()
  const notify = useNotify()
  const settings = useAdminSettings(canManage)
  const versions = useSettingsVersions(canManage)
  const data = settings.data

  const [editor, setEditor] = useState<EditorState | null>(null)
  const [serverErrors, setServerErrors] = useState<Record<string, string>>({})
  const [saveError, setSaveError] = useState<ApiError | null>(null)
  const [attempted, setAttempted] = useState(false)
  const [saving, setSaving] = useState(false)
  const [confirmDiscard, setConfirmDiscard] = useState(false)
  const [confirmPublish, setConfirmPublish] = useState(false)

  const editorBase = editor?.base
  const baseForm = useMemo(() => (editorBase ? toFormValues(editorBase) : null), [editorBase])
  const dirty = !!editor && !!baseForm && !sameForm(editor.form, baseForm)

  // مزامنة النموذج مع نسخة الخادم دون مسح تعديلات غير محفوظة.
  if (data && (!editor || (editor.key !== dataKey(data) && !dirty))) {
    setEditor(editorFrom(data))
  }
  const stale = !!data && !!editor && editor.key !== dataKey(data) && dirty

  const clientErrors = useMemo(() => (editor ? validateForm(editor.form) : {}), [editor])
  const errors = { ...serverErrors, ...clientErrors }
  const hasClientErrors = Object.keys(clientErrors).length > 0

  const publishedRow = versions.data?.pages.flat().find((v) => v.version === data?.published_version)
  const diffCount = data?.draft ? diffContent(data.published, data.draft).length : 0
  const unknown = editor ? unknownEntries(editor.base) : []

  function applyServer(res: AdminSettingsPayload) {
    qc.setQueryData(SETTINGS_KEYS.current, res)
    setEditor(editorFrom(res))
    setServerErrors({})
    setSaveError(null)
    setAttempted(false)
    void qc.invalidateQueries({ queryKey: SETTINGS_KEYS.all })
  }

  function onField(path: string, value: string | boolean | string[]) {
    setEditor((prev) => (prev ? { ...prev, form: { ...prev.form, [path]: value } } : prev))
    if (serverErrors[path]) {
      setServerErrors((prev) => {
        const next = { ...prev }
        delete next[path]
        return next
      })
    }
  }

  async function save(e?: FormEvent) {
    e?.preventDefault()
    if (!editor || saving) return
    setAttempted(true)
    if (hasClientErrors) return
    setSaving(true)
    setSaveError(null)
    try {
      const res = await saveSettingsDraft(buildContent(editor.base, editor.form))
      applyServer(res)
      notify.success('حفظت المسودة. لا تسري التعديلات حتى تنشر.')
    } catch (err) {
      const apiErr = toApiError(err)
      setSaveError(apiErr)
      setServerErrors(serverFieldErrors(apiErr))
    } finally {
      setSaving(false)
    }
  }

  function handleStateError(err: unknown): never {
    const apiErr = toApiError(err)
    const reason = invalidStateReason(apiErr)
    if (apiErr.code === 'INVALID_STATE' || apiErr.code === 'NOT_FOUND') {
      if (reason) notify.error(reason)
      void qc.invalidateQueries({ queryKey: SETTINGS_KEYS.all })
    }
    throw apiErr
  }

  async function discardDraft() {
    try {
      const res = await saveSettingsDraft(null)
      applyServer(res)
      notify.success('ألغيت المسودة. الإصدار المنشور لم يتغير.')
    } catch (err) {
      handleStateError(err)
    }
  }

  async function publish(note: string | undefined) {
    try {
      const res = await publishSettings(note)
      applyServer(res)
      notify.success(`نشر الإصدار ${res.published_version}. تسري الحدود الجديدة الآن.`)
    } catch (err) {
      handleStateError(err)
    }
  }

  async function rollback(version: number, note: string | undefined) {
    try {
      const res = await rollbackSettings(version, note)
      applyServer(res)
      notify.success(`نشر الإصدار ${res.published_version} بمحتوى الإصدار ${version}.`)
    } catch (err) {
      handleStateError(err)
    }
  }

  const header = <PageHeader title="الإعدادات والحدود" description="تعدل الحدود على مسودة ثم تنشر بإصدار جديد. يطبق التطبيق والموقع الإصدار المنشور فقط." />

  if (!canManage) {
    return (
      <div className="page">
        {header}
        <Alert tone="warning" title="لا تملك صلاحية">
          إدارة الإعدادات تتطلب قدرة «الإعدادات وإصداراتها».
        </Alert>
      </div>
    )
  }

  if (settings.isPending) {
    return (
      <div className="page">
        {header}
        <Loading />
      </div>
    )
  }

  if (settings.isError || !data || !editor) {
    return (
      <div className="page">
        {header}
        <ErrorState error={settings.error} onRetry={() => void settings.refetch()} title="تعذر تحميل الإعدادات" />
      </div>
    )
  }

  return (
    <div className="page">
      {header}

      <div className="grid grid-2">
        <Card title="الإصدار المنشور">
          <KeyValue
            items={[
              { label: 'رقم الإصدار', value: <strong>{data.published_version}</strong> },
              { label: 'تاريخ النشر', value: formatDateTime(data.published_at) },
              { label: 'الناشر', value: publishedRow ? publisherLabel(publishedRow.published_by) : '—' },
              { label: 'مصدر المحتوى', value: publishedRow?.restored_from_version ? `استعادة الإصدار ${publishedRow.restored_from_version}` : '—' },
              { label: 'الملاحظة', value: publishedRow?.note ?? '—', wide: true },
            ]}
          />
        </Card>

        <Card title="المسودة">
          {data.draft ? (
            <Alert tone="warning" title="مسودة غير منشورة">
              آخر حفظ {formatDateTime(data.draft_updated_at)} بواسطة {publisherLabel(data.draft_updated_by)}. لا تسري حتى تنشر.
            </Alert>
          ) : (
            <Alert tone="info" title="لا توجد مسودة">
              النموذج أدناه يبدأ من الإصدار المنشور. احفظ التعديلات لإنشاء مسودة ثم انشرها.
            </Alert>
          )}
          {data.draft && (
            <div className="row settings-actions">
              <Button variant="primary" onClick={() => setConfirmPublish(true)} disabled={dirty || diffCount === 0}>
                نشر المسودة
              </Button>
              <Button variant="danger" onClick={() => setConfirmDiscard(true)}>
                إلغاء المسودة
              </Button>
            </div>
          )}
          {data.draft && dirty && <p className="muted small">احفظ التعديلات الحالية أولًا؛ النشر ينشر المسودة المحفوظة فقط.</p>}
        </Card>
      </div>

      {data.draft && (
        <Card title={`التغييرات في المسودة (${diffCount})`}>
          <SettingsDiff published={data.published} draft={data.draft} />
        </Card>
      )}

      <Card title="تعديل الإعدادات">
        <form onSubmit={(e) => void save(e)} noValidate className="stack">
          {stale && (
            <Alert tone="warning" title="تغيرت الإعدادات على الخادم">
              <p>حفظت مسودة أو نشر إصدار جديد بعد فتح النموذج. تعديلاتك غير المحفوظة مبنية على نسخة أقدم.</p>
              <Button size="sm" onClick={() => setEditor(editorFrom(data))}>
                تحميل آخر نسخة (تفقد تعديلاتك)
              </Button>
            </Alert>
          )}
          <SettingsForm form={editor.form} errors={errors} disabled={saving} onChange={onField} />
          {unknown.length > 0 && <UnknownKeys entries={unknown} note="مفاتيح لا تعرضها اللوحة؛ ترسل كما هي مع المسودة. يحتفظ الخادم بالمفاتيح المعرفة في العقد فقط." />}
          {attempted && hasClientErrors && (
            <Alert tone="danger" title="لم تحفظ المسودة">
              صحح الحقول المحددة قبل الحفظ.
            </Alert>
          )}
          {saveError && (
            <Alert tone="danger" title="لم تحفظ المسودة">
              {errorMessage(saveError)}
            </Alert>
          )}
          <div className="row settings-actions">
            <Button type="submit" variant="primary" loading={saving} disabled={!dirty}>
              حفظ المسودة
            </Button>
            <Button
              variant="ghost"
              disabled={!dirty || saving}
              onClick={() => {
                setEditor(editorFrom(data))
                setServerErrors({})
                setSaveError(null)
                setAttempted(false)
              }}
            >
              تجاهل التعديلات غير المحفوظة
            </Button>
            {dirty && <span className="muted small">توجد تعديلات غير محفوظة.</span>}
          </div>
        </form>
      </Card>

      <VersionsCard publishedVersion={data.published_version} canManage={canManage} onRollback={rollback} />

      <ConfirmDialog
        open={confirmDiscard}
        title="إلغاء المسودة"
        message="تحذف المسودة غير المنشورة ويعود النموذج إلى الإصدار المنشور. لا يتغير الإصدار المنشور."
        confirmLabel="إلغاء المسودة"
        tone="danger"
        onClose={() => setConfirmDiscard(false)}
        onConfirm={() => discardDraft()}
      />
      <ConfirmDialog
        open={confirmPublish}
        title="نشر المسودة"
        message={
          <p>
            ينشر إصدار جديد بالتغييرات ({diffCount}) ويسري فورًا على التطبيق والموقع، مع تحديث حدود رفع الملفات في التخزين في العملية نفسها.
          </p>
        }
        confirmLabel="نشر"
        noteLabel="ملاحظة الإصدار (اختيارية)"
        noteHint={`حتى ${NOTE_MAX} حرف. تظهر في سجل الإصدارات وسجل الإجراءات.`}
        noteMax={NOTE_MAX}
        onClose={() => setConfirmPublish(false)}
        onConfirm={(note) => publish(note)}
      />
    </div>
  )
}
