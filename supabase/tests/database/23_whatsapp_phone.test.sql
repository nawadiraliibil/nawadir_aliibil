-- MOBILE-BE-WA-20261123 — TEAM-DEC-012: رقم واتساب مستقل عن رقم الاتصال
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001');
insert into auth.users (id, instance_id, aud, role, email) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin@example.test');
update public.profiles set display_name = 'معلن الاختبار', region_id = 1
  where id = '00000000-0000-0000-0000-00000000000a';
insert into public.policy_consents (user_id, document_id)
  select '00000000-0000-0000-0000-00000000000a', d.id from private.current_policy_documents() d;
select private.bootstrap_first_admin('00000000-0000-0000-0000-0000000000a1');

create function pg_temp.login(p_user uuid, p_aal text) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)::text, true);
$$;

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated, anon;

-- مسودة مكتملة عدا الرقمين، ثم يضاف patch الرقمين. عند p_submit تصعد إلى المراجعة.
create function pg_temp.mk(p_key text, p_contact jsonb, p_submit boolean, p_approve boolean)
returns void language plpgsql as $$
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
    'title', 'ناقة مجاهيم للبيع', 'description', 'وصف كاف لاجتياز الحد الأدنى للطول المطلوب في الاختبار',
    'breed_id', (select id from public.breeds where not requires_note order by id limit 1),
    'sex', 'FEMALE', 'age_months', 48, 'region_id', 1,
    'city_id', (select id from public.cities where region_id = 1 order by id limit 1),
    'health_notes', 'لا توجد عيوب معروفة', 'owner_declaration', true,
    'offer_type', 'FIXED_PRICE', 'price', 25000) || p_contact);
  insert into ids values (p_key, v_listing);
  if not p_submit then return; end if;
  for i in 1..3 loop
    v_m := (public.add_listing_media(v_listing, 'IMAGE', 'image/jpeg', 1000) ->> 'media_id')::uuid;
    perform public.finalize_listing_media(v_m, 'image/jpeg', 1000, 800, 600);
    v_media := v_media || v_m;
  end loop;
  perform public.arrange_listing_media(v_listing, v_media, v_media[1]);
  perform public.submit_listing(v_listing, gen_random_uuid());
  if not p_approve then return; end if;
  perform pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
end;
$$;

-- رقمان مختلفان: يعتمد وينشر.
select pg_temp.mk('both', '{"contact_phone": "0500000009", "contact_whatsapp_phone": "055 111 2222"}', true, true);
-- واتساب فقط.
select pg_temp.mk('wa', '{"contact_whatsapp_phone": "0551112222"}', true, true);
-- اتصال فقط.
select pg_temp.mk('call', '{"contact_phone": "0500000009"}', true, true);
-- لا رقم: مسودة.
select pg_temp.mk('none', '{}', false, false);

select is((select contact_phone from public.listing_versions where listing_id = (select v from ids where k = 'both')),
  '+966500000009', 'رقم الاتصال محفوظ بالصيغة الدولية');
select is((select contact_whatsapp_phone from public.listing_versions where listing_id = (select v from ids where k = 'both')),
  '+966551112222', 'رقم واتساب مستقل ومحفوظ بالصيغة الدولية');
select is((select contact_call_enabled and contact_whatsapp_enabled from public.listing_versions
  where listing_id = (select v from ids where k = 'both')), true, 'العلامتان المشتقتان صحيحتان بوجود الرقمين');

-- العرض العام
select is((select contact_phone from public.public_listing_details where listing_id = (select v from ids where k = 'both')),
  '+966500000009', 'التفاصيل العامة: رقم الاتصال');
select is((select contact_whatsapp_phone from public.public_listing_details where listing_id = (select v from ids where k = 'both')),
  '+966551112222', 'التفاصيل العامة: رقم واتساب');
select is((select contact_phone from public.public_listing_details where listing_id = (select v from ids where k = 'wa')),
  null, 'واتساب فقط: لا رقم اتصال في العرض العام');
select is((select contact_whatsapp_phone from public.public_listing_details where listing_id = (select v from ids where k = 'wa')),
  '+966551112222', 'واتساب فقط: الرقم ظاهر');
select is((select contact_call_enabled::text || '/' || contact_whatsapp_enabled::text from public.public_listing_details
  where listing_id = (select v from ids where k = 'wa')), 'false/true', 'واتساب فقط: العلامتان المشتقتان');
select is((select contact_whatsapp_phone from public.public_listing_details where listing_id = (select v from ids where k = 'call')),
  null, 'اتصال فقط: لا رقم واتساب في العرض العام');
select is((select contact_call_enabled::text || '/' || contact_whatsapp_enabled::text from public.public_listing_details
  where listing_id = (select v from ids where k = 'call')), 'true/false', 'اتصال فقط: العلامتان المشتقتان');

