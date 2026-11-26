import { defaultRange, rangeDays, rangeToArgs, shiftDay, validateRange } from './dateRange'
import { buildStatGroups } from './statsGroups'
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
