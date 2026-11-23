-- عمليات الإشراف إلى أن توجد لوحة الإدارة — MOBILE-BE-107 (TEAM-DEC-007)
--
-- ينفذ من محرر SQL في لوحة Supabase أو psql بصلاحية قاعدة البيانات، لبيئة التطوير.
-- الدوال هي نفسها التي ستستدعيها اللوحة، وتفحص الدور والقدرة وتكتب سجل الإجراءات.
-- محرر SQL لا يحمل جلسة موظف، فيحدد الموظف المنفذ هنا: معرف حساب له دور فعال في
-- admin_roles. لا تلتزم بالملف بعد وضع معرفات حقيقية.
--
-- الاستخدام: انسخ المقطع المطلوب مع سطر «جلسة الموظف» ونفذهما معًا داخل begin/commit.

begin;

-- جلسة الموظف: ضع معرف حساب الموظف المنفذ.
select set_config('request.jwt.claims', json_build_object(
  'sub', '00000000-0000-0000-0000-000000000000',
  'role', 'authenticated',
  'aal', 'aal2')::text, true);

-- 1) قائمة المراجعة (الأقدم أولًا)
select jsonb_pretty(public.admin_review_queue(20));

-- 2) تفاصيل إعلان: خذ منها version.id وversion.content_hash للقرار
-- select jsonb_pretty(public.admin_get_listing_review('<listing_id>'));

-- 3) اعتماد
-- select public.admin_approve_listing_version('<listing_id>', '<version_id>', '<content_hash>');

-- 4) رفض (السبب إلزامي؛ النص إلزامي مع OTHER)
-- select code, label_ar from public.moderation_reasons where 'LISTING_REJECT' = any (applies_to) and is_active;
-- select public.admin_reject_listing_version('<listing_id>', '<version_id>', '<content_hash>', 'MISSING_INFO', 'نص يراه المعلن');

-- 5) إخفاء منشور وإعادة إظهاره
-- select public.admin_hide_listing('<listing_id>', 'FRAUD', null);
-- select public.admin_unhide_listing('<listing_id>', 'ملاحظة داخلية');

-- 6) الحسابات
-- select jsonb_pretty(public.admin_get_account('<user_id>'));
-- select public.admin_suspend_account('<user_id>', 'ABUSE', null);
-- select public.admin_reactivate_account('<user_id>', 'ملاحظة داخلية');

commit;
