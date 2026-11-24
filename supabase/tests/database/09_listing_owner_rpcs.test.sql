-- MOBILE-BE-106 — الترحيل 09 listing_owner_rpcs
begin;

create extension if not exists pgtap with schema extensions;

select no_plan();

insert into auth.users (id, instance_id, aud, role, phone) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000001'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '966500000002');

-- المستخدم أ: ملف مكتمل وموافقة. المستخدم ب: ملف ناقص.
update public.profiles set display_name = 'معلن الاختبار', region_id = 1
  where id = '00000000-0000-0000-0000-00000000000a';
insert into public.policy_consents (user_id, document_id)
  select '00000000-0000-0000-0000-00000000000a', d.id from private.current_policy_documents() d;

create function pg_temp.login(p_user uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal1')::text, true);
$$;

create temp table ids (k text primary key, v uuid);
grant all on ids to authenticated, anon;
create temp table lk as
select
  (select id from public.cities where region_id = 1 order by id limit 1) as city_r1,
  (select id from public.cities where region_id = 2 order by id limit 1) as city_r2,
  (select id from public.breeds where not requires_note order by id limit 1) as breed,
  (select id from public.breeds where requires_note order by id limit 1) as breed_other;
grant select on lk to authenticated, anon;

------------------------------------------------------------------------------
-- المسودة
------------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-00000000000a');
set local role authenticated;

insert into ids select 'l1', (public.create_listing_draft('aaaaaaaa-0000-0000-0000-000000000001') #>> '{listing,id}')::uuid;
select is(
  (public.create_listing_draft('aaaaaaaa-0000-0000-0000-000000000001') #>> '{listing,id}')::uuid,
  (select v from ids where k = 'l1'), 'إعادة طلب الإنشاء تعيد المسودة نفسها');
select is((select count(*)::integer from public.listings), 1, 'طلب مكرر لا ينشئ إعلانًا ثانيًا');
select is((select status::text from public.listings), 'DRAFT', 'الإعلان الجديد مسودة');

select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'l1'), '{"unknown": 1}')$$,
  'P0001', 'VALIDATION_FAILED', 'حقل غير معروف مرفوض');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'l1'),
      jsonb_build_object('region_id', 1, 'city_id', (select city_r2 from lk)))$$,
  'P0001', 'VALIDATION_FAILED', 'مدينة لا تتبع المنطقة مرفوضة');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'l1'), '{"offer_type": "FIXED_PRICE", "price": 10.123}')$$,
  'P0001', 'VALIDATION_FAILED', 'سعر بأكثر من منزلتين مرفوض');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'l1'), '{"offer_type": "FIXED_PRICE", "price": "100"}')$$,
  'P0001', 'VALIDATION_FAILED', 'سعر نصي مرفوض');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'l1'), '{"offer_type": "FIXED_PRICE", "price": 0}')$$,
  'P0001', 'VALIDATION_FAILED', 'سعر غير موجب مرفوض');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'l1'), '{"contact_phone": "12345"}')$$,
  'P0001', 'VALIDATION_FAILED', 'رقم تواصل غير صالح مرفوض');

select is(
  public.save_listing_draft((select v from ids where k = 'l1'),
    jsonb_build_object(
      'title', '  ناقة   مجاهيم للبيع  ',
      'description', 'وصف كاف لاجتياز الحد الأدنى للطول المطلوب',
      'breed_id', (select breed from lk), 'sex', 'FEMALE', 'age_months', 48,
      'region_id', 1, 'city_id', (select city_r1 from lk),
      'health_notes', 'لا توجد عيوب معروفة', 'owner_declaration', true,
      'offer_type', 'FIXED_PRICE', 'price', 25000.5,
      'contact_phone', '050 000 0009', 'contact_call_enabled', true)) #>> '{version,title}',
  'ناقة مجاهيم للبيع', 'الحفظ يوحد فراغات العنوان');
