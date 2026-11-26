// عميل Supabase مزيف للاختبارات: جداول في الذاكرة، ودوال RPC بمعالجات، وتخزين بروابط موقعة وهمية.
// يمر عبر rpc() وunwrap() الحقيقيين، فيختبر ربط الأخطاء ورموز العقد.
import { setSupabaseForTests } from '../lib/supabase'

export type Row = Record<string, unknown>
export interface RpcErrorSpec {
  code: string
  details?: Record<string, unknown>
}
export type RpcHandler = (args: Record<string, unknown>) => unknown | Promise<unknown>

export interface FakeCall {
  kind: 'rpc' | 'select' | 'upload'
  name: string
  args?: Record<string, unknown>
  filters?: Array<[string, ...unknown[]]>
}

export interface FakeSupabase {
  calls: FakeCall[]
  tables: Record<string, Row[]>
  rpcHandlers: Record<string, RpcHandler>
  /** يجعل استدعاء RPC يفشل برمز من العقد مرة أو دائمًا. */
  failRpc: (name: string, code: string, details?: Record<string, unknown>, times?: number) => void
  failTable: (name: string, code: string) => void
  rpcCalls: (name: string) => Array<Record<string, unknown>>
  client: unknown
}

/** خطأ بصيغة PostgREST: الرمز في message والتفاصيل نص JSON (contracts/api/errors.json). */
export function postgrestError(code: string, details: Record<string, unknown> = {}) {
  return { message: code, details: JSON.stringify(details), code: 'P0001', hint: null }
}

function likeToRegex(pattern: string): RegExp {
  const escaped = pattern.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/%/g, '.*').replace(/_/g, '.')
  return new RegExp(`^${escaped}$`, 'i')
}

function get(row: Row, col: string): unknown {
  return row[col]
}

