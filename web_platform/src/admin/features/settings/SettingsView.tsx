import { DataTable, EmptyState, KeyValue } from '@admin/ui'
import type { SettingsContent } from './types'
import { GROUPS, diffContent, fieldLabel, formatSettingValue, getPath, pathLabel, unknownEntries, type DiffEntry } from './schema'

/** محتوى إصدار للقراءة: مجموعات الحقول المعروفة ثم أي مفاتيح أخرى بصيغة JSON. */
export function SettingsContentView({ content }: { content: SettingsContent }) {
  const unknown = unknownEntries(content)
  return (
    <div className="stack">
      {GROUPS.map((g) => (
        <section key={g.id} aria-label={g.title}>
          <h3 className="settings-view-title">{g.title}</h3>
          <KeyValue items={g.fields.map((fd) => ({ label: fieldLabel(fd.path), value: formatSettingValue(fd.path, getPath(content, fd.section, fd.key)) }))} />
        </section>
      ))}
      {unknown.length > 0 && <UnknownKeys entries={unknown} />}
    </div>
  )
}

export function UnknownKeys({ entries, note }: { entries: Array<{ path: string; value: unknown }>; note?: string }) {
  const obj = Object.fromEntries(entries.map((e) => [e.path, e.value]))
  return (
    <section aria-label="مفاتيح أخرى">
      <h3 className="settings-view-title">مفاتيح أخرى (للقراءة فقط)</h3>
      {note && <p className="muted small">{note}</p>}
      <pre className="pre ltr" dir="ltr">
        {JSON.stringify(obj, null, 2)}
      </pre>
    </section>
  )
}

/** الفروقات بين المنشور والمسودة. */
export function SettingsDiff({ published, draft }: { published: SettingsContent; draft: SettingsContent }) {
  const rows = diffContent(published, draft)
  return (
    <DataTable<DiffEntry>
      caption="الفروقات بين الإصدار المنشور والمسودة"
      rows={rows}
      rowKey={(r) => r.path}
      empty={<EmptyState title="المسودة مطابقة للإصدار المنشور">لا توجد تغييرات للنشر.</EmptyState>}
      columns={[
        { key: 'path', header: 'الإعداد', render: (r) => pathLabel(r.path) },
        { key: 'before', header: 'المنشور', render: (r) => <span className="muted">{formatSettingValue(r.path, r.before)}</span> },
        { key: 'arrow', header: <span className="sr-only">إلى</span>, render: () => <span aria-hidden="true">←</span> },
        { key: 'after', header: 'المسودة', render: (r) => <strong>{formatSettingValue(r.path, r.after)}</strong> },
      ]}
    />
  )
}
