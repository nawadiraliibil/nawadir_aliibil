-- MOBILE-BE-302 — الترحيل 17 blocks_comments
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

-- a معلن، b مشترٍ، c ثالث، s مدير، u مستخدم عادي ليس موظفًا هو b.
insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002'),
  ('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000003');
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mod@example.test');
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
-- مشرف بقدرة الردود فقط
insert into public.admin_roles (user_id, role, capabilities)
  values ('00000000-0000-0000-0000-0000000000a2', 'MODERATOR', array['comments.moderate']);

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

select columns_are('public', 'user_blocks', array['blocker_id', 'blocked_id', 'created_at']);
select columns_are('public', 'my_blocks', array['user_id', 'display_name', 'blocked_at']);
select columns_are('public', 'public_comments', array[
  'comment_id', 'listing_id', 'parent_id', 'author_id', 'author_display_name', 'is_owner', 'state',
  'body', 'edited_at', 'created_at']);

-- أسباب الإشراف على الردود
select is((select applies_to::text from public.moderation_reasons where code = 'SPAM'), '{COMMENT_HIDE,RATING_HIDE}',
  'سبب الرد المزعج');
select is((select 'COMMENT_HIDE' = any (applies_to) from public.moderation_reasons where code = 'OTHER'), true,
  '«أخرى» تنطبق على الردود');

-- ===================== الحظر =====================
-- محادثة بين b وa
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
insert into ids select 'c1', (public.start_conversation((select v from ids where k = 'p1')) ->> 'conversation_id')::uuid;
select public.send_message((select v from ids where k = 'c1'), 'مرحبا', gen_random_uuid());
select throws_ok($$select public.block_user(auth.uid())$$, 'P0001', 'VALIDATION_FAILED', 'لا حظر للنفس');
select throws_ok($$select public.block_user('00000000-0000-0000-0000-000000000099')$$, 'P0001', 'NOT_FOUND',
  'حظر غير موجود');
select is(public.block_user('00000000-0000-0000-0000-00000000000a') ->> 'blocked', 'true', 'حظر المعلن');
select is(public.block_user('00000000-0000-0000-0000-00000000000a') ->> 'blocked', 'true', 'التكرار آمن');
select is((select count(*)::integer from public.user_blocks), 1, 'صف واحد');
select is((select display_name from public.my_blocks), 'معلن الاختبار', 'قائمة المحظورين');
select throws_ok(
  $$insert into public.user_blocks (blocker_id, blocked_id) values (auth.uid(), '00000000-0000-0000-0000-00000000000c')$$,
  '42501', null, 'لا كتابة مباشرة');
select is((select writable from public.my_conversations), false, 'الحاظر: المحادثة قراءة فقط');
select throws_ok($$select public.send_message((select v from ids where k = 'c1'), 'بعد الحظر', gen_random_uuid())$$,
  'P0001', 'CONVERSATION_READ_ONLY', 'الحاظر لا يرسل');
select ok((select count(*) from public.messages) > 0, 'السجل يبقى');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is((select count(*)::integer from public.user_blocks), 0, 'المحظور لا يرى أنه محظور');
select is((select count(*)::integer from public.my_blocks), 0, 'ولا في القائمة');
select is((select writable from public.my_conversations), false, 'المحظور: قراءة فقط في الاتجاه الآخر');
select throws_ok($$select public.send_message((select v from ids where k = 'c1'), 'ردا على الحظر', gen_random_uuid())$$,
  'P0001', 'CONVERSATION_READ_ONLY', 'المحظور لا يرسل');
reset role;

-- الحظر يمنع الردود على إعلانات الطرف الآخر
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select throws_ok($$select public.post_comment((select v from ids where k = 'p1'), 'هل متاحة؟', gen_random_uuid())$$,
  'P0001', 'FORBIDDEN', 'الحاظر لا يرد على إعلان المحظور');
reset role;

-- فك الحظر
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is(public.unblock_user('00000000-0000-0000-0000-00000000000a') ->> 'blocked', 'false', 'فك الحظر');
select lives_ok($$select public.unblock_user('00000000-0000-0000-0000-00000000000a')$$, 'فك الحظر المتكرر آمن');
select is((select writable from public.my_conversations), true, 'تعود قابلة للكتابة');
select lives_ok($$select public.send_message((select v from ids where k = 'c1'), 'بعد فك الحظر', gen_random_uuid())$$,
  'الإرسال بعد فك الحظر');
reset role;

-- ===================== الردود =====================
select set_config('request.jwt.claims', '', true);
set local role anon;
select is((select count(*)::integer from public.public_comments), 0, 'لا ردود بعد');
select throws_ok($$select public.post_comment((select v from ids where k = 'p1'), 'رد', gen_random_uuid())$$,
  '42501', null, 'الزائر لا يرد');