-- get_listing يعرض الحقل (للزائر)
select set_config('request.jwt.claims', '', true);
set local role anon;
select is(public.get_listing((select v from ids where k = 'both')) #>> '{listing,contact_whatsapp_phone}',
  '+966551112222', 'get_listing يعرض رقم واتساب');
reset role;

-- المالك: الحقل ومنطق الإرسال
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'aal1');
set local role authenticated;
select throws_ok(
  $$select public.submit_listing((select v from ids where k = 'none'), gen_random_uuid())$$,
  'P0001', 'VALIDATION_FAILED', 'لا إرسال دون أي رقم');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'none'), '{"contact_whatsapp_phone": "12345"}')$$,
  'P0001', 'VALIDATION_FAILED', 'رقم واتساب بصيغة خاطئة مرفوض');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'none'), '{"contact_whatsapp_phone": 5}')$$,
  'P0001', 'VALIDATION_FAILED', 'رقم واتساب غير نصي مرفوض');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'none'), '{"contact_phone": "0612345678"}')$$,
  'P0001', 'VALIDATION_FAILED', 'رقم اتصال غير سعودي مرفوض');
select is((select contact_consent_at from public.listing_versions where listing_id = (select v from ids where k = 'none')),
  null, 'لا موافقة دون رقم');
select is(
  public.save_listing_draft((select v from ids where k = 'none'), '{"contact_whatsapp_phone": "0551112222"}')
    #>> '{version,contact_whatsapp_phone}',
  '+966551112222', 'مخرج المالك يحوي contact_whatsapp_phone');
select isnt((select contact_consent_at from public.listing_versions where listing_id = (select v from ids where k = 'none')),
  null, 'حفظ رقم واتساب وحده يسجل وقت الموافقة');
select is(
  public.save_listing_draft((select v from ids where k = 'none'), '{"contact_whatsapp_phone": null}')
    #>> '{version,contact_whatsapp_phone}',
  null, 'مسح رقم واتساب');
select is((select contact_consent_at from public.listing_versions where listing_id = (select v from ids where k = 'none')),
  null, 'مسح الرقمين يمسح الموافقة');

-- مفتاحا العلامتين القديمان: يقبلان ويحوّلان
select is(
  public.save_listing_draft((select v from ids where k = 'none'),
    '{"contact_phone": "0500000009", "contact_call_enabled": true, "contact_whatsapp_enabled": true}')
    #>> '{version,contact_whatsapp_phone}',
  '+966500000009', 'تحويل قديم: واتساب مفعل ينسخ رقم الاتصال');
select is(
  public.save_listing_draft((select v from ids where k = 'none'),
    '{"contact_call_enabled": false}') #>> '{version,contact_phone}',
  null, 'تحويل قديم: الاتصال معطل يفرغ رقم الاتصال');
select is((select contact_whatsapp_phone from public.listing_versions where listing_id = (select v from ids where k = 'none')),
  '+966500000009', 'رقم واتساب باق بعد تعطيل الاتصال');
select is(
  public.save_listing_draft((select v from ids where k = 'none'),
    '{"contact_phone": "0500000009", "contact_whatsapp_phone": "0551112222", "contact_whatsapp_enabled": false}')
    #>> '{version,contact_whatsapp_phone}',
  '+966551112222', 'الرقم الصريح يغلب مفتاح العلامة القديم');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'none'), '{"contact_call_enabled": "yes"}')$$,
  'P0001', 'VALIDATION_FAILED', 'علامة قديمة بنوع خاطئ مرفوضة');

-- نسخة التعديل تنسخ الرقمين
select is(
  public.start_listing_edit((select v from ids where k = 'both')) #>> '{version,contact_whatsapp_phone}',
  '+966551112222', 'نسخة التعديل تحمل رقم واتساب');
select is(
  public.start_listing_edit((select v from ids where k = 'both')) #>> '{version,contact_phone}',
  '+966500000009', 'نسخة التعديل تحمل رقم الاتصال');
reset role;

-- الإدارة: مراجعة تعرض الحقلين
select pg_temp.login('00000000-0000-0000-0000-0000000000a1', 'aal2');
set local role authenticated;
select is(public.admin_get_listing_review((select v from ids where k = 'wa')) #>> '{version,contact_whatsapp_phone}',
  '+966551112222', 'مراجعة الإدارة تعرض contact_whatsapp_phone');
select is(public.admin_get_listing_review((select v from ids where k = 'wa')) #>> '{version,contact_phone}',
  null, 'مراجعة الإدارة: لا رقم اتصال لواتساب فقط');
reset role;

-- القيد على الجدول مباشرة: نسخة مرسلة بلا رقم أو بلا موافقة ترفض
select throws_ok(
  $$update public.listing_versions set contact_phone = null, contact_whatsapp_phone = null
    where listing_id = (select v from ids where k = 'call') and status = 'APPROVED'$$,
  null, null, 'نسخة غير مسودة لا تقبل حذف الرقمين');

select * from finish();
rollback;
