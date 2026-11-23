# حالات الإعلان والنسخة وانتقالاتها

المرجع: SRS القسم 6، TEAM-DEC-011. الحالة لا تعدل من العميل مباشرة؛ كل انتقال دالة في `rpc.yaml`.

## حالات الإعلان (`listing_status`)

| من | الدالة | إلى | المنفذ | ملاحظات |
|---|---|---|---|---|
| — | `create_listing_draft` | `DRAFT` | المعلن | نسخة 1 مسودة |
| `DRAFT` | `submit_listing` | `UNDER_REVIEW` | المعلن | يشترط ملفًا مكتملًا وموافقة ووسائط جاهزة |
| `PUBLISHED` (بمسودة تعديل) | `submit_listing` | `UNDER_REVIEW` | المعلن | يختفي عن العامة حتى الاعتماد |
| `UNDER_REVIEW` | `admin_approve_listing_version` | `PUBLISHED` | `listings.review` | يرفض لحساب معلق ولمزاد مضى موعده |
| `UNDER_REVIEW` | `admin_reject_listing_version` | `REJECTED` | `listings.review` | بسبب إلزامي؛ رفض تعديل منشور لا يستعيد النسخة السابقة |
| `PUBLISHED` | `start_listing_edit` | `PUBLISHED` | المعلن | تنشأ مسودة خاصة؛ المنشور باق كما هو |
| `PUBLISHED` | `discard_listing_edit` | `PUBLISHED` | المعلن | تحذف مسودة التعديل |
| `REJECTED` أو `ARCHIVED` | `start_listing_edit` | `DRAFT` | المعلن | المعرف نفسه بنسخة جديدة |
| `PUBLISHED` | `archive_listing` | `ARCHIVED` | المعلن | |
| `PUBLISHED` | `admin_hide_listing` | `HIDDEN` | `listings.hide` | بسبب إلزامي |
| `PUBLISHED` | `admin_suspend_account` | `HIDDEN` | `accounts.manage` | لكل إعلانات الحساب المنشورة |
| `HIDDEN` | `admin_unhide_listing` | `PUBLISHED` | `listings.hide` | يرفض إن كان حساب المعلن معلقًا |
| `DRAFT` أو `REJECTED` | `delete_listing` | (محذوف) | المعلن | ما أرسل للمراجعة يومًا يحذف منطقيًا |

لا يستطيع المعلن الخروج من `HIDDEN` أو `UNDER_REVIEW`. تفعيل حساب معلق لا يعيد نشر إعلاناته.

## حالات النسخة (`listing_version_status`)

`DRAFT` ← (إرسال) ← `SUBMITTED` ← (قرار) ← `APPROVED` أو `REJECTED`.

- المسودة وحدها تتغير. نسخة غير مسودة ووسائطها ثابتة؛ محاولة تغييرها ترفع `VERSION_IMMUTABLE`.
- لكل إعلان مسودة واحدة ونسخة واحدة قيد المراجعة على الأكثر.
- `content_hash` يحسب عند الإرسال من حقول المحتوى والوسائط. دالتا الاعتماد والرفض تستقبلان `version_id` و`content_hash` كما أعادتهما `admin_get_listing_review`، وتفشلان بـ`VERSION_CHANGED` عند الاختلاف.
- `current_version_id`: المسودة إن وجدت، وإلا آخر نسخة مرسلة أو مقررة. `published_version_id`: النسخة المعتمدة المعروضة للعامة.

## الأوقات

كل الأوقات UTC بصيغة ISO 8601، وتعرض بتوقيت `Asia/Riyadh`.

| العمود | يتغير عند |
|---|---|
| `first_submitted_at` | أول إرسال للمراجعة؛ مرجع حد الإعلانات الجديدة (5 كل 24 ساعة) |
| `first_published_at` | أول اعتماد فقط |
| `published_version_at` | كل اعتماد نسخة |
| `last_published_at` | كل انتقال إلى `PUBLISHED` (اعتماد أو إعادة إظهار) |
| `last_bumped_at` | كل تجديد ظهور مقبول |
| `visibility_updated_at` | أول نشر، ثم كل تجديد ظهور؛ مفتاح الترتيب الافتراضي مع `listing_id` لفك التعادل |

تجديد الظهور يستحق بعد `bump.interval_hours` (24 على الأقل) من الأحدث بين `last_published_at` و`last_bumped_at`، بوقت الخادم. تعديل المحتوى وإعادة النشر لا يرفعان الترتيب، وإعادة النشر تؤخر استحقاق التجديد.

## المزاد الحضوري

`auction_starts_at` يجب أن يكون مستقبليًا عند الإرسال وعند الاعتماد (`AUCTION_TIME_PASSED`). بعد مرور الموعد يبقى الإعلان منشورًا وقابلًا للفتح، ويعيد `auction_passed = true`، ولا يجدد ظهوره. لا حالة بيع أو فائز.
