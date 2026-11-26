import fx from '@contracts/fixtures/published-settings.json'
import { buildContent, diffContent, FIELDS, formatSettingValue, toFormValues, unknownEntries, validateForm } from './schema'
import type { SettingsContent } from './types'

const PUBLISHED = fx.settings as SettingsContent

describe('settings schema', () => {
  it('covers every key of the published fixture (no unknown keys in the contract fixture)', () => {
    expect(unknownEntries(PUBLISHED)).toEqual([])
    expect(FIELDS).toHaveLength(23)
  })

  it('round-trips the fixture through the form unchanged', () => {
    const form = toFormValues(PUBLISHED)
    expect(validateForm(form)).toEqual({})
    expect(buildContent(PUBLISHED, form)).toEqual(PUBLISHED)
  })

  it('keeps unknown keys when building content', () => {
    const base = { ...PUBLISHED, experimental: { flag: true }, listing: { ...(PUBLISHED.listing as object), legacy: 7 } }
    const form = { ...toFormValues(base), 'listing.title_max': '90' }
    const out = buildContent(base, form)
    expect(out.experimental).toEqual({ flag: true })
    expect((out.listing as Record<string, unknown>).legacy).toBe(7)
    expect((out.listing as Record<string, unknown>).title_max).toBe(90)
    expect(unknownEntries(base).map((e) => e.path)).toEqual(['listing.legacy', 'experimental'])
  })

  it('mirrors server validation rules', () => {
    const ok = toFormValues(PUBLISHED)
    expect(validateForm({ ...ok, 'bump.interval_hours': '12' })['bump.interval_hours']).toMatch(/لا تقل عن 24/)
    expect(validateForm({ ...ok, 'bump.interval_hours': '48' })).toEqual({})
    expect(validateForm({ ...ok, 'listing.title_min': '100', 'listing.title_max': '50' })['listing.title_min']).toMatch(/أكبر/)
    expect(validateForm({ ...ok, 'media.images_min': '0' })['media.images_min']).toMatch(/عددًا صحيحًا موجبًا/)
    expect(validateForm({ ...ok, 'media.images_max': '2.5' })['media.images_max']).toMatch(/عددًا صحيحًا موجبًا/)
    expect(validateForm({ ...ok, 'media.images_max': '21' })['media.images_max']).toMatch(/الحد التقني/)
    expect(validateForm({ ...ok, 'interaction.message_max': '' })['interaction.message_max']).toMatch(/مطلوب/)
    expect(validateForm({ ...ok, 'media.image_mime_types': [] })['media.image_mime_types']).toMatch(/صيغة/)
  })

  it('diffs leaves and formats values', () => {
    const draft = buildContent(PUBLISHED, { ...toFormValues(PUBLISHED), 'media.video_enabled': true, 'bump.interval_hours': '48' })
    expect(diffContent(PUBLISHED, draft)).toEqual([
      { path: 'media.video_enabled', before: false, after: true },
      { path: 'bump.interval_hours', before: 24, after: 48 },
    ])
    expect(formatSettingValue('media.image_max_bytes', 10485760)).toBe('10,485,760 بايت (10 ميجابايت)')
    expect(formatSettingValue('media.image_mime_types', ['image/jpeg', 'image/png'])).toBe('JPEG، PNG')
    expect(formatSettingValue('media.video_enabled', false)).toBe('معطل')
  })
})