select throws_ok($$select count(*) from public.comments$$, '42501', null, 'الجدول مغلق');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select throws_ok($$select public.post_comment((select v from ids where k = 'p1'), 'رد على إعلاني', gen_random_uuid())$$,
  'P0001', 'FORBIDDEN', 'المعلن لا يبدأ ردًا على إعلانه');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select throws_ok($$select public.post_comment((select v from ids where k = 'p1'), '  ', gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', 'رد فارغ');
select throws_ok($$select public.post_comment((select v from ids where k = 'p1'), repeat('أ', 1001), gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', 'رد أطول من الحد');
select throws_ok($$select public.post_comment((select v from ids where k = 'p1'), 'نص', null)$$,
  'P0001', 'VALIDATION_FAILED', 'معرف الطلب إلزامي');
select throws_ok($$select public.post_comment('00000000-0000-0000-0000-000000000099', 'نص', gen_random_uuid())$$,
  'P0001', 'NOT_FOUND', 'إعلان غير موجود');
insert into ids select 'k1', (public.post_comment((select v from ids where k = 'p1'), ' هل الناقة ما زالت متاحة؟ ',
  'cccccccc-0000-0000-0000-000000000001') ->> 'id')::uuid;
select is(
  (public.post_comment((select v from ids where k = 'p1'), 'نص آخر', 'cccccccc-0000-0000-0000-000000000001') ->> 'id')::uuid,
  (select v from ids where k = 'k1'), 'إعادة الطلب بالمعرف نفسه تعيد الرد الأول');
select is((select body from public.public_comments where comment_id = (select v from ids where k = 'k1')),
  'هل الناقة ما زالت متاحة؟', 'النص يقص');
reset role;

select is((select count(*)::integer from public.comments), 1, 'لا تكرار');

-- الغريب لا يرد كمعلن
select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
set local role authenticated;
select throws_ok(
  $$select public.post_comment((select v from ids where k = 'p1'), 'رد غير مخول', gen_random_uuid(), (select v from ids where k = 'k1'))$$,
  'P0001', 'FORBIDDEN', 'غير المعلن لا يرد على رد');
select throws_ok($$select public.edit_comment((select v from ids where k = 'k1'), 'تحرير غيري')$$,
  'P0001', 'NOT_FOUND', 'لا يحرر نص غيره');
select throws_ok($$select public.delete_comment((select v from ids where k = 'k1'))$$,
  'P0001', 'NOT_FOUND', 'ولا يحذفه');
reset role;

-- رد المعلن
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
insert into ids select 'k2', (public.post_comment((select v from ids where k = 'p1'), 'نعم متاحة',
  gen_random_uuid(), (select v from ids where k = 'k1')) ->> 'id')::uuid;
select is((select is_owner from public.public_comments where comment_id = (select v from ids where k = 'k2')),
  true, 'رد المعلن موسوم');
select throws_ok(
  $$select public.post_comment((select v from ids where k = 'p1'), 'رد على الرد', gen_random_uuid(), (select v from ids where k = 'k2'))$$,
  'P0001', 'NOT_FOUND', 'مستوى واحد من الردود');
reset role;

-- إشعارات بلا نص
select is(
  (select count(*)::integer from public.notifications
   where recipient_id = '00000000-0000-0000-0000-00000000000a' and event = 'comment.created'), 1,
  'إشعار للمعلن بالرد الجديد');
select is(
  (select count(*)::integer from public.notifications
   where recipient_id = '00000000-0000-0000-0000-00000000000b' and event = 'comment.replied'), 1,
  'إشعار لكاتب الرد برد المعلن');
select is(
  (select count(*)::integer from public.notifications
   where event in ('comment.created', 'comment.replied')
     and (payload::text like '%متاحة%' or payload ? 'body')), 0,
  'لا نص في إشعارات الردود');

-- تحرير وحذف الكاتب
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is(public.edit_comment((select v from ids where k = 'k1'), 'هل ما زالت متاحة اليوم؟') ->> 'body',
  'هل ما زالت متاحة اليوم؟', 'تحرير الكاتب');
select isnt((select edited_at from public.public_comments where comment_id = (select v from ids where k = 'k1')),
  null, 'علامة التحرير');
select throws_ok($$select public.edit_comment((select v from ids where k = 'k1'), '')$$, 'P0001',
  'VALIDATION_FAILED', 'تحرير بنص فارغ');
reset role;

-- إغلاق الردود
select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
set local role authenticated;
select throws_ok($$select public.set_comments_closed((select v from ids where k = 'p1'), true)$$, 'P0001',
  'NOT_FOUND', 'غير المعلن لا يغلق');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is(public.set_comments_closed((select v from ids where k = 'p1'), true) ->> 'comments_closed', 'true',
  'المعلن يغلق الردود');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
set local role authenticated;
select throws_ok($$select public.post_comment((select v from ids where k = 'p1'), 'بعد الإغلاق', gen_random_uuid())$$,
  'P0001', 'COMMENTS_CLOSED', 'لا ردود جديدة بعد الإغلاق');
select is((select comments_closed from public.public_listing_details), true, 'الحالة في التفاصيل العامة');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select lives_ok(
  $$select public.post_comment((select v from ids where k = 'p1'), 'رد المعلن يعمل بعد الإغلاق', gen_random_uuid(), (select v from ids where k = 'k1'))$$,
  'رد المعلن لا يمنعه الإغلاق');
select is((select count(*)::integer from public.public_comments), 3, 'ما نُشر يبقى بعد الإغلاق');
select public.set_comments_closed((select v from ids where k = 'p1'), false);
reset role;

-- حد المعدل: 5 ردود في الدقيقة
select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
create temp table rate_err (msg text);
grant all on rate_err to authenticated;
set local role authenticated;
do $$
begin
  for i in 1..8 loop
    begin
      perform public.post_comment((select v from ids where k = 'p1'), 'رد ' || i, gen_random_uuid());
    exception when others then
      insert into rate_err values (sqlerrm);
      exit;
    end;
  end loop;
end;
$$;
reset role;
select is((select msg from rate_err), 'RATE_LIMITED', 'تجاوز 5 ردود في الدقيقة');
select is((select count(*)::integer from public.comments where author_id = '00000000-0000-0000-0000-00000000000c'),
  5, 'السقف 5 بالضبط');

-- الإشراف
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal2');
set local role authenticated;
select throws_ok($$select public.admin_hide_comment((select v from ids where k = 'k1'), 'SPAM')$$, 'P0001',
  'FORBIDDEN', 'المستخدم العادي لا يشرف');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal1');
set local role authenticated;
select throws_ok($$select public.admin_hide_comment((select v from ids where k = 'k1'), 'SPAM')$$, 'P0001',
  'MFA_REQUIRED', 'الإشراف يشترط aal2');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal2');
set local role authenticated;
select throws_ok($$select public.admin_hide_comment((select v from ids where k = 'k1'), null)$$, 'P0001',
  'REASON_REQUIRED', 'السبب إلزامي');
select throws_ok($$select public.admin_hide_comment((select v from ids where k = 'k1'), 'OTHER')$$, 'P0001',
  'REASON_REQUIRED', '«أخرى» تشترط نصًا');
select throws_ok($$select public.admin_hide_comment((select v from ids where k = 'k1'), 'MISSING_INFO')$$, 'P0001',
  'VALIDATION_FAILED', 'سبب لا ينطبق على الردود');
select throws_ok($$select public.admin_hide_comment('00000000-0000-0000-0000-000000000099', 'SPAM')$$, 'P0001',
  'NOT_FOUND', 'رد غير موجود');
select is(public.admin_hide_comment((select v from ids where k = 'k1'), 'SPAM') ->> 'state', 'HIDDEN', 'إخفاء الرد');
select throws_ok($$select public.admin_hide_comment((select v from ids where k = 'k1'), 'SPAM')$$, 'P0001',
  'INVALID_STATE', 'إخفاء المخفي');
reset role;

set local role anon;
select is(
  (select state || ':' || coalesce(body, 'null') from public.public_comments where comment_id = (select v from ids where k = 'k1')),
  'HIDDEN:null', 'المخفي بلا نص للعامة');
select is((select count(*)::integer from public.public_comments where parent_id = (select v from ids where k = 'k1')),
  2, 'ردود المعلن عليه تبقى');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select throws_ok($$select public.edit_comment((select v from ids where k = 'k1'), 'محاولة تعديل مخفي')$$, 'P0001',
  'INVALID_STATE', 'الكاتب لا يحرر المخفي');
reset role;

select is((select count(*)::integer from public.audit_log where action = 'comment.hidden'
  and reason_code = 'SPAM' and resource_id = (select v::text from ids where k = 'k1')), 1, 'سجل الإجراء');

select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal2');
set local role authenticated;
select is(public.admin_unhide_comment((select v from ids where k = 'k1'), 'خطأ في التقدير') ->> 'state', 'VISIBLE',
  'إعادة الإظهار');
select throws_ok($$select public.admin_unhide_comment((select v from ids where k = 'k1'))$$, 'P0001',
  'INVALID_STATE', 'إعادة إظهار المرئي');
reset role;

-- حذف الكاتب
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is(public.delete_comment((select v from ids where k = 'k1')) ->> 'deleted', 'true', 'حذف الكاتب');
select lives_ok($$select public.delete_comment((select v from ids where k = 'k1'))$$, 'الحذف المتكرر آمن');
select throws_ok($$select public.edit_comment((select v from ids where k = 'k1'), 'بعد الحذف')$$, 'P0001',
  'INVALID_STATE', 'لا تحرير بعد الحذف');
reset role;
set local role anon;
select is(
  (select state || ':' || coalesce(body, 'null') from public.public_comments where comment_id = (select v from ids where k = 'k1')),
  'DELETED:null', 'المحذوف بلا نص');
reset role;

-- إخفاء الإعلان يخفي ردوده
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
select public.admin_hide_listing((select v from ids where k = 'p1'), 'OTHER', 'اختبار');
set local role anon;
select is((select count(*)::integer from public.public_comments), 0, 'ردود المخفي تختفي');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select throws_ok($$select public.post_comment((select v from ids where k = 'p1'), 'رد جديد', gen_random_uuid())$$,
  'P0001', 'NOT_FOUND', 'لا رد على مخفي');
reset role;

select * from finish();
rollback;
