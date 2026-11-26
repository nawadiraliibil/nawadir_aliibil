import errorsJson from '@contracts/api/errors.json'
import enums from '@contracts/api/enums.json'
import whoamiFixture from '@contracts/fixtures/admin-whoami.json'
import { ERROR_MESSAGES_AR, toApiError, errorMessage, ApiError } from './errors'
import { isSecretKey, validateEnv } from './env'
import { formatDateTime, riyadhDayToIso } from './format'
import { CAPABILITIES, hasAny, type Whoami } from './capabilities'
import { LISTING_STATUS_LABELS, ACCOUNT_STATUS_LABELS, OFFER_TYPE_LABELS, REVIEW_DECISION_LABELS } from './labels'
import { installFakeSupabase } from '../test/fakeSupabase'
import { rpc } from './rpc'

function fakeJwt(payload: object): string {
  const b64 = (o: object) => btoa(JSON.stringify(o)).replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_')
  return `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64(payload)}.sig`
}

describe('contract error codes', () => {
  it('has an Arabic message for every error code in contracts/api/errors.json', () => {
    const missing = Object.keys(errorsJson.errors).filter((c) => !ERROR_MESSAGES_AR[c])
    expect(missing).toEqual([])
  })

  it('maps a PostgREST P0001 error to the contract code and parses JSON details', () => {
    const e = toApiError({ message: 'VALIDATION_FAILED', details: '{"fields":["p_status"]}', code: 'P0001' })
    expect(e.code).toBe('VALIDATION_FAILED')
    expect(e.fields).toEqual(['p_status'])
    expect(errorMessage(e)).toBe(ERROR_MESSAGES_AR.VALIDATION_FAILED)
  })

  it('maps REASON_REQUIRED single field detail', () => {
    const e = toApiError({ message: 'REASON_REQUIRED', details: '{"field":"reason_text"}', code: 'P0001' })
    expect(e.fields).toEqual(['reason_text'])
  })

  it('maps JWT expiry and network failures', () => {
    expect(toApiError({ message: 'JWT expired', code: 'PGRST301' }).code).toBe('AUTH_REQUIRED')
    expect(toApiError(new TypeError('Failed to fetch')).code).toBe('NETWORK')
    expect(toApiError({ message: 'something odd' }).code).toBe('UNKNOWN')
  })
})

describe('env', () => {
  it('rejects service_role JWT and sb_secret keys', () => {
    expect(isSecretKey(fakeJwt({ role: 'service_role' }))).toBe(true)
    expect(isSecretKey('sb_secret_abc')).toBe(true)
    expect(isSecretKey(fakeJwt({ role: 'anon' }))).toBe(false)
    expect(isSecretKey('sb_publishable_abc')).toBe(false)
    const res = validateEnv({ url: 'https://x.supabase.co', key: fakeJwt({ role: 'service_role' }) })
    expect(res.ok).toBe(false)
  })

  it('requires both values', () => {
    expect(validateEnv({ url: '', key: '' }).ok).toBe(false)
    expect(validateEnv({ url: 'https://x.supabase.co', key: 'sb_publishable_abc' }).ok).toBe(true)
  })
})

describe('format', () => {
  it('shows times in Asia/Riyadh', () => {
    // 21:30 UTC = 00:30 next day in Riyadh.
    const s = formatDateTime('2026-11-23T21:30:00Z')
    expect(s).toContain('24')
    expect(s).toContain('12:30')
  })

  it('converts a Riyadh day to UTC bounds', () => {
    expect(riyadhDayToIso('2026-11-24')).toBe('2026-11-23T21:00:00.000Z')
    expect(riyadhDayToIso('2026-11-24', true)).toBe('2026-11-24T21:00:00.000Z')
  })
})

describe('capabilities and labels', () => {
  it('matches the whoami fixture capabilities', () => {
    expect([...whoamiFixture.capabilities].sort()).toEqual([...CAPABILITIES].sort())
  })

  it('ADMIN has everything; MODERATOR only granted capabilities', () => {
    const mod: Whoami = { role: 'MODERATOR', user_id: 'x', capabilities: ['reports.handle'] }
    expect(hasAny(whoamiFixture as Whoami, ['staff.manage'])).toBe(true)
    expect(hasAny(mod, ['reports.handle'])).toBe(true)
    expect(hasAny(mod, ['staff.manage'])).toBe(false)
    expect(hasAny(null, [])).toBe(false)
  })

  it('labels every enum value used by the panel', () => {
    for (const v of enums.listing_status) expect(LISTING_STATUS_LABELS[v]).toBeTruthy()
    for (const v of enums.account_status) expect(ACCOUNT_STATUS_LABELS[v]).toBeTruthy()
    for (const v of enums.offer_type) expect(OFFER_TYPE_LABELS[v]).toBeTruthy()
    for (const v of enums.review_decision) expect(REVIEW_DECISION_LABELS[v]).toBeTruthy()
  })
})

describe('rpc wrapper', () => {
  it('passes typed args and returns data', async () => {
    const fake = installFakeSupabase({ rpc: { admin_list_listings: () => [] } })
    await expect(rpc('admin_list_listings', { p_status: 'HIDDEN', p_limit: 10 })).resolves.toEqual([])
    expect(fake.rpcCalls('admin_list_listings')[0]).toEqual({ p_status: 'HIDDEN', p_limit: 10 })
  })

  it('throws ApiError with the server code', async () => {
    const fake = installFakeSupabase()
    fake.failRpc('admin_whoami', 'MFA_REQUIRED')
    const err = await rpc('admin_whoami').catch((e: unknown) => e)
    expect(err).toBeInstanceOf(ApiError)
    expect((err as ApiError).code).toBe('MFA_REQUIRED')
  })
})
