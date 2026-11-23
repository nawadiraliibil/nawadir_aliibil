-- MOBILE-BE-303 — الترحيل 18 reports
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

-- a معلن، b مشترٍ، c ثالث، s مدير، m1 مشرف بلاغات فقط، m2 مشرف بلاغات وأدلة.
insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002'),
  ('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000003');
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'm1@example.test'),
  ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'm2@example.test');
update public.profiles set display_name = 'معلن الاختبار', region_id = 1
  where id = '00000000-0000-0000-0000-00000000000a';
update public.profiles set display_name = 'مشتري الاختبار', region_id = 1
  where id = '00000000-0000-0000-0000-00000000000b';
update public.profiles set display_name = 'طرف ثالث', region_id = 1
  where id = '00000000-0000-0000-0000-00000000000c';
insert into public.policy_consents (user_id, document_id)
  select u.id, d.id from private.current_policy_documents() d,
    (values ('00000000-0000-0000-0000-00000000000a'::uuid),
            ('00000000-0000-0000-0000-00000000000b'::uuid),
            ('00000000-0000-0000-0000-00000000000c'::uuid)) u(id);
select private.bootstrap_first_admin('00000000-0000-0000-0000-0000000000a1');
insert into public.admin_roles (user_id, role, capabilities) values
  ('00000000-0000-0000-0000-0000000000a2', 'MODERATOR', array['reports.handle']),
  ('00000000-0000-0000-0000-0000000000a3', 'MODERATOR', array['reports.handle', 'evidence.read']);

