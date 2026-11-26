// اختبار تكامل send-sms على الخلفية المحلية — MOBILE-BE-SMS-TAQNYAT-20261126
//
// يثبت السلسلة كاملة دون إرسال فعلي: العميل يطلب رمزًا من Supabase Auth ← Auth يستدعي
// الـhook موقّعًا ← الدالة ترسل إلى خادم يحاكي واجهة تقنيات هنا ← نقرأ الرمز من الرسالة
// ونتحقق به فتفتح جلسة. لا يثبت الوصول الفعلي للجوال؛ ذلك يحتاج حساب تقنيات حقيقيًا.
//
// المتطلبات (انظر supabase/README.md):
//   1. `[auth.hook.send_sms]` مفعّل في config.toml، وSEND_SMS_HOOK_SECRETS في البيئة قبل
//      `supabase start`.
//   2. `supabase functions serve --env-file <ملف>` وفيه السر نفسه مع:
//        TAQNYAT_BEARER_TOKEN=mock-token   TAQNYAT_SENDER=MockSender
//        TAQNYAT_API_URL=http://host.docker.internal:54399
// التشغيل من جذر المستودع:
//   node supabase/tests/functions/send_sms.integration.mjs
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import { createServer } from "node:http";

const MOCK_PORT = 54399;
// رقم وهمي بصيغة جوال سعودي، خارج أرقام test_otp حتى يمر بالـhook.
const PHONE = `9665${String(Date.now()).slice(-8)}`;

const env = Object.fromEntries(
  execSync("supabase status -o env", { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] })
    .split(/\r?\n/)
    .map((line) => line.match(/^([A-Z_]+)="?(.*?)"?$/))
    .filter(Boolean)
    .map((m) => [m[1], m[2]]),
);
const API = env.API_URL;
const ANON = env.ANON_KEY;
const SERVICE = env.SERVICE_ROLE_KEY;
assert.ok(API && ANON && SERVICE, "تعذر قراءة مفاتيح الخلفية المحلية من supabase status");

const received = [];
let reply = (phone) => ({
  status: 201,
  body: { statusCode: 201, messageId: 1, cost: 0.026, currency: "SAR", accepted: `[${phone},]`, rejected: "[]" },
});
const mock = createServer((req, res) => {
  let raw = "";
  req.on("data", (chunk) => (raw += chunk));
  req.on("end", () => {
    const body = JSON.parse(raw || "{}");
    received.push({ method: req.method, url: req.url, authorization: req.headers.authorization, body });
    const out = reply(String(body.recipients?.[0]));
    res.writeHead(out.status, { "Content-Type": "application/json" });
    res.end(JSON.stringify(out.body));
  });
});
await new Promise((resolve) => mock.listen(MOCK_PORT, "0.0.0.0", resolve));

const auth = (path, body, key = ANON) =>
  fetch(`${API}/auth/v1/${path}`, {
    method: "POST",
    headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

let userId;
try {
  // 1) طلب الرمز يمر بالـhook ويصل إلى «تقنيات» بالصيغة الموثقة.
  const otpRes = await auth("otp", { phone: `+${PHONE}` });
  assert.equal(otpRes.status, 200, `طلب الرمز: ${otpRes.status} ${await otpRes.clone().text()}`);
  assert.equal(received.length, 1, "لم يصل طلب واحد إلى خادم المحاكاة");
  const sent = received[0];
  assert.equal(sent.method, "POST");
  assert.equal(sent.url, "/v1/messages");
  assert.equal(sent.authorization, "Bearer mock-token");
  assert.deepEqual(sent.body.recipients, [PHONE]);
  assert.equal(sent.body.sender, "MockSender");
  const match = sent.body.body.match(/^رمز التحقق في نوادر الإبل: (\d{6})$/);
  assert.ok(match, `نص الرسالة غير متوقع: ${sent.body.body}`);

  // 2) الرمز المرسل هو ما يتحقق به Auth، وتفتح جلسة لصاحب الرقم.
  const verifyRes = await auth("verify", { phone: `+${PHONE}`, token: match[1], type: "sms" });
  const session = await verifyRes.json();
  assert.equal(verifyRes.status, 200, `التحقق: ${verifyRes.status} ${JSON.stringify(session)}`);
  assert.ok(session.access_token, "لا جلسة بعد التحقق");
  assert.equal(session.user.phone, PHONE);
  userId = session.user.id;

  // 3) فشل المزود لا يعلن نجاحًا وهميًا: طلب الرمز يفشل عند العميل.
  reply = () => ({ status: 400, body: { statusCode: 400, message: "Your balance is not enough" } });
  const other = `9665${String(Date.now() + 1).slice(-8)}`;
  const failRes = await auth("otp", { phone: `+${other}` });
  const failBody = await failRes.text();
  assert.ok(failRes.status >= 400, `فشل المزود أعاد ${failRes.status}`);
  console.log(`فشل المزود عند العميل: ${failRes.status} ${failBody}`);

  // 4) الدالة لا تقبل طلبًا غير موقّع.
  const unsigned = await fetch(`${API}/functions/v1/send-sms`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ user: { phone: PHONE }, sms: { otp: "123456" } }),
  });
  assert.equal(unsigned.status, 401);
  assert.equal(received.length, 2, "طلب غير موقّع وصل إلى المزود");

  console.log("send-sms: اختبار التكامل ناجح");
} finally {
  mock.close();
  if (userId) {
    await fetch(`${API}/auth/v1/admin/users/${userId}`, {
      method: "DELETE",
      headers: { apikey: SERVICE, Authorization: `Bearer ${SERVICE}` },
    });
  }
}
