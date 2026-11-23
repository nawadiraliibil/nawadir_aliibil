-- MOBILE-BE-102 — الترحيل 04 settings
begin;

create extension if not exists pgtap with schema extensions;

select plan(19);

select has_table('public', 'settings_versions', 'جدول settings_versions');
select has_table('public', 'platform_settings', 'جدول platform_settings');
select ok((select relrowsecurity from pg_class where oid = 'public.settings_versions'::regclass), 'RLS مفعل على settings_versions');
select ok((select relrowsecurity from pg_class where oid = 'public.platform_settings'::regclass), 'RLS مفعل على platform_settings');
select table_privs_are('public', 'settings_versions', 'anon', array[]::text[], 'anon بلا صلاحية على settings_versions');
select table_privs_are('public', 'platform_settings', 'authenticated', array['SELECT'], 'authenticated: SELECT فقط على platform_settings (بسياسة الموظف)');

-- الإصدار 1
select is((select published_version from public.platform_settings), 1, 'الإصدار المنشور 1');
select is((private.published_settings() #>> '{bump,interval_hours}')::integer, 24, 'تجديد الظهور 24 ساعة');
select is((private.published_settings() #>> '{media,video_enabled}')::boolean, false, 'الفيديو معطل افتراضيًا');

-- صف واحد وسجل إضافة فقط
select throws_ok(
  $$insert into public.platform_settings (id, published_version) values (false, 1)$$,
  '23514', null, 'platform_settings صف واحد');
select throws_ok(
  $$update public.settings_versions set note = 'x' where version = 1$$,
  'P0001', 'APPEND_ONLY', 'لا تعديل لإصدار منشور');
select throws_ok(
  $$delete from public.settings_versions where version = 1$$,
  'P0001', 'APPEND_ONLY', 'لا حذف لإصدار');

-- التحقق من المحتوى
select lives_ok(
  $$select private.validate_settings(private.published_settings())$$,
  'الإصدار 1 صالح');
select throws_ok(
  $$select private.validate_settings(jsonb_set(private.published_settings(), '{bump,interval_hours}', '23'))$$,
  'P0001', 'BELOW_HARD_MINIMUM', 'تجديد أقل من 24 ساعة مرفوض');
select throws_ok(
  $$select private.validate_settings(jsonb_set(private.published_settings(), '{listing,title_min}', '81'))$$,
  'P0001', 'VALIDATION_FAILED', 'حد أدنى يتجاوز الأعلى مرفوض');
select throws_ok(
  $$select private.validate_settings(jsonb_set(private.published_settings(), '{media,image_mime_types}', '["image/gif"]'))$$,
  'P0001', 'VALIDATION_FAILED', 'صيغة غير مدعومة مرفوضة');
select throws_ok(
  $$select private.validate_settings(private.published_settings() #- '{listing,title_max}')$$,
  'P0001', 'VALIDATION_FAILED', 'حقل ناقص مرفوض');

-- العميل: الدالة فقط
set local role anon;
select is((public.get_published_settings() ->> 'version')::integer, 1, 'anon يقرأ الإصدار المنشور');
select is(
  jsonb_array_length(public.get_published_settings() #> '{lookups,regions}'),
  13, 'القوائم الفعالة ضمن الرد');
reset role;

select * from finish();
rollback;
