import { clickRate, effectiveState, isHttpsUrl, normalizePromotion, normalizeSaudiMobile, validateFeedInterval, validateImageFile, validatePromotion } from './logic'
import type { PromotionInput } from './types'

const VALID: PromotionInput = {
  title: 'أعلاف الصحراء',
  body: 'خصم 15٪ على أعلاف الإبل',
  advertiser_name: 'مؤسسة الصحراء',
  image_path: 'data:image/png;base64,AAAA',
  action_type: 'URL',
  action_value: 'https://example.com/offer',
  placements: ['HOME_FEED'],
  region_ids: null,
  starts_at: '2026-11-25T21:00:00.000Z',
  ends_at: '2026-12-31T21:00:00.000Z',
  priority: 50,
}

describe('validatePromotion', () => {
  it('accepts a complete promotion', () => {
    expect(validatePromotion(VALID)).toEqual({})
  })

  it('requires title, advertiser, image and a placement', () => {
    const e = validatePromotion({ ...VALID, title: ' ', advertiser_name: '', image_path: '', placements: [] })
    expect(Object.keys(e).sort()).toEqual(['advertiser_name', 'image', 'placements', 'title'])
  })

  it('enforces length limits', () => {
    const e = validatePromotion({ ...VALID, title: 'ع'.repeat(61), body: 'ن'.repeat(141), advertiser_name: 'م'.repeat(61) })
    expect(Object.keys(e).sort()).toEqual(['advertiser_name', 'body', 'title'])
  })

  it('accepts only https links for URL actions', () => {
    expect(validatePromotion({ ...VALID, action_value: 'http://example.com' }).action_value).toBeDefined()
    expect(validatePromotion({ ...VALID, action_value: 'javascript:alert(1)' }).action_value).toBeDefined()
    expect(validatePromotion({ ...VALID, action_value: 'https://localhost' }).action_value).toBeDefined()
  })

  it('requires a Saudi mobile for WhatsApp and call actions, nothing for NONE', () => {
    expect(validatePromotion({ ...VALID, action_type: 'WHATSAPP', action_value: '0112345678' }).action_value).toBeDefined()
    expect(validatePromotion({ ...VALID, action_type: 'CALL', action_value: '055 123 4567' })).toEqual({})
    expect(validatePromotion({ ...VALID, action_type: 'NONE', action_value: null })).toEqual({})
  })

  it('checks the period, regions and priority', () => {
    expect(validatePromotion({ ...VALID, ends_at: VALID.starts_at }).ends_at).toBeDefined()
    expect(validatePromotion({ ...VALID, starts_at: '' }).starts_at).toBeDefined()
    expect(validatePromotion({ ...VALID, region_ids: [] }).region_ids).toBeDefined()
    expect(validatePromotion({ ...VALID, priority: 101 }).priority).toBeDefined()
    expect(validatePromotion({ ...VALID, priority: Number.NaN }).priority).toBeDefined()
    expect(validatePromotion({ ...VALID, ends_at: null })).toEqual({})
  })
})

describe('helpers', () => {
  it('normalizes Saudi mobiles to +9665XXXXXXXX', () => {
    for (const raw of ['0551234567', '551234567', '966551234567', '+966551234567', '055-123-4567']) {
      expect(normalizeSaudiMobile(raw)).toBe('+966551234567')
    }
    expect(normalizeSaudiMobile('0112345678')).toBeNull()
    expect(normalizeSaudiMobile('+971501234567')).toBeNull()
  })

  it('recognizes https URLs only', () => {
    expect(isHttpsUrl('https://shop.example.sa/x?y=1')).toBe(true)
    expect(isHttpsUrl('ftp://example.com')).toBe(false)
    expect(isHttpsUrl('example.com')).toBe(false)
  })

  it('normalizes before saving', () => {
    const n = normalizePromotion({ ...VALID, title: '  عنوان  ', body: '   ', action_type: 'WHATSAPP', action_value: '0551234567', region_ids: [3, 1, 3] })
    expect(n.title).toBe('عنوان')
    expect(n.body).toBeNull()
    expect(n.action_value).toBe('+966551234567')
    expect(n.region_ids).toEqual([1, 3])
    expect(normalizePromotion({ ...VALID, action_type: 'NONE', action_value: 'x' }).action_value).toBeNull()
  })

  it('derives the effective state from status and period', () => {
    const now = new Date('2026-12-01T00:00:00Z')
    const base = { status: 'ACTIVE' as const, starts_at: '2026-11-25T00:00:00Z', ends_at: '2026-12-10T00:00:00Z' }
    expect(effectiveState(base, now)).toBe('RUNNING')
    expect(effectiveState({ ...base, starts_at: '2026-12-05T00:00:00Z' }, now)).toBe('SCHEDULED')
    expect(effectiveState({ ...base, ends_at: '2026-12-01T00:00:00Z' }, now)).toBe('EXPIRED')
    expect(effectiveState({ ...base, ends_at: null }, now)).toBe('RUNNING')
    expect(effectiveState({ ...base, status: 'PAUSED' }, now)).toBe('PAUSED')
    expect(effectiveState({ ...base, status: 'ARCHIVED' }, now)).toBe('ARCHIVED')
  })

  it('computes click rate and validates interval and image files', () => {
    expect(clickRate({ impression_count: 0, click_count: 0 })).toBeNull()
    expect(clickRate({ impression_count: 400, click_count: 9 })).toBe(2.3)
    expect(validateFeedInterval(8)).toBeNull()
    expect(validateFeedInterval(3)).not.toBeNull()
    expect(validateFeedInterval(8.5)).not.toBeNull()
    expect(validateImageFile({ type: 'image/webp', size: 500_000 })).toBeNull()
    expect(validateImageFile({ type: 'image/gif', size: 10 })).not.toBeNull()
    expect(validateImageFile({ type: 'image/png', size: 2_000_000 })).not.toBeNull()
  })
})
