-- 02b service_role_defaults — MOBILE-BE-101
-- الصلاحيات الافتراضية لـservice_role تختلف بين القاعدة المحلية والمشروع السحابي
-- (السحابي لا يمنحه القراءة والكتابة على الجداول الجديدة ولا EXECUTE على الدوال).
-- تثبت هنا صراحة لتتطابق البيئتان. service_role دور خادم فقط (دوال Edge)
-- ولا يصل مفتاحه إلى أي عميل.
alter default privileges for role postgres in schema public
  grant all on tables to service_role;
alter default privileges for role postgres in schema public
  grant all on sequences to service_role;
alter default privileges for role postgres in schema public
  grant execute on functions to service_role;

grant execute on function private.raise_error(text, jsonb) to service_role;