export function createFakeSupabase(init: { tables?: Record<string, Row[]>; rpc?: Record<string, RpcHandler> } = {}): FakeSupabase {
  const calls: FakeCall[] = []
  const tables: Record<string, Row[]> = { ...(init.tables ?? {}) }
  const rpcHandlers: Record<string, RpcHandler> = { ...(init.rpc ?? {}) }
  const rpcFailures: Record<string, { spec: RpcErrorSpec; times: number }> = {}
  const tableFailures: Record<string, string> = {}

  function builder(table: string) {
    const filters: Array<[string, ...unknown[]]> = []
    let orderBy: Array<{ col: string; asc: boolean }> = []
    let limitN: number | null = null
    let rangeFrom: number | null = null
    let rangeTo: number | null = null
    let single: 'single' | 'maybe' | null = null
    let countMode = false
    const preds: Array<(r: Row) => boolean> = []

    const api = {
      select(_cols?: string, opts?: { count?: string; head?: boolean }) {
        if (opts?.count) countMode = true
        return api
      },
      eq(col: string, v: unknown) {
        filters.push(['eq', col, v])
        preds.push((r) => get(r, col) === v)
        return api
      },
      neq(col: string, v: unknown) {
        filters.push(['neq', col, v])
        preds.push((r) => get(r, col) !== v)
        return api
      },
      in(col: string, vs: unknown[]) {
        filters.push(['in', col, vs])
        preds.push((r) => vs.includes(get(r, col)))
        return api
      },
      is(col: string, v: unknown) {
        filters.push(['is', col, v])
        preds.push((r) => (v === null ? get(r, col) === null || get(r, col) === undefined : get(r, col) === v))
        return api
      },
      not(col: string, op: string, v: unknown) {
        filters.push(['not', col, op, v])
        if (op === 'is' && v === null) preds.push((r) => get(r, col) !== null && get(r, col) !== undefined)
        return api
      },
      ilike(col: string, pattern: string) {
        filters.push(['ilike', col, pattern])
        const re = likeToRegex(pattern)
        preds.push((r) => typeof get(r, col) === 'string' && re.test(get(r, col) as string))
        return api
      },
      like(col: string, pattern: string) {
        return api.ilike(col, pattern)
      },
      contains(col: string, vs: unknown[]) {
        filters.push(['contains', col, vs])
        preds.push((r) => Array.isArray(get(r, col)) && vs.every((v) => (get(r, col) as unknown[]).includes(v)))
        return api
      },
      gt(col: string, v: unknown) {
        filters.push(['gt', col, v])
        preds.push((r) => (get(r, col) as never) > (v as never))
        return api
      },
      gte(col: string, v: unknown) {
        filters.push(['gte', col, v])
        preds.push((r) => (get(r, col) as never) >= (v as never))
        return api
      },
      lt(col: string, v: unknown) {
        filters.push(['lt', col, v])
        preds.push((r) => (get(r, col) as never) < (v as never))
        return api
      },
      lte(col: string, v: unknown) {
        filters.push(['lte', col, v])
        preds.push((r) => (get(r, col) as never) <= (v as never))
        return api
      },
      /** يسجل ولا يطبق (منطق or في PostgREST خارج نطاق المزيف). */
      or(expr: string) {
        filters.push(['or', expr])
        return api
      },
      filter(col: string, op: string, v: unknown) {
        filters.push(['filter', col, op, v])
        return api
      },
      match(obj: Row) {
        for (const [k, v] of Object.entries(obj)) api.eq(k, v)
        return api
      },
      order(col: string, opts?: { ascending?: boolean }) {
        orderBy = [...orderBy, { col, asc: opts?.ascending ?? true }]
        filters.push(['order', col, opts?.ascending ?? true])
        return api
      },
      limit(n: number) {
        limitN = n
        filters.push(['limit', n])
        return api
      },
      range(from: number, to: number) {
        rangeFrom = from
        rangeTo = to
        filters.push(['range', from, to])
        return api
      },
      single() {
        single = 'single'
        return api
      },
      maybeSingle() {
        single = 'maybe'
        return api
      },
      then<TResult1, TResult2>(resolve: (v: { data: unknown; error: unknown; count?: number | null; status: number }) => TResult1, reject?: (e: unknown) => TResult2) {
        return Promise.resolve(run()).then(resolve, reject)
      },
    }

    function run() {
      calls.push({ kind: 'select', name: table, filters })
      const fail = tableFailures[table]
      if (fail) return { data: null, error: postgrestError(fail), status: 400, count: null }
      let rows = (tables[table] ?? []).filter((r) => preds.every((p) => p(r)))
      for (const o of [...orderBy].reverse()) {
        rows = [...rows].sort((a, b) => {
          const x = get(a, o.col) as never
          const y = get(b, o.col) as never
          if (x === y) return 0
          return (x < y ? -1 : 1) * (o.asc ? 1 : -1)
        })
      }
      const count = rows.length
      if (rangeFrom !== null && rangeTo !== null) rows = rows.slice(rangeFrom, rangeTo + 1)
      if (limitN !== null) rows = rows.slice(0, limitN)
      if (single) {
        const first = rows[0] ?? null
        if (!first && single === 'single') return { data: null, error: { message: 'no rows', code: 'PGRST116', details: '' }, status: 406, count: null }
        return { data: first, error: null, status: 200, count: countMode ? count : null }
      }
      return { data: rows, error: null, status: 200, count: countMode ? count : null }
    }
    return api
  }

  const client = {
    from: (table: string) => builder(table),
    rpc: async (name: string, args: Record<string, unknown> = {}) => {
      calls.push({ kind: 'rpc', name, args })
      const failure = rpcFailures[name]
      if (failure && failure.times !== 0) {
        if (failure.times > 0) failure.times -= 1
        return { data: null, error: postgrestError(failure.spec.code, failure.spec.details), status: 400 }
      }
      const handler = rpcHandlers[name]
      if (!handler) return { data: null, error: { message: `no fake handler for ${name}`, code: 'PGRST202', details: '' }, status: 404 }
      try {
        const data = await handler(args)
        return { data, error: null, status: 200 }
      } catch (e) {
        if (e && typeof e === 'object' && 'code' in e && typeof (e as RpcErrorSpec).code === 'string') {
          const spec = e as RpcErrorSpec
          return { data: null, error: postgrestError(spec.code, spec.details), status: 400 }
        }
        throw e
      }
    },
    storage: {
      from: (bucket: string) => ({
        // الرفع يسجل في calls (kind 'upload'، name = bucket، args.path).
        upload: async (path: string, file: unknown, options?: Record<string, unknown>) => {
          calls.push({ kind: 'upload', name: bucket, args: { path, file, ...options } })
          return { data: { path }, error: null }
        },
        getPublicUrl: (path: string) => ({ data: { publicUrl: `https://storage.test/public/${bucket}/${path}` } }),
        createSignedUrl: async (path: string) => ({ data: { signedUrl: `https://storage.test/${bucket}/${path}?token=t` }, error: null }),
        createSignedUrls: async (paths: string[]) => ({
          data: paths.map((p) => ({ path: p, signedUrl: `https://storage.test/${bucket}/${p}?token=t`, error: null })),
          error: null,
        }),
      }),
    },
    auth: {
      getSession: async () => ({ data: { session: null }, error: null }),
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe: () => {} } } }),
      signOut: async () => ({ error: null }),
      signInWithPassword: async () => ({ data: {}, error: null }),
      mfa: {
        getAuthenticatorAssuranceLevel: async () => ({ data: { currentLevel: 'aal2', nextLevel: 'aal2' }, error: null }),
        listFactors: async () => ({ data: { all: [], totp: [], phone: [] }, error: null }),
        enroll: async () => ({ data: { id: 'f1', totp: { qr_code: 'data:image/svg+xml;utf8,<svg/>', secret: 'SECRET', uri: 'otpauth://x' } }, error: null }),
        unenroll: async () => ({ data: {}, error: null }),
        challengeAndVerify: async () => ({ data: {}, error: null }),
      },
    },
  }

  const fake: FakeSupabase = {
    calls,
    tables,
    rpcHandlers,
    failRpc: (name, code, details, times = -1) => {
      rpcFailures[name] = { spec: { code, details }, times }
    },
    failTable: (name, code) => {
      tableFailures[name] = code
    },
    rpcCalls: (name) => calls.filter((c) => c.kind === 'rpc' && c.name === name).map((c) => c.args ?? {}),
    client,
  }
  return fake
}

/** ينشئ المزيف ويركبه عميلًا للوحة. */
export function installFakeSupabase(init?: Parameters<typeof createFakeSupabase>[0]): FakeSupabase {
  const fake = createFakeSupabase(init)
  setSupabaseForTests(fake.client)
  return fake
}
