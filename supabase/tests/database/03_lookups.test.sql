-- MOBILE-BE-102 — الترحيل 03 lookups
begin;

create extension if not exists pgtap with schema extensions;

select plan(19);

select has_table('public', 'regions', 'جدول regions');
select has_table('public', 'cities', 'جدول cities');
select has_table('public', 'breeds', 'جدول breeds');

select ok((select relrowsecurity from pg_class where oid = 'public.regions'::regclass), 'RLS مفعل على regions');
select ok((select relrowsecurity from pg_class where oid = 'public.cities'::regclass), 'RLS مفعل على cities');
select ok((select relrowsecurity from pg_class where oid = 'public.breeds'::regclass), 'RLS مفعل على breeds');

select table_privs_are('public', 'regions', 'anon', array['SELECT'], 'anon: SELECT فقط على regions');
select table_privs_are('public', 'cities', 'authenticated', array['SELECT'], 'authenticated: SELECT فقط على cities');
select table_privs_are('public', 'breeds', 'authenticated', array['SELECT'], 'authenticated: SELECT فقط على breeds');

-- البيانات المرجعية
select is((select count(*)::integer from public.regions), 13, '13 منطقة');
select is((select name_ar from public.regions where id = 1), 'الرياض', 'معرف المنطقة 1 ثابت');
select is(
  (select count(*)::integer from public.regions r
    where not exists (select 1 from public.cities c where c.region_id = r.id)),
  0, 'لكل منطقة مدينة واحدة على الأقل');
select is((select count(*)::integer from public.breeds where requires_note), 1, 'قيمة «أخرى» واحدة تستلزم توضيحًا');
select fk_ok('public', 'cities', 'region_id', 'public', 'regions', 'id');

-- قيمة معطلة لا تظهر للعميل
insert into public.breeds (name_ar, is_active) values ('سلالة معطلة للاختبار', false);
insert into public.cities (region_id, name_ar, is_active) values (1, 'مدينة معطلة للاختبار', false);

set local role anon;
select is(
  (select count(*)::integer from public.breeds where name_ar = 'سلالة معطلة للاختبار'),
  0, 'anon لا يرى سلالة معطلة');
select is(
  (select count(*)::integer from public.cities where name_ar = 'مدينة معطلة للاختبار'),
  0, 'anon لا يرى مدينة معطلة');
select ok((select count(*) from public.regions) = 13, 'anon يقرأ المناطق الفعالة');

-- لا كتابة مباشرة
select throws_ok(
  $$insert into public.breeds (name_ar) values ('x')$$,
  '42501', null, 'anon لا يدرج في breeds');
reset role;

set local role authenticated;
select throws_ok(
  $$update public.regions set name_ar = 'x' where id = 1$$,
  '42501', null, 'authenticated لا يعدل regions');
reset role;

select * from finish();
rollback;
