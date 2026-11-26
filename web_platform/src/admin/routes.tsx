import { lazy, type ComponentType, type LazyExoticComponent } from 'react'
import type { Capability } from './lib/capabilities'

/**
 * سجل صفحات اللوحة. كل ميزة في مجلدها تحت features/ وتصدر صفحاتها افتراضيًا.
 * caps: القدرات التي تظهر الصفحة لمن يملك إحداها (المدير يملك الكل). الخادم يفحص كل استدعاء.
 */
export interface AdminRoute {
  path: string
  Component: LazyExoticComponent<ComponentType>
  caps: readonly Capability[]
}

export interface NavItem {
  to: string
  label: string
  icon: string
  caps: readonly Capability[]
  group: 'main' | 'moderation' | 'config'
}

const OverviewPage = lazy(() => import('./features/overview/OverviewPage'))
const ListingsPage = lazy(() => import('./features/listings/ListingsPage'))
const ListingDetailPage = lazy(() => import('./features/listings/ListingDetailPage'))
const AccountsPage = lazy(() => import('./features/accounts/AccountsPage'))
const AccountDetailPage = lazy(() => import('./features/accounts/AccountDetailPage'))
const ReportsPage = lazy(() => import('./features/reports/ReportsPage'))
const ReportDetailPage = lazy(() => import('./features/reports/ReportDetailPage'))
const RatingsPage = lazy(() => import('./features/ratings/RatingsPage'))
const RatingDetailPage = lazy(() => import('./features/ratings/RatingDetailPage'))
const LookupsPage = lazy(() => import('./features/lookups/LookupsPage'))
const SettingsPage = lazy(() => import('./features/settings/SettingsPage'))
const StaffPage = lazy(() => import('./features/staff/StaffPage'))
const AuditPage = lazy(() => import('./features/staff/AuditPage'))
const PromotionsPage = lazy(() => import('./features/promotions/PromotionsPage'))
const PromotionEditorPage = lazy(() => import('./features/promotions/PromotionEditorPage'))

const LISTINGS_CAPS = ['listings.hide', 'listings.review'] as const
/** الدعايات التجارية (TEAM-DEC-017، العقد 1.6.0). */
const PROMOTIONS_CAPS = ['promotions.manage'] as const

/** المسارات نسبية إلى /admin. */
export const ADMIN_ROUTES: AdminRoute[] = [
  { path: 'listings', Component: ListingsPage, caps: LISTINGS_CAPS },
  { path: 'listings/:listingId', Component: ListingDetailPage, caps: LISTINGS_CAPS },
  { path: 'accounts', Component: AccountsPage, caps: ['accounts.manage'] },
  { path: 'accounts/:userId', Component: AccountDetailPage, caps: ['accounts.manage'] },
  { path: 'promotions', Component: PromotionsPage, caps: PROMOTIONS_CAPS },
  { path: 'promotions/new', Component: PromotionEditorPage, caps: PROMOTIONS_CAPS },
  { path: 'promotions/:promotionId', Component: PromotionEditorPage, caps: PROMOTIONS_CAPS },
  { path: 'reports', Component: ReportsPage, caps: ['reports.handle'] },
  { path: 'reports/:reportId', Component: ReportDetailPage, caps: ['reports.handle'] },
  { path: 'ratings', Component: RatingsPage, caps: ['ratings.moderate'] },
  { path: 'ratings/:ratingId', Component: RatingDetailPage, caps: ['ratings.moderate'] },
  { path: 'lookups', Component: LookupsPage, caps: ['lookups.manage'] },
  { path: 'settings', Component: SettingsPage, caps: ['settings.manage'] },
  { path: 'staff', Component: StaffPage, caps: ['staff.manage'] },
  { path: 'audit', Component: AuditPage, caps: ['audit.read'] },
]

/** الصفحة الرئيسية متاحة لكل موظف؛ تعرض التقارير لمن يملك stats.read. */
export const OVERVIEW_ROUTE: AdminRoute = { path: '', Component: OverviewPage, caps: [] }

export const NAV_ITEMS: NavItem[] = [
  { to: '/admin', label: 'الرئيسية', icon: '⌂', caps: [], group: 'main' },
  { to: '/admin/listings', label: 'إدارة الإعلانات', icon: '▤', caps: LISTINGS_CAPS, group: 'main' },
  { to: '/admin/accounts', label: 'الحسابات', icon: '◉', caps: ['accounts.manage'], group: 'main' },
  { to: '/admin/promotions', label: 'الدعايات التجارية', icon: '✦', caps: PROMOTIONS_CAPS, group: 'main' },
  { to: '/admin/reports', label: 'البلاغات والردود', icon: '⚑', caps: ['reports.handle'], group: 'moderation' },
  { to: '/admin/ratings', label: 'التقييمات والاعتراضات', icon: '★', caps: ['ratings.moderate'], group: 'moderation' },
  { to: '/admin/lookups', label: 'القوائم وأسباب الإشراف', icon: '☰', caps: ['lookups.manage'], group: 'config' },
  { to: '/admin/settings', label: 'الإعدادات والحدود', icon: '⚙', caps: ['settings.manage'], group: 'config' },
  { to: '/admin/staff', label: 'الموظفون والأدوار', icon: '♙', caps: ['staff.manage'], group: 'config' },
  { to: '/admin/audit', label: 'سجل الإجراءات', icon: '⧗', caps: ['audit.read'], group: 'config' },
]

export const NAV_GROUP_LABELS: Record<NavItem['group'], string> = {
  main: 'الإدارة',
  moderation: 'الإشراف',
  config: 'الإعداد والموظفون',
}
