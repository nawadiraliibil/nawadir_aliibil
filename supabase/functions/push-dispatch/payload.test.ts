import { assert, assertEquals, assertFalse } from "jsr:@std/assert@1";

import { buildMessage, isInvalidTokenResponse, type PushJob } from "./payload.ts";

const job: PushJob = {
  outbox_id: 1,
  notification_id: "n-1",
  category: "MESSAGES",
  event: "message.received",
  resource_type: "conversation",
  resource_id: "c-1",
  tokens: ["t".repeat(30)],
};

Deno.test("رسالة الدفع عامة ولا تحمل محتوى خاصًا", () => {
  const m = buildMessage(job, job.tokens[0]).message;
  assertEquals(m.notification.title, "رسالة جديدة");
  assertEquals(m.data, {
    notification_id: "n-1",
    event: "message.received",
    resource_type: "conversation",
    resource_id: "c-1",
  });
  // لا حقول أخرى تحمل نصوصًا (مثل نص الرسالة أو العنوان).
  assertEquals(Object.keys(m.data).sort(), ["event", "notification_id", "resource_id", "resource_type"]);
});

Deno.test("حدث غير معروف يأخذ عنوانًا عامًا", () => {
  assertEquals(buildMessage({ ...job, event: "x.y" }, "t").message.notification.title, "إشعار جديد");
});

Deno.test("الرمز غير الصالح يُعرف من رد المزود", () => {
  assert(isInvalidTokenResponse(404, {}));
  assert(isInvalidTokenResponse(400, { error: { details: [{ errorCode: "UNREGISTERED" }] } }));
  assertFalse(isInvalidTokenResponse(500, {}));
  assertFalse(isInvalidTokenResponse(429, { error: { details: [{ errorCode: "QUOTA_EXCEEDED" }] } }));
});
