-- MOBILE-BE-401 — الترحيل 21 ratings
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

-- a معلن، b مشترٍ تبادل معه، c مشترٍ فتح محادثة ولم يتبادل، d بلا محادثة،
-- s مدير، m مشرف بقدرة التقييمات.
insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002'),
  ('00000000-0000-0000-0000-00000000000c', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000003'),
  ('00000000-0000-0000-0000-00000000000d', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000004');
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test'),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mod@example.test');
update public.profiles set display_name = 'معلن الاختبار', region_id = 1 where id = '00000000-0000-0000-0000-00000000000a';
update public.profiles set display_name = 'مشتري أول', region_id = 1 where id = '00000000-0000-0000-0000-00000000000b';
update public.profiles set display_name = 'مشتري ثان', region_id = 1 where id = '00000000-0000-0000-0000-00000000000c';
update public.profiles set display_name = 'مشتري ثالث', region_id = 1 where id = '00000000-0000-0000-0000-00000000000d';
insert into public.policy_consents (user_id, document_id)
  select u.id, d.id from private.current_policy_documents() d,
    (values ('00000000-0000-0000-0000-00000000000a'::uuid), ('00000000-0000-0000-0000-00000000000b'::uuid),
            ('00000000-0000-0000-0000-00000000000c'::uuid), ('00000000-0000-0000-0000-00000000000d'::uuid)) u(id);
select private.bootstrap_first_admin('00000000-0000-0000-0000-0000000000a1');
insert into public.admin_roles (user_id, role, capabilities)
  values ('00000000-0000-0000-0000-0000000000a2', 'MODERATOR', array['ratings.moderate']);

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
end;
$$;

select pg_temp.publish('p1', 'ناقة مجاهيم للبيع');

-- محادثات: b تبادل، c كتب فقط، d لا محادثة
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
insert into ids select 'cb', (public.start_conversation((select v from ids where k = 'p1')) ->> 'conversation_id')::uuid;
select public.send_message((select v from ids where k = 'cb'), 'مرحبا', gen_random_uuid());
select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
insert into ids select 'cc', (public.start_conversation((select v from ids where k = 'p1')) ->> 'conversation_id')::uuid;
select public.send_message((select v from ids where k = 'cc'), 'هل متاحة؟', gen_random_uuid());

select columns_are('public', 'seller_ratings', array[
  'id', 'rater_id', 'seller_id', 'conversation_id', 'score', 'body', 'declaration_at', 'status', 'hidden_at',
  'hidden_by', 'hidden_reason_code', 'hidden_reason_text', 'request_id', 'edited_at', 'created_at', 'updated_at']);
select columns_are('public', 'public_ratings', array[
  'rating_id', 'seller_id', 'rater_id', 'rater_display_name', 'score', 'body', 'reply_body', 'reply_at',
  'edited_at', 'created_at']);
select columns_are('public', 'my_received_ratings', array[
  'rating_id', 'rater_id', 'rater_display_name', 'score', 'body', 'status', 'reply_body', 'appeal_id',
  'appeal_status', 'edited_at', 'created_at']);
select columns_are('public', 'public_profiles', array[
  'id', 'display_name', 'region_id', 'region_name_ar', 'joined_at', 'published_listings_count',
  'rating_avg', 'rating_count']);

-- الزائر
select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok(
  $$select public.submit_rating('00000000-0000-0000-0000-00000000000a', 5, 'ممتاز', true, gen_random_uuid())$$,
  '42501', null, 'الزائر لا يقيّم');
select is((select count(*)::integer from public.public_ratings), 0, 'لا تقييمات بعد');
reset role;

-- الأهلية
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is(public.get_rating_eligibility('00000000-0000-0000-0000-00000000000a') ->> 'reason', 'SELF', 'لا تقييم للنفس');
select throws_ok(
  $$select public.submit_rating('00000000-0000-0000-0000-00000000000a', 5, 'ممتاز', true, gen_random_uuid())$$,
  'P0001', 'RATING_NOT_ELIGIBLE', 'التقييم الذاتي مرفوض');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000d', 'aal1');
set local role authenticated;
select is(public.get_rating_eligibility('00000000-0000-0000-0000-00000000000a') ->> 'reason', 'NO_CONVERSATION',
  'بلا محادثة');
select throws_ok(
  $$select public.submit_rating('00000000-0000-0000-0000-00000000000a', 5, 'ممتاز', true, gen_random_uuid())$$,
  'P0001', 'RATING_NOT_ELIGIBLE', 'دون محادثة لا تقييم');
reset role;

select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
set local role authenticated;
select is(public.get_rating_eligibility('00000000-0000-0000-0000-00000000000a') ->> 'reason', 'NO_EXCHANGE',
  'محادثة دون رد المعلن');
select throws_ok(
  $$select public.submit_rating('00000000-0000-0000-0000-00000000000a', 5, 'ممتاز', true, gen_random_uuid())$$,
  'P0001', 'RATING_NOT_ELIGIBLE', 'محادثة من طرف واحد لا تكفي');
reset role;

-- المعلن يرد في محادثتي b وc
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
select public.send_message((select v from ids where k = 'cb'), 'أهلًا', gen_random_uuid());

select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is((public.get_rating_eligibility('00000000-0000-0000-0000-00000000000a') ->> 'eligible')::boolean, true,
  'بعد التبادل مؤهل');
select is(public.get_rating_eligibility('00000000-0000-0000-0000-00000000000a') ? 'conversation_id', false,
  'لا تسريب لمعرف المحادثة');
-- التحقق
select throws_ok(
  $$select public.submit_rating('00000000-0000-0000-0000-00000000000a', 0, 'x', true, gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', 'درجة صفر');
select throws_ok(
  $$select public.submit_rating('00000000-0000-0000-0000-00000000000a', 6, 'x', true, gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', 'درجة فوق الحد');
select throws_ok(
  $$select public.submit_rating('00000000-0000-0000-0000-00000000000a', 5, 'x', false, gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', 'الإقرار إلزامي');
select throws_ok(
  $$select public.submit_rating('00000000-0000-0000-0000-00000000000a', 5, repeat('أ', 1001), true, gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', 'نص أطول من الحد');
select throws_ok(
  $$select public.submit_rating('00000000-0000-0000-0000-00000000000a', 5, 'x', true, null)$$,
  'P0001', 'VALIDATION_FAILED', 'معرف الطلب إلزامي');
insert into ids select 'r1', (public.submit_rating('00000000-0000-0000-0000-00000000000a', 4, '  معاملة طيبة  ', true,
  'eeeeeeee-0000-0000-0000-000000000001') ->> 'rating_id')::uuid;
select is(
  (public.submit_rating('00000000-0000-0000-0000-00000000000a', 1, 'نص آخر', true,
    'eeeeeeee-0000-0000-0000-000000000001') ->> 'rating_id')::uuid,
  (select v from ids where k = 'r1'), 'إعادة الطلب تعيد التقييم الأول');
select throws_ok(
  $$select public.submit_rating('00000000-0000-0000-0000-00000000000a', 5, 'مرة أخرى', true, gen_random_uuid())$$,
  'P0001', 'RATING_EXISTS', 'لا تقييم مكرر للمعلن نفسه');
select is(public.get_rating_eligibility('00000000-0000-0000-0000-00000000000a') ->> 'reason', 'ALREADY_RATED',
  'بعد التقييم');
select is((select count(*)::integer from public.seller_ratings), 0, 'الجدول مغلق على غير الموظف');
reset role;

select is((select count(*)::integer from public.seller_ratings), 1, 'تقييم واحد');
select is((select count(*)::integer from public.notifications
  where recipient_id = '00000000-0000-0000-0000-00000000000a' and event = 'rating.received'), 1,
  'إشعار للمعلن');

-- القراءة العامة والمتوسط
select set_config('request.jwt.claims', '', true);
set local role anon;
select is((select body from public.public_ratings), 'معاملة طيبة', 'التقييم ظاهر والنص مقصوص');
select is((select rater_display_name from public.public_ratings), 'مشتري أول', 'اسم المقيّم');
select is((select rating_avg from public.public_profiles where id = '00000000-0000-0000-0000-00000000000a'), 4.00,
  'المتوسط');
select is((select rating_count from public.public_profiles where id = '00000000-0000-0000-0000-00000000000a'), 1,
  'العدد');
select is((select rating_count from public.public_profiles where id = '00000000-0000-0000-0000-00000000000b'), 0,
  'من لا تقييم له عدده صفر');
reset role;

-- المقيّم الثاني c (مؤهل بعد رد المعلن)
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
select public.send_message((select v from ids where k = 'cc'), 'نعم متاحة', gen_random_uuid());
select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
set local role authenticated;
insert into ids select 'r2', (public.submit_rating('00000000-0000-0000-0000-00000000000a', 2, null, true, gen_random_uuid())
  ->> 'rating_id')::uuid;
reset role;
set local role anon;
select is((select rating_avg from public.public_profiles where id = '00000000-0000-0000-0000-00000000000a'), 3.00,
  'متوسط تقييمين');
reset role;

-- التعديل وسجله
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select is(public.edit_rating((select v from ids where k = 'r1'), 4, 'معاملة طيبة') ->> 'edited_at', null,
  'تعديل بلا تغيير لا يعد تعديلًا');
select is(public.edit_rating((select v from ids where k = 'r1'), 5, 'ممتاز بعد التجربة') ->> 'score', '5', 'تعديل الدرجة');
select throws_ok($$select public.edit_rating((select v from ids where k = 'r1'), 9, 'x')$$, 'P0001',
  'VALIDATION_FAILED', 'تعديل بدرجة غير صالحة');
reset role;
select is((select count(*)::integer from public.seller_rating_history), 1, 'سجل التعديل');
select is((select score || ':' || body from public.seller_rating_history), '4:معاملة طيبة', 'الصيغة السابقة محفوظة');

select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
set local role authenticated;
select throws_ok($$select public.edit_rating((select v from ids where k = 'r1'), 1, 'تخريب')$$, 'P0001',
  'NOT_FOUND', 'لا يعدل تقييم غيره');
reset role;

-- رد المعلن
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select throws_ok($$select public.reply_to_rating((select v from ids where k = 'r1'), 'رد المقيّم')$$, 'P0001',
  'NOT_FOUND', 'غير المعلن لا يرد');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select throws_ok($$select public.reply_to_rating((select v from ids where k = 'r1'), '  ')$$, 'P0001',
  'VALIDATION_FAILED', 'رد فارغ');
select is(public.reply_to_rating((select v from ids where k = 'r1'), 'شكرًا لك') ->> 'replied', 'true', 'رد المعلن');
select lives_ok($$select public.reply_to_rating((select v from ids where k = 'r1'), 'شكرًا جزيلًا')$$, 'استبدال الرد');
reset role;
select is((select score from public.seller_ratings where id = (select v from ids where k = 'r1')), 5::smallint,
  'الرد لا يغير الدرجة');
select is((select count(*)::integer from public.notifications
  where recipient_id = '00000000-0000-0000-0000-00000000000b' and event = 'rating.replied'), 1,
  'إشعار واحد بالرد رغم الاستبدال');
set local role anon;
select is((select reply_body from public.public_ratings where rating_id = (select v from ids where k = 'r1')),
  'شكرًا جزيلًا', 'الرد في العرض العام');
reset role;

-- الاعتراض
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select throws_ok($$select public.appeal_rating((select v from ids where k = 'r2'), 'سبب')$$, 'P0001',
  'NOT_FOUND', 'غير صاحب التقييم لا يعترض');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select throws_ok($$select public.appeal_rating((select v from ids where k = 'r2'), '')$$, 'P0001',
  'VALIDATION_FAILED', 'اعتراض بلا سبب');
insert into ids select 'ap2', (public.appeal_rating((select v from ids where k = 'r2'), 'لم أتعامل مع هذا المستخدم') ->> 'appeal_id')::uuid;
select is(public.appeal_rating((select v from ids where k = 'r2'), 'سبب آخر') ->> 'created', 'false',
  'اعتراض واحد لكل تقييم');
select is((select appeal_status from public.my_received_ratings where rating_id = (select v from ids where k = 'r2')),
  'OPEN', 'يرى المعلن حالة اعتراضه');
reset role;
set local role anon;
select is((select count(*)::integer from public.public_ratings), 2, 'الاعتراض لا يخفي التقييم');
reset role;

-- الإدارة
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal2');
set local role authenticated;
select throws_ok($$select public.admin_hide_rating((select v from ids where k = 'r2'), 'SPAM')$$, 'P0001',
  'FORBIDDEN', 'المستخدم العادي لا يشرف');
reset role;
select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal1');
set local role authenticated;
select throws_ok($$select public.admin_hide_rating((select v from ids where k = 'r2'), 'SPAM')$$, 'P0001',
  'MFA_REQUIRED', 'الإشراف يشترط aal2');
reset role;

select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal2');
set local role authenticated;
select is((select count(*)::integer from public.seller_ratings), 2, 'المشرف يقرأ التقييمات');
select throws_ok($$select public.admin_hide_rating((select v from ids where k = 'r2'), null)$$, 'P0001',
  'REASON_REQUIRED', 'السبب إلزامي');
select throws_ok($$select public.admin_hide_rating((select v from ids where k = 'r2'), 'MISSING_INFO')$$, 'P0001',
  'VALIDATION_FAILED', 'سبب لا ينطبق على التقييمات');
select throws_ok($$select public.admin_decide_rating_appeal((select v from ids where k = 'ap2'), 'ACCEPTED')$$,
  'P0001', 'REASON_REQUIRED', 'قبول الاعتراض يشترط سببًا');
select throws_ok($$select public.admin_decide_rating_appeal((select v from ids where k = 'ap2'), 'MAYBE')$$,
  'P0001', 'VALIDATION_FAILED', 'قرار غير معروف');
select is(public.admin_decide_rating_appeal((select v from ids where k = 'ap2'), 'ACCEPTED', 'UNFAIR_RATING',
  'لا محادثة حقيقية') ->> 'status', 'ACCEPTED', 'قبول الاعتراض');
select throws_ok($$select public.admin_decide_rating_appeal((select v from ids where k = 'ap2'), 'REJECTED')$$,
  'P0001', 'INVALID_STATE', 'لا قرار ثانٍ');
reset role;

select is((select status from public.seller_ratings where id = (select v from ids where k = 'r2')), 'HIDDEN',
  'القبول يخفي التقييم');
set local role anon;
select is((select count(*)::integer from public.public_ratings), 1, 'المخفي خارج العرض العام');
select is((select rating_avg from public.public_profiles where id = '00000000-0000-0000-0000-00000000000a'), 5.00,
  'المتوسط من الظاهر فقط');
select is((select rating_count from public.public_profiles where id = '00000000-0000-0000-0000-00000000000a'), 1,
  'والعدد');
reset role;
select is((select count(*)::integer from public.notifications
  where recipient_id = '00000000-0000-0000-0000-00000000000a' and event = 'rating.appeal_decided'), 1,
  'إشعار قرار الاعتراض');
select is((select count(*)::integer from public.audit_log where action = 'rating.appeal_decided'), 1, 'سجل القرار');

select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select is((select status from public.my_received_ratings where rating_id = (select v from ids where k = 'r2')),
  'HIDDEN', 'المعلن يرى حالة المخفي');
select throws_ok($$select public.reply_to_rating((select v from ids where k = 'r2'), 'رد على مخفي')$$, 'P0001',
  'INVALID_STATE', 'لا رد على المخفي');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
set local role authenticated;
select throws_ok($$select public.edit_rating((select v from ids where k = 'r2'), 5, 'تعديل مخفي')$$, 'P0001',
  'INVALID_STATE', 'المقيّم لا يعدل المخفي');
reset role;

-- رفض اعتراض يبقي التقييم، وإخفاء مباشر وإعادة إظهار
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
insert into ids select 'ap1', (public.appeal_rating((select v from ids where k = 'r1'), 'لا أوافق') ->> 'appeal_id')::uuid;
reset role;
select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal2');
set local role authenticated;
select is(public.admin_decide_rating_appeal((select v from ids where k = 'ap1'), 'REJECTED', null, 'تقييم صحيح') ->> 'status',
  'REJECTED', 'رفض الاعتراض');
reset role;
select is((select status from public.seller_ratings where id = (select v from ids where k = 'r1')), 'VISIBLE',
  'الرفض يبقي التقييم ظاهرًا');

select pg_temp.login('00000000-0000-0000-0000-0000000000a2', 'aal2');
set local role authenticated;
select is(public.admin_hide_rating((select v from ids where k = 'r1'), 'SPAM') ->> 'status', 'HIDDEN', 'إخفاء مباشر');
select throws_ok($$select public.admin_hide_rating((select v from ids where k = 'r1'), 'SPAM')$$, 'P0001',
  'INVALID_STATE', 'إخفاء المخفي');
select is(public.admin_unhide_rating((select v from ids where k = 'r1'), 'خطأ') ->> 'status', 'VISIBLE', 'إعادة الإظهار');
select throws_ok($$select public.admin_unhide_rating((select v from ids where k = 'r1'))$$, 'P0001',
  'INVALID_STATE', 'إعادة إظهار الظاهر');
reset role;
select is((select count(*)::integer from public.audit_log where action in ('rating.hidden', 'rating.unhidden')), 2,
  'سجل الإخفاء وإعادته');

-- البلاغ عن تقييم
select pg_temp.login('00000000-0000-0000-0000-00000000000d', 'aal1');
set local role authenticated;
select is(public.submit_report('RATING', (select v from ids where k = 'r1'), 'ABUSE', null, gen_random_uuid()) ->> 'created',
  'true', 'بلاغ عن تقييم ظاهر');
select throws_ok(
  $$select public.submit_report('RATING', (select v from ids where k = 'r2'), 'ABUSE', null, gen_random_uuid())$$,
  'P0001', 'NOT_FOUND', 'لا بلاغ عن تقييم مخفي');
reset role;
select pg_temp.login('00000000-0000-0000-0000-00000000000b', 'aal1');
set local role authenticated;
select throws_ok(
  $$select public.submit_report('RATING', (select v from ids where k = 'r1'), 'ABUSE', null, gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', 'المقيّم لا يبلغ عن تقييمه');
reset role;

-- الحظر لا يلغي تقييمًا قائمًا، ويمنع الجديد
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select public.block_user('00000000-0000-0000-0000-00000000000b');
reset role;
select is((select count(*)::integer from public.seller_ratings where rater_id = '00000000-0000-0000-0000-00000000000b'),
  1, 'الحظر لا يلغي التقييم القائم');
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
select pg_temp.login('00000000-0000-0000-0000-00000000000c', 'aal1');
set local role authenticated;
select public.block_user('00000000-0000-0000-0000-00000000000a');
select is(public.get_rating_eligibility('00000000-0000-0000-0000-00000000000a') ->> 'reason', 'ALREADY_RATED',
  'الأسبقية لحالة التقييم القائم');
reset role;

select * from finish();
rollback;
