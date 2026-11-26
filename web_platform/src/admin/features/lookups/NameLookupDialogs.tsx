import { useEffect, useState } from 'react'
import { CheckboxField, SelectField, TextField } from '@admin/ui'
import { lookupKeys, upsertBreed, upsertCity, upsertRegion } from './api'
import { cleanName, parseSortOrder, validateName } from './errors'
import { FormDialog, useFormSubmit } from './FormDialog'
import type { Breed, City, FieldErrors, Region } from './types'

const NAME_MAX = 60

function sortHint(isNew: boolean) {
  return isNew ? 'اختياري. اتركه فارغًا لإضافة القيمة في آخر القائمة.' : 'الرقم الأصغر يظهر أولًا. اتركه فارغًا لإبقاء الترتيب الحالي.'
}

interface DialogBase<T> {
  open: boolean
  /** null: إضافة قيمة جديدة. */
  value: T | null
  onClose: () => void
}

/** حالة مشتركة لحقلي الاسم والترتيب. */
function useNameSortState(open: boolean, name: string, sort: number | undefined) {
  const [nameAr, setNameAr] = useState('')
  const [sortOrder, setSortOrder] = useState('')
  const [touched, setTouched] = useState(false)
  useEffect(() => {
    if (open) {
      setNameAr(name)
      setSortOrder(sort === undefined ? '' : String(sort))
      setTouched(false)
    }
    // القيم الابتدائية من القيمة المفتوحة (ثابتة طوال فتح النافذة).
  }, [open, name, sort])
  return { nameAr, setNameAr, sortOrder, setSortOrder, touched, setTouched }
}

function localErrors(nameAr: string, sortOrder: string): FieldErrors {
  const out: FieldErrors = {}
  const n = validateName(nameAr, NAME_MAX)
  if (n) out.name_ar = n
  const s = parseSortOrder(sortOrder)
  if (s.error) out.sort_order = s.error
  return out
}

// ---------------------------------------------------------------- السلالة

export function BreedDialog({ open, value, onClose }: DialogBase<Breed>) {
  const isNew = value === null
  const st = useNameSortState(open, value?.name_ar ?? '', value?.sort_order)
  const [requiresNote, setRequiresNote] = useState(false)
  const submit = useFormSubmit()
  const { reset } = submit

  useEffect(() => {
    if (open) {
      setRequiresNote(value?.requires_note ?? false)
      reset()
    }
  }, [open, value, reset])

  const local = localErrors(st.nameAr, st.sortOrder)
  const errors: FieldErrors = { ...submit.serverErrors, ...(st.touched ? local : {}) }

  function onSubmit() {
    st.setTouched(true)
    if (Object.keys(local).length > 0) return
    void submit.run({
      action: () =>
        upsertBreed({
          id: value?.id ?? null,
          name_ar: cleanName(st.nameAr),
          requires_note: requiresNote,
          sort_order: parseSortOrder(st.sortOrder).value,
        }),
      invalidate: [lookupKeys.breeds()],
      success: isNew ? 'تمت إضافة السلالة.' : 'تم حفظ السلالة.',
      onDone: onClose,
    })
  }

  return (
    <FormDialog open={open} title={isNew ? 'إضافة سلالة' : `تعديل السلالة «${value.name_ar}»`} submitLabel={isNew ? 'إضافة' : 'حفظ'} busy={submit.busy} error={submit.error} onClose={onClose} onSubmit={onSubmit}>
      <TextField
        label="اسم السلالة"
        required
        maxLength={NAME_MAX}
        value={st.nameAr}
        onChange={(e) => {
          st.setNameAr(e.target.value)
          submit.clearField('name_ar')
        }}
        error={errors.name_ar}
        hint={`حتى ${NAME_MAX} حرفًا، ولا يتكرر.`}
      />
      <CheckboxField
        label="يتطلب ملاحظة عند الاختيار"
        hint="مثل «أخرى»: يكتب المعلن توضيحًا نصيًا عند اختيار هذه السلالة."
        checked={requiresNote}
        onChange={(e) => setRequiresNote(e.target.checked)}
      />
      <TextField
        label="رقم الترتيب"
        type="number"
        inputMode="numeric"
        step={1}
        value={st.sortOrder}
        onChange={(e) => {
          st.setSortOrder(e.target.value)
          submit.clearField('sort_order')
        }}
        error={errors.sort_order}
        hint={sortHint(isNew)}
      />
    </FormDialog>
  )
}

// ---------------------------------------------------------------- المنطقة

