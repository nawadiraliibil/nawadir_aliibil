-- 08 storage — MOBILE-BE-105
-- وسائط الإعلانات: AD-FR-007، AD-NFR-002، SRS القسمان 5 و6.
-- buckets خاصة دون روابط عامة دائمة. قراءة العامة تتحقق من حالة النشر في كل طلب،
-- فيسري الإخفاء والأرشفة من الطلب التالي.
-- مسار الملف: {owner}/{listing}/{media}.{ext}، ويسجل أولًا في public.media.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('listing-images', 'listing-images', false, 10485760, array['image/jpeg', 'image/png']),
  -- الفيديو معطل في الإعدادات المنشورة (media.video_enabled)؛ الحد الفعلي يتبع خطة المشروع.
  ('listing-videos', 'listing-videos', false, 104857600, array['video/mp4']);

-- هل الملف وسيط جاهز في النسخة المعتمدة لإعلان منشور؟
-- في public لأن سياسات التخزين تنفذ بصلاحيات الطالب، والزائر لا يقرأ الجداول.
create function public.storage_object_is_public(p_bucket text, p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.media m
    join public.listings l on l.id = m.listing_id
    where m.bucket = p_bucket
      and m.object_path = p_name
      and m.status = 'READY'
      and l.status = 'PUBLISHED'
      and l.published_version_id = m.version_id
  )
$$;

comment on function public.storage_object_is_public(text, text) is
  'هل ملف التخزين وسيط جاهز في النسخة المعتمدة لإعلان منشور. تستخدمها سياسات التخزين.';

grant execute on function public.storage_object_is_public(text, text) to anon, authenticated;

-- القراءة
create policy listing_media_read_public on storage.objects
  for select to anon, authenticated
  using (
    bucket_id in ('listing-images', 'listing-videos')
    and public.storage_object_is_public(bucket_id, name)
  );

create policy listing_media_read_own on storage.objects
  for select to authenticated
  using (
    bucket_id in ('listing-images', 'listing-videos')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy listing_media_read_staff on storage.objects
  for select to authenticated
  using (
    bucket_id in ('listing-images', 'listing-videos')
    and (
      (select public.has_staff_capability('listings.review'))
      or (select public.has_staff_capability('listings.hide'))
    )
  );

-- الرفع: في مجلد المالك، ولمسار سجلته دالة إضافة الوسائط وما زال بانتظار الرفع.
create policy listing_media_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('listing-images', 'listing-videos')
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.media m
      where m.bucket = objects.bucket_id
        and m.object_path = objects.name
        and m.owner_id = (select auth.uid())
        and m.status = 'PENDING'
    )
  );

-- الحذف: ملف في مجلد المالك لم يعد أي صف وسائط يشير إليه.
create policy listing_media_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('listing-images', 'listing-videos')
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and not exists (
      select 1 from public.media m
      where m.bucket = objects.bucket_id and m.object_path = objects.name
    )
  );
