// منطق Send SMS Hook مفصولًا عن Deno.serve ليختبر بـfetch مزيف.
import { maskPhone, saudiMobile, sendOtpSms, TAQNYAT_DEFAULT_BASE_URL } from "./taqnyat.ts";
import { verifyWebhook } from "./webhook.ts";

export interface Deps {
  env(name: string): string | undefined;
  fetch: typeof fetch;
  now(): number;
  log(line: string): void;
}

/** صيغة الخطأ التي يتوقعها Supabase Auth من الـhook. */
function hookError(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: { http_code: status, message } }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

export async function handle(req: Request, deps: Deps): Promise<Response> {
  if (req.method !== "POST") return hookError(405, "method not allowed");

  const secrets = deps.env("SEND_SMS_HOOK_SECRETS");
  const token = deps.env("TAQNYAT_BEARER_TOKEN");
  const sender = deps.env("TAQNYAT_SENDER");
  const missing = [
    ["SEND_SMS_HOOK_SECRETS", secrets],
    ["TAQNYAT_BEARER_TOKEN", token],
    ["TAQNYAT_SENDER", sender],
  ]
    .filter(([, value]) => !value)
    .map(([name]) => name);
  if (!secrets || !token || !sender) {
    deps.log(`send-sms: أسرار غير مضبوطة: ${missing.join(", ")}`);
    return hookError(500, "sms_not_configured");
  }

  const payload = await req.text();
  const verified = await verifyWebhook(payload, req.headers, secrets, deps.now());
  if (!verified.ok) {
    deps.log(`send-sms: رفض التوقيع (${verified.reason})`);
    return hookError(verified.reason === "bad_secret" ? 500 : 401, "invalid_signature");
  }

  let event: { user?: { phone?: unknown }; sms?: { otp?: unknown } };
  try {
    event = JSON.parse(payload);
  } catch {
    return hookError(400, "invalid_payload");
  }
  const otp = event?.sms?.otp;
  if (typeof otp !== "string" || !/^\d{4,10}$/.test(otp)) return hookError(400, "invalid_payload");

  const phone = saudiMobile(event?.user?.phone);
  if (!phone) {
    deps.log("send-sms: رقم غير سعودي أو غير صالح");
    return hookError(400, "unsupported_phone");
  }

  const result = await sendOtpSms(
    { baseUrl: deps.env("TAQNYAT_API_URL") || TAQNYAT_DEFAULT_BASE_URL, token, sender },
    phone,
    otp,
    deps.fetch,
  );
  // السجل لا يحمل الرمز ولا الرقم كاملًا ولا رمز الوصول (AD-NFR-003).
  if (!result.ok) {
    deps.log(`send-sms: فشل الإرسال إلى ${maskPhone(phone)}: taqnyat ${result.status} ${result.reason}`);
    return hookError(502, "sms_send_failed");
  }
  deps.log(`send-sms: أرسل إلى ${maskPhone(phone)} (messageId=${result.messageId ?? "-"})`);
  return new Response("{}", { status: 200, headers: { "Content-Type": "application/json" } });
}
