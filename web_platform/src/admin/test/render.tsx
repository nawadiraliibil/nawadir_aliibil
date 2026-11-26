import type { ReactElement, ReactNode } from 'react'
import { render } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router'
import { AuthContext, type AuthValue } from '../auth/AuthContext'
import { hasAny, CAPABILITIES, type Capability, type Whoami } from '../lib/capabilities'
import { NotifyProvider } from '../ui'

export const ADMIN_WHOAMI: Whoami = { role: 'ADMIN', user_id: '95002fec-541b-4085-b6db-671b43ea977f', capabilities: [...CAPABILITIES] }

export function moderator(caps: Capability[]): Whoami {
  return { role: 'MODERATOR', user_id: '11111111-1111-4111-8111-111111111111', capabilities: caps }
}

export function fakeAuth(whoami: Whoami | null = ADMIN_WHOAMI, overrides: Partial<AuthValue> = {}): AuthValue {
  return {
    status: whoami ? 'ready' : 'signedOut',
    email: 'staff@example.test',
    whoami,
    error: null,
    can: (caps) => hasAny(whoami, typeof caps === 'string' ? [caps] : caps),
    signIn: async () => {},
    signOut: async () => {},
    refresh: async () => {},
    handleApiError: () => {},
    ...overrides,
  }
}

export interface RenderAdminOptions {
  /** العنوان الحالي، مثل /admin/listings/abc. */
  route?: string
  /** نمط المسار الذي تركب عليه الصفحة، مثل /admin/listings/:listingId. */
  path?: string
  whoami?: Whoami | null
  auth?: Partial<AuthValue>
  /** صفحات إضافية للتحقق من التنقل. */
  extraRoutes?: Array<{ path: string; element: ReactNode }>
}

/** يركب الصفحة داخل مزودي الاستعلام والتوجيه والإشعارات وسياق موظف مزيف. */
export function renderAdmin(ui: ReactElement, opts: RenderAdminOptions = {}) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: 0 }, mutations: { retry: false } } })
  const route = opts.route ?? '/admin'
  const path = opts.path ?? route
  const auth = fakeAuth(opts.whoami === undefined ? ADMIN_WHOAMI : opts.whoami, opts.auth)
  const result = render(
    <QueryClientProvider client={client}>
      <NotifyProvider>
        <AuthContext.Provider value={auth}>
          <MemoryRouter initialEntries={[route]}>
            <Routes>
              <Route path={path} element={ui} />
              {(opts.extraRoutes ?? []).map((r) => (
                <Route key={r.path} path={r.path} element={r.element} />
              ))}
              <Route path="*" element={<div data-testid="other-route" />} />
            </Routes>
          </MemoryRouter>
        </AuthContext.Provider>
      </NotifyProvider>
    </QueryClientProvider>,
  )
  return { ...result, queryClient: client, auth }
}
