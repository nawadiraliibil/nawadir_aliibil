import { useEffect, useState, type ChangeEvent, type FormEvent } from 'react'
import { useNavigate, useParams } from 'react-router'
import { errorMessage, toApiError } from '@admin/lib/errors'
import { riyadhDayString, riyadhDayToIso } from '@admin/lib/format'
import {
  Alert,
  Button,
  Card,
  CheckboxField,
  ErrorState,
  Loading,
  PageHeader,
  SelectField,
  TextAreaField,
  TextField,
  useNotify,
} from '@admin/ui'
import { promotionImageUrl, useActiveRegions, usePromotion, useSavePromotion } from './api'
import {
  ACTION_LABELS,
  IMAGE_RATIO,
  IMAGE_TYPES,
  LIMITS,
  PLACEMENT_LABELS,
  validateImageFile,
  validatePromotion,
  type PromotionErrors,
} from './logic'
import { PromotionPreview } from './PromotionPreview'
import { ACTION_TYPES, PLACEMENTS, type ActionType, type Placement, type Promotion, type PromotionInput } from './types'
import './promotions.css'

interface FormState {
  title: string
  body: string
  advertiser_name: string
  image_path: string
  action_type: ActionType
  action_value: string
  placements: Placement[]
  allRegions: boolean
  region_ids: number[]
  startDay: string
  endDay: string
  priority: string
}

function emptyForm(): FormState {
  return {
    title: '',
    body: '',
    advertiser_name: '',
    image_path: '',
    action_type: 'URL',
    action_value: '',
    placements: ['HOME_FEED'],
    allRegions: true,
    region_ids: [],
    startDay: riyadhDayString(new Date()),
    endDay: '',
    priority: '50',
  }
}

function fromPromotion(p: Promotion): FormState {
  return {
    title: p.title,
    body: p.body ?? '',
    advertiser_name: p.advertiser_name,
    image_path: p.image_path,
    action_type: p.action_type,
    action_value: p.action_value ?? '',
    placements: [...p.placements],
    allRegions: p.region_ids === null,
    region_ids: p.region_ids ?? [],
    startDay: riyadhDayString(new Date(p.starts_at)),
    // ends_at حد غير شامل (بداية اليوم التالي)؛ يعرض آخر يوم شامل.
    endDay: p.ends_at ? riyadhDayString(new Date(new Date(p.ends_at).getTime() - 1)) : '',
    priority: String(p.priority),
  }
}

function toInput(f: FormState): PromotionInput {
  return {
    title: f.title,
    body: f.body || null,
    advertiser_name: f.advertiser_name,
    image_path: f.image_path,
    action_type: f.action_type,
    action_value: f.action_type === 'NONE' ? null : f.action_value,
    placements: f.placements,
    region_ids: f.allRegions ? null : f.region_ids,
    starts_at: f.startDay ? riyadhDayToIso(f.startDay) : '',
    ends_at: f.endDay ? riyadhDayToIso(f.endDay, true) : null,
    priority: f.priority.trim() === '' ? Number.NaN : Number(f.priority),
  }
}

const ACTION_VALUE_LABEL: Record<ActionType, string> = {
  URL: 'الرابط',
  WHATSAPP: 'رقم واتساب',
  CALL: 'رقم الاتصال',
  NONE: '',
}

function readAsDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(String(reader.result))
    reader.onerror = () => reject(reader.error ?? new Error('تعذر قراءة الملف.'))
    reader.readAsDataURL(file)
  })
}

/** تحذير غير مانع إن ابتعدت نسبة الصورة عن 16:10 (تُقص في التطبيق). */
function checkRatio(src: string): Promise<string | null> {
  return new Promise((resolve) => {
    const img = new Image()
    img.onload = () => {
      if (!img.naturalWidth || !img.naturalHeight) return resolve(null)
      const ratio = img.naturalWidth / img.naturalHeight
      resolve(
        Math.abs(ratio - IMAGE_RATIO) / IMAGE_RATIO > 0.04
          ? `أبعاد الصورة ${img.naturalWidth}×${img.naturalHeight}؛ النسبة المطلوبة 16:10 (مثل 1600×1000) وإلا قُصّت أطرافها في التطبيق.`
          : null,
      )
    }
    img.onerror = () => resolve(null)
    img.src = src
  })
}

