// يولد contracts/api/rpc.yaml من قاعدة البيانات المحلية — MOBILE-CON-101
//
// التوقيعات والأوصاف والصلاحيات تقرأ من القاعدة نفسها (pg_proc، تعليقات الدوال،
// has_function_privilege)، فلا يختلف التوثيق عن المنفذ. ما لا تعرفه القاعدة
// (القدرة المطلوبة، الأخطاء، منع التكرار، المتطلب) في الخريطة META أدناه.
// السكربت يفشل إن وجدت دالة متاحة للعميل دون بيانات في META أو العكس.
//
// المتطلبات: `supabase start` بعد `supabase db reset`، وDocker في PATH.
// التشغيل من جذر المستودع: node contracts/tools/build_rpc.mjs
import { execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";

const COMMON_USER = ["AUTH_REQUIRED", "FORBIDDEN"];
const COMMON_OWNER = [...COMMON_USER, "ACCOUNT_SUSPENDED", "NOT_FOUND"];
const COMMON_STAFF = ["AUTH_REQUIRED", "FORBIDDEN", "MFA_REQUIRED"];

/** access: anon (زائر ومستخدم) | user | staff:<capability> | staff (أي موظف) | service */
const META = {
  // الإعدادات والسياسات
  get_published_settings: { access: "anon", errors: [], req: "AD-FR-037", since: "0.1.0" },
  get_current_policies: { access: "anon", errors: [], req: "AD-FR-003", since: "0.1.0" },
  storage_object_is_public: {
    access: "anon", errors: [], req: "AD-NFR-002", since: "0.1.0",
    note: "تستخدمها سياسات التخزين؛ لا حاجة للعميل إلى استدعائها.",
  },
  // البحث والتفاصيل والمشاركة
  search_listings: {
    access: "anon", errors: ["VALIDATION_FAILED"], req: "AD-FR-011، AD-FR-012، AD-FR-024", since: "0.2.0",
    note: "الرد {items, next_cursor} وفق schemas/search-result. المزاد الماضي خارج النتائج؛ نطاق السعر يستبعد المزاد؛ الفرز بالسعر يضع المزاد أخيرًا. p_sort: NEWEST_VISIBLE (الافتراضي) | NEWEST_PUBLISHED | PRICE_ASC | PRICE_DESC | MOST_VIEWED (1.4.0؛ الأعلى مشاهدة ثم الأحدث، والمؤشر {views, id}). next_cursor يمرر كما هو مع المرشحات والفرز نفسها.",
  },
  get_listing: {
    access: "anon", errors: ["NOT_FOUND"], req: "AD-FR-011، AD-FR-013", since: "0.2.0",
    note: "الرد وفق schemas/listing-detail. غير المنشور NOT_FOUND بالرد نفسه لكل الأسباب.",
  },
  resolve_listing_ref: {
    access: "anon", errors: ["NOT_FOUND"], req: "AD-FR-023", since: "0.2.0",
    note: "يترجم public_ref في رابط المشاركة إلى معرف إعلان منشور؛ المخفي NOT_FOUND فيتوقف الرابط.",
  },
  record_listing_view: {
    access: "anon", errors: ["NOT_FOUND"], req: "AD-FR-011", since: "1.3.0",
    note: "يسجل مشاهدة إعلان منشور مرة واحدة لكل مشاهد (الحساب إن كان داخلًا، وإلا p_device_id وهو uuid يولده التطبيق ويحفظه) ويعيد العدد (integer). بلا حساب ولا معرف جهاز لا تحسب. مشاهدة المعلن لإعلانه لا تحسب.",
  },
  add_favorite: {
    access: "user", errors: [...COMMON_USER, "ACCOUNT_SUSPENDED", "NOT_FOUND"], req: "AD-FR-022", since: "0.2.0",
    idempotency: "التكرار لا ينشئ صفًا ولا يغير تاريخ الحفظ.",
  },
  remove_favorite: {
    access: "user", errors: COMMON_USER, req: "AD-FR-022", since: "0.2.0",
    idempotency: "الإزالة المتكررة تعيد removed=false.",
  },
  // المحادثات والحظر والردود والبلاغات والمتابعات والدفع (0.3.0)
  start_conversation: {
    access: "user", errors: [...COMMON_USER, "ACCOUNT_SUSPENDED", "NOT_FOUND", "CANNOT_MESSAGE_SELF", "RATE_LIMITED"],
    req: "AD-FR-031", since: "0.3.0",
    idempotency: "محادثة واحدة لكل إعلان وطرفين؛ التكرار يعيد الموجودة (created=false).",
  },
  send_message: {
    access: "user",
    errors: [...COMMON_USER, "ACCOUNT_SUSPENDED", "NOT_FOUND", "VALIDATION_FAILED", "CONVERSATION_READ_ONLY", "RATE_LIMITED"],
    req: "AD-FR-031، AD-NFR-005", since: "0.3.0",
    idempotency: "p_request_id: إعادة الطلب تعيد الرسالة الأولى دون تكرار.",
  },
  mark_conversation_read: { access: "user", errors: [...COMMON_USER, "NOT_FOUND"], req: "AD-FR-031", since: "0.3.0" },
  set_conversation_muted: {
    access: "user", errors: [...COMMON_USER, "NOT_FOUND", "VALIDATION_FAILED"], req: "AD-FR-027", since: "0.3.0",
  },
  block_user: {
    access: "user", errors: [...COMMON_USER, "ACCOUNT_SUSPENDED", "NOT_FOUND", "VALIDATION_FAILED"],
    req: "AD-FR-033", since: "0.3.0", idempotency: "التكرار آمن.",
  },
  unblock_user: { access: "user", errors: COMMON_USER, req: "AD-FR-033", since: "0.3.0", idempotency: "التكرار آمن." },
  post_comment: {
    access: "user",
    errors: [
      ...COMMON_USER, "ACCOUNT_SUSPENDED", "NOT_FOUND", "VALIDATION_FAILED", "COMMENTS_CLOSED", "RATE_LIMITED",
    ],
    req: "AD-FR-032", since: "0.3.0",
    idempotency: "p_request_id: إعادة الطلب تعيد الرد الأول. الرد الرئيسي لغير المعلن؛ رد المعلن بـp_parent_id.",
  },
  edit_comment: {
    access: "user", errors: [...COMMON_USER, "ACCOUNT_SUSPENDED", "NOT_FOUND", "INVALID_STATE", "VALIDATION_FAILED"],
    req: "AD-FR-032", since: "0.3.0",
  },
  delete_comment: { access: "user", errors: [...COMMON_USER, "NOT_FOUND"], req: "AD-FR-032", since: "0.3.0", idempotency: "التكرار آمن." },
  set_comments_closed: {
    access: "user", errors: [...COMMON_OWNER, "VALIDATION_FAILED"], req: "AD-FR-032", since: "0.3.0",
  },
  admin_hide_comment: {
    access: "staff:comments.moderate",
    errors: [...COMMON_STAFF, "NOT_FOUND", "INVALID_STATE", "REASON_REQUIRED", "VALIDATION_FAILED"],
    req: "AD-FR-032، AD-FR-036", since: "0.3.0",
  },
  admin_unhide_comment: {
    access: "staff:comments.moderate", errors: [...COMMON_STAFF, "NOT_FOUND", "INVALID_STATE", "VALIDATION_FAILED"],
    req: "AD-FR-032", since: "0.3.0",
  },
  submit_report: {
    access: "user", errors: [...COMMON_USER, "ACCOUNT_SUSPENDED", "NOT_FOUND", "VALIDATION_FAILED", "RATE_LIMITED"],
    req: "AD-FR-015", since: "0.3.0",
    idempotency: "p_request_id: إعادة الطلب تعيد البلاغ الأول؛ بلاغ مفتوح للهدف نفسه يعاد (duplicate=true).",
  },
  get_report_status: { access: "user", errors: [...COMMON_USER, "NOT_FOUND"], req: "AD-FR-015", since: "0.3.0" },
  admin_assign_report: {
    access: "staff:reports.handle", errors: [...COMMON_STAFF, "NOT_FOUND", "INVALID_STATE", "VALIDATION_FAILED"],
    req: "AD-FR-019", since: "0.3.0",
  },
  admin_set_report_status: {
    access: "staff:reports.handle", errors: [...COMMON_STAFF, "NOT_FOUND", "INVALID_STATE", "VALIDATION_FAILED"],
    req: "AD-FR-019", since: "0.3.0",
  },
  admin_close_report: {
    access: "staff:reports.handle",
    errors: [...COMMON_STAFF, "NOT_FOUND", "INVALID_STATE", "REASON_REQUIRED", "VALIDATION_FAILED"],
    req: "AD-FR-019", since: "0.3.0",
  },
  admin_get_report_evidence: {
    access: "staff:evidence.read", errors: [...COMMON_STAFF, "NOT_FOUND", "INVALID_STATE"],
    req: "AD-FR-036", since: "0.3.0",
    note: "تسجل كل قراءة ناجحة في report_evidence_access وسجل الإجراءات.",
  },
  save_search: {
    access: "user", errors: [...COMMON_USER, "ACCOUNT_SUSPENDED", "VALIDATION_FAILED", "FOLLOW_LIMIT_REACHED"],
    req: "AD-FR-026", since: "0.3.0", idempotency: "المرشحات نفسها تعيد المحفوظ (created=false).",
  },
  delete_saved_search: { access: "user", errors: COMMON_USER, req: "AD-FR-026", since: "0.3.0", idempotency: "التكرار آمن." },
  follow_seller: {
    access: "user", errors: [...COMMON_USER, "ACCOUNT_SUSPENDED", "NOT_FOUND", "VALIDATION_FAILED", "FOLLOW_LIMIT_REACHED"],
    req: "AD-FR-026", since: "0.3.0", idempotency: "التكرار آمن.",
  },
  unfollow_seller: { access: "user", errors: COMMON_USER, req: "AD-FR-026", since: "0.3.0", idempotency: "التكرار آمن." },
  set_notification_preference: {
    access: "user", errors: [...COMMON_USER, "VALIDATION_FAILED"], req: "AD-FR-027", since: "0.3.0",
  },
  register_device_token: {
    access: "user", errors: [...COMMON_USER, "VALIDATION_FAILED"], req: "AD-FR-016، AD-FR-027", since: "0.3.0",
    idempotency: "الرمز نفسه يعاد تفعيله وتنتقل ملكيته لصاحب الجلسة.",
  },
  unregister_device_token: {
    access: "user", errors: COMMON_USER, req: "AD-FR-027", since: "0.3.0", idempotency: "التكرار آمن.",
  },
  claim_push_batch: {
    access: "service", errors: [], req: "AD-FR-016", since: "0.3.0", note: "لمرسل الدفع push-dispatch فقط.",
  },
  complete_push: {
    access: "service", errors: [], req: "AD-FR-016", since: "0.3.0", note: "لمرسل الدفع push-dispatch فقط.",
  },
  // التقييمات والتقارير (1.0.0)
  get_rating_eligibility: { access: "user", errors: COMMON_USER, req: "AD-FR-029", since: "1.0.0",
    note: "reason عند عدم الأهلية: SELF | ALREADY_RATED | BLOCKED | NO_CONVERSATION | NO_EXCHANGE." },
  submit_rating: {
    access: "user",
    errors: [...COMMON_USER, "ACCOUNT_SUSPENDED", "VALIDATION_FAILED", "RATING_NOT_ELIGIBLE", "RATING_EXISTS"],
    req: "AD-FR-029، AD-NFR-005", since: "1.0.0",
    idempotency: "p_request_id: إعادة الطلب تعيد التقييم الأول. تقييم واحد لكل معلن.",
  },
  edit_rating: {
    access: "user", errors: [...COMMON_USER, "ACCOUNT_SUSPENDED", "NOT_FOUND", "INVALID_STATE", "VALIDATION_FAILED"],
    req: "AD-FR-029", since: "1.0.0", note: "تحفظ الصيغة السابقة في سجل التعديلات.",
  },
  reply_to_rating: {
    access: "user", errors: [...COMMON_USER, "ACCOUNT_SUSPENDED", "NOT_FOUND", "INVALID_STATE", "VALIDATION_FAILED"],
    req: "AD-FR-029", since: "1.0.0", note: "الرد لا يغير الدرجة؛ استبداله يعدل الرد نفسه.",
  },
  appeal_rating: {
    access: "user", errors: [...COMMON_USER, "ACCOUNT_SUSPENDED", "NOT_FOUND", "INVALID_STATE", "VALIDATION_FAILED"],
    req: "AD-FR-029", since: "1.0.0", idempotency: "اعتراض واحد لكل تقييم؛ التكرار يعيد القائم (created=false).",
    note: "الاعتراض لا يخفي التقييم تلقائيًا.",
  },
  admin_hide_rating: {
    access: "staff:ratings.moderate",
    errors: [...COMMON_STAFF, "NOT_FOUND", "INVALID_STATE", "REASON_REQUIRED", "VALIDATION_FAILED"],
    req: "AD-FR-036", since: "1.0.0",
  },
  admin_unhide_rating: {
    access: "staff:ratings.moderate", errors: [...COMMON_STAFF, "NOT_FOUND", "INVALID_STATE", "VALIDATION_FAILED"],
    req: "AD-FR-036", since: "1.0.0",
  },
  admin_decide_rating_appeal: {
    access: "staff:ratings.moderate",
    errors: [...COMMON_STAFF, "NOT_FOUND", "INVALID_STATE", "REASON_REQUIRED", "VALIDATION_FAILED"],
    req: "AD-FR-036", since: "1.0.0",
    note: "p_decision: ACCEPTED يخفي التقييم بسبب إلزامي (RATING_HIDE)، REJECTED يبقيه.",
  },
  admin_stats: {
    access: "staff:stats.read", errors: [...COMMON_STAFF, "VALIDATION_FAILED"], req: "AD-FR-020", since: "1.0.0",
    note: "أعداد تجميعية فقط للفترة (الافتراضي آخر 30 يومًا، وحتى 366).",
  },
  // الحساب
  get_my_account: { access: "user", errors: COMMON_USER, req: "AD-FR-003", since: "0.1.0" },
  update_my_profile: {
    access: "user", errors: [...COMMON_USER, "ACCOUNT_SUSPENDED", "VALIDATION_FAILED"],
    req: "AD-FR-003، AD-FR-004", since: "0.1.0",
  },
  set_my_avatar: {
    access: "user", errors: [...COMMON_USER, "ACCOUNT_SUSPENDED", "VALIDATION_FAILED"],
    req: "AD-FR-003", since: "1.5.0",
    note: "p_path مسار ملف مرفوع في avatars/{uid}/ أو null للمسح؛ يعيد رد الحساب. الملف القديم يحذفه العميل.",
  },
  accept_policies: {
    access: "user", errors: [...COMMON_USER, "VALIDATION_FAILED"], req: "AD-FR-003", since: "0.1.0",
    idempotency: "تكرار الموافقة على النص نفسه لا يغير تاريخها.",
  },
  mark_notifications_read: {
    access: "user", errors: COMMON_USER, req: "AD-FR-016", since: "0.1.0",
    idempotency: "تعليم المقروء مرة أخرى يعيد 0.",
  },
  // إعلانات المعلن
  create_listing_draft: {
    access: "user", errors: [...COMMON_USER, "ACCOUNT_SUSPENDED", "VALIDATION_FAILED", "DRAFT_LIMIT_REACHED"],
    req: "AD-FR-005، AD-NFR-005", since: "0.1.0",
    idempotency: "p_request_id: الطلب المكرر يعيد المسودة نفسها.",
  },
  save_listing_draft: {
    access: "user", errors: [...COMMON_OWNER, "INVALID_STATE", "VALIDATION_FAILED"],
    req: "AD-FR-005، AD-FR-006، AD-FR-014، AD-FR-025", since: "0.1.0",
    note: "p_patch وفق contracts/schemas/listing-draft-patch.schema.json. رقمان مستقلان اختياريان (1.1.0، TEAM-DEC-012): contact_phone للاتصال وcontact_whatsapp_phone لواتساب، بصيغة 05XXXXXXXX أو +9665XXXXXXXX؛ مفتاحا contact_call_enabled وcontact_whatsapp_enabled قديمان يحوَّلان إلى الرقمين ويتجاهلان إن وجد contact_whatsapp_phone.",
  },
  add_listing_media: {
    access: "user",
    errors: [...COMMON_OWNER, "INVALID_STATE", "VALIDATION_FAILED", "VIDEO_DISABLED", "MEDIA_LIMIT_REACHED"],
    req: "AD-FR-007", since: "0.1.0",
    note: "بعد الرفع إلى المسار المعاد يستدعي العميل دالة Edge ‏media-finalize.",
  },
  remove_listing_media: {
    access: "user", errors: [...COMMON_OWNER, "INVALID_STATE"], req: "AD-FR-007", since: "0.1.0",
  },
  arrange_listing_media: {
    access: "user", errors: [...COMMON_OWNER, "INVALID_STATE", "VALIDATION_FAILED"], req: "AD-FR-007", since: "0.1.0",
  },
  submit_listing: {
    access: "user",
    errors: [
      ...COMMON_OWNER, "PROFILE_INCOMPLETE", "POLICIES_NOT_ACCEPTED", "INVALID_STATE",
      "MEDIA_NOT_READY", "VALIDATION_FAILED", "RATE_LIMITED",
    ],
    req: "AD-FR-003، AD-FR-008، AD-FR-009، AD-NFR-005", since: "0.1.0",
    note: "ينشر مباشرة (1.2.0، TEAM-DEC-013): لا مراجعة؛ يعيد listing.status = PUBLISHED وversion.status = APPROVED مع published_version_id = current_version_id وfirst_published_at وlast_published_at وnext_bump_at. DRAFT -> PUBLISHED (أول نشر يحتسب حد 5/24 ساعة ويطلق follow.new_listing)؛ PUBLISHED بمسودة تعديل -> تسري النسخة الجديدة فورًا دون اختفاء ودون رفع الترتيب. المخفي HIDDEN وغيره من الحالات غير DRAFT/PUBLISHED يرفع INVALID_STATE. يلزم أحد الرقمين contact_phone أو contact_whatsapp_phone على الأقل، ويبقى وقت الموافقة على نشر الرقم مطلوبًا؛ وإلا VALIDATION_FAILED بالحقلين.",
    idempotency: "p_request_id: الطلب المكرر لا ينشئ إرسالًا ثانيًا ويعيد الحالة الحالية.",
  },
  start_listing_edit: {
    access: "user", errors: [...COMMON_OWNER, "INVALID_STATE"], req: "AD-FR-009، AD-FR-010", since: "0.1.0",
    idempotency: "الاستدعاء مع وجود مسودة يعيدها دون إنشاء أخرى.",
  },
  discard_listing_edit: {
    access: "user", errors: [...COMMON_OWNER, "INVALID_STATE"], req: "AD-FR-009", since: "0.1.0",
  },
  archive_listing: {
    access: "user", errors: [...COMMON_OWNER, "INVALID_STATE"], req: "AD-FR-010", since: "0.1.0",
  },
  delete_listing: {
    access: "user", errors: [...COMMON_OWNER, "INVALID_STATE"], req: "AD-FR-005", since: "0.1.0",
  },
  bump_listing: {
    access: "user",
    errors: [...COMMON_OWNER, "INVALID_STATE", "AUCTION_TIME_PASSED", "BUMP_TOO_EARLY"],
    req: "AD-FR-030", since: "0.1.0",
  },
  finalize_listing_media: {
    access: "service", errors: ["NOT_FOUND", "VERSION_IMMUTABLE"], req: "AD-FR-007", since: "0.1.0",
    note: "لا يستدعيها العميل؛ تستدعيها دالة Edge ‏media-finalize.",
    idempotency: "وسيط ليس بانتظار الرفع يعاد بحالته دون تغيير.",
  },
  // الموظفون
  has_staff_capability: { access: "user", errors: [], req: "AD-FR-017", since: "0.1.0",
    note: "تعيد false لغير الموظف ولجلسة دون aal2. للعرض فقط؛ الصلاحية تفحص في كل دالة." },
  admin_whoami: { access: "staff", errors: COMMON_STAFF, req: "AD-FR-017", since: "0.1.0" },
  admin_grant_role: {
    access: "staff:staff.manage",
    errors: [...COMMON_STAFF, "CANNOT_MODIFY_SELF", "VALIDATION_FAILED", "LAST_ADMIN"],
    req: "AD-FR-021", since: "0.1.0",
  },
  admin_revoke_role: {
    access: "staff:staff.manage",
    errors: [...COMMON_STAFF, "CANNOT_MODIFY_SELF", "INVALID_STATE", "LAST_ADMIN"],
    req: "AD-FR-021", since: "0.1.0",
  },
  // إشراف الإعلانات والحسابات
  admin_review_queue: { access: "staff:listings.review", errors: COMMON_STAFF, req: "AD-FR-008", since: "0.1.0",
    note: "مهملة منذ 1.2.0 (TEAM-DEC-013): تعيد [] دائمًا؛ لا إعلان قيد المراجعة. استخدم admin_list_listings." },
  admin_list_listings: {
    access: "staff:listings.hide|listings.review", errors: [...COMMON_STAFF, "VALIDATION_FAILED"],
    req: "AD-FR-018", since: "1.2.0",
    note: "قائمة كل الإعلانات لإدارة الظهور: p_status (DRAFT|PUBLISHED|HIDDEN|ARCHIVED|REJECTED أو فارغ)، p_query (جزء من العنوان أو اسم المعلن، أو المعرف العام public_ref أو معرف الإعلان)، p_limit (1-100، 50)، والتصفح بمفتاح آخر عنصر (p_after_changed_at, p_after_id) بترتيب status_changed_at تنازليًا. العنصر يضم listing_id وpublic_ref وstatus وtitle وowner_display_name وowner_status وhide_reason_code وhide_reason_text وhidden_at وغيرها.",
  },
  admin_get_listing_review: {
    access: "staff:listings.review|listings.hide", errors: [...COMMON_STAFF, "NOT_FOUND"],
    req: "AD-FR-008، AD-FR-018", since: "0.1.0",
  },
  admin_approve_listing_version: {
    access: "staff:listings.review",
    errors: [...COMMON_STAFF, "NOT_FOUND", "INVALID_STATE", "VERSION_CHANGED", "AUCTION_TIME_PASSED"],
    req: "AD-FR-008، AD-FR-009", since: "0.1.0",
    note: "مهملة منذ 1.2.0 (TEAM-DEC-013): ترفع INVALID_STATE دائمًا (الإعلان ينشر عند الإرسال).",
  },
  admin_reject_listing_version: {
    access: "staff:listings.review",
    errors: [...COMMON_STAFF, "REASON_REQUIRED", "VALIDATION_FAILED", "NOT_FOUND", "INVALID_STATE", "VERSION_CHANGED"],
    req: "AD-FR-008، AD-FR-018", since: "0.1.0",
    note: "مهملة منذ 1.2.0 (TEAM-DEC-013): ترفع INVALID_STATE دائمًا؛ الإخفاء admin_hide_listing هو أداة التحكم.",
  },
  admin_hide_listing: {
    access: "staff:listings.hide",
    errors: [...COMMON_STAFF, "REASON_REQUIRED", "VALIDATION_FAILED", "NOT_FOUND", "INVALID_STATE"],
    req: "AD-FR-018", since: "0.1.0",
  },
  admin_unhide_listing: {
    access: "staff:listings.hide",
    errors: [...COMMON_STAFF, "NOT_FOUND", "INVALID_STATE", "VALIDATION_FAILED"],
    req: "AD-FR-018", since: "0.1.0",
  },
  admin_get_account: {
    access: "staff:accounts.manage", errors: [...COMMON_STAFF, "NOT_FOUND"], req: "AD-FR-018", since: "0.1.0",
  },
  admin_suspend_account: {
    access: "staff:accounts.manage",
    errors: [...COMMON_STAFF, "REASON_REQUIRED", "VALIDATION_FAILED", "NOT_FOUND", "INVALID_STATE"],
    req: "AD-FR-018", since: "0.1.0",
  },
  admin_reactivate_account: {
    access: "staff:accounts.manage",
    errors: [...COMMON_STAFF, "NOT_FOUND", "INVALID_STATE", "VALIDATION_FAILED"],
    req: "AD-FR-018", since: "0.1.0",
  },
  // القوائم والإعدادات
  admin_upsert_region: {
    access: "staff:lookups.manage", errors: [...COMMON_STAFF, "VALIDATION_FAILED", "NOT_FOUND"],
    req: "AD-FR-037", since: "0.1.0",
  },
  admin_upsert_city: {
    access: "staff:lookups.manage", errors: [...COMMON_STAFF, "VALIDATION_FAILED", "NOT_FOUND", "INVALID_STATE"],
    req: "AD-FR-037", since: "0.1.0",
  },
  admin_upsert_breed: {
    access: "staff:lookups.manage", errors: [...COMMON_STAFF, "VALIDATION_FAILED", "NOT_FOUND"],
    req: "AD-FR-037", since: "0.1.0",
  },
  admin_upsert_moderation_reason: {
    access: "staff:lookups.manage", errors: [...COMMON_STAFF, "VALIDATION_FAILED"], req: "AD-FR-037", since: "0.1.0",
  },
  admin_set_lookup_active: {
    access: "staff:lookups.manage", errors: [...COMMON_STAFF, "VALIDATION_FAILED", "NOT_FOUND"],
    req: "AD-FR-037", since: "0.1.0",
  },
  admin_reorder_lookup: {
    access: "staff:lookups.manage", errors: [...COMMON_STAFF, "VALIDATION_FAILED", "NOT_FOUND"],
    req: "AD-FR-037", since: "0.1.0",
  },
  admin_get_settings: { access: "staff:settings.manage", errors: COMMON_STAFF, req: "AD-FR-037", since: "0.1.0" },
  admin_update_settings_draft: {
    access: "staff:settings.manage", errors: [...COMMON_STAFF, "VALIDATION_FAILED", "BELOW_HARD_MINIMUM"],
    req: "AD-FR-037", since: "0.1.0",
  },
  admin_publish_settings: {
    access: "staff:settings.manage",
    errors: [...COMMON_STAFF, "INVALID_STATE", "VALIDATION_FAILED", "BELOW_HARD_MINIMUM"],
    req: "AD-FR-037", since: "0.1.0",
  },
  admin_rollback_settings: {
    access: "staff:settings.manage",
    errors: [...COMMON_STAFF, "NOT_FOUND", "INVALID_STATE", "VALIDATION_FAILED", "BELOW_HARD_MINIMUM"],
    req: "AD-FR-037", since: "0.1.0",
  },
};

const SQL = `
select coalesce(json_agg(f order by f.name), '[]'::json) from (
  select
    p.proname as name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as returns,
    coalesce(obj_description(p.oid, 'pg_proc'), '') as description,
    has_function_privilege('anon', p.oid, 'execute') as anon,
    has_function_privilege('authenticated', p.oid, 'execute') as authenticated,
    has_function_privilege('service_role', p.oid, 'execute') as service_role
  from pg_proc p
  where p.pronamespace = 'public'::regnamespace
) f`;

const functions = JSON.parse(
  execFileSync(
    "docker",
    ["exec", "-i", "supabase_db_nawadir_aliibil", "psql", "-U", "postgres", "-At", "-c", SQL],
    { encoding: "utf8" },
  ),
);

const known = new Set(Object.keys(JSON.parse(readFileSync("contracts/api/errors.json", "utf8")).errors));
const problems = [];
const dbNames = new Set(functions.map((f) => f.name));
for (const name of Object.keys(META)) {
  if (!dbNames.has(name)) problems.push(`في META وليست في القاعدة: ${name}`);
}

const q = (text) => JSON.stringify(text);
const lines = [
  "# دوال الخلفية المتاحة عبر PostgREST (‎/rest/v1/rpc/<name>).",
  "# مولد من القاعدة المحلية بالسكربت contracts/tools/build_rpc.mjs؛ لا يعدل يدويًا.",
  "#",
  "# access:",
  "#   anon                 الزائر والمستخدم",
  "#   user                 مستخدم مسجل بحساب هاتف",
  "#   staff                أي موظف فعال بجلسة aal2",
  "#   staff:<capability>   موظف يملك القدرة (المدير يملك كل القدرات)",
  "#   service              دور الخادم فقط؛ لا يستدعيها العميل",
  "# الأخطاء: الرمز في message والتفاصيل JSON في details بحالة SQL ‏P0001؛",
  "# انظر api/errors.json. الرد jsonb ما لم يذكر غير ذلك.",
  "",
  `version: ${q(readFileSync("contracts/VERSION", "utf8").trim())}`,
  "functions:",
];

for (const f of functions) {
  const meta = META[f.name];
  if (!meta) {
    problems.push(`في القاعدة ودون بيانات في META: ${f.name}`);
    continue;
  }
  const expected = {
    anon: meta.access === "anon",
    authenticated: meta.access !== "service",
    service_role: true,
  };
  for (const role of ["anon", "authenticated", "service_role"]) {
    if (f[role] !== expected[role]) {
      problems.push(`${f.name}: صلاحية ${role} في القاعدة ${f[role]} وتوثيقها ${expected[role]}`);
    }
  }
  for (const code of meta.errors) {
    if (!known.has(code)) problems.push(`${f.name}: رمز خطأ غير معرف في errors.json: ${code}`);
  }
  if (!f.description) problems.push(`${f.name}: دون تعليق وصف في القاعدة`);

  lines.push(`  ${f.name}:`);
  lines.push(`    description: ${q(f.description)}`);
  lines.push(`    access: ${q(meta.access)}`);
  lines.push(`    arguments: ${q(f.arguments)}`);
  lines.push(`    returns: ${q(f.returns)}`);
  lines.push(`    errors: [${meta.errors.join(", ")}]`);
  if (meta.idempotency) lines.push(`    idempotency: ${q(meta.idempotency)}`);
  if (meta.note) lines.push(`    note: ${q(meta.note)}`);
  lines.push(`    requirement: ${q(meta.req)}`);
  lines.push(`    since: ${q(meta.since)}`);
}

if (problems.length > 0) {
  console.error(problems.join("\n"));
  process.exit(1);
}

writeFileSync("contracts/api/rpc.yaml", lines.join("\n") + "\n");
console.log(`rpc.yaml: ${functions.length} دالة`);