create function pg_temp.login(p_user uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated, anon;

create function pg_temp.publish(p_key text, p_title text) returns void language plpgsql as $$
declare
  v_listing uuid;
  v_media uuid[] := array[]::uuid[];
  v_m uuid;
  v_ver uuid;
  v_hash text;
begin
  perform pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
  v_listing := (public.create_listing_draft(gen_random_uuid()) #>> '{listing,id}')::uuid;
  perform public.save_listing_draft(v_listing, jsonb_build_object(
    'title', p_title, 'description', 'وصف كاف لاجتياز الحد الأدنى للطول المطلوب في الاختبار',
    'breed_id', (select id from public.breeds where not requires_note order by id limit 1),
    'sex', 'FEMALE', 'age_months', 48, 'region_id', 1,
    'city_id', (select id from public.cities where region_id = 1 order by id limit 1),
    'health_notes', 'لا توجد عيوب معروفة', 'owner_declaration', true,
    'offer_type', 'FIXED_PRICE', 'price', 25000, 'contact_phone', '0500000009',
    'contact_call_enabled', true));
  insert into ids values (p_key, v_listing);
  for i in 1..3 loop
    v_m := (public.add_listing_media(v_listing, 'IMAGE', 'image/jpeg', 1000) ->> 'media_id')::uuid;
    perform public.finalize_listing_media(v_m, 'image/jpeg', 1000, 800, 600);
    v_media := v_media || v_m;
  end loop;
  perform public.arrange_listing_media(v_listing, v_media, v_media[1]);
  perform public.submit_listing(v_listing, gen_random_uuid());
  perform pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
  v_ver := (public.admin_get_listing_review(v_listing) #>> '{version,id}')::uuid;
  v_hash := public.admin_get_listing_review(v_listing) #>> '{version,content_hash}';
  perform public.admin_approve_listing_version(v_listing, v_ver, v_hash);
end;
$$;

select pg_temp.publish('p1', 'ناقة مجاهيم للبيع');

-- محادثة: b يبدأ ويكتب، a يرد بعدة رسائل
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
insert into ids select 'c1', (public.start_conversation((select v from ids where k = 'p1')) ->> 'conversation_id')::uuid;
insert into ids select 'mb1', (public.send_message((select v from ids where k = 'c1'), 'مرحبا', gen_random_uuid()) ->> 'id')::uuid;
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
select public.send_message((select v from ids where k = 'c1'), 'رسالة أ1', gen_random_uuid());
select public.send_message((select v from ids where k = 'c1'), 'رسالة أ2', gen_random_uuid());
insert into ids select 'ma3', (public.send_message((select v from ids where k = 'c1'), 'رسالة مسيئة', gen_random_uuid()) ->> 'id')::uuid;
select public.send_message((select v from ids where k = 'c1'), 'رسالة أ4', gen_random_uuid());
select public.send_message((select v from ids where k = 'c1'), 'رسالة أ5', gen_random_uuid());
select public.send_message((select v from ids where k = 'c1'), 'رسالة أ6', gen_random_uuid());
select public.send_message((select v from ids where k = 'c1'), 'رسالة أ7', gen_random_uuid());
-- رد عام
select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
insert into ids select 'k1', (public.post_comment((select v from ids where k = 'p1'), 'رد مزعج', gen_random_uuid()) ->> 'id')::uuid;

select columns_are('public', 'reports', array[
  'id', 'ref', 'reporter_id', 'target_type', 'target_id', 'target_user_id', 'listing_id', 'reason',
  'description', 'request_id', 'status', 'assigned_to', 'close_reason', 'response_text', 'internal_note',
  'closed_by', 'closed_at', 'created_at', 'updated_at']);

-- الزائر
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok(
  $$select public.submit_report('LISTING', (select v from ids where k = 'p1'), 'SPAM', null, gen_random_uuid())$$,
  '42501', null, 'الزائر لا يبلغ');
reset role;

-- الإرسال
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select throws_ok($$select public.submit_report('X', (select v from ids where k = 'p1'), 'SPAM', null, gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', 'نوع هدف غير معروف');
select throws_ok($$select public.submit_report('LISTING', (select v from ids where k = 'p1'), 'X', null, gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', 'سبب غير معروف');
select throws_ok($$select public.submit_report('LISTING', (select v from ids where k = 'p1'), 'OTHER', '  ', gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', '«أخرى» تشترط وصفًا');
select throws_ok($$select public.submit_report('LISTING', (select v from ids where k = 'p1'), 'SPAM', repeat('أ', 2001), gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', 'وصف طويل');
select throws_ok($$select public.submit_report('LISTING', (select v from ids where k = 'p1'), 'SPAM', null, null)$$,
  'P0001', 'VALIDATION_FAILED', 'معرف الطلب إلزامي');
select throws_ok($$select public.submit_report('LISTING', '00000000-0000-0000-0000-000000000099', 'SPAM', null, gen_random_uuid())$$,
  'P0001', 'NOT_FOUND', 'هدف غير موجود');
select throws_ok($$select public.submit_report('ACCOUNT', auth.uid(), 'SPAM', null, gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', 'لا بلاغ عن النفس');
select throws_ok($$select public.submit_report('MESSAGE', (select v from ids where k = 'mb1'), 'ABUSE', null, gen_random_uuid())$$,
  'P0001', 'NOT_FOUND', 'لا بلاغ عن رسالة كتبها المبلغ');

insert into ids select 'r1', (public.submit_report('MESSAGE', (select v from ids where k = 'ma3'), 'ABUSE', 'ألفاظ مسيئة',
  'dddddddd-0000-0000-0000-000000000001') ->> 'report_id')::uuid;
select is(
  (public.submit_report('MESSAGE', (select v from ids where k = 'ma3'), 'ABUSE', 'ألفاظ مسيئة',
    'dddddddd-0000-0000-0000-000000000001') ->> 'report_id')::uuid,
  (select v from ids where k = 'r1'), 'إعادة الطلب تعيد البلاغ الأول');
select is(
  public.submit_report('MESSAGE', (select v from ids where k = 'ma3'), 'ABUSE', 'مرة أخرى', gen_random_uuid()) ->> 'duplicate',
  'true', 'بلاغ مفتوح للهدف نفسه لا يتكرر');
select matches(public.get_report_status((select v from ids where k = 'r1')) ->> 'ref', '^R-[0-9]+$', 'رقم مرجعي');
select is(public.get_report_status((select v from ids where k = 'r1')) ->> 'status', 'OPEN', 'حالة البلاغ للمبلغ');
select is(public.get_report_status((select v from ids where k = 'r1')) ? 'internal_note', false, 'لا ملاحظات داخلية');
select is((select count(*)::integer from public.reports), 0, 'المبلغ لا يقرأ جدول البلاغات');
reset role;

select is((select count(*)::integer from public.reports), 1, 'بلاغ واحد');

-- بلاغات على أنواع الهدف الأخرى
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
insert into ids select 'r2', (public.submit_report('COMMENT', (select v from ids where k = 'k1'), 'SPAM', null, gen_random_uuid()) ->> 'report_id')::uuid;
insert into ids select 'r3', (public.submit_report('LISTING', (select v from ids where k = 'p1'), 'MISLEADING', null, gen_random_uuid()) ->> 'report_id')::uuid;
insert into ids select 'r4', (public.submit_report('ACCOUNT', '00000000-0000-0000-0000-00000000000a', 'FRAUD', null, gen_random_uuid()) ->> 'report_id')::uuid;
reset role;
select is((select count(*)::integer from public.reports), 4, 'أربعة بلاغات');

-- الثالث لا يبلغ عن رسالة لا يقرؤها، ولا يقرأ بلاغات غيره
select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
set local role authenticated;
select throws_ok($$select public.submit_report('MESSAGE', (select v from ids where k = 'ma3'), 'ABUSE', null, gen_random_uuid())$$,
  'P0001', 'NOT_FOUND', 'لا بلاغ عن رسالة لا يملك قراءتها');
select throws_ok($$select public.get_report_status((select v from ids where k = 'r1'))$$,
  'P0001', 'NOT_FOUND', 'لا يرى حالة بلاغ غيره');
select throws_ok($$select public.admin_close_report((select v from ids where k = 'r1'), 'NO_VIOLATION')$$,
  'P0001', 'FORBIDDEN', 'المستخدم العادي لا يدير');
reset role;

-- المبلغ عنه لا يعرف بالبلاغ
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is((select count(*)::integer from public.reports), 0, 'المبلغ عنه لا يقرأ البلاغات');
select throws_ok($$select public.get_report_status((select v from ids where k = 'r1'))$$,
  'P0001', 'NOT_FOUND', 'ولا حالتها');
reset role;
select is((select count(*)::integer from public.notifications where recipient_id = '00000000-0000-0000-0000-00000000000a'
  and category = 'REPORTS'), 0, 'لا إشعار للمبلغ عنه');

-- حد البلاغات اليومي: 10 في 24 ساعة
select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
set local role authenticated;
select public.submit_report('ACCOUNT', '00000000-0000-0000-0000-00000000000a', 'SPAM', null, gen_random_uuid());
select is(public.submit_report('ACCOUNT', '00000000-0000-0000-0000-00000000000a', 'SPAM', null, gen_random_uuid()) ->> 'duplicate',
  'true', 'تكرار الهدف نفسه لا ينشئ بلاغًا');
reset role;
insert into public.reports (reporter_id, target_type, target_id, target_user_id, reason, request_id)
  select '00000000-0000-0000-0000-00000000000c', 'ACCOUNT', gen_random_uuid(),
    '00000000-0000-0000-0000-00000000000a', 'SPAM', gen_random_uuid()
  from generate_series(1, 9);
set local role authenticated;
select throws_ok(
  $$select public.submit_report('ACCOUNT', '00000000-0000-0000-0000-00000000000b', 'SPAM', null, gen_random_uuid())$$,
  'P0001', 'RATE_LIMITED', 'تجاوز 10 بلاغات في اليوم');
reset role;
-- بلاغات الاختبار الإضافية تحذف حتى لا تؤثر في عدّ الإدارة.
delete from public.reports where reporter_id = '00000000-0000-0000-0000-00000000000c';

-- الإدارة
select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal1');
set local role authenticated;
select is((select count(*)::integer from public.reports), 0, 'الموظف دون aal2 لا يقرأ');
select throws_ok($$select public.admin_assign_report((select v from ids where k = 'r1'))$$, 'P0001',
  'MFA_REQUIRED', 'الإدارة تشترط aal2');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal2');
set local role authenticated;
select is((select count(*)::integer from public.reports), 4, 'المشرف يقرأ البلاغات');
select is(public.admin_assign_report((select v from ids where k = 'r1')) ->> 'status', 'IN_REVIEW', 'إسناد لنفسه');
select is((select assigned_to from public.reports where id = (select v from ids where k = 'r1')),
  '00000000-0000-0000-0000-0000000000a2'::uuid, 'المسؤول');
select throws_ok(
  $$select public.admin_assign_report((select v from ids where k = 'r1'), '00000000-0000-0000-0000-00000000000b')$$,
  'P0001', 'VALIDATION_FAILED', 'لا إسناد لغير موظف');
select is(public.admin_set_report_status((select v from ids where k = 'r1'), 'OPEN', 'سأعود إليه') ->> 'status', 'OPEN',
  'إعادة للفتح');
select throws_ok($$select public.admin_set_report_status((select v from ids where k = 'r1'), 'CLOSED')$$, 'P0001',
  'VALIDATION_FAILED', 'الإغلاق بدالته');
select throws_ok($$select public.admin_close_report((select v from ids where k = 'r1'), null)$$, 'P0001',
  'REASON_REQUIRED', 'سبب الإغلاق إلزامي');
select throws_ok($$select public.admin_close_report((select v from ids where k = 'r1'), 'X')$$, 'P0001',
  'VALIDATION_FAILED', 'سبب إغلاق غير معروف');
select throws_ok($$select public.admin_get_report_evidence((select v from ids where k = 'r1'))$$, 'P0001',
  'FORBIDDEN', 'دون evidence.read لا أدلة');
reset role;

select is((select count(*)::integer from public.report_evidence_access), 0, 'لا اطلاع مسجل بعد الرفض');

-- الأدلة
select pg_temp.login('00000000-0000-0000-0000-0000000000a3', 'aal2');
set local role authenticated;
select is(jsonb_array_length(public.admin_get_report_evidence((select v from ids where k = 'r1')) -> 'items'), 7,
  'الرسالة المبلغ عنها مع ثلاث قبلها وثلاث بعدها');
select is(
  (select e ->> 'body' from jsonb_array_elements(
    public.admin_get_report_evidence((select v from ids where k = 'r1')) -> 'items') e
   where (e ->> 'is_reported')::boolean), 'رسالة مسيئة', 'الرسالة المبلغ عنها موسومة');
select is(
  (select count(*)::integer from jsonb_array_elements(
    public.admin_get_report_evidence((select v from ids where k = 'r1')) -> 'items') e
   where e ->> 'body' = 'رسالة أ7'), 0, 'السياق محدود: أبعد من ثلاث رسائل بعدها لا يظهر');
select is(
  (select e ->> 'body' from jsonb_array_elements(
    public.admin_get_report_evidence((select v from ids where k = 'r2')) -> 'items') e),
  'رد مزعج', 'دليل الرد');
select throws_ok($$select public.admin_get_report_evidence((select v from ids where k = 'r3'))$$, 'P0001',
  'INVALID_STATE', 'لا أدلة لبلاغ إعلان');
reset role;

select is((select count(*)::integer from public.report_evidence_access
  where actor_id = '00000000-0000-0000-0000-0000000000a3'), 4, 'كل اطلاع ناجح مسجل');
select is((select count(*)::integer from public.audit_log where action = 'report.evidence_read'), 4,
  'وفي سجل الإجراءات');

-- الإغلاق
select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal2');
set local role authenticated;
select is(
  public.admin_close_report((select v from ids where k = 'r1'), 'ACTION_TAKEN', 'شكرًا، اتخذنا الإجراء المناسب',
    'حظر مؤقت للمرسل') ->> 'status', 'CLOSED', 'إغلاق البلاغ');
select throws_ok($$select public.admin_close_report((select v from ids where k = 'r1'), 'NO_VIOLATION')$$, 'P0001',
  'INVALID_STATE', 'لا إغلاق ثانٍ');
select throws_ok($$select public.admin_assign_report((select v from ids where k = 'r1'))$$, 'P0001',
  'INVALID_STATE', 'لا إسناد لمغلق');
select is((select closed_by from public.reports where id = (select v from ids where k = 'r1')),
  '00000000-0000-0000-0000-0000000000a2'::uuid, 'الفاعل محفوظ');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is(public.get_report_status((select v from ids where k = 'r1')) ->> 'response_text', 'شكرًا، اتخذنا الإجراء المناسب',
  'المبلغ يرى الرد');
select is(public.get_report_status((select v from ids where k = 'r1')) ->> 'status', 'CLOSED', 'وحالة الإغلاق');
select is(public.get_report_status((select v from ids where k = 'r1')) ? 'internal_note', false,
  'دون الملاحظة الداخلية');
-- بعد الإغلاق يمكن بلاغ جديد عن الهدف نفسه
select is(public.submit_report('MESSAGE', (select v from ids where k = 'ma3'), 'ABUSE', 'تكرر الأمر', gen_random_uuid()) ->> 'created',
  'true', 'بلاغ جديد بعد الإغلاق');
reset role;

select is(
  (select count(*)::integer from public.notifications
   where recipient_id = '00000000-0000-0000-0000-00000000000b' and event = 'report.closed'), 1,
  'إشعار الإغلاق للمبلغ');
select is(
  (select payload ? 'internal_note' from public.notifications where event = 'report.closed'), false,
  'لا ملاحظة داخلية في الإشعار');
select is(
  (select count(*)::integer from public.audit_log where action in ('report.assigned', 'report.closed', 'report.status_changed')),
  3, 'قرارات البلاغات في سجل الإجراءات');

select * from finish();
rollback;