export function RegionDialog({ open, value, onClose }: DialogBase<Region>) {
  const isNew = value === null
  const st = useNameSortState(open, value?.name_ar ?? '', value?.sort_order)
  const submit = useFormSubmit()
  const { reset } = submit

  useEffect(() => {
    if (open) reset()
  }, [open, reset])

  const local = localErrors(st.nameAr, st.sortOrder)
  const errors: FieldErrors = { ...submit.serverErrors, ...(st.touched ? local : {}) }

  function onSubmit() {
    st.setTouched(true)
    if (Object.keys(local).length > 0) return
    void submit.run({
      action: () => upsertRegion({ id: value?.id ?? null, name_ar: cleanName(st.nameAr), sort_order: parseSortOrder(st.sortOrder).value }),
      invalidate: [lookupKeys.regions()],
      success: isNew ? 'تمت إضافة المنطقة.' : 'تم حفظ المنطقة.',
      onDone: onClose,
    })
  }

  return (
    <FormDialog open={open} title={isNew ? 'إضافة منطقة' : `تعديل المنطقة «${value.name_ar}»`} submitLabel={isNew ? 'إضافة' : 'حفظ'} busy={submit.busy} error={submit.error} onClose={onClose} onSubmit={onSubmit}>
      <TextField
        label="اسم المنطقة"
        required
        maxLength={NAME_MAX}
        value={st.nameAr}
        onChange={(e) => {
          st.setNameAr(e.target.value)
          submit.clearField('name_ar')
        }}
        error={errors.name_ar}
        hint={`حتى ${NAME_MAX} حرفًا، ولا يتكرر.`}
      />
      <TextField
        label="رقم الترتيب"
        type="number"
        inputMode="numeric"
        step={1}
        value={st.sortOrder}
        onChange={(e) => {
          st.setSortOrder(e.target.value)
          submit.clearField('sort_order')
        }}
        error={errors.sort_order}
        hint={sortHint(isNew)}
      />
    </FormDialog>
  )
}

// ---------------------------------------------------------------- المدينة

export interface CityDialogProps extends DialogBase<City> {
  regions: Region[]
  /** المنطقة المختارة في المرشح، تقترح للمدينة الجديدة. */
  defaultRegionId: number | null
}

export function CityDialog({ open, value, onClose, regions, defaultRegionId }: CityDialogProps) {
  const isNew = value === null
  const st = useNameSortState(open, value?.name_ar ?? '', value?.sort_order)
  const [regionId, setRegionId] = useState('')
  const submit = useFormSubmit()
  const { reset } = submit

  useEffect(() => {
    if (open) {
      const initial = value?.region_id ?? defaultRegionId
      setRegionId(initial === null ? '' : String(initial))
      reset()
    }
  }, [open, value, defaultRegionId, reset])

  const local = localErrors(st.nameAr, st.sortOrder)
  if (regionId === '') local.region_id = 'اختر المنطقة.'
  const errors: FieldErrors = { ...submit.serverErrors, ...(st.touched ? local : {}) }
  const selectedRegion = regions.find((r) => String(r.id) === regionId)
  const moved = !isNew && regionId !== '' && Number(regionId) !== value.region_id

  function onSubmit() {
    st.setTouched(true)
    if (Object.keys(local).length > 0) return
    const rid = Number(regionId)
    void submit.run({
      action: () => upsertCity({ id: value?.id ?? null, region_id: rid, name_ar: cleanName(st.nameAr), sort_order: parseSortOrder(st.sortOrder).value }),
      invalidate: [lookupKeys.citiesAll()],
      duplicateMessage: 'الاسم مكرر في هذه المنطقة',
      success: isNew ? 'تمت إضافة المدينة.' : 'تم حفظ المدينة.',
      onDone: onClose,
    })
  }

  let regionHint: string | undefined
  if (selectedRegion && !selectedRegion.is_active) regionHint = 'المنطقة المختارة معطلة؛ لا تظهر مدنها في الاختيارات الجديدة حتى تفعل.'
  else if (moved) regionHint = 'نقل مدينة مستخدمة في إعلانات إلى منطقة أخرى يرفضه الخادم.'

  return (
    <FormDialog open={open} title={isNew ? 'إضافة مدينة' : `تعديل المدينة «${value.name_ar}»`} submitLabel={isNew ? 'إضافة' : 'حفظ'} busy={submit.busy} error={submit.error} onClose={onClose} onSubmit={onSubmit}>
      <SelectField
        label="المنطقة"
        required
        value={regionId}
        onChange={(e) => {
          setRegionId(e.target.value)
          submit.clearField('region_id')
        }}
        error={errors.region_id}
        hint={regionHint}
      >
        <option value="">اختر المنطقة</option>
        {regions.map((r) => (
          <option key={r.id} value={String(r.id)}>
            {r.is_active ? r.name_ar : `${r.name_ar} (معطلة)`}
          </option>
        ))}
      </SelectField>
      <TextField
        label="اسم المدينة"
        required
        maxLength={NAME_MAX}
        value={st.nameAr}
        onChange={(e) => {
          st.setNameAr(e.target.value)
          submit.clearField('name_ar')
        }}
        error={errors.name_ar}
        hint={`حتى ${NAME_MAX} حرفًا، ولا يتكرر في المنطقة نفسها.`}
      />
      <TextField
        label="رقم الترتيب"
        type="number"
        inputMode="numeric"
        step={1}
        value={st.sortOrder}
        onChange={(e) => {
          st.setSortOrder(e.target.value)
          submit.clearField('sort_order')
        }}
        error={errors.sort_order}
        hint={isNew ? 'اختياري. اتركه فارغًا لإضافة المدينة في آخر مدن المنطقة.' : sortHint(false)}
      />
    </FormDialog>
  )
}
