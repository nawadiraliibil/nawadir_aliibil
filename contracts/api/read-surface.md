# سطح القراءة

ما يقرؤه كل دور عبر PostgREST (`/rest/v1/<relation>`). لا كتابة مباشرة لأي دور عميل على أي جدول؛ الكتابة عبر دوال `rpc.yaml`. الأعمدة الدقيقة وأنواعها في `generated/database.types.ts`، وأعمدة الـviews مثبتة باختبار pgTAP.

## الزائر والمستخدم

| العلاقة | ما تعرضه |
|---|---|
| `regions`، `cities`، `breeds` | القيم الفعالة فقط |
| `public_listing_cards` | بطاقات الإعلانات المنشورة من نسختها المعتمدة |
| `public_listing_details` | تفاصيل الإعلان المنشور، ومنها رقم التواصل المنشور وقنواته |
| `public_listing_media` | الوسائط الجاهزة للنسخة المعتمدة لإعلان منشور |
| `public_ratings` | التقييمات الظاهرة وردود المعلنين؛ المخفي لا يظهر |
| `public_comments` | ردود إعلان منشور؛ `state` المخفي والمحذوف بلا نص |
| `public_profiles` | اسم العرض والمنطقة وتاريخ الانضمام وعدد الإعلانات المنشورة ومتوسط التقييم الظاهر وعدده (`rating_avg`، `rating_count`) |

- إعلان غير منشور (مسودة، قيد المراجعة، مرفوض، مخفي، مؤرشف) لا يعيد صفًا حتى بطلب مباشر بمعرفه؛ يعرض العميل «الإعلان غير متاح» دون سبب.
- الترتيب الافتراضي للبطاقات: `visibility_updated_at` تنازليًا ثم `listing_id`. البحث والمرشحات والفرز والتصفح على دفعات عبر الدالة `search_listings` (من 0.2.0)؛ والتفاصيل مع الوسائط وحالة المفضلة عبر `get_listing`؛ وترجمة `public_ref` في رابط المشاركة عبر `resolve_listing_ref`. `public_ref` عمود في `public_listing_cards` و`public_listing_details` (من 0.2.0).
- لا هاتف دخول في أي علاقة عامة. `contact_phone` رقم أدخله المعلن لهذا الإعلان.
- الإعدادات والقوائم مجتمعة من `get_published_settings()`، ونصوص السياسات من `get_current_policies()`.

## المستخدم المسجل (صفوفه فقط)

| العلاقة | ما تعرضه |
|---|---|
| `my_conversations` | محادثاته مع آخر رسالة وغير المقروء و`writable` و`listing_available` (محتوى الإعلان المحجوب فارغ) |
| `conversations`، `messages` | محادثاته ورسائلها (طرفا المحادثة فقط، وتنشر `messages` عبر Realtime) |
| `my_blocks` / `user_blocks` | من حظرهم |
| `my_saved_searches`، `saved_searches` | عمليات بحثه المحفوظة |
| `my_follows`، `follows` | معلنوه المتابَعون |
| `my_notification_preferences`، `notification_preferences` | تفضيلات الدفع لكل فئة (الافتراضي مفعل) |
| `my_received_ratings` | تقييماته كمعلن بحالتها (ومنها المخفي) وردّه واعتراضه |
| `my_favorites` | مفضلته بالأحدث حفظًا؛ `available=false` للإعلان الذي لم يعد منشورًا وبقية أعمدته فارغة |
| `favorites` | صفوف مفضلته (معرف الإعلان وتاريخ الحفظ) |
| `my_listings` | إعلاناته بكل حالاتها من نسختها الحالية، مع سبب الرفض أو الإخفاء و`next_bump_at` |
| `profiles` | صفه |
| `policy_consents` | موافقاته |
| `listings`، `listing_versions`، `media` | إعلاناته غير المحذوفة ونسخها ووسائطها |
| `listing_bumps` | تجديداته |
| `notifications` | إشعاراته |
| `moderation_reasons` | الأسباب الفعالة (تسميات) |

## الموظف (جلسة `aal2`، بحسب القدرة)

| القدرة | العلاقات |
|---|---|
| `listings.review` | `listings`، `listing_versions`، `media`، `reviews`، `listing_bumps` |
| `listings.hide` | `listings`، `listing_versions`، `media`، `reviews` |
| `accounts.manage` | `profiles` |
| `lookups.manage` | القيم المعطلة في `regions` و`cities` و`breeds` و`moderation_reasons` |
| `settings.manage` | `settings_versions`، `platform_settings` |
| `staff.manage` | `admin_roles` (ولكل موظف صفه) |
| `audit.read` | `audit_log`، `report_evidence_access` |
| `reports.handle` | `reports` |
| `ratings.moderate` | `seller_ratings`، `seller_rating_history`، `rating_replies`، `rating_appeals` |

هاتف دخول المستخدم لا يقرأ من جدول؛ تعيده `admin_get_account` لمن يملك `accounts.manage`. جلسة موظف دون `aal2` لا تقرأ شيئًا من هذه القراءات الإدارية.

## مغلق أمام كل أدوار العميل

`policy_documents`، `notification_outbox`، `comments` (القراءة العامة عبر `public_comments`)، `device_tokens`، ومخطط `private` كله.
