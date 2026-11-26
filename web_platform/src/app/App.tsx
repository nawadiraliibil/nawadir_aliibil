import { lazy, Suspense } from 'react'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router'

// لوحة الإدارة وحدها في هذه المرحلة. الموقع العام (AD-FR-035) غير مسند (TEAM-DEC-002، INT-001)؛
// المسار الجذر يحول إلى /admin مؤقتًا إلى أن يسند ويبنى.
const AdminApp = lazy(() => import('../admin/AdminApp'))

export function App() {
  return (
    <BrowserRouter>
      <Suspense fallback={null}>
        <Routes>
          <Route path="/admin/*" element={<AdminApp />} />
          <Route path="*" element={<Navigate to="/admin" replace />} />
        </Routes>
      </Suspense>
    </BrowserRouter>
  )
}