select is((select contact_phone from public.listing_versions), '+966500000009', 'رقم التواصل يحفظ بالصيغة الدولية');
select isnt((select contact_consent_at from public.listing_versions), null, 'وقت الموافقة على نشر الرقم يحفظه الخادم');
select isnt((select owner_declaration_at from public.listing_versions), null, 'وقت الإقرار يحفظه الخادم');

-- تغيير المنطقة يمسح المدينة
select is(
  public.save_listing_draft((select v from ids where k = 'l1'), '{"region_id": 2}') #>> '{version,city_id}',
  null, 'تغيير المنطقة يمسح المدينة');
select lives_ok(
  $$select public.save_listing_draft((select v from ids where k = 'l1'),
      jsonb_build_object('region_id', 1, 'city_id', (select city_r1 from lk)))$$,
  'إعادة المنطقة والمدينة');

-- تبديل النوع يمسح الحقول غير المنطبقة
select is(
  public.save_listing_draft((select v from ids where k = 'l1'),
    jsonb_build_object('offer_type', 'IN_PERSON_AUCTION', 'auction_region_id', 1,
      'auction_city_id', (select city_r1 from lk), 'auction_venue', 'سوق الإبل',
      'auction_starts_at', '2099-01-01T16:00:00+03:00')) #>> '{version,price}',
  null, 'التبديل إلى مزاد يمسح السعر');
select is((select auction_starts_at from public.listing_versions),
  '2099-01-01T13:00:00Z'::timestamptz, 'موعد المزاد يحفظ UTC');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'l1'), '{"price": 100}')$$,
  'P0001', 'VALIDATION_FAILED', 'لا سعر مع المزاد');
select is(
  public.save_listing_draft((select v from ids where k = 'l1'),
    '{"offer_type": "FIXED_PRICE", "price": 25000.5}') #>> '{version,auction_venue}',
  null, 'التبديل إلى سعر محدد يمسح حقول المزاد');

-- توضيح السلالة
select is(
  public.save_listing_draft((select v from ids where k = 'l1'), '{"breed_note": "توضيح"}') #>> '{version,breed_note}',
  null, 'توضيح السلالة يهمل لسلالة لا تستلزمه');

------------------------------------------------------------------------------
-- الوسائط والإرسال
------------------------------------------------------------------------------
select throws_ok(
  $$select public.submit_listing((select v from ids where k = 'l1'), 'bbbbbbbb-0000-0000-0000-000000000001')$$,
  'P0001', 'VALIDATION_FAILED', 'لا إرسال دون صور وغلاف');
select throws_ok(
  $$select public.add_listing_media((select v from ids where k = 'l1'), 'IMAGE', 'image/gif', 1000)$$,
  'P0001', 'VALIDATION_FAILED', 'صيغة صورة غير مدعومة');
select throws_ok(
  $$select public.add_listing_media((select v from ids where k = 'l1'), 'IMAGE', 'image/jpeg', 99999999)$$,
  'P0001', 'VALIDATION_FAILED', 'صورة تتجاوز الحجم');
select throws_ok(
  $$select public.add_listing_media((select v from ids where k = 'l1'), 'VIDEO', 'video/mp4', 1000)$$,
  'P0001', 'VIDEO_DISABLED', 'الفيديو معطل في الإعدادات');

insert into ids select 'm1', (public.add_listing_media((select v from ids where k = 'l1'), 'IMAGE', 'image/jpeg', 1000) ->> 'media_id')::uuid;
insert into ids select 'm2', (public.add_listing_media((select v from ids where k = 'l1'), 'IMAGE', 'image/png', 2000) ->> 'media_id')::uuid;
insert into ids select 'm3', (public.add_listing_media((select v from ids where k = 'l1'), 'IMAGE', 'image/jpeg', 3000) ->> 'media_id')::uuid;
select is(
  (select object_path from public.media where id = (select v from ids where k = 'm1')),
  '00000000-0000-0000-0000-00000000000a/' || (select v from ids where k = 'l1') || '/' || (select v from ids where k = 'm1') || '.jpg',
  'مسار الملف: المالك/الإعلان/الوسيط');

