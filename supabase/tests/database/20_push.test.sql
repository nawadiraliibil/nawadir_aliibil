-- MOBILE-BE-305 — الترحيل 20 push
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002');

create function pg_temp.login(p_user uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

select columns_are('public', 'notification_preferences', array['user_id', 'category', 'push_enabled', 'updated_at']);
select columns_are('public', 'device_tokens', array['id', 'user_id', 'token', 'platform', 'created_at', 'last_seen_at', 'disabled_at']);
select columns_are('public', 'my_notification_preferences', array['category', 'push_enabled']);

-- الزائر
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok($$select public.register_device_token(repeat('t', 30), 'ANDROID')$$, '42501', null, 'الزائر لا يسجل جهازًا');
select throws_ok($$select count(*) from public.my_notification_preferences$$, '42501', null, 'ولا يقرأ التفضيلات');
reset role;

-- التفضيلات
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is((select count(*)::integer from public.my_notification_preferences), 7, 'كل الفئات ظاهرة');
select is((select count(*)::integer from public.my_notification_preferences where push_enabled), 7, 'الافتراضي مفعل');
select throws_ok($$select public.set_notification_preference('X', false)$$, 'P0001', 'VALIDATION_FAILED', 'فئة غير معروفة');
select throws_ok($$select public.set_notification_preference('MESSAGES', null)$$, 'P0001', 'VALIDATION_FAILED', 'قيمة فارغة');
select is(public.set_notification_preference('MESSAGES', false) ->> 'push_enabled', 'false', 'إيقاف دفع فئة');
select is((select push_enabled from public.my_notification_preferences where category = 'MESSAGES'), false, 'يظهر في القائمة');
select is((select count(*)::integer from public.my_notification_preferences where push_enabled), 6, 'بقية الفئات كما هي');
select lives_ok($$select public.set_notification_preference('MESSAGES', false)$$, 'التكرار آمن');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is((select count(*)::integer from public.my_notification_preferences where push_enabled), 7,
  'تفضيلات غيره لا تؤثر');
reset role;

-- الأجهزة
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select throws_ok($$select public.register_device_token('قصير', 'ANDROID')$$, 'P0001', 'VALIDATION_FAILED', 'رمز قصير');
select throws_ok($$select public.register_device_token(repeat('t', 30), 'WEB')$$, 'P0001', 'VALIDATION_FAILED', 'منصة غير معروفة');
select is(public.register_device_token(repeat('t', 30), 'ANDROID') ->> 'registered', 'true', 'تسجيل جهاز');
select lives_ok($$select public.register_device_token(repeat('t', 30), 'ANDROID')$$, 'التكرار آمن');
select throws_ok($$select count(*) from public.device_tokens$$, '42501', null, 'الرموز لا تقرأ من العميل');
reset role;
select is((select count(*)::integer from public.device_tokens), 1, 'رمز واحد');

-- انتقال الجهاز لمستخدم آخر ينقل ملكيته
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select public.register_device_token(repeat('t', 30), 'ANDROID');
reset role;
select is((select user_id from public.device_tokens), '00000000-0000-0000-0000-00000000000a'::uuid, 'الجهاز انتقل');
select is((select count(*)::integer from public.device_tokens where user_id = '00000000-0000-0000-0000-00000000000b'), 0,
  'المستخدم السابق لا يصله شيء');

select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select public.register_device_token(repeat('b', 30), 'IOS');
reset role;

-- المرسل
select private.notify('00000000-0000-0000-0000-00000000000b', 'MESSAGES', 'message.received', 'conversation', 'c1',
  '{}'::jsonb, 'k-msg');
select private.notify('00000000-0000-0000-0000-00000000000b', 'FOLLOWS', 'follow.new_listing', 'listing', 'l1',
  '{"title": "عنوان خاص"}'::jsonb, 'k-follow');


set local role authenticated;
select throws_ok($$select public.claim_push_batch(10)$$, '42501', null, 'المستخدم لا يطالب بالدفعة');
select throws_ok($$select public.complete_push(1, 'SENT')$$, '42501', null, 'ولا يسجل النتائج');
reset role;
set local role anon;
select throws_ok($$select public.claim_push_batch(10)$$, '42501', null, 'الزائر لا يطالب بالدفعة');
reset role;

create temp table batch (j jsonb);
insert into batch select public.claim_push_batch(10);
select is(jsonb_array_length((select j from batch)), 1, 'مهمة واحدة: الفئة الموقوفة تُتخطى');
select is((select j -> 0 ->> 'event' from batch), 'follow.new_listing', 'إشعار المتابعة');
select is((select j -> 0 -> 'tokens' ->> 0 from batch), repeat('b', 30), 'رمز جهاز المستلم');
select is(
  (select j::text from batch) like '%عنوان خاص%', false,
  'لا محتوى خاص في المهمة');
select is(
  (select o.status from public.notification_outbox o join public.notifications n on n.id = o.notification_id
   where n.event = 'message.received'), 'SKIPPED', 'الفئة الموقوفة تُسجل متخطاة');
select is(
  (select last_error from public.notification_outbox o join public.notifications n on n.id = o.notification_id
   where n.event = 'message.received'), 'preference_off', 'وسبب التخطي');
select is((select count(*)::integer from public.notifications where event = 'message.received'), 1,
  'الإشعار يبقى في مركز الإشعارات رغم إيقاف الدفع');
select is(jsonb_array_length(public.claim_push_batch(10)), 0, 'المهمة المحجوزة لا تعطى لمطالب ثانٍ');

-- نتيجة الإرسال
select public.complete_push(
  (select (j -> 0 ->> 'outbox_id')::bigint from batch), 'FAILED', 'fcm 503');
select is((select o.status from public.notification_outbox o join public.notifications n on n.id = o.notification_id
  where n.event = 'follow.new_listing'), 'PENDING', 'الفشل الأول يبقى للمحاولة');
select ok((select o.next_attempt_at > now() from public.notification_outbox o join public.notifications n on n.id = o.notification_id
  where n.event = 'follow.new_listing'), 'وموعد المحاولة مؤجل');

-- بلوغ حد المحاولات
update public.notification_outbox set attempts = 5, next_attempt_at = now()
  where notification_id = (select id from public.notifications where event = 'follow.new_listing');
select public.complete_push(
  (select o.id from public.notification_outbox o join public.notifications n on n.id = o.notification_id
   where n.event = 'follow.new_listing'), 'FAILED', 'fcm 503');
select is((select o.status from public.notification_outbox o join public.notifications n on n.id = o.notification_id
  where n.event = 'follow.new_listing'), 'FAILED', 'بعد خمس محاولات يفشل نهائيًا');

-- الرمز غير الصالح يعطل، ونجاح الإرسال يسجل
select private.notify('00000000-0000-0000-0000-00000000000b', 'FOLLOWS', 'follow.new_listing', 'listing', 'l2',
  '{}'::jsonb, 'k-follow-2');
delete from batch;
insert into batch select public.claim_push_batch(10);
select is(jsonb_array_length((select j from batch)), 1, 'إشعار جديد يطالب به');
select public.complete_push((select (j -> 0 ->> 'outbox_id')::bigint from batch), 'SENT', null, array[repeat('b', 30)]);
select is((select o.status from public.notification_outbox o join public.notifications n on n.id = o.notification_id
  where n.resource_id = 'l2'), 'SENT', 'نجاح الإرسال');
select isnt((select disabled_at from public.device_tokens where token = repeat('b', 30)), null, 'الرمز غير الصالح عُطل');

-- بلا جهاز فعال: يتخطى
select private.notify('00000000-0000-0000-0000-00000000000b', 'FOLLOWS', 'follow.new_listing', 'listing', 'l3',
  '{}'::jsonb, 'k-follow-3');
select is(jsonb_array_length(public.claim_push_batch(10)), 0, 'لا جهاز فعال: لا مهمة');
select is((select o.last_error from public.notification_outbox o join public.notifications n on n.id = o.notification_id
  where n.resource_id = 'l3'), 'no_device', 'تخطي بسبب غياب الجهاز');

-- إلغاء التسجيل
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select public.register_device_token(repeat('c', 30), 'ANDROID');
select is(public.unregister_device_token(repeat('c', 30)) ->> 'unregistered', 'true', 'إلغاء التسجيل');
select is(public.unregister_device_token(repeat('c', 30)) ->> 'unregistered', 'false', 'الإلغاء المتكرر آمن');
select is(public.unregister_device_token(repeat('t', 30)) ->> 'unregistered', 'false', 'لا يلغي جهاز غيره');
reset role;
select private.notify('00000000-0000-0000-0000-00000000000b', 'FOLLOWS', 'follow.new_listing', 'listing', 'l4',
  '{}'::jsonb, 'k-follow-4');
select is(jsonb_array_length(public.claim_push_batch(10)), 0, 'بعد إلغاء التسجيل لا إرسال');

select * from finish();
rollback;
