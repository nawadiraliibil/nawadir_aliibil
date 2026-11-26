// يعمل بـNode 24 (`node --test supabase/functions/send-sms/handler.test.ts`) وبـDeno (`deno test`).
import assert from "node:assert/strict";
import { test } from "node:test";

import { type Deps, handle } from "./handler.ts";
import { maskPhone, otpMessage, readSendResponse, saudiMobile } from "./taqnyat.ts";
import { sign, verifyWebhook } from "./webhook.ts";

// سر اختباري ثابت وليس سرًا حقيقيًا.
const SECRET = `v1,whsec_${btoa("local-test-secret-0123456789abcdef")}`;
const NOW = 1_800_000_000_000;
const PHONE = "966512345678";
const OTP = "482913";

interface Call {
  url: string;
  headers: Record<string, string>;
  body: Record<string, unknown>;
}

function setup(
  respond: () => Response | Promise<Response> = () =>
    Response.json(
      { statusCode: 201, messageId: 5452899970, accepted: `[${PHONE},]`, rejected: "[]" },
      { status: 201 },
    ),
  env: Record<string, string | undefined> = {},
) {
  const calls: Call[] = [];
  const logs: string[] = [];
  const vars: Record<string, string | undefined> = {
    SEND_SMS_HOOK_SECRETS: SECRET,
    TAQNYAT_BEARER_TOKEN: "test-token",
    TAQNYAT_SENDER: "Nawader",
    ...env,
  };
  const deps: Deps = {
    env: (name) => vars[name],
    now: () => NOW,
    log: (line) => logs.push(line),
    fetch: ((url: string | URL | Request, init?: RequestInit) => {
      calls.push({
        url: String(url),
        headers: init?.headers as Record<string, string>,
        body: JSON.parse(String(init?.body)),
      });
      return Promise.resolve(respond());
    }) as typeof fetch,
  };
  return { deps, calls, logs };
}

async function signed(
  payload: unknown,
  opts: { secret?: string; timestampMs?: number; tamper?: boolean } = {},
): Promise<Request> {
  const text = JSON.stringify(payload);
  const id = "msg_test";
  const timestamp = String(Math.floor((opts.timestampMs ?? NOW) / 1000));
  const signature = await sign(opts.secret ?? SECRET, id, timestamp, text);
  return new Request("http://localhost/functions/v1/send-sms", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "webhook-id": id,
      "webhook-timestamp": timestamp,
      "webhook-signature": `v1,${signature}`,
    },
    body: opts.tamper ? text.replace(OTP, "000000") : text,
  });
}

const event = (phone: string = PHONE, otp: string = OTP) => ({ user: { id: "u-1", phone }, sms: { otp } });

test("طلب موقّع يرسل الرمز إلى تقنيات بالصيغة الموثقة", async () => {
  const { deps, calls } = setup();
  const res = await handle(await signed(event()), deps);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), {});
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, "https://api.taqnyat.sa/v1/messages");
  assert.equal(calls[0].headers.Authorization, "Bearer test-token");
  assert.deepEqual(calls[0].body, {
    recipients: [PHONE],
    body: "رمز التحقق في نوادر الإبل: 482913",
    sender: "Nawader",
  });
});

test("السجل لا يحمل الرمز ولا الرقم كاملًا ولا رمز الوصول", async () => {
  const { deps, logs } = setup();
  await handle(await signed(event()), deps);
  const all = logs.join("\n");
  assert.ok(all.includes("9665****78"));
  assert.ok(!all.includes(OTP));
  assert.ok(!all.includes(PHONE));
  assert.ok(!all.includes("test-token"));
});

test("توقيع خاطئ أو جسم معدّل أو طابع قديم أو رؤوس ناقصة: رفض دون إرسال", async () => {
  const other = `v1,whsec_${btoa("another-secret-another-secret-00")}`;
  const cases: Request[] = [
    await signed(event(), { secret: other }),
    await signed(event(), { tamper: true }),
    await signed(event(), { timestampMs: NOW - 6 * 60 * 1000 }),
    new Request("http://localhost/", { method: "POST", body: JSON.stringify(event()) }),
  ];
  for (const req of cases) {
    const { deps, calls } = setup();
    const res = await handle(req, deps);
    assert.equal(res.status, 401);
    assert.equal((await res.json()).error.message, "invalid_signature");
    assert.equal(calls.length, 0);
  }
});