select throws_ok(
  $$select public.submit_listing((select v from ids where k = 'l1'), 'bbbbbbbb-0000-0000-0000-000000000001')$$,
  'P0001', 'MEDIA_NOT_READY', 'لا إرسال قبل جاهزية الوسائط');
select throws_ok(
  $$select public.finalize_listing_media((select v from ids where k = 'm1'), 'image/jpeg', 1000)$$,
  '42501', null, 'العميل لا يثبت نتيجة فحص الوسائط');
reset role;

-- الخادم يثبت نتيجة الفحص
select is(
  public.finalize_listing_media((select v from ids where k = 'm1'), 'image/jpeg', 1000, 800, 600) ->> 'status',
  'READY', 'وسيط صالح يصير جاهزًا');
select is(
  public.finalize_listing_media((select v from ids where k = 'm2'), 'image/gif', 2000) ->> 'status',
  'FAILED', 'نوع فعلي غير مدعوم يفشل');
select is(
  public.finalize_listing_media((select v from ids where k = 'm3'), 'image/jpeg', 3000, 800, 600) ->> 'status',
  'READY', 'وسيط ثالث جاهز');

set local role authenticated;
select is(
  (public.remove_listing_media((select v from ids where k = 'm2')) ->> 'delete_object')::boolean,
  true, 'حذف وسيط فاشل ويطلب حذف ملفه');
insert into ids select 'm4', (public.add_listing_media((select v from ids where k = 'l1'), 'IMAGE', 'image/png', 2000) ->> 'media_id')::uuid;
reset role;
select lives_ok(
  $$select public.finalize_listing_media((select v from ids where k = 'm4'), 'image/png', 2000, 800, 600)$$,
  'وسيط بديل جاهز');

set local role authenticated;
select throws_ok(
  $$select public.arrange_listing_media((select v from ids where k = 'l1'),
      array[(select v from ids where k = 'm1'), (select v from ids where k = 'm3')],
      (select v from ids where k = 'm1'))$$,
  'P0001', 'VALIDATION_FAILED', 'الترتيب يضم كل وسائط المسودة');
select is(
  public.arrange_listing_media((select v from ids where k = 'l1'),
    array[(select v from ids where k = 'm4'), (select v from ids where k = 'm1'), (select v from ids where k = 'm3')],
    (select v from ids where k = 'm4')) #>> '{media,0,id}',
  (select v::text from ids where k = 'm4'), 'الترتيب الجديد يطبق');
select is((select count(*)::integer from public.media where is_cover), 1, 'غلاف واحد بعد الترتيب');
reset role;

-- حد الإعلانات الجديدة: خمسة خلال 24 ساعة
insert into public.listings (owner_id, create_request_id, first_submitted_at)
  select '00000000-0000-0000-0000-00000000000a', gen_random_uuid(), now() - interval '1 hour'
  from generate_series(1, 5);
set local role authenticated;
select throws_ok(
  $$select public.submit_listing((select v from ids where k = 'l1'), 'bbbbbbbb-0000-0000-0000-000000000001')$$,
  'P0001', 'RATE_LIMITED', 'حد الإعلانات الجديدة خلال 24 ساعة');
reset role;
delete from public.listings where id <> (select v from ids where k = 'l1');

set local role authenticated;
select is(
  public.submit_listing((select v from ids where k = 'l1'), 'bbbbbbbb-0000-0000-0000-000000000001') #>> '{listing,status}',
  'PUBLISHED', 'الإرسال ينشر الإعلان مباشرة');
select is((select status::text from public.listing_versions), 'APPROVED', 'النسخة المرسلة تصير معتمدة تلقائيًا');
select ok((select l.published_version_id = l.current_version_id and l.first_published_at is not null
    and l.first_submitted_at is not null and l.last_published_at is not null
    and l.visibility_updated_at is not null from public.listings l),
  'مؤشرات النشر تضبط عند أول نشر');
