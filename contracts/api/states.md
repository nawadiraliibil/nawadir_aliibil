# حالات الإعلان والنسخة وانتقالاتها

المرجع: SRS القسم 6، TEAM-DEC-011. الحالة لا تعدل من العميل مباشرة؛ كل انتقال دالة في `rpc.yaml`.

## حالات الإعلان (`listing_status`)

| من | الدالة | إلى | المنفذ | ملاحظات |
|---|---|---|---|---|
| — | `create_listing_draft` | `DRAFT` | المعلن | نسخة 1 مسودة |
| `DRAFT` | `submit_listing` | `PUBLISHED` | المعلن | ينشر مباشرة (1.2.0، TEAM-DEC-013)؛ يشترط ملفًا مكتملًا وموافقة ووسائط جاهزة وموعد مزاد مستقبليًا وحد 5/24 ساعة |
| `PUBLISHED` (بمسودة تعديل) | `submit_listing` | `PUBLISHED` | المعلن | النسخة الجديدة هي المنشورة فورًا؛ لا يختفي الإعلان ولا يرتفع ترتيبه |
| `PUBLISHED` | `start_listing_edit` | `PUBLISHED` | المعلن | تنشأ مسودة خاصة؛ المنشور باق كما هو |
| `PUBLISHED` | `discard_listing_edit` | `PUBLISHED` | المعلن | تحذف مسودة التعديل |
| `REJECTED` أو `ARCHIVED` | `start_listing_edit` | `DRAFT` | المعلن | المعرف نفسه بنسخة جديدة |
| `PUBLISHED` | `archive_listing` | `ARCHIVED` | المعلن | |
| `PUBLISHED` | `admin_hide_listing` | `HIDDEN` | `listings.hide` | بسبب إلزامي |
| `PUBLISHED` | `admin_suspend_account` | `HIDDEN` | `accounts.manage` | لكل إعلانات الحساب المنشورة |
| `HIDDEN` | `admin_unhide_listing` | `PUBLISHED` | `listings.hide` | يرفض إن كان حساب المعلن معلقًا |
| `DRAFT` أو `REJECTED` | `delete_listing` | (محذوف) | المعلن | ما أرسل يومًا يحذف منطقيًا |

لا يستطيع المعلن الخروج من `HIDDEN` ولا تعديله أو نشره. تفعيل حساب معلق لا يعيد نشر إعلاناته.

**ملغاة منذ 1.2.0:** `UNDER_REVIEW` (لا إعلان يدخلها؛ قيد قاعدة يمنعها) و`REJECTED` (لا إعلان جديد يدخلها؛ قديمها يبقى ويعود مسودة بـ`start_listing_edit`). `admin_approve_listing_version` و`admin_reject_listing_version` مهملتان ترفعان `INVALID_STATE`. التحكم الإداري بالظهور هو الإخفاء وإعادة الإظهار فقط.

## حالات النسخة (`listing_version_status`)

`DRAFT` ← (إرسال) ← `APPROVED` مباشرة (منذ 1.2.0). `SUBMITTED` و`REJECTED` للنسخة باقيتان للتوافق وللبيانات القديمة ولا تنتجان.

- المسودة وحدها تتغير. نسخة غير مسودة ووسائطها ثابتة؛ محاولة تغييرها ترفع `VERSION_IMMUTABLE`.
- لكل إعلان مسودة واحدة على الأكثر.
- `content_hash` يحسب عند الإرسال من حقول المحتوى والوسائط ويحفظ للتدقيق.
- `current_version_id`: المسودة إن وجدت، وإلا آخر نسخة مرسلة أو مقررة. `published_version_id`: النسخة المعتمدة المعروضة للعامة.

## الأوقات

كل الأوقات UTC بصيغة ISO 8601، وتعرض بتوقيت `Asia/Riyadh`.

| العمود | يتغير عند |
|---|---|
| `first_submitted_at` | أول إرسال (ينشر مباشرة)؛ مرجع حد الإعلانات الجديدة (5 كل 24 ساعة) |
| `first_published_at` | أول نشر فقط (عند أول إرسال ناجح) |
| `published_version_at` | كل نشر نسخة (إرسال أول أو تعديل) |
| `last_published_at` | كل انتقال إلى `PUBLISHED` (أول نشر أو إعادة إظهار)؛ تعديل المنشور لا يغيره |
| `last_bumped_at` | كل تجديد ظهور مقبول |
| `visibility_updated_at` | أول نشر، ثم كل تجديد ظهور؛ مفتاح الترتيب الافتراضي مع `listing_id` لفك التعادل |

تجديد الظهور يستحق بعد `bump.interval_hours` (24 على الأقل) من الأحدث بين `last_published_at` و`last_bumped_at`، بوقت الخادم. تعديل المحتوى وإعادة الإظهار لا يرفعان الترتيب، وإعادة النشر تؤخر استحقاق التجديد.

## المزاد الحضوري

`auction_starts_at` يجب أن يكون مستقبليًا عند الإرسال (`VALIDATION_FAILED` بحقل `auction_starts_at`). بعد مرور الموعد يبقى الإعلان منشورًا وقابلًا للفتح، ويعيد `auction_passed = true`، ولا يجدد ظهوره. لا حالة بيع أو فائز.
