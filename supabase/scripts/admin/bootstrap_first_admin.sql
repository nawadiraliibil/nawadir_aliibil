-- تهيئة أول مدير للمنصة — MOBILE-BE-104
--
-- ينفذ مرة واحدة من محرر SQL في لوحة Supabase (أو psql بصلاحية قاعدة البيانات).
-- لا يعمل من جلسة عميل. يرفض إن وجد مدير فعال؛ بعدها تمنح الأدوار بالدالة
-- admin_grant_role من جلسة المدير.
--
-- قبل التنفيذ:
--   1. أنشئ حساب الموظف في Authentication > Users ببريد وكلمة مرور (لا رقم هاتف).
--   2. ضع معرف الحساب (UUID) مكان القيمة أدناه. لا تلتزم بالملف بعد وضع معرف حقيقي.
--   3. بعد التنفيذ يسجل الموظف عامل TOTP؛ دوال الإدارة ترفض الجلسة دون aal2.

select private.bootstrap_first_admin('00000000-0000-0000-0000-000000000000'::uuid);

select user_id, role, is_active, granted_at
from public.admin_roles
where role = 'ADMIN' and is_active;
