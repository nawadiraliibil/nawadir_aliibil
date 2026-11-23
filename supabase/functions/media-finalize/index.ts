// media-finalize — MOBILE-BE-110
// يستدعيها العميل بعد رفع ملف وسائط إلى مساره المسجل (add_listing_media).
// تفحص ملكية الوسيط، وتقرأ الملف من التخزين، وتتحقق من نوعه الفعلي من بايتاته،
// وتزيل البيانات الوصفية من الصورة (ومنها الموقع)، ثم تثبت النتيجة بالدالة
// finalize_listing_media التي تتحقق من الحدود المنشورة. AD-FR-007، SRS القسم 5.
//
// الطلب:  POST { "media_id": "<uuid>" } بجلسة المستخدم.
// الرد:   200 { "media_id", "status": "READY" | "FAILED", "failure_reason" }
//         4xx { "code", "details" } برموز contracts/api/errors.json.
import { createClient } from "npm:@supabase/supabase-js@2";

import { MalformedImageError, sanitizeImage, sniffMime } from "./image.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// حد أمان لما تحمله الدالة في الذاكرة؛ الحد المنشور يفحصه finalize_listing_media.
const MAX_IMAGE_BYTES = 20 * 1024 * 1024;

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function fail(status: number, code: string, details: Record<string, unknown> = {}): Response {
  return json(status, { code, details });
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return fail(405, "METHOD_NOT_ALLOWED");

  const authorization = req.headers.get("Authorization");
  if (!authorization) return fail(401, "AUTH_REQUIRED");

  let mediaId: unknown;
  try {
    mediaId = (await req.json())?.media_id;
  } catch {
    return fail(400, "VALIDATION_FAILED", { fields: ["media_id"] });
  }
  if (typeof mediaId !== "string" || !UUID.test(mediaId)) {
    return fail(400, "VALIDATION_FAILED", { fields: ["media_id"] });
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const userClient = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const serviceClient = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData?.user) return fail(401, "AUTH_REQUIRED");

  // الملكية: صف الوسيط يقرأ بجلسة المستخدم (RLS)، ويشترط أنه مالكه.
  const { data: media, error: mediaError } = await userClient
    .from("media")
    .select("id, owner_id, kind, status, bucket, object_path")
    .eq("id", mediaId)
    .maybeSingle();
  if (mediaError) return fail(500, "INTERNAL_ERROR", { reason: "media lookup failed" });
  if (!media || media.owner_id !== userData.user.id) {
    return fail(404, "NOT_FOUND", { resource: "media" });
  }
  if (media.status !== "PENDING") {
    return json(200, { media_id: media.id, status: media.status, failure_reason: null });
  }

  const finalize = async (args: Record<string, unknown>): Promise<Response> => {
    const { data, error } = await serviceClient.rpc("finalize_listing_media", {
      p_media_id: media.id,
      ...args,
    });
    if (error) {
      // رمز الخطأ من الخادم في message (مثل VERSION_IMMUTABLE).
      return fail(409, error.message || "INTERNAL_ERROR", safeDetails(error.details));
    }
    return json(200, data);
  };

  // معالجة الفيديو (المدة والترميز) تحتاج عامل معالجة غير متوفر؛ الفيديو معطل في
  // الإعدادات المنشورة. لا نجاح وهمي.
  if (media.kind !== "IMAGE") {
    return await finalize({
      p_mime_type: null,
      p_size_bytes: null,
      p_failure_reason: "VIDEO_PROCESSING_UNAVAILABLE",
    });
  }

  const { data: blob, error: downloadError } = await serviceClient.storage
    .from(media.bucket)
    .download(media.object_path);
  if (downloadError || !blob) {
    // الملف لم يرفع بعد: يبقى الوسيط بانتظار الرفع ويعيد العميل المحاولة.
    return fail(409, "MEDIA_NOT_UPLOADED", { media_id: media.id });
  }
  if (blob.size > MAX_IMAGE_BYTES) {
    return await finalize({
      p_mime_type: null,
      p_size_bytes: blob.size,
      p_failure_reason: "FILE_TOO_LARGE",
    });
  }

  const original = new Uint8Array(await blob.arrayBuffer());
  const mime = sniffMime(original);
  if (mime !== "image/jpeg" && mime !== "image/png") {
    return await finalize({
      p_mime_type: mime,
      p_size_bytes: original.length || null,
      p_failure_reason: "UNSUPPORTED_TYPE",
    });
  }

  let cleaned;
  try {
    cleaned = sanitizeImage(original, mime);
  } catch (error) {
    if (!(error instanceof MalformedImageError)) throw error;
    return await finalize({
      p_mime_type: mime,
      p_size_bytes: original.length,
      p_failure_reason: "CORRUPT_FILE",
    });
  }

  if (cleaned.changed) {
    const { error: uploadError } = await serviceClient.storage
      .from(media.bucket)
      .upload(media.object_path, cleaned.bytes, { contentType: mime, upsert: true });
    // تعذر حفظ النسخة المنظفة: لا يثبت الوسيط جاهزًا ببياناته الوصفية.
    if (uploadError) return fail(503, "MEDIA_PROCESSING_FAILED", { media_id: media.id });
  }

  return await finalize({
    p_mime_type: mime,
    p_size_bytes: cleaned.bytes.length,
    p_width: cleaned.width,
    p_height: cleaned.height,
  });
});

function safeDetails(details: unknown): Record<string, unknown> {
  if (typeof details !== "string") return {};
  try {
    const parsed = JSON.parse(details);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}
