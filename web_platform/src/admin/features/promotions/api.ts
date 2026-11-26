import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { unwrap } from '@admin/lib/rpc'
import { getSupabase } from '@admin/lib/supabase'
import { normalizePromotion } from './logic'
import {
  DEFAULT_DISPLAY_SETTINGS,
  type Promotion,
  type PromotionDisplaySettings,
  type PromotionInput,
  type PromotionStatus,
} from './types'

/**
 * طبقة بيانات الدعايات. **وضع تجريبي (MOCK) موسوم:** لا عقد خادم بعد (INT-010)، فالبيانات
 * تحفظ في متصفح الموظف فقط ولا تصل إلى التطبيق. عند تسليم العقد تستبدل `mockPromotionsApi`
 * بتنفيذ عبر دوال admin_* المقترحة في INT-010 دون تغيير الصفحات.
 */
export interface PromotionsApi {
  readonly mode: 'mock' | 'live'
  list(): Promise<Promotion[]>
  get(id: string): Promise<Promotion | null>
  save(id: string | null, input: PromotionInput): Promise<Promotion>
  setStatus(id: string, status: PromotionStatus): Promise<Promotion>
  getSettings(): Promise<PromotionDisplaySettings>
  saveSettings(settings: PromotionDisplaySettings): Promise<PromotionDisplaySettings>
}

const STORAGE_KEY = 'nawadir.admin.promotions.mock.v1'

interface MockState {
  promotions: Promotion[]
  settings: PromotionDisplaySettings
}

function emptyState(): MockState {
  return { promotions: [], settings: { ...DEFAULT_DISPLAY_SETTINGS } }
}

let memory: MockState | null = null

function load(): MockState {
  if (memory) return memory
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY)
    memory = raw ? { ...emptyState(), ...(JSON.parse(raw) as MockState) } : emptyState()
  } catch {
    memory = emptyState()
  }
  return memory
}

function persist(state: MockState) {
  memory = state
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
  } catch {
    // امتلاء التخزين المحلي بالصور: يبقى في الذاكرة لهذه الجلسة فقط.
  }
}

/** للاختبارات: يفرغ المخزن التجريبي. */
export function resetMockPromotions(state: Partial<MockState> = {}) {
  memory = { ...emptyState(), ...state }
  try {
    window.localStorage.removeItem(STORAGE_KEY)
  } catch {
    /* لا شيء */
  }
}

const clone = <T,>(v: T): T => JSON.parse(JSON.stringify(v)) as T

export const mockPromotionsApi: PromotionsApi = {
  mode: 'mock',
  async list() {
    return clone(load().promotions).sort((a, b) => b.updated_at.localeCompare(a.updated_at))
  },
  async get(id) {
    const p = load().promotions.find((x) => x.id === id)
    return p ? clone(p) : null
  },
  async save(id, input) {
    const state = load()
    const now = new Date().toISOString()
    const clean = normalizePromotion(input)
    if (id) {
      const i = state.promotions.findIndex((x) => x.id === id)
      if (i < 0) throw new Error('NOT_FOUND')
      const updated: Promotion = { ...state.promotions[i]!, ...clean, updated_at: now }
      const promotions = [...state.promotions]
      promotions[i] = updated
      persist({ ...state, promotions })
      return clone(updated)
    }
    const created: Promotion = {
      ...clean,
      id: crypto.randomUUID(),
      status: 'ACTIVE',
      impression_count: 0,
      click_count: 0,
      created_at: now,
      updated_at: now,
    }
    persist({ ...state, promotions: [created, ...state.promotions] })
    return clone(created)
  },
  async setStatus(id, status) {
    const state = load()
    const i = state.promotions.findIndex((x) => x.id === id)
    if (i < 0) throw new Error('NOT_FOUND')
    const updated: Promotion = { ...state.promotions[i]!, status, updated_at: new Date().toISOString() }
    const promotions = [...state.promotions]
    promotions[i] = updated
    persist({ ...state, promotions })
    return clone(updated)
  },
  async getSettings() {
    return { ...load().settings }
  },
  async saveSettings(settings) {
    const state = load()
    persist({ ...state, settings: { ...settings } })
    return { ...settings }
  },
}

/** نقطة الاستبدال الوحيدة عند تسليم INT-010. */
export const promotionsApi: PromotionsApi = mockPromotionsApi

export const promotionKeys = {
  all: ['admin', 'promotions'] as const,
  list: ['admin', 'promotions', 'list'] as const,
  detail: (id: string) => ['admin', 'promotions', 'detail', id] as const,
  settings: ['admin', 'promotions', 'settings'] as const,
  regions: ['admin', 'promotions', 'regions'] as const,
}

export function usePromotions() {
  return useQuery({ queryKey: promotionKeys.list, queryFn: () => promotionsApi.list() })
}

export function usePromotion(id: string | undefined) {
  return useQuery({
    queryKey: promotionKeys.detail(id ?? ''),
    enabled: Boolean(id),
    queryFn: async () => {
      const p = await promotionsApi.get(id!)
      if (!p) throw Object.assign(new Error('الدعاية غير موجودة.'), { code: 'NOT_FOUND' })
      return p
    },
  })
}

export function useDisplaySettings() {
  return useQuery({ queryKey: promotionKeys.settings, queryFn: () => promotionsApi.getSettings() })
}

function useInvalidateAll() {
  const qc = useQueryClient()
  return () => qc.invalidateQueries({ queryKey: promotionKeys.all })
}

export function useSavePromotion() {
  const invalidate = useInvalidateAll()
  return useMutation({
    mutationFn: ({ id, input }: { id: string | null; input: PromotionInput }) => promotionsApi.save(id, input),
    onSuccess: () => invalidate(),
  })
}

export function useSetPromotionStatus() {
  const invalidate = useInvalidateAll()
  return useMutation({
    mutationFn: ({ id, status }: { id: string; status: PromotionStatus }) => promotionsApi.setStatus(id, status),
    onSuccess: () => invalidate(),
  })
}

export function useSaveDisplaySettings() {
  const invalidate = useInvalidateAll()
  return useMutation({
    mutationFn: (s: PromotionDisplaySettings) => promotionsApi.saveSettings(s),
    onSuccess: () => invalidate(),
  })
}

/** المناطق الفعالة للاستهداف: قراءة حقيقية من جدول regions القائم. */
export function useActiveRegions() {
  return useQuery({
    queryKey: promotionKeys.regions,
    staleTime: 10 * 60 * 1000,
    queryFn: async () =>
      unwrap(
        await getSupabase().from('regions').select('id, name_ar, is_active').eq('is_active', true).order('sort_order', { ascending: true }),
      ) as Array<{ id: number; name_ar: string }>,
  })
}