/** إنشاء دعاية أو تعديلها (المسار promotions/new أو promotions/:promotionId). */
export default function PromotionEditorPage() {
  const { promotionId } = useParams()
  const isNew = !promotionId || promotionId === 'new'
  const navigate = useNavigate()
  const notify = useNotify()
  const existing = usePromotion(isNew ? undefined : promotionId)
  const regions = useActiveRegions()
  const save = useSavePromotion()
  const [form, setForm] = useState<FormState>(emptyForm)
  const [errors, setErrors] = useState<PromotionErrors>({})
  const [imageWarning, setImageWarning] = useState<string | null>(null)
  // صورة جديدة تُرفع عند الحفظ؛ المعاينة من الملف المحلي قبل الرفع.
  const [imageFile, setImageFile] = useState<File | null>(null)
  const [imagePreview, setImagePreview] = useState<string | null>(null)
  const [serverError, setServerError] = useState<string | null>(null)
  const [loadedId, setLoadedId] = useState<string | null>(null)

  useEffect(() => {
    if (existing.data && existing.data.id !== loadedId) {
      setForm(fromPromotion(existing.data))
      setLoadedId(existing.data.id)
    }
  }, [existing.data, loadedId])

  function set<K extends keyof FormState>(key: K, value: FormState[K]) {
    setForm((f) => ({ ...f, [key]: value }))
  }

  function togglePlacement(p: Placement, on: boolean) {
    setForm((f) => ({ ...f, placements: on ? [...new Set([...f.placements, p])] : f.placements.filter((x) => x !== p) }))
  }

  function toggleRegion(id: number, on: boolean) {
    setForm((f) => ({ ...f, region_ids: on ? [...new Set([...f.region_ids, id])] : f.region_ids.filter((x) => x !== id) }))
  }

  async function onImage(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    e.target.value = ''
    if (!file) return
    const problem = validateImageFile(file)
    if (problem) {
      setErrors((x) => ({ ...x, image: problem }))
      return
    }
    const src = await readAsDataUrl(file)
    setImageFile(file)
    setImagePreview(src)
    setErrors((x) => ({ ...x, image: undefined }))
    setImageWarning(null)
    void checkRatio(src).then(setImageWarning)
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    const input = toInput(form)
    // الصورة الجديدة لم ترفع بعد: تكفي للتحقق المحلي، ويحل مسارها الحقيقي عند الحفظ.
    const found = validatePromotion({ ...input, image_path: input.image_path || (imageFile ? 'pending' : '') })
    setErrors(found)
    setServerError(null)
    if (Object.keys(found).length > 0) {
      notify.error('راجع الحقول المظللة.')
      return
    }
    try {
      const saved = await save.mutateAsync({ id: isNew ? null : promotionId!, input, imageFile })
      notify.success(isNew ? 'أضيفت الدعاية.' : 'حُفظت التعديلات.')
      setImageFile(null)
      setImagePreview(null)
      navigate(isNew ? '/admin/promotions' : `/admin/promotions/${saved.id}`, { replace: isNew })
    } catch (err) {
      // رفض الخادم بالحقول (VALIDATION_FAILED) يظلل الحقول نفسها.
      const e = toApiError(err)
      const fields = Array.isArray(e.details.fields) ? (e.details.fields as string[]) : []
      if (e.code === 'VALIDATION_FAILED' && fields.length > 0) {
        setErrors(
          Object.fromEntries(
            fields.map((f) => [f === 'image_path' ? 'image' : f, 'رفض الخادم هذه القيمة؛ راجعها.']),
          ) as PromotionErrors,
        )
      }
      setServerError(errorMessage(err))
    }
  }

  const crumbs = [{ label: 'الدعايات التجارية', to: '/admin/promotions' }, { label: isNew ? 'دعاية جديدة' : 'تعديل' }]

  if (!isNew && existing.isPending) return <Loading />
  if (!isNew && existing.isError)
    return (
      <div className="page">
        <PageHeader title="الدعاية" crumbs={crumbs} />
        <ErrorState error={existing.error} onRetry={() => void existing.refetch()} />
      </div>
    )

  return (
    <div className="page">
      <PageHeader
        title={isNew ? 'دعاية جديدة' : `تعديل: ${existing.data?.title ?? ''}`}
        crumbs={crumbs}
        description="تظهر الدعاية في التطبيق بين إعلانات المستخدمين خلال فترة العرض، ما لم توقف أو تؤرشف."
      />
      {serverError && (
        <Alert tone="danger" title="تعذر الحفظ">
          {serverError}
        </Alert>
      )}

      <form className="promo-editor" onSubmit={(e) => void onSubmit(e)} noValidate aria-label="بيانات الدعاية">
        <div className="stack">
          <Card title="المحتوى">
            <TextField
              label="العنوان"
              required
              maxLength={LIMITS.title}
              value={form.title}
              onChange={(e) => set('title', e.target.value)}
              error={errors.title}
              hint={`${form.title.trim().length}/${LIMITS.title}`}
            />
            <TextAreaField
              label="نص قصير (اختياري)"
              maxLength={LIMITS.body}
              value={form.body}
              onChange={(e) => set('body', e.target.value)}
              error={errors.body}
              hint={`${form.body.trim().length}/${LIMITS.body}`}
            />
            <TextField
              label="اسم المعلن التجاري"
              required
              maxLength={LIMITS.advertiser}
              value={form.advertiser_name}
              onChange={(e) => set('advertiser_name', e.target.value)}
              error={errors.advertiser_name}
            />
            <div className={errors.image ? 'field field-invalid' : 'field'}>
              <label htmlFor="promo-image">
                الصورة <span className="req">*</span>
              </label>
              {/* زر عربي بدل نص المتصفح «Choose File»؛ الحقل الأصلي يبقى للوحة المفاتيح وقارئ الشاشة. */}
              <div className="promo-file">
                <input
                  id="promo-image"
                  className="promo-file-input"
                  type="file"
                  accept={IMAGE_TYPES.join(',')}
                  onChange={(e) => void onImage(e)}
                  aria-describedby="promo-image-hint"
                  aria-invalid={errors.image ? true : undefined}
                />
                <span className="btn btn-secondary" aria-hidden="true">
                  {imagePreview || form.image_path ? 'تغيير الصورة' : 'اختيار صورة'}
                </span>
                <span className="muted small" aria-hidden="true">
                  {imagePreview
                    ? 'صورة جديدة تُرفع عند الحفظ.'
                    : form.image_path
                      ? 'الصورة الحالية ظاهرة في المعاينة.'
                      : 'لم تُختر صورة بعد.'}
                </span>
              </div>
              <p id="promo-image-hint" className="field-hint">
                JPEG أو PNG أو WebP حتى 1 ميغابايت، بنسبة 16:10 (مثل 1600×1000).
              </p>
              {errors.image && (
                <p className="field-error" role="alert">
                  {errors.image}
                </p>
              )}
              {imageWarning && <Alert tone="warning">{imageWarning}</Alert>}
            </div>
          </Card>

          <Card title="عند الضغط على الدعاية">
            <SelectField label="الإجراء" value={form.action_type} onChange={(e) => set('action_type', e.target.value as ActionType)}>
              {ACTION_TYPES.map((a) => (
                <option key={a} value={a}>
                  {ACTION_LABELS[a]}
                </option>
              ))}
            </SelectField>
            {form.action_type !== 'NONE' && (
              <TextField
                label={ACTION_VALUE_LABEL[form.action_type]}
                required
                dir="ltr"
                className="input ltr"
                inputMode={form.action_type === 'URL' ? 'url' : 'tel'}
                placeholder={form.action_type === 'URL' ? 'https://example.com' : '05XXXXXXXX'}
                value={form.action_value}
                onChange={(e) => set('action_value', e.target.value)}
                error={errors.action_value}
                autoComplete="off"
              />
            )}
          </Card>

          <Card title="أين ومتى تظهر">
            <fieldset className={errors.placements ? 'field field-invalid' : 'field'}>
              <legend>المواضع</legend>
              {PLACEMENTS.map((p) => (
                <CheckboxField
                  key={p}
                  label={PLACEMENT_LABELS[p]}
                  checked={form.placements.includes(p)}
                  onChange={(e) => togglePlacement(p, e.target.checked)}
                />
              ))}
              {errors.placements && (
                <p className="field-error" role="alert">
                  {errors.placements}
                </p>
              )}
            </fieldset>

            <fieldset className={errors.region_ids ? 'field field-invalid' : 'field'}>
              <legend>المناطق</legend>
              <CheckboxField label="كل المناطق" checked={form.allRegions} onChange={(e) => set('allRegions', e.target.checked)} />
              {!form.allRegions &&
                (regions.isPending ? (
                  <Loading label="جارٍ تحميل المناطق…" />
                ) : regions.isError ? (
                  <ErrorState error={regions.error} onRetry={() => void regions.refetch()} />
                ) : (
                  <div className="promo-regions">
                    {regions.data.map((r) => (
                      <CheckboxField
                        key={r.id}
                        label={r.name_ar}
                        checked={form.region_ids.includes(r.id)}
                        onChange={(e) => toggleRegion(r.id, e.target.checked)}
                      />
                    ))}
                  </div>
                ))}
              <p className="field-hint">تظهر الدعاية المحددة بمناطق لمن اختار إحداها في التطبيق، والعامة للجميع.</p>
              {errors.region_ids && (
                <p className="field-error" role="alert">
                  {errors.region_ids}
                </p>
              )}
            </fieldset>

            <div className="filters">
              <TextField
                label="من يوم"
                type="date"
                required
                value={form.startDay}
                onChange={(e) => set('startDay', e.target.value)}
                error={errors.starts_at}
                hint="بتوقيت الرياض"
              />
              <TextField
                label="إلى يوم (اختياري)"
                type="date"
                value={form.endDay}
                onChange={(e) => set('endDay', e.target.value)}
                error={errors.ends_at}
                hint="شاملًا؛ فارغ = بلا نهاية"
              />
              <TextField
                label="الأولوية"
                type="number"
                inputMode="numeric"
                min={0}
                max={100}
                value={form.priority}
                onChange={(e) => set('priority', e.target.value)}
                error={errors.priority}
                hint="0 إلى 100؛ الأعلى يظهر أولًا"
              />
            </div>
          </Card>

          <div className="row">
            <Button type="submit" variant="primary" loading={save.isPending}>
              {isNew ? 'إضافة الدعاية' : 'حفظ التعديلات'}
            </Button>
            <Button variant="ghost" onClick={() => navigate('/admin/promotions')}>
              إلغاء
            </Button>
          </div>
        </div>

        <aside className="promo-editor-side">
          <PromotionPreview
            data={{
              title: form.title,
              body: form.body || null,
              advertiser_name: form.advertiser_name,
              image_src: imagePreview ?? (form.image_path ? promotionImageUrl(form.image_path) : null),
              action_type: form.action_type,
            }}
          />
        </aside>
      </form>
    </div>
  )
}