test("تدوير المفاتيح: يكفي تطابق أحد الأسرار", async () => {
  const old = `v1,whsec_${btoa("old-secret-old-secret-old-secret")}`;
  const { deps, calls } = setup(undefined, { SEND_SMS_HOOK_SECRETS: `${SECRET}|${old}` });
  assert.equal((await handle(await signed(event(), { secret: old }), deps)).status, 200);
  assert.equal(calls.length, 1);
});

test("أسرار ناقصة: 500 مع أسماء المتغيرات في السجل دون قيم", async () => {
  const { deps, calls, logs } = setup(undefined, { TAQNYAT_SENDER: undefined });
  const res = await handle(await signed(event()), deps);
  assert.equal(res.status, 500);
  assert.equal((await res.json()).error.message, "sms_not_configured");
  assert.ok(logs[0].includes("TAQNYAT_SENDER"));
  assert.ok(!logs[0].includes("TAQNYAT_BEARER_TOKEN"));
  assert.equal(calls.length, 0);
});

test("غير POST يرفض", async () => {
  const { deps } = setup();
  assert.equal((await handle(new Request("http://localhost/"), deps)).status, 405);
});

test("رقم غير سعودي أو رمز غير رقمي: 400 دون إرسال", async () => {
  for (const payload of [event("201001234567"), event("966112345678"), event(PHONE, "12ab56"), { user: {} }]) {
    const { deps, calls } = setup();
    const res = await handle(await signed(payload), deps);
    assert.equal(res.status, 400);
    assert.equal(calls.length, 0);
  }
});

test("رفض تقنيات (رصيد، مرسل، بيانات اعتماد) يعيد 502 ويسجل سبب المزود", async () => {
  const { deps, logs } = setup(() =>
    Response.json({ statusCode: 400, message: "Your balance is not enough" }, { status: 400 })
  );
  const res = await handle(await signed(event()), deps);
  assert.equal(res.status, 502);
  assert.deepEqual(await res.json(), { error: { http_code: 502, message: "sms_send_failed" } });
  assert.ok(logs.at(-1)?.includes("taqnyat 400 Your balance is not enough"));
});

test("تعذر الوصول إلى تقنيات يعيد 502", async () => {
  const { deps, logs } = setup(() => {
    throw new TypeError("fetch failed");
  });
  assert.equal((await handle(await signed(event()), deps)).status, 502);
  assert.ok(logs.at(-1)?.includes("provider_unreachable"));
});

test("عنوان تقنيات البديل للاختبار", async () => {
  const { deps, calls } = setup(undefined, { TAQNYAT_API_URL: "http://127.0.0.1:9999/" });
  await handle(await signed(event()), deps);
  assert.equal(calls[0].url, "http://127.0.0.1:9999/v1/messages");
});

test("قراءة رد تقنيات: المرفوض فشل ولو كان الرد 201", () => {
  assert.deepEqual(readSendResponse(201, { messageId: 7, accepted: `[${PHONE},]`, rejected: "[]" }, PHONE), {
    ok: true,
    messageId: "7",
  });
  assert.equal(readSendResponse(201, { accepted: "[]", rejected: `[${PHONE},]` }, PHONE).ok, false);
  assert.equal(readSendResponse(201, { accepted: "[]", rejected: "[]" }, PHONE).ok, false);
  assert.deepEqual(readSendResponse(401, { message: "invalid credentials information" }, PHONE), {
    ok: false,
    status: 401,
    reason: "invalid credentials information",
  });
  assert.equal(readSendResponse(201, null, PHONE).ok, true);
});

test("تطبيع الرقم السعودي والإخفاء والنص", () => {
  assert.equal(saudiMobile("+966512345678"), PHONE);
  assert.equal(saudiMobile("00966512345678"), PHONE);
  assert.equal(saudiMobile(PHONE), PHONE);
  assert.equal(saudiMobile("0512345678"), null);
  assert.equal(saudiMobile("9665123456789"), null);
  assert.equal(saudiMobile(undefined), null);
  assert.equal(maskPhone(PHONE), "9665****78");
  assert.equal(otpMessage("123456"), "رمز التحقق في نوادر الإبل: 123456");
});

test("سر تالف يعد خطأ إعداد لا توقيعًا خاطئًا", async () => {
  const headers = new Headers({
    "webhook-id": "a",
    "webhook-timestamp": String(NOW / 1000),
    "webhook-signature": "v1,AAAA",
  });
  assert.deepEqual(await verifyWebhook("{}", headers, "v1,whsec_%%%", NOW), { ok: false, reason: "bad_secret" });
});
