# منصة الويب — لوحة إدارة نوادر الإبل

مشروع React 19 وVite وTypeScript. يضم حاليًا **لوحة الإدارة** فقط تحت المسار `/admin`. الموقع العام (AD-FR-035) غير مسند بعد (TEAM-DEC-002، INT-001)؛ المسار الجذر يحول إلى `/admin` إلى أن يبنى.

- الجانب المالك للواجهات: `ADMIN` في `src/admin/` (تعليمات `AGENTS.md`).
- الخلفية والعقد يملكهما `MOBILE` (TEAM-DEC-007). اللوحة تستهلك `../contracts/` ولا تعدله.
- أنشئ الهيكل بمهمة `ADMIN-DASH-20261124` (إسناد INT-004 بطلب المستخدم).

## التشغيل

```bash
cd web_platform
npm install
cp .env.example .env.local   # ثم املأ القيمتين
npm run dev                  # http://localhost:5173/admin
```

| المتغير | القيمة |
|---|---|
| `VITE_SUPABASE_URL` | عنوان مشروع Supabase (التطوير) |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | المفتاح العام للعميل فقط (publishable أو anon) |

**ممنوع** وضع مفتاح `service_role` أو أي مفتاح سري (`sb_secret_…`) في `VITE_*` أو المستودع. اللوحة تفحص المفتاح عند التشغيل وترفض المفاتيح السرية. `.env.local` مستثنى من Git.

## الفحوص

```bash
npm run typecheck   # tsc -b
npm test            # vitest run
npm run build       # tsc -b && vite build → dist/
```

> **Windows:** شغّل Vitest من مسار بحرف قرص كبير (`C:\…`). في Git Bash استخدم `cd C:/Users/.../web_platform` لا `cd /c/...`؛ الحرف الصغير `c:` يحمّل Vitest مرتين فتفشل الملفات بخطأ «failed to find the current suite».

## دخول الموظفين

1. ينشأ حساب الموظف في لوحة Supabase: Authentication ← Users ببريد وكلمة مرور (لا رقم هاتف). لا تسجيل ذاتي.
2. أول مدير: `supabase/scripts/admin/bootstrap_first_admin.sql` (ينفذه صاحب المشروع). بعده تمنح الأدوار من صفحة «الموظفون والأدوار» (`admin_grant_role`).
3. عند أول دخول يسجل الموظف تطبيق مصادقة TOTP بمسح رمز QR، ثم يدخل الرمز في كل جلسة. دوال الإدارة ترفض أي جلسة دون `aal2` (`MFA_REQUIRED`).
4. الحساب العادي (هاتف) أو حساب بلا دور فعال يرفض: `admin_whoami` تعيد `FORBIDDEN`.

القوائم تظهر بحسب قدرات `admin_whoami` للتوضيح فقط؛ **الصلاحية تفحص في الخادم في كل استدعاء**، وسحب الدور يسري في الاستدعاء التالي. اللوحة تعيد قراءة الدور كل دقيقة وعند العودة إلى النافذة.

## البنية

```text
src/
  app/                 نقطة الدخول والتوجيه الجذري (/ ← /admin)
  admin/
    AdminApp.tsx       المزودات والحماية والمسارات
    routes.tsx         سجل الصفحات والقائمة والقدرات
    auth/              الدخول، TOTP، حماية الموظف والقدرة
    layout/            الهيكل والقائمة الجانبية
    lib/               عميل Supabase، rpc()، الأخطاء، التنسيق، التسميات، القدرات
    ui/                مكونات مشتركة (حوار السبب الإلزامي، الجداول، الحقول…)
    features/<area>/   صفحة كل قسم واختباراته
    styles/admin.css   الهوية: رملي #F5F1EA، بني #2D241B، ذهبي #A77434، IBM Plex Sans Arabic؛ وضع فاتح فقط
    test/              عميل Supabase مزيف وأداة التركيب للاختبارات
```

## قواعد العقد في الشيفرة

- كل كتابة عبر `rpc('admin_…', args)` من `src/admin/lib/rpc.ts`، والمدخلات مفحوصة بالأنواع المولدة `contracts/generated/database.types.ts`. لا `insert`/`update`/`delete` على الجداول.
- القراءة من الجداول والـviews المسموحة لدور الموظف في `contracts/api/read-surface.md`.
- رمز الخطأ في `message` والتفاصيل JSON؛ `toApiError` يحوله و`errorMessage` يعرض النص العربي. اختبار يتحقق أن لكل رمز في `contracts/api/errors.json` نصًا.
- السبب إلزامي للإخفاء والتعليق عبر `ReasonDialog` (رمز من `moderation_reasons` ونص إلزامي عند «أخرى»).
- لا اعتماد ولا رفض ولا «قيد المراجعة» (TEAM-DEC-013، INT-008).
- الأوقات UTC في الخادم وتعرض بتوقيت `Asia/Riyadh`.
