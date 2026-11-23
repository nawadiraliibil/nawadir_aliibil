# العقود المشتركة

العقد بين الخلفية (`supabase/`) وعملائها: تطبيق الجوال ولوحة الإدارة والموقع العام. المجلد مسند إلى جانب `MOBILE` بالقرار TEAM-DEC-007. جانب `ADMIN` يقرأ ويستورد ولا يعدل، ويسجل احتياجاته تحت INT-003 في `docs/shared/INTEGRATION.md`.

## الحالة

الإصدار في ملف `VERSION`. الإصدار `0.0.0` يعني أن لا عقد منشور بعد. ما لم يظهر هنا ليس جزءًا من العقد حتى لو ذكر في خطة أو تصميم.

الإصدار الحالي `0.1.0` (2026-11-23) يغطي المرحلة M1. `api/realtime.md` لم يصدر: لا جداول منشورة لحظيًا بعد.

## البنية المستهدفة

```
contracts/
  VERSION                إصدار العقد (semver)
  CHANGELOG.md           سجل إضافة فقط؛ كل قيد يذكر المهمة والترحيل
  api/
    enums.json           كل enum وقيمه
    errors.json          رمز الخطأ ومعناه وشكل تفاصيله ومفتاح رسالته العربية
    rpc.yaml             كل دالة: الدور أو القدرة، المدخلات، المخرجات، الأخطاء، منع التكرار، المتطلب، إصدار الإضافة
    read-surface.md      الجداول والـviews المسموح قراءتها لكل دور وأعمدتها
    storage.md           الـbuckets ونمط المسارات وقاعدة تقديم الوسائط
    realtime.md          الجداول المنشورة لحظيًا ومرشحاتها وصلاحياتها
    states.md            حالات الإعلان والنسخة وانتقالاتها وقواعد الأوقات
  schemas/               JSON Schema 2020-12 للحمولات
  fixtures/              أمثلة حمولات مطابقة للمخططات
  generated/
    database.types.ts    ناتج supabase gen types typescript؛ لا يعدل يدويًا
```

الملفات تضاف مع الترحيلات التي تنفذها؛ لا يوثق هنا ما لم ينشر.

## التوليد

من جذر المستودع، والخلفية المحلية تعمل بعد `supabase db reset`:

```bash
supabase gen types typescript --local > contracts/generated/database.types.ts
node contracts/tools/build_rpc.mjs        # api/rpc.yaml من القاعدة؛ يفشل إن اختلف التوثيق عن الصلاحيات الفعلية
node contracts/tools/build_schemas.mjs    # schemas/ من enums.json وerrors.json
node contracts/tools/build_fixtures.mjs   # fixtures/ من ردود الخادم؛ يحتاج supabase functions serve
```

`api/rpc.yaml` و`schemas/` و`fixtures/` و`generated/` مولدة ولا تعدل يدويًا. `enums.json` و`errors.json` و`events.json` وملفات Markdown تكتب يدويًا مع الترحيل الذي يغيرها.

## قواعد التغيير

| نوع التغيير | الإجراء |
|---|---|
| إضافة دالة أو حقل اختياري أو قيمة خطأ جديدة | رفع minor وقيد في `CHANGELOG.md` |
| تصحيح توثيق دون تغيير سلوك | رفع patch |
| تغيير كاسر: حذف، إعادة تسمية، تغيير نوع أو معنى، قيمة enum تزال | رفع major، ويتطلب قرارًا في `DECISIONS.md` وطلب تكامل وخطة انتقال (تعليمات الجذر، البند 4). الدالة الكاسرة تنشر باسم `name_v2` بجانب القديمة إلى أن تنتقل العملاء |

قبل أول إصدار منشور للتطبيقات (الإصدار 1.0.0) يسمح بتغييرات كاسرة ضمن الإصدارات `0.x` مع قيد واضح في السجل.

## مطابقة العملاء

- **Dart:** نماذج freezed تكتب يدويًا في `mobile_app/`. اختبارات `mobile_app/test/contracts/` تقارن الـenums ورموز الأخطاء بملفات `api/` وتحلل كل ملف في `fixtures/`.
- **TypeScript:** تستورد اللوحة `generated/database.types.ts` مباشرة.
- **قاعدة البيانات:** اختبار pgTAP يثبت قيم الـenums وأعمدة الـviews العامة.

## التحقق

```bash
supabase gen types typescript --linked > contracts/generated/database.types.ts
cd mobile_app && flutter test test/contracts
```
