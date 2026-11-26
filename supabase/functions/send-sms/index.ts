// send-sms — MOBILE-BE-SMS-TAQNYAT-20261126
// Send SMS Hook لـSupabase Auth: يستلم رمز التحقق الذي أصدره Auth ويرسله برسالة نصية
// عبر منصة تقنيات (Taqnyat). Auth يبقى مسؤولًا عن إصدار الرمز والتحقق منه والجلسات
// والحدود (DEC-04)؛ هذه الدالة ناقل إرسال فقط. لا يستدعيها العميل: الطلب يُقبل بتوقيع
// Standard Webhooks فقط، لذلك تنشر بـ`verify_jwt = false`.
//
// الأسرار (supabase secrets set):
//   SEND_SMS_HOOK_SECRETS   سر الـhook كما يظهر في لوحة Auth › Hooks (`v1,whsec_…`)
//   TAQNYAT_BEARER_TOKEN    رمز تطبيق SMS من بوابة تقنيات
//   TAQNYAT_SENDER          اسم المرسل المعتمد في حساب تقنيات (حساس لحالة الأحرف)
//   TAQNYAT_API_URL         اختياري؛ للاختبار بخادم بديل. الافتراضي https://api.taqnyat.sa
//
// أرقام `[auth.sms.test_otp]` لا تمر بالـhook. الأرقام غير السعودية ترفض.
import { handle } from "./handler.ts";

Deno.serve((req: Request) =>
  handle(req, {
    env: (name) => Deno.env.get(name),
    fetch,
    now: () => Date.now(),
    log: (line) => console.log(line),
  })
);
