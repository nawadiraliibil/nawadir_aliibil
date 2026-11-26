import { useEffect, useState } from 'react'
import { Route, Routes } from 'react-router'
import { QueryClientProvider } from '@tanstack/react-query'
import { AuthProvider, useAuth } from './auth/AuthContext'
import { RequireCapability, RequireStaff } from './auth/Guards'
import { AdminShell } from './layout/AdminShell'
import { ADMIN_ROUTES, OVERVIEW_ROUTE } from './routes'
import { createAdminQueryClient, setGlobalApiErrorHandler } from './lib/queryClient'
import { readEnv } from './lib/env'
import { NotifyProvider, PageHeader, EmptyState } from './ui'
import { AuthLayout } from './auth/AuthLayout'
import { Alert } from './ui'
import './styles/admin.css'

function ErrorBridge() {
  const { handleApiError } = useAuth()
  useEffect(() => {
    setGlobalApiErrorHandler(handleApiError)
    return () => setGlobalApiErrorHandler(null)
  }, [handleApiError])
  return null
}

function NotFound() {
  return (
    <div className="page">
      <PageHeader title="الصفحة غير موجودة" />
      <EmptyState title="لا توجد صفحة بهذا العنوان." />
    </div>
  )
}

/** جذر لوحة الإدارة تحت /admin. */
export default function AdminApp() {
  const [queryClient] = useState(createAdminQueryClient)
  const env = readEnv()
  if (!env.ok) {
    return (
      <AuthLayout title="إعداد اللوحة غير مكتمل">
        <Alert tone="danger">{env.problem}</Alert>
      </AuthLayout>
    )
  }
  return (
    <QueryClientProvider client={queryClient}>
      <NotifyProvider>
        <AuthProvider>
          <ErrorBridge />
          <RequireStaff>
            <Routes>
              <Route element={<AdminShell />}>
                <Route index element={<OVERVIEW_ROUTE.Component />} />
                {ADMIN_ROUTES.map((r) => (
                  <Route
                    key={r.path}
                    path={r.path}
                    element={
                      <RequireCapability caps={r.caps}>
                        <r.Component />
                      </RequireCapability>
                    }
                  />
                ))}
                <Route path="*" element={<NotFound />} />
              </Route>
            </Routes>
          </RequireStaff>
        </AuthProvider>
      </NotifyProvider>
    </QueryClientProvider>
  )
}
