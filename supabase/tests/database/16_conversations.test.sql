-- MOBILE-BE-301 — الترحيل 16 conversations
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

-- a معلن، b مشترٍ، c طرف ثالث، s مدير.
insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002'),
  ('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000003');
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test');
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

create function pg_temp.login(p_user uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated, anon;

create function pg_temp.publish(p_key text, p_title text, p_approve boolean) returns void language plpgsql as $$
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
  if not p_approve then return; end if;
  for i in 1..3 loop
    v_m := (public.add_listing_media(v_listing, 'IMAGE', 'image/jpeg', 1000) ->> 'media_id')::uuid;
    perform public.finalize_listing_media(v_m, 'image/jpeg', 1000, 800, 600);
    v_media := v_media || v_m;
  end loop;
  perform public.arrange_listing_media(v_listing, v_media, v_media[1]);
  perform public.submit_listing(v_listing, gen_random_uuid());
  perform pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
end;
$$;

select pg_temp.publish('p1', 'ناقة مجاهيم للبيع', true);
select pg_temp.publish('d1', 'مسودة لم ترسل بعد', false);

select columns_are('public', 'conversations', array[
  'id', 'listing_id', 'buyer_id', 'seller_id', 'last_message_at', 'buyer_read_at', 'seller_read_at',
  'buyer_muted', 'seller_muted', 'created_at']);
select columns_are('public', 'messages', array[
  'id', 'conversation_id', 'sender_id', 'body', 'request_id', 'created_at']);
select columns_are('public', 'my_conversations', array[
  'conversation_id', 'listing_id', 'my_role', 'other_user_id', 'other_display_name', 'listing_available',
  'listing_title', 'cover_bucket', 'cover_path', 'writable', 'muted', 'last_message_at',
  'last_message_body', 'last_message_sender_id', 'unread_count', 'created_at']);

-- الزائر
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok($$select public.start_conversation((select v from ids where k = 'p1'))$$, '42501', null,
  'الزائر لا يبدأ محادثة');
select throws_ok($$select count(*) from public.messages$$, '42501', null, 'الزائر لا يقرأ الرسائل');
reset role;

-- البدء
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select throws_ok($$select public.start_conversation((select v from ids where k = 'p1'))$$, 'P0001',
  'CANNOT_MESSAGE_SELF', 'لا محادثة مع النفس');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select throws_ok($$select public.start_conversation((select v from ids where k = 'd1'))$$, 'P0001', 'NOT_FOUND',
  'إعلان غير منشور');
select throws_ok($$select public.start_conversation('00000000-0000-0000-0000-000000000099')$$, 'P0001', 'NOT_FOUND',
  'إعلان غير موجود');
insert into ids select 'c1', (public.start_conversation((select v from ids where k = 'p1')) ->> 'conversation_id')::uuid;
select is(
  public.start_conversation((select v from ids where k = 'p1')) ->> 'created', 'false', 'إعادة البدء تعيد الموجودة');
select is(
  (public.start_conversation((select v from ids where k = 'p1')) ->> 'conversation_id')::uuid,
  (select v from ids where k = 'c1'), 'المحادثة نفسها');
select is((select count(*)::integer from public.conversations), 1, 'محادثة واحدة لكل إعلان وطرفين');

-- الإرسال
select throws_ok($$select public.send_message((select v from ids where k = 'c1'), '   ', gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', 'رسالة فارغة');
select throws_ok($$select public.send_message((select v from ids where k = 'c1'), repeat('أ', 2001), gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', 'رسالة أطول من الحد');
select throws_ok($$select public.send_message((select v from ids where k = 'c1'), 'مرحبا', null)$$,
  'P0001', 'VALIDATION_FAILED', 'معرف الطلب إلزامي');
insert into ids select 'm1',
  (public.send_message((select v from ids where k = 'c1'), '  السلام عليكم، هل الناقة متاحة؟ ',
    'bbbbbbbb-0000-0000-0000-000000000001') ->> 'id')::uuid;
select is(
  (public.send_message((select v from ids where k = 'c1'), 'نص مختلف لا يهم',
    'bbbbbbbb-0000-0000-0000-000000000001') ->> 'id')::uuid,
  (select v from ids where k = 'm1'), 'إعادة الطلب بالمعرف نفسه تعيد الرسالة الأولى');
select is((select count(*)::integer from public.messages), 1, 'لا تكرار');
select is((select body from public.messages), 'السلام عليكم، هل الناقة متاحة؟', 'النص يقص');
select public.send_message((select v from ids where k = 'c1'), 'وما سعرها النهائي؟', 'bbbbbbbb-0000-0000-0000-000000000002');
select is((select count(*)::integer from public.messages), 2, 'رسالتان');
select is((select unread_count from public.my_conversations), 0, 'المرسل لا يرى رسائله غير مقروءة');
reset role;

-- الطرف الثالث
select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
set local role authenticated;
select is((select count(*)::integer from public.conversations), 0, 'الثالث لا يقرأ المحادثة');
select is((select count(*)::integer from public.messages), 0, 'ولا الرسائل');
select is((select count(*)::integer from public.my_conversations), 0, 'ولا قائمتها');
select throws_ok($$select public.send_message((select v from ids where k = 'c1'), 'تطفل', gen_random_uuid())$$,
  'P0001', 'NOT_FOUND', 'الثالث لا يرسل');
select throws_ok($$select public.mark_conversation_read((select v from ids where k = 'c1'))$$,
  'P0001', 'NOT_FOUND', 'ولا يعلّم القراءة');
select throws_ok($$select public.set_conversation_muted((select v from ids where k = 'c1'), true)$$,
  'P0001', 'NOT_FOUND', 'ولا يكتم');
select throws_ok(
  $$insert into public.messages (conversation_id, sender_id, body, request_id)
    values ((select v from ids where k = 'c1'), auth.uid(), 'x', gen_random_uuid())$$,
  '42501', null, 'لا كتابة مباشرة');
reset role;

-- المعلن (الطرف الآخر)
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is((select count(*)::integer from public.messages), 2, 'المعلن يقرأ الرسالتين');
select is((select unread_count from public.my_conversations), 2, 'غير مقروءتين');
select is((select my_role from public.my_conversations), 'SELLER', 'دوره بائع');
select is((select other_display_name from public.my_conversations), 'مشتري الاختبار', 'اسم الطرف الآخر');
select is((select last_message_body from public.my_conversations), 'وما سعرها النهائي؟', 'آخر رسالة');
select is((select listing_title from public.my_conversations), 'ناقة مجاهيم للبيع', 'عنوان الإعلان المنشور');
select is((select writable from public.my_conversations), true, 'قابلة للكتابة');
reset role;

-- إشعار واحد لرسالتين غير مقروءتين، دون نص
select is(
  (select count(*)::integer from public.notifications
   where recipient_id = '00000000-0000-0000-0000-00000000000a' and event = 'message.received'),
  1, 'إشعار واحد لرسائل غير مقروءة');
select is(
  (select payload ? 'body' or payload::text like '%السلام%' from public.notifications
   where event = 'message.received'),
  false, 'لا نص رسالة في الإشعار');
select is(
  (select category::text || ':' || resource_type || ':' || (resource_id = (select v::text from ids where k = 'c1'))::text
   from public.notifications where event = 'message.received'),
  'MESSAGES:conversation:true', 'الإشعار يفتح المحادثة');

select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is(public.mark_conversation_read((select v from ids where k = 'c1')) ->> 'conversation_id',
  (select v::text from ids where k = 'c1'), 'تعليم القراءة');
select is((select unread_count from public.my_conversations), 0, 'بعد القراءة');
-- رد المعلن
select public.send_message((select v from ids where k = 'c1'), 'متاحة، تفضل بالاتصال', 'aaaaaaaa-0000-0000-0000-000000000001');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is((select unread_count from public.my_conversations), 1, 'المشتري يرى رد المعلن غير مقروء');
select public.mark_conversation_read((select v from ids where k = 'c1'));
reset role;

-- رسالة جديدة بعد القراءة: إشعار جديد للمعلن
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select public.send_message((select v from ids where k = 'c1'), 'شكرًا', 'bbbbbbbb-0000-0000-0000-000000000003');
reset role;
select is(
  (select count(*)::integer from public.notifications
   where recipient_id = '00000000-0000-0000-0000-00000000000a' and event = 'message.received'),
  2, 'إشعار جديد بعد القراءة');

-- الكتم: لا إشعار للمعلن
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select public.mark_conversation_read((select v from ids where k = 'c1'));
select is(public.set_conversation_muted((select v from ids where k = 'c1'), true) ->> 'muted', 'true', 'كتم المحادثة');
select is((select muted from public.my_conversations), true, 'الكتم يظهر في القائمة');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select public.send_message((select v from ids where k = 'c1'), 'هل ما زالت متاحة؟', 'bbbbbbbb-0000-0000-0000-000000000004');
select is((select muted from public.my_conversations), false, 'كتم الطرف الآخر مستقل');
reset role;
select is(
  (select count(*)::integer from public.notifications
   where recipient_id = '00000000-0000-0000-0000-00000000000a' and event = 'message.received'),
  2, 'المكتوم لا يولد إشعارًا');

-- حد المعدل: 20 رسالة في الدقيقة
create temp table rate_err (msg text);
grant all on rate_err to authenticated;
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
do $$
begin
  for i in 1..30 loop
    begin
      perform public.send_message(
        (select v from ids where k = 'c1'), 'رسالة ' || i, gen_random_uuid());
    exception when others then
      insert into rate_err values (sqlerrm);
      exit;
    end;
  end loop;
end;
$$;
reset role;
select is((select msg from rate_err), 'RATE_LIMITED', 'تجاوز 20 رسالة في الدقيقة');
select is(
  (select count(*)::integer from public.messages where sender_id = '00000000-0000-0000-0000-00000000000b'
    and created_at > now() - interval '1 minute'), 20, 'سقف الدقيقة 20 بالضبط');

-- القراءة فقط بعد إخفاء الإعلان
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
select public.admin_hide_listing((select v from ids where k = 'p1'), 'OTHER', 'اختبار');
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select throws_ok($$select public.send_message((select v from ids where k = 'c1'), 'بعد الإخفاء', gen_random_uuid())$$,
  'P0001', 'CONVERSATION_READ_ONLY', 'لا إرسال بعد الإخفاء');
select is((select writable from public.my_conversations), false, 'القائمة تعرض القراءة فقط');
select is((select listing_available from public.my_conversations), false, 'محتوى الإعلان المحجوب غير متاح');
select is(
  (select (listing_title, cover_path)::text from public.my_conversations), '(,)',
  'لا عنوان ولا غلاف للمحجوب');
select ok((select count(*) from public.messages) > 0, 'السجل يبقى مقروءًا');
select lives_ok($$select public.mark_conversation_read((select v from ids where k = 'c1'))$$,
  'تعليم القراءة يعمل في القراءة فقط');
select throws_ok($$select public.start_conversation((select v from ids where k = 'p1'))$$, 'P0001', 'NOT_FOUND',
  'لا بدء محادثة على مخفي');
reset role;

-- إعادة الإظهار تعيد الكتابة
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
select public.admin_unhide_listing((select v from ids where k = 'p1'), 'إعادة');
select is(private.conversation_writable((select v from ids where k = 'c1')), true, 'تعود قابلة للكتابة');

-- تعليق أحد الطرفين
select public.admin_suspend_account('00000000-0000-0000-0000-00000000000a', 'OTHER', 'اختبار');
select is(private.conversation_writable((select v from ids where k = 'c1')), false, 'تعليق البائع يجعلها قراءة فقط');
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select throws_ok($$select public.send_message((select v from ids where k = 'c1'), 'بعد التعليق', gen_random_uuid())$$,
  'P0001', 'CONVERSATION_READ_ONLY', 'المشتري لا يرسل لموقوف');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select throws_ok($$select public.send_message((select v from ids where k = 'c1'), 'من موقوف', gen_random_uuid())$$,
  'P0001', 'ACCOUNT_SUSPENDED', 'الموقوف لا يرسل');
reset role;

select * from finish();
rollback;
