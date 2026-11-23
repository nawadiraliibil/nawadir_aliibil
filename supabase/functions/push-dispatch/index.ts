// push-dispatch — MOBILE-BE-305
// يرسل إشعارات الدفع من طابور notification_outbox عبر FCM HTTP v1. تستدعيه مهمة
// مجدولة (pg_cron أو Supabase Cron) كل دقيقة بالسر المشترك؛ لا يستدعيه العميل.
//
// الأسرار (supabase secrets set):
//   PUSH_DISPATCH_SECRET   سر مشترك مع الجدولة (رأس x-dispatch-secret)
//   FCM_SERVICE_ACCOUNT    JSON حساب خدمة Firebase مرمزًا base64
// المتغيرات تحقنها المنصة: SUPABASE_URL وSUPABASE_SERVICE_ROLE_KEY.
//
// لم يجرب مقابل FCM حقيقي: يحتاج مشروع Firebase وملف الخدمة (INT-006).
import { createClient } from "npm:@supabase/supabase-js@2";

import { buildMessage, isInvalidTokenResponse, type PushJob } from "./payload.ts";

const BATCH = 50;

function b64url(bytes: Uint8Array | string): string {
  const data = typeof bytes === "string" ? new TextEncoder().encode(bytes) : bytes;
  let s = "";
  for (const b of data) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

/** رمز وصول OAuth2 لخدمة FCM من حساب الخدمة (JWT بتوقيع RS256). */
async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const pem = sa.private_key.replace(/-----[A-Z ]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`)),
  );
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${b64url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`oauth ${res.status}`);
  return (await res.json()).access_token as string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });
  const secret = Deno.env.get("PUSH_DISPATCH_SECRET");
  if (!secret || req.headers.get("x-dispatch-secret") !== secret) {
    return new Response("forbidden", { status: 403 });
  }
  const encoded = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!encoded) return new Response("FCM_SERVICE_ACCOUNT غير مضبوط", { status: 503 });

  const sa = JSON.parse(atob(encoded)) as ServiceAccount;
  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await db.rpc("claim_push_batch", { p_limit: BATCH });
  if (error) return new Response(`claim: ${error.message}`, { status: 500 });
  const jobs = (data ?? []) as PushJob[];
  if (jobs.length === 0) return Response.json({ claimed: 0, sent: 0, failed: 0 });

  const token = await accessToken(sa);
  const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
  let sent = 0;
  let failed = 0;

  for (const job of jobs) {
    const invalid: string[] = [];
    let delivered = 0;
    let lastError = "";
    for (const deviceToken of job.tokens) {
      const res = await fetch(url, {
        method: "POST",
        headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
        body: JSON.stringify(buildMessage(job, deviceToken)),
      });
      if (res.ok) {
        delivered++;
      } else {
        const body = await res.json().catch(() => ({}));
        if (isInvalidTokenResponse(res.status, body)) invalid.push(deviceToken);
        else lastError = `fcm ${res.status}`;
      }
    }
    // وصل لجهاز واحد على الأقل، أو لم يبق إلا رموز غير صالحة: لا إعادة محاولة.
    const done = delivered > 0 || (invalid.length === job.tokens.length && lastError === "");
    const { error: completeError } = await db.rpc("complete_push", {
      p_outbox_id: job.outbox_id,
      p_status: done ? "SENT" : "FAILED",
      p_error: done ? null : lastError || "no_delivery",
      p_invalid_tokens: invalid.length ? invalid : null,
    });
    if (completeError) failed++;
    else if (done) sent++;
    else failed++;
  }
  return Response.json({ claimed: jobs.length, sent, failed });
});
