// عميل إرسال الرسائل عبر منصة تقنيات (Taqnyat) — https://dev.taqnyat.sa/ar/doc/sms/
// POST {base}/v1/messages برأس `Authorization: Bearer <token>` وجسم JSON:
//   { recipients: ["9665XXXXXXXX"], body: "...", sender: "<اسم مرسل معتمد>" }
// النجاح: HTTP 201 مع `accepted` و`rejected` كنصين بشكل قائمة، مثل "[966500000000,]".

export const TAQNYAT_DEFAULT_BASE_URL = "https://api.taqnyat.sa";

/** مهلة الطلب: مهلة hook كاملة في Supabase Auth خمس ثوانٍ. */
export const TAQNYAT_TIMEOUT_MS = 4000;

/** يطابق قالب `[auth.sms].template` في config.toml؛ الـhook يستلم الرمز فقط لا النص. */
export function otpMessage(otp: string): string {
  return `رمز التحقق في نوادر الإبل: ${otp}`;
}

/**
 * يعيد الرقم بالصيغة التي تقبلها تقنيات (دولي بلا + ولا 00) إن كان جوالًا سعوديًا،
 * وإلا null. المنصة للسوق السعودي، والتقييد يمنع استنزاف الرصيد بأرقام دولية.
 */
export function saudiMobile(phone: unknown): string | null {
  if (typeof phone !== "string") return null;
  let digits = phone.replace(/[^\d]/g, "");
  if (digits.startsWith("00")) digits = digits.slice(2);
  return /^9665\d{8}$/.test(digits) ? digits : null;
}

/** للسجلات: لا يظهر الرقم كاملًا. */
export function maskPhone(phone: string): string {
  return phone.length <= 6 ? "****" : `${phone.slice(0, 4)}****${phone.slice(-2)}`;
}

export type SendResult =
  | { ok: true; messageId: string | null }
  | { ok: false; status: number; reason: string };

/** يقرأ رد تقنيات. `rejected` غير الفارغ الذي يحوي الرقم يعد فشلًا ولو كان الرد 201. */
export function readSendResponse(status: number, body: unknown, phone: string): SendResult {
  const data = (body && typeof body === "object" ? body : {}) as Record<string, unknown>;
  const message = typeof data.message === "string" ? data.message : "";
  if (status < 200 || status >= 300) {
    return { ok: false, status, reason: message || "provider_error" };
  }
  if (String(data.rejected ?? "").includes(phone)) {
    return { ok: false, status, reason: "recipient_rejected" };
  }
  if (data.accepted !== undefined && !String(data.accepted).includes(phone)) {
    return { ok: false, status, reason: "recipient_not_accepted" };
  }
  return { ok: true, messageId: data.messageId === undefined ? null : String(data.messageId) };
}

export interface TaqnyatConfig {
  baseUrl: string;
  token: string;
  sender: string;
}

export async function sendOtpSms(
  config: TaqnyatConfig,
  phone: string,
  otp: string,
  fetchFn: typeof fetch,
): Promise<SendResult> {
  let res: Response;
  try {
    res = await fetchFn(`${config.baseUrl.replace(/\/+$/, "")}/v1/messages`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${config.token}`,
        "Content-Type": "application/json; charset=UTF-8",
      },
      body: JSON.stringify({ recipients: [phone], body: otpMessage(otp), sender: config.sender }),
      signal: AbortSignal.timeout(TAQNYAT_TIMEOUT_MS),
    });
  } catch (e) {
    const name = e instanceof Error ? e.name : "";
    return { ok: false, status: 0, reason: name === "TimeoutError" ? "provider_timeout" : "provider_unreachable" };
  }
  const body = await res.json().catch(() => null);
  return readSendResponse(res.status, body, phone);
}
