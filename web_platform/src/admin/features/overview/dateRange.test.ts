import { defaultRange, presetRange, rangeDays, rangeToArgs, shiftDay, validateRange } from './dateRange'
import { buildReportView, buildStatGroups } from './statsGroups'
import statsFixture from '@contracts/fixtures/admin-stats.json'

describe('dateRange', () => {
  it('defaults to 30 Riyadh days ending today', () => {
    // 22:30 UTC = 01:30 the next day in Riyadh.
    const r = defaultRange(new Date('2026-11-23T22:30:00Z'))
    expect(r).toEqual({ from: '2026-10-26', to: '2026-11-24' })
    expect(rangeDays(r)).toBe(30)
  })

  it('shifts days across months and leap years', () => {
    expect(shiftDay('2024-03-01', -1)).toBe('2024-02-29')
    expect(shiftDay('2026-12-31', 1)).toBe('2027-01-01')
  })

  it('validates order, span and format', () => {
    expect(validateRange({ from: '2026-01-01', to: '2026-01-01' })).toEqual({})
    expect(validateRange({ from: '2025-01-01', to: '2026-01-01' })).toEqual({})
    expect(validateRange({ from: '2025-01-01', to: '2026-01-02' }).to).toBe('الفترة لا تتجاوز 366 يومًا.')
    expect(validateRange({ from: '2026-01-02', to: '2026-01-01' }).to).toBe('تاريخ النهاية يجب أن يكون في يوم البداية أو بعده.')
    expect(validateRange({ from: '2026-02-30', to: '2026-03-01' }).from).toBe('تاريخ البداية غير صالح.')
    expect(validateRange({ from: '', to: '' })).toEqual({ from: 'أدخل تاريخ البداية.', to: 'أدخل تاريخ النهاية.' })
  })

  it('builds preset ranges ending today in Riyadh', () => {
    const now = new Date('2026-11-23T22:30:00Z') // 2026-11-24 في الرياض
    expect(presetRange(7, now)).toEqual({ from: '2026-11-18', to: '2026-11-24' })
    expect(presetRange(30, now)).toEqual(defaultRange(now))
    expect(rangeDays(presetRange(90, now))).toBe(90)
    expect(presetRange('ytd', now)).toEqual({ from: '2026-01-01', to: '2026-11-24' })
    // بداية السنة بتوقيت الرياض لا UTC.
    expect(presetRange('ytd', new Date('2026-12-31T21:30:00Z'))).toEqual({ from: '2027-01-01', to: '2027-01-01' })
    for (const p of [7, 30, 90, 'ytd'] as const) expect(validateRange(presetRange(p, now))).toEqual({})
  })

  it('converts to UTC bounds with an exclusive upper bound', () => {
    expect(rangeToArgs({ from: '2026-11-01', to: '2026-11-01' })).toEqual({
      p_from: '2026-10-31T21:00:00.000Z',
      p_to: '2026-11-01T21:00:00.000Z',
    })
  })
})

describe('buildStatGroups', () => {
  it('keeps the fixed group order and drops dead listing keys', () => {
    const groups = buildStatGroups(statsFixture)
    expect(groups.map((g) => g.key)).toEqual(['accounts', 'listings', 'reports', 'ratings', 'follows', 'interaction'])
    const listings = groups.find((g) => g.key === 'listings')!
    expect(listings.tiles.map((t) => t.key)).toEqual(['submitted', 'approved', 'hidden', 'published_now'])
  })

  it('ignores non-object top-level values and non-numeric entries', () => {
    const groups = buildStatGroups({ ...statsFixture, extra: 5, odd: { a: 'x', b: 2 } })
    const odd = groups.find((g) => g.key === 'odd')!
    expect(odd.raw).toBe(true)
    expect(odd.tiles).toEqual([{ key: 'b', label: 'b', value: 2, raw: true }])
    expect(groups.find((g) => g.key === 'extra')).toBeUndefined()
  })
})

describe('buildReportView', () => {
  it('moves snapshot counts to the pulse in a fixed order and keeps period counts in groups', () => {
    const view = buildReportView(statsFixture)
    expect(view.pulse.map((t) => `${t.groupKey}.${t.key}`)).toEqual([
      'listings.published_now',
      'reports.open_now',
      'ratings.appeals_open_now',
      'accounts.total',
      'accounts.suspended_now',
      'ratings.hidden_now',
    ])
    expect(view.pulse.filter((t) => t.hero).map((t) => t.key)).toEqual(['published_now'])
    const listings = view.groups.find((g) => g.key === 'listings')!
    expect(listings.tiles.map((t) => t.key)).toEqual(['submitted', 'approved', 'hidden'])
    expect(listings.max).toBe(1)
  })

  it('computes the share of new accounts only with a positive total, clamped to 1', () => {
    const share = (accounts: Record<string, number>) =>
      buildReportView({ ...statsFixture, accounts }).groups.find((g) => g.key === 'accounts')?.share
    expect(share({ total: 8, created: 2 })).toEqual({ ratio: 0.25, label: 'من إجمالي الحسابات انضم خلال الفترة' })
    expect(share({ total: 0, created: 0 })).toBeUndefined()
    expect(share({ total: 2, created: 5 })?.ratio).toBe(1)
  })

  it('keeps unknown keys in their group and drops groups left empty', () => {
    const view = buildReportView({ ...statsFixture, listings: { published_now: 4, views_total: 9 }, views: { unique: 3 } })
    expect(view.groups.find((g) => g.key === 'listings')!.tiles).toEqual([{ key: 'views_total', label: 'views_total', value: 9, raw: true }])
    expect(view.groups.find((g) => g.key === 'views')!.raw).toBe(true)
    const onlySnapshot = buildReportView({ ...statsFixture, reports: { open_now: 2 } })
    expect(onlySnapshot.groups.find((g) => g.key === 'reports')).toBeUndefined()
    expect(onlySnapshot.pulse.find((t) => t.key === 'open_now')?.value).toBe(2)
  })
})
