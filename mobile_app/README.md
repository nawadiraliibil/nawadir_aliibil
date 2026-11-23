# نوادر الإبل — تطبيق الجوال

تطبيق Flutter واحد المصدر لـAndroid وiOS، عربي باتجاه RTL، يتصل بخلفية Supabase المشتركة في `../supabase`. هذا المجلد يملكه جانب `MOBILE`؛ اقرأ `AGENTS.md` هنا و`../AGENTS.md` قبل أي تعديل.

- معرف التطبيق: `com.nawadiraliibil.app`
- مرجع التصميم: `../docs/shared/stitch-distinct-20261121/`
- المتطلبات: `../Nawader_AlIbil_SRS_Ads_AR.md` (مع القسم 13: تعديلات النطاق)
- العقد مع الخلفية: `../contracts/`

## المتطلبات

| الأداة | الملاحظة |
|---|---|
| Flutter | أنشئ المشروع على 3.41.6 (Dart 3.11.4). الإصدارات مثبتة في `pubspec.lock` |
| Android SDK | لبناء وتشغيل Android |
| macOS و Xcode | لبناء iOS؛ لا يبنى iOS من Windows |

## ملف البيئة

التطبيق يقرأ إعداداته وقت البناء من ملف JSON:

```bash
cp env/dev.example.json env/dev.json   # ثم املأ القيم
```

| المفتاح | المعنى |
|---|---|
| `SUPABASE_URL` | عنوان مشروع Supabase |
| `SUPABASE_PUBLISHABLE_KEY` | المفتاح العام للعميل فقط |
| `APP_ENV` | اسم البيئة، مثل `dev` |
| `SHARE_BASE_URL` | أساس روابط المشاركة العامة؛ فارغ إلى أن يحدد النطاق (INT-005) |

`env/*.json` مستثنى من git عدا ملفات `*.example.json`. لا يوضع مفتاح `service_role` أو أي مفتاح سري في هذا الملف؛ التطبيق يرفض التشغيل به ويعرض تحذيرًا. إذا شغل التطبيق دون ملف بيئة يعرض تعليمات الإعداد بدل الاتصال.

## الأوامر

من داخل `mobile_app/`:

```bash
flutter pub get
flutter run --dart-define-from-file=env/dev.json

# الفحوص قبل أي تسليم
dart format --set-exit-if-changed .
flutter analyze
flutter test

# توليد شيفرة freezed و json_serializable عند تغيير النماذج
dart run build_runner build --delete-conflicting-outputs

# بناء Android للتجربة
flutter build apk --debug --dart-define-from-file=env/dev.json
```

## البنية

```
lib/
  main.dart
  app/        تهيئة التطبيق، المسارات، الهيكل، السمة
  core/       ما تشترك فيه الميزات: البيئة، عميل Supabase، الأخطاء، الإعدادات، المكونات
  features/   ميزة لكل مجلد: data/ (الوصول للبيانات) ، domain/ (النماذج وواجهات المستودعات) ، presentation/ (الحالة والشاشات)
test/         اختبارات الوحدة والواجهات؛ تطابق مسارات lib/
```

قواعد الشيفرة:

- الواجهة لا تستدعي Supabase مباشرة؛ تمر بواجهة مستودع في `domain/` وتنفيذها في `data/`.
- إدارة الحالة بـRiverpod بمزودات مكتوبة يدويًا. مولد Riverpod غير مستخدم لأنه يشترط إصدار `meta` أحدث مما يثبته Flutter 3.41.6.
- لا تعرض رسالة نجاح قبل تأكيد الخادم، ولا يتحول الضغط المتكرر إلى طلب مكرر (SRS القسم 7).
- النماذج تطابق `../contracts/`؛ اختبارات `test/contracts/` تتحقق من ذلك عند وجود عقد منشور.

## الحالة

المنجز والمخطط في `../docs/shared/PROGRESS.md` تحت `MOBILE-PLAN-20261122`.

المنفذ حتى الآن: السمة بالوضعين والخطان، هيكل التبويبات الأربعة مع كبسولة التنقل وزر «إعلان»، وشاشة البداية بانتقالها إلى شعار الترويسة. محتوى التبويبات شاشات مؤقتة تحمل عبارة «قيد التنفيذ» ومعرف المهمة التي ستنفذها؛ ليست من التصميم المعتمد.
