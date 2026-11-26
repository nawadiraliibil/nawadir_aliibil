-- 28 profile_avatar — MOBILE-AVATAR-20261126
-- الصورة الشخصية: عمود مسار في profiles، وbucket عام للصور الرمزية، ودالة حفظ.
-- bucket عام لأن الصورة الرمزية تظهر لغير صاحبها (الإعلانات والتعليقات والمحادثات لاحقًا)
-- ولا تحوي بيانات حساسة. اسم الملف جديد في كل تغيير، فلا حاجة لاستبدال ملف قائم.
-- مسار الملف: {user}/{اسم}.{ext}.

alter table public.profiles add column avatar_path text check (
  avatar_path is null
  or (char_length(avatar_path) <= 120 and avatar_path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]+$')
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp']);

-- الرفع والحذف في مجلد صاحب الحساب فقط. لا تعديل: كل صورة باسم جديد.
create policy avatars_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- حذف التخزين يقرأ الصف أولًا، فيلزم المالك سياسة قراءة (القراءة العامة بالرابط لا تحتاجها).
create policy avatars_read_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy avatars_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- رد الحساب بمفتاح avatar_path جديد (فارغ إن لم تُضبط صورة).
create or replace function private.account_json(p_user uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'id', p.id,
    'display_name', p.display_name,
    'region_id', p.region_id,
    'avatar_path', p.avatar_path,
    'status', p.status,
    'created_at', p.created_at,
    'profile_complete', (p.display_name is not null and p.region_id is not null),
    'pending_policies', coalesce((
      select pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object('id', d.id, 'kind', d.kind, 'version', d.version, 'title', d.title)
        order by d.kind)
      from private.current_policy_documents() d
      where d.id = any (private.pending_policy_ids(p.id))
    ), '[]'::jsonb),
    'can_publish', (
      p.status = 'ACTIVE'
      and p.display_name is not null
      and p.region_id is not null
      and pg_catalog.cardinality(private.pending_policy_ids(p.id)) = 0
    )
  )
  from public.profiles p
  where p.id = p_user
$$;

-- يضبط الصورة بعد رفع الملف إلى avatars، أو يمسحها بـnull.
-- يعيد رد الحساب. الملف القديم يحذفه العميل بعد النجاح.
create function public.set_my_avatar(p_path text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := private.require_user();
  v_status public.account_status;
begin
  select p.status into v_status from public.profiles p where p.id = v_uid for update;

  if v_status <> 'ACTIVE' then
    perform private.raise_error('ACCOUNT_SUSPENDED');
  end if;

  if p_path is not null and (
    p_path !~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]+$'
    or char_length(p_path) > 120
    or (pg_catalog.string_to_array(p_path, '/'))[1] <> v_uid::text
    or not exists (
      select 1 from storage.objects o
      where o.bucket_id = 'avatars' and o.name = p_path
    )
  ) then
    perform private.raise_error(
      'VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('avatar_path'))
    );
  end if;

  update public.profiles p set avatar_path = p_path where p.id = v_uid;

  return private.account_json(v_uid);
end;
$$;

comment on function public.set_my_avatar(text) is
  'ضبط الصورة الشخصية لصاحب الجلسة من ملف مرفوع في avatars/{uid}/، أو مسحها بـnull.';

grant execute on function public.set_my_avatar(text) to authenticated;
