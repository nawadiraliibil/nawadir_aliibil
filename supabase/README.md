# الخلفية المشتركة — Supabase

خلفية واحدة لتطبيق الجوال ولوحة الإدارة والموقع العام. المجلد مسند إلى جانب `MOBILE` بالقرار TEAM-DEC-007؛ جانب `ADMIN` يقرأ ولا يعدل، ويسجل احتياجاته تحت INT-003 في `docs/shared/INTEGRATION.md`.

## المتطلبات

| الأداة | الاستخدام |
|---|---|
| Supabase CLI | الإصدار المستخدم عند الإنشاء 2.84.2. الإصدار 3 يغير بعض الخيارات (`--linked` و`--db-url` تصير `--remote`)؛ وحّد الإصدار بين المطورين قبل الترقية وحدّث هذا الملف |
| Docker Desktop | تشغيل الخلفية محليًا واختبارات pgTAP |

## البنية

```
supabase/
  config.toml      إعداد التشغيل المحلي: دخول الهاتف، أرقام اختبارية، TOTP
  migrations/      ترحيلات قاعدة البيانات بالترتيب؛ المصدر الوحيد للمخطط
  functions/       دوال Edge (TypeScript): media-finalize، push-dispatch، send-sms
  tests/database/  اختبارات pgTAP للصلاحيات والقيود وحالات الإعلان
  scripts/admin/   سكربتات SQL تستدعي دوال admin_* إلى أن توجد لوحة الإدارة
  seed.sql         بيانات اختبار محلية دون بيانات أشخاص حقيقيين
```

## قواعد المخطط

- كل كتابة عبر دوال `SECURITY DEFINER` بـ`search_path` فارغ. أدوار العميل لا تملك `INSERT` أو `UPDATE` أو `DELETE` على أي جدول.
- الدوال المساعدة في مخطط `private` غير المكشوف للـAPI.
- القراءة العامة عبر views بأعمدة محددة فوق جداول مغلقة بـRLS.
- البيانات المرجعية (المناطق والمدن والسلالات) داخل الترحيلات، لأن `supabase db push` لا ينفذ `seed.sql`.
- كل ترحيل يصاحبه اختبار pgTAP، ويحدّث معه `contracts/`.

## الأوامر

من جذر المستودع:

```bash
# محليًا (يتطلب Docker)
supabase start                 # تشغيل الخلفية المحلية
supabase db reset              # إعادة بناء القاعدة المحلية من الترحيلات ثم seed.sql
supabase test db               # اختبارات pgTAP
supabase db lint               # فحص الدوال

# ترحيل جديد
supabase migration new <name>

# مشروع التطوير السحابي (بعد supabase link)
supabase migration list
supabase db push --dry-run
supabase db push
supabase gen types typescript --linked > contracts/generated/database.types.ts
```

## الربط بالمشروع السحابي

```bash
supabase login
supabase link --project-ref <مرجع مشروع التطوير>
```

مرجع المشروع وكلمة مرور القاعدة ورموز الوصول لا تكتب في المستودع ولا في ملفات Markdown. مجلد `supabase/.temp` وملفات `.env*.local` مستثناة من git.

المشروع السحابي الحالي بيئة تطوير (TEAM-DEC-010). مشروع الإنتاج ينشأ منفصلًا قبل الإطلاق، ولا يدفع إليه شيء دون قرار صريح.

## أرقام الاختبار المحلية

`config.toml` يعرّف أرقامًا وهمية برمز ثابت `123456` للتطوير المحلي فقط: `966500000001` إلى `966500000003`. لا تعد إرسالًا فعليًا للرسائل، ولا تستخدم في الإنتاج.

## رسائل رمز التحقق — منصة تقنيات (Taqnyat)

Supabase Auth يصدر الرمز ويتحقق منه، ويرسله عبر Send SMS Hook إلى الدالة `functions/send-sms` التي تستدعي `POST https://api.taqnyat.sa/v1/messages` (TEAM-DEC-015). الدالة تقبل طلبات Auth الموقّعة فقط (`verify_jwt = false` مع توقيع Standard Webhooks) والجوال السعودي فقط.

| السر | المصدر |
|---|---|
| `SEND_SMS_HOOK_SECRETS` | سر الـhook من لوحة Authentication › Hooks (`v1,whsec_…`؛ عند التدوير أكثر من سر بفاصل الخط العمودي) |
| `TAQNYAT_BEARER_TOKEN` | تطبيق بخدمة SMS في بوابة تقنيات |
| `TAQNYAT_SENDER` | اسم مرسل معتمد ونشط (حساس لحالة الأحرف) |
| `TAQNYAT_API_URL` | اختياري، للاختبار بخادم بديل |

على المشروع السحابي يضبط الـhook من اللوحة لا من `config.toml`؛ الخطوات في INT-006 (تحديث 2026-11-26). محليًا الـhook معلّق في `config.toml` والأرقام الاختبارية لا تمر به.

```bash
# اختبارات الوحدة (Node 24 أو deno test)
node --test supabase/functions/send-sms/handler.test.ts

# اختبار السلسلة محليًا بخادم يحاكي تقنيات (لا إرسال فعلي):
# 1) أزل التعليق عن [auth.hook.send_sms] في config.toml
# 2) ملف بيئة خارج المستودع فيه: SEND_SMS_HOOK_SECRETS=v1,whsec_<base64 عشوائي>
#    TAQNYAT_BEARER_TOKEN=mock-token  TAQNYAT_SENDER=MockSender
#    TAQNYAT_API_URL=http://host.docker.internal:54399
# 3) صدّر SEND_SMS_HOOK_SECRETS نفسه في الطرفية (أوامر CLI تطلبه ما دام الـhook مفعّلًا)
supabase stop && supabase start
supabase functions serve --env-file <ملف البيئة>
node supabase/tests/functions/send_sms.integration.mjs
# 4) أعد التعليق في config.toml ثم supabase stop && supabase start
```

## حالة التحقق

- 2026-11-22: أنشئ المجلد بـ`supabase init` وعُدل `config.toml`. لم يشغل `supabase start` بعد لغياب Docker، ولم يربط مشروع سحابي بعد. إعداد دخول الهاتف المحلي (ومنه حاجة مزود SMS مفعّل مع الأرقام الاختبارية) يتحقق منه عند أول تشغيل.
