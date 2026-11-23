-- 22 admin_stats — MOBILE-BE-402
-- التقارير التجميعية للإدارة: AD-FR-020. أعداد فقط، دون نصوص رسائل أو مستندات
-- ولا أي معرف شخص. الضغط على التواصل (اتصال أو واتساب) لا يُسجل في الخادم فلا
-- يحسب، ولا يُحسب أي تواصل عملية بيع.

create function public.admin_stats(
  p_from timestamptz default null,
  p_to timestamptz default null
)
returns jsonb
language plpgsql

security definer
set search_path = ''
as $$
declare
  v_actor uuid := private.require_staff('stats.read');
  v_to timestamptz := coalesce(p_to, clock_timestamp());
  v_from timestamptz := coalesce(p_from, coalesce(p_to, clock_timestamp()) - interval '30 days');
begin
  if v_from >= v_to or v_to - v_from > interval '366 days' then
    perform private.raise_error('VALIDATION_FAILED',
      pg_catalog.jsonb_build_object('fields', pg_catalog.jsonb_build_array('p_from', 'p_to')));
  end if;

  return pg_catalog.jsonb_build_object(
    'period', pg_catalog.jsonb_build_object('from', v_from, 'to', v_to),
    'generated_at', clock_timestamp(),
    'accounts', pg_catalog.jsonb_build_object(
      'created', (select count(*) from public.profiles p where p.created_at >= v_from and p.created_at < v_to),
      'suspended_now', (select count(*) from public.profiles p where p.status = 'SUSPENDED'),
      'total', (select count(*) from public.profiles)),
    'listings', pg_catalog.jsonb_build_object(
      'submitted', (select count(*) from public.listings l
        where l.first_submitted_at >= v_from and l.first_submitted_at < v_to),
      'approved', (select count(*) from public.reviews r
        where r.decision = 'APPROVED' and r.created_at >= v_from and r.created_at < v_to),
      'rejected', (select count(*) from public.reviews r
        where r.decision = 'REJECTED' and r.created_at >= v_from and r.created_at < v_to),
      'hidden', (select count(*) from public.reviews r
        where r.decision = 'HIDDEN' and r.created_at >= v_from and r.created_at < v_to),
      'published_now', (select count(*) from public.listings l
        where l.status = 'PUBLISHED' and l.deleted_at is null),
      'under_review_now', (select count(*) from public.listings l where l.status = 'UNDER_REVIEW')),
    'reports', pg_catalog.jsonb_build_object(
      'opened', (select count(*) from public.reports r where r.created_at >= v_from and r.created_at < v_to),
      'closed', (select count(*) from public.reports r where r.closed_at >= v_from and r.closed_at < v_to),
      'open_now', (select count(*) from public.reports r where r.status <> 'CLOSED')),
    'interaction', pg_catalog.jsonb_build_object(
      'conversations_started', (select count(*) from public.conversations c
        where c.created_at >= v_from and c.created_at < v_to),
      'messages_sent', (select count(*) from public.messages m
        where m.created_at >= v_from and m.created_at < v_to),
      'comments_posted', (select count(*) from public.comments c
        where c.created_at >= v_from and c.created_at < v_to),
      'favorites_added', (select count(*) from public.favorites f
        where f.created_at >= v_from and f.created_at < v_to)),
    'follows', pg_catalog.jsonb_build_object(
      'sellers_followed', (select count(*) from public.follows f
        where f.created_at >= v_from and f.created_at < v_to),
      'searches_saved', (select count(*) from public.saved_searches s
        where s.created_at >= v_from and s.created_at < v_to)),
    'ratings', pg_catalog.jsonb_build_object(
      'created', (select count(*) from public.seller_ratings r
        where r.created_at >= v_from and r.created_at < v_to),
      'hidden_now', (select count(*) from public.seller_ratings r where r.status = 'HIDDEN'),
      'appeals_opened', (select count(*) from public.rating_appeals a
        where a.created_at >= v_from and a.created_at < v_to),
      'appeals_open_now', (select count(*) from public.rating_appeals a where a.status = 'OPEN'))
  );
end;
$$;

comment on function public.admin_stats(timestamptz, timestamptz) is
  'تقارير تجميعية للفترة (الافتراضي آخر 30 يومًا، وحتى 366). أعداد فقط. القدرة: stats.read.';

grant execute on function public.admin_stats(timestamptz, timestamptz) to authenticated;
