// التحقق من توقيع Standard Webhooks الذي يوقّع به Supabase Auth طلبات الـhooks.
// المحتوى الموقّع: `${id}.${timestamp}.${payload}` بـHMAC-SHA256، والمفتاح هو الجزء
// المرمّز base64 بعد البادئة `v1,whsec_`. الملف بلا اعتماديات ليعمل في Deno وNode.

const TOLERANCE_SECONDS = 5 * 60;
const SECRET_PREFIX = "v1,whsec_";

export type VerifyFailure = "missing_headers" | "stale_timestamp" | "bad_signature" | "bad_secret";

export type VerifyResult = { ok: true } | { ok: false; reason: VerifyFailure };

function fromBase64(text: string): Uint8Array<ArrayBuffer> | null {
  try {
    const raw = atob(text);
    const bytes = new Uint8Array(new ArrayBuffer(raw.length));
    for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
    return bytes;
  } catch {
    return null;
  }
}

function toBase64(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}

/** مقارنة بزمن ثابت حتى لا يكشف التوقيت موضع أول اختلاف. */
function sameText(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

/** يوقّع المحتوى بسر واحد بصيغة `v1,whsec_<base64>` ويعيد التوقيع base64، أو null لسر تالف. */
export async function sign(secret: string, id: string, timestamp: string, payload: string): Promise<string | null> {
  const trimmed = secret.trim();
  const encoded = trimmed.startsWith(SECRET_PREFIX) ? trimmed.slice(SECRET_PREFIX.length) : trimmed;
  const keyBytes = fromBase64(encoded);
  if (!keyBytes || keyBytes.length === 0) return null;
  const key = await crypto.subtle.importKey("raw", keyBytes, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${id}.${timestamp}.${payload}`));
  return toBase64(new Uint8Array(mac));
}

/**
 * يتحقق من رؤوس `webhook-id` و`webhook-timestamp` و`webhook-signature`.
 * `secrets` قد يحمل أكثر من سر مفصولة بـ`|` (تدوير المفاتيح)، ويكفي تطابق أحدها.
 */
export async function verifyWebhook(
  payload: string,
  headers: Headers,
  secrets: string,
  nowMs: number,
): Promise<VerifyResult> {
  const id = headers.get("webhook-id");
  const timestamp = headers.get("webhook-timestamp");
  const signatureHeader = headers.get("webhook-signature");
  if (!id || !timestamp || !signatureHeader) return { ok: false, reason: "missing_headers" };

  const seconds = Number(timestamp);
  if (!Number.isFinite(seconds) || Math.abs(nowMs / 1000 - seconds) > TOLERANCE_SECONDS) {
    return { ok: false, reason: "stale_timestamp" };
  }

  const received = signatureHeader
    .split(" ")
    .map((part) => part.trim())
    .filter((part) => part.startsWith("v1,"))
    .map((part) => part.slice(3));

  let usable = 0;
  let matched = false;
  for (const secret of secrets.split("|")) {
    if (!secret.trim()) continue;
    const expected = await sign(secret, id, timestamp, payload);
    if (!expected) continue;
    usable++;
    for (const candidate of received) {
      if (sameText(candidate, expected)) matched = true;
    }
  }
  if (usable === 0) return { ok: false, reason: "bad_secret" };
  return matched ? { ok: true } : { ok: false, reason: "bad_signature" };
}