select ok((select content_hash ~ '^[0-9a-f]{64}$' and settings_version = 1 from public.listing_versions),
  'البصمة وإصدار الإعدادات يحفظان عند الإرسال');
select lives_ok(
  $$select public.submit_listing((select v from ids where k = 'l1'), 'bbbbbbbb-0000-0000-0000-000000000001')$$,
  'إعادة طلب الإرسال لا تفشل');
select is((select count(*)::integer from public.listing_versions), 1, 'إرسال مكرر لا ينشئ نسخة');
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'l1'), '{"title": "عنوان آخر للإعلان"}')$$,
  'P0001', 'INVALID_STATE', 'لا حفظ مسودة دون مسودة تعديل');
select throws_ok(
  $$select public.delete_listing((select v from ids where k = 'l1'))$$,
  'P0001', 'INVALID_STATE', 'لا حذف لإعلان منشور');
reset role;

------------------------------------------------------------------------------
-- مستخدم آخر والزائر
------------------------------------------------------------------------------
select pg_temp.login('00000000-0000-0000-0000-00000000000b');
set local role authenticated;
select throws_ok(
  $$select public.save_listing_draft((select v from ids where k = 'l1'), '{"title": "اختراق"}')$$,
  'P0001', 'NOT_FOUND', 'مستخدم آخر لا يعدل إعلان غيره');
select throws_ok(
  $$select public.bump_listing((select v from ids where k = 'l1'))$$,
  'P0001', 'NOT_FOUND', 'مستخدم آخر لا يجدد إعلان غيره');
insert into ids select 'lb', (public.create_listing_draft('cccccccc-0000-0000-0000-000000000001') #>> '{listing,id}')::uuid;
select throws_ok(
  $$select public.submit_listing((select v from ids where k = 'lb'), 'cccccccc-0000-0000-0000-000000000002')$$,
  'P0001', 'PROFILE_INCOMPLETE', 'لا إرسال قبل إكمال الملف الشخصي');
reset role;

-- حد المسودات المفتوحة: 20
insert into public.listings (owner_id, create_request_id)
  select '00000000-0000-0000-0000-00000000000b', gen_random_uuid() from generate_series(1, 19);
set local role authenticated;
select throws_ok(
  $$select public.create_listing_draft('cccccccc-0000-0000-0000-000000000003')$$,
  'P0001', 'DRAFT_LIMIT_REACHED', 'حد المسودات المفتوحة');
-- حذف مسودة لم ترسل: حذف فعلي
select is(
  (public.delete_listing((select v from ids where k = 'lb')) ->> 'deleted')::boolean, true, 'حذف مسودة');
reset role;
select is((select count(*)::integer from public.listings where id = (select v from ids where k = 'lb')), 0,
  'مسودة لم ترسل تحذف فعليًا');

select set_config('request.jwt.claims', '', true);
set local role anon;
select throws_ok(
  $$select public.create_listing_draft('dddddddd-0000-0000-0000-000000000001')$$,
  '42501', null, 'الزائر لا ينشئ إعلانًا');
reset role;

------------------------------------------------------------------------------
-- بعد الاعتماد (محاكاة قرار الإدارة): تجديد وتعديل وأرشفة
------------------------------------------------------------------------------
update public.listings set
    first_published_at = now() - interval '23 hours', published_version_at = now() - interval '23 hours',
    last_published_at = now() - interval '23 hours', visibility_updated_at = now() - interval '23 hours'
  where id = (select v from ids where k = 'l1');

select pg_temp.login('00000000-0000-0000-0000-00000000000a');
set local role authenticated;
select throws_ok(
  $$select public.bump_listing((select v from ids where k = 'l1'))$$,
  'P0001', 'BUMP_TOO_EARLY', 'تجديد قبل 24 ساعة مرفوض');
reset role;
update public.listings set last_published_at = now() - interval '24 hours 1 second'
  where id = (select v from ids where k = 'l1');
set local role authenticated;
select isnt(
  public.bump_listing((select v from ids where k = 'l1')) #>> '{listing,last_bumped_at}',
  null, 'تجديد عند اكتمال 24 ساعة يقبل');
select throws_ok(
  $$select public.bump_listing((select v from ids where k = 'l1'))$$,
  'P0001', 'BUMP_TOO_EARLY', 'تجديد ثان مباشرة مرفوض');
select is((select count(*)::integer from public.listing_bumps), 1, 'تجديد واحد في السجل');

-- تعديل منشور: يبقى منشورًا والمسودة خاصة
select is(
  public.start_listing_edit((select v from ids where k = 'l1')) #>> '{listing,status}',
  'PUBLISHED', 'المنشور يبقى منشورًا أثناء التعديل');
select is((select count(*)::integer from public.listing_versions where status = 'DRAFT'), 1, 'مسودة تعديل واحدة');
select is(
  (select count(*)::integer from public.media m join public.listing_versions v on v.id = m.version_id
    where v.status = 'DRAFT'),
  3, 'وسائط النسخة تنسخ إلى مسودة التعديل');
select lives_ok(
  $$select public.start_listing_edit((select v from ids where k = 'l1'))$$,
  'بدء التعديل مرتين لا ينشئ مسودة ثانية');
select is(
  (public.discard_listing_edit((select v from ids where k = 'l1')) #>> '{listing,has_draft}')::boolean,
  false, 'التراجع عن التعديل يحذف المسودة');
select is((select count(*)::integer from public.media), 3, 'وسائط المنشور باقية بعد التراجع');

select lives_ok(
  $$select public.start_listing_edit((select v from ids where k = 'l1'))$$, 'بدء تعديل جديد');
select lives_ok(
  $$select public.save_listing_draft((select v from ids where k = 'l1'), '{"price": 30000}')$$, 'تعديل السعر');
select is(
  public.submit_listing((select v from ids where k = 'l1'), 'bbbbbbbb-0000-0000-0000-000000000002') #>> '{listing,status}',
  'PUBLISHED', 'إرسال تعديل المنشور يسري فورًا');
select is(
  (select l.published_version_id from public.listings l where l.id = (select v from ids where k = 'l1')),
  (select v.id from public.listing_versions v where v.version_no = 2),
  'النسخة المعدلة هي المنشورة');
select is((select price from public.public_listing_details where listing_id = (select v from ids where k = 'l1')),
  30000.00::numeric, 'السعر الجديد ظاهر للعامة فورًا');
select ok((select l.visibility_updated_at = l.last_bumped_at and l.first_published_at = now() - interval '23 hours'
    and l.last_published_at = now() - interval '24 hours 1 second'
    from public.listings l where l.id = (select v from ids where k = 'l1')),
  'التعديل لا يرفع ترتيب الظهور ولا يجدد last_published_at ولا يغير النشر الأول');
select isnt(
  (select content_hash from public.listing_versions where version_no = 2),
  (select content_hash from public.listing_versions where version_no = 1),
  'بصمة النسخة المعدلة تختلف');
reset role;

-- إعلان مرفوض قديم (بيانات سابقة لإلغاء المراجعة) ثم تصحيح
update public.listings set status = 'REJECTED' where id = (select v from ids where k = 'l1');

set local role authenticated;
select is(
  public.start_listing_edit((select v from ids where k = 'l1')) #>> '{listing,status}',
  'DRAFT', 'المرفوض يعود مسودة بالمعرف نفسه');
select is((select max(version_no) from public.listing_versions), 3, 'نسخة جديدة للتصحيح');
select is((public.delete_listing((select v from ids where k = 'l1')) ->> 'deleted')::boolean, true, 'حذف إعلان له سجل');
select is((select count(*)::integer from public.listings), 0, 'المحذوف منطقيًا لا يراه صاحبه');
reset role;
select isnt((select deleted_at from public.listings where id = (select v from ids where k = 'l1')), null,
  'إعلان أرسل للمراجعة يحذف منطقيًا ويبقى صفه');

------------------------------------------------------------------------------
-- مزاد مضى موعده وأرشفة
------------------------------------------------------------------------------
insert into public.listings (id, owner_id, create_request_id) values
  ('10000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-00000000000a', gen_random_uuid());
insert into public.listing_versions (id, listing_id, version_no) values
  ('20000000-0000-0000-0000-000000000009', '10000000-0000-0000-0000-000000000009', 1);
update public.listing_versions set
    title = 'مزاد حضوري للإبل', description = 'وصف كاف لاجتياز الحد الأدنى للطول',
    breed_id = (select breed from lk), sex = 'MALE', age_months = 36,
    region_id = 1, city_id = (select city_r1 from lk),
    health_notes = 'سليم', owner_declaration_at = now(),
    offer_type = 'IN_PERSON_AUCTION', auction_region_id = 1, auction_city_id = (select city_r1 from lk),
    auction_venue = 'سوق الإبل', auction_starts_at = now() - interval '1 hour',
    contact_phone = '+966500000009', contact_whatsapp_enabled = true, contact_consent_at = now(),
    settings_version = 1, content_hash = 'h', submitted_at = now() - interval '3 days', status = 'SUBMITTED'
  where id = '20000000-0000-0000-0000-000000000009';
update public.listing_versions set status = 'APPROVED', decided_at = now()
  where id = '20000000-0000-0000-0000-000000000009';
update public.listings set status = 'PUBLISHED',
    current_version_id = '20000000-0000-0000-0000-000000000009',
    published_version_id = '20000000-0000-0000-0000-000000000009',
    first_submitted_at = now() - interval '3 days', first_published_at = now() - interval '2 days',
    published_version_at = now() - interval '2 days', last_published_at = now() - interval '2 days',
    visibility_updated_at = now() - interval '2 days'
  where id = '10000000-0000-0000-0000-000000000009';

set local role authenticated;
select throws_ok(
  $$select public.bump_listing('10000000-0000-0000-0000-000000000009')$$,
  'P0001', 'AUCTION_TIME_PASSED', 'لا تجديد لمزاد مضى موعده');
select throws_ok(
  $$select public.delete_listing('10000000-0000-0000-0000-000000000009')$$,
  'P0001', 'INVALID_STATE', 'المنشور لا يحذف');
select is(
  public.archive_listing('10000000-0000-0000-0000-000000000009') #>> '{listing,status}',
  'ARCHIVED', 'أرشفة المنشور');
select throws_ok(
  $$select public.bump_listing('10000000-0000-0000-0000-000000000009')$$,
  'P0001', 'INVALID_STATE', 'لا تجديد لمؤرشف');
select is(
  public.start_listing_edit('10000000-0000-0000-0000-000000000009') #>> '{listing,status}',
  'DRAFT', 'إعادة عرض المؤرشف تبدأ بمسودة');
select throws_ok(
  $$select public.submit_listing('10000000-0000-0000-0000-000000000009', 'bbbbbbbb-0000-0000-0000-000000000009')$$,
  'P0001', 'VALIDATION_FAILED', 'مزاد بموعد ماض لا يرسل');
reset role;

-- إعلان مخفي إداريًا: لا يستعيده المعلن
update public.listings set status = 'HIDDEN' where id = '10000000-0000-0000-0000-000000000009';
set local role authenticated;
select throws_ok(
  $$select public.start_listing_edit('10000000-0000-0000-0000-000000000009')$$,
  'P0001', 'INVALID_STATE', 'المخفي إداريًا لا يعدله المعلن');
reset role;

-- حساب معلق
update public.profiles set status = 'SUSPENDED' where id = '00000000-0000-0000-0000-00000000000a';
set local role authenticated;
select throws_ok(
  $$select public.create_listing_draft('aaaaaaaa-0000-0000-0000-000000000099')$$,
  'P0001', 'ACCOUNT_SUSPENDED', 'الحساب المعلق لا ينشئ إعلانًا');
reset role;

select * from finish();
rollback;
