// اختبار تكامل media-finalize على الخلفية المحلية — MOBILE-BE-110
//
// المتطلبات: `supabase start` و`supabase functions serve` يعملان، والقاعدة بعد
// `supabase db reset` (أرقام الاختبار الوهمية 9665000000NN برمز 123456).
// التشغيل من جذر المستودع:
//   node supabase/tests/functions/media_finalize.integration.mjs
// المفتاحان يقرآن من `supabase status -o env`؛ لا أسرار في الملف.
import assert from "node:assert/strict";
import { execSync } from "node:child_process";

const env = Object.fromEntries(
  execSync("supabase status -o env", { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] })
    .split(/\r?\n/)
    .map((line) => line.match(/^([A-Z_]+)="?(.*?)"?$/))
    .filter(Boolean)
    .map((m) => [m[1], m[2]]),
);
const API = env.API_URL;
const ANON = env.ANON_KEY;
assert.ok(API && ANON, "تعذر قراءة API_URL وANON_KEY من supabase status");

const ascii = (text) => [...text].map((c) => c.charCodeAt(0));
const segment = (marker, payload) => {
  const length = payload.length + 2;
  return [0xff, marker, (length >> 8) & 0xff, length & 0xff, ...payload];
};
const GPS_TEXT = "GPS-24.7136N-46.6753E";

function jpegWithGps() {
  const tiff = [
    0x49, 0x49, 0x2a, 0x00, 0x08, 0x00, 0x00, 0x00, 0x02, 0x00,
    0x12, 0x01, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00,
    0x25, 0x88, 0x04, 0x00, 0x01, 0x00, 0x00, 0x00, 0x26, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, ...ascii(GPS_TEXT),
  ];
  return new Uint8Array([
    0xff, 0xd8,
    ...segment(0xe0, [...ascii("JFIF\0"), 1, 1, 0, 0, 1, 0, 1, 0, 0]),
    ...segment(0xe1, [...ascii("Exif\0\0"), ...tiff]),
    ...segment(0xdb, [0, ...new Array(64).fill(1)]),
    ...segment(0xc0, [8, 0x02, 0x58, 0x03, 0x20, 1, 1, 0x11, 0]),
    ...segment(0xda, [1, 1, 0, 0, 63, 0]), 0x12, 0x34, 0x56, 0xff, 0xd9,
  ]);
}

function includesAscii(bytes, text) {
  const needle = ascii(text);
  for (let i = 0; i + needle.length <= bytes.length; i++) {
    if (needle.every((b, j) => bytes[i + j] === b)) return true;
  }
  return false;
}

async function http(path, { token, body, method = "POST", headers = {}, raw = false } = {}) {
  const response = await fetch(`${API}${path}`, {
    method,
    headers: {
      apikey: ANON,
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(raw ? {} : { "Content-Type": "application/json" }),
      ...headers,
    },
    body: raw ? body : body === undefined ? undefined : JSON.stringify(body),
  });
  return response;
}

async function signIn(phone) {
  const otp = await http("/auth/v1/otp", { body: { phone } });
  assert.equal(otp.status, 200, `إرسال الرمز: ${await otp.text()}`);
  const verify = await http("/auth/v1/verify", { body: { phone, token: "123456", type: "sms" } });
  const session = await verify.json();
  assert.ok(session.access_token, "تعذر الدخول برقم الاختبار");
  return session.access_token;
}

async function rpc(name, args, token) {
  const response = await http(`/rest/v1/rpc/${name}`, { token, body: args });
  const data = await response.json();
  assert.ok(response.ok, `${name}: ${JSON.stringify(data)}`);
  return data;
}

const finalize = (mediaId, token) => http("/functions/v1/media-finalize", { token, body: { media_id: mediaId } });

const upload = (media, bytes, token, contentType) =>
  http(`/storage/v1/object/${media.bucket}/${media.object_path}`, {
    token, body: bytes, raw: true, headers: { "Content-Type": contentType },
  });

let passed = 0;
const check = async (name, fn) => {
  await fn();
  passed++;
  console.log(`ok - ${name}`);
};

const owner = await signIn("+966500000001");
const other = await signIn("+966500000002");

const draft = await rpc("create_listing_draft", { p_request_id: crypto.randomUUID() }, owner);
const listingId = draft.listing.id;
const addImage = () =>
  rpc("add_listing_media", {
    p_listing_id: listingId, p_kind: "IMAGE", p_mime_type: "image/jpeg", p_size_bytes: 1000,
  }, owner);

await check("دون جلسة: 401", async () => {
  const response = await http("/functions/v1/media-finalize", { body: { media_id: crypto.randomUUID() } });
  assert.equal(response.status, 401);
});

await check("معرف غير صالح: VALIDATION_FAILED", async () => {
  const response = await finalize("not-a-uuid", owner);
  assert.equal(response.status, 400);
  assert.equal((await response.json()).code, "VALIDATION_FAILED");
});

const good = await addImage();

await check("ملف لم يرفع: MEDIA_NOT_UPLOADED ويبقى بانتظار الرفع", async () => {
  const response = await finalize(good.media_id, owner);
  assert.equal(response.status, 409);
  assert.equal((await response.json()).code, "MEDIA_NOT_UPLOADED");
});

await check("مستخدم آخر لا يرفع إلى مسار غيره", async () => {
  const response = await upload(good, jpegWithGps(), other, "image/jpeg");
  assert.ok(response.status >= 400, `الحالة ${response.status}`);
});

await check("المالك يرفع إلى المسار المسجل", async () => {
  const response = await upload(good, jpegWithGps(), owner, "image/jpeg");
  assert.ok(response.ok, await response.text());
});

await check("مستخدم آخر لا يثبت وسيط غيره: NOT_FOUND", async () => {
  const response = await finalize(good.media_id, other);
  assert.equal(response.status, 404);
  assert.equal((await response.json()).code, "NOT_FOUND");
});

await check("صورة صالحة: READY بأبعادها", async () => {
  const response = await finalize(good.media_id, owner);
  const body = await response.json();
  assert.equal(response.status, 200, JSON.stringify(body));
  assert.equal(body.status, "READY");
});

await check("الملف المخزن بلا بيانات موقع، والاتجاه باق", async () => {
  const response = await http(`/storage/v1/object/authenticated/${good.bucket}/${good.object_path}`, {
    token: owner, method: "GET",
  });
  assert.ok(response.ok, `قراءة الملف: ${response.status}`);
  const stored = new Uint8Array(await response.arrayBuffer());
  assert.equal(includesAscii(stored, GPS_TEXT), false, "إحداثيات الموقع ما زالت في الملف");
  assert.deepEqual([...stored.subarray(0, 2)], [0xff, 0xd8]);
  const orientation = [0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, 0x06];
  let kept = false;
  for (let i = 0; i + orientation.length <= stored.length; i++) {
    if (orientation.every((b, j) => stored[i + j] === b)) kept = true;
  }
  assert.ok(kept, "الاتجاه غير محفوظ");
});

await check("صف الوسيط جاهز بالنوع والحجم والأبعاد الفعلية", async () => {
  const response = await http(
    `/rest/v1/media?id=eq.${good.media_id}&select=status,mime_type,size_bytes,width,height`,
    { token: owner, method: "GET" },
  );
  const [row] = await response.json();
  assert.equal(row.status, "READY");
  assert.equal(row.mime_type, "image/jpeg");
  assert.equal(row.width, 800);
  assert.equal(row.height, 600);
  assert.ok(row.size_bytes > 0 && row.size_bytes < jpegWithGps().length);
});

await check("إعادة الاستدعاء بعد الجاهزية لا تغير شيئًا", async () => {
  const response = await finalize(good.media_id, owner);
  assert.equal(response.status, 200);
  assert.equal((await response.json()).status, "READY");
});

await check("ملف ليس صورة بترويسة image/jpeg: FAILED بسبب UNSUPPORTED_TYPE", async () => {
  const fake = await addImage();
  const html = new TextEncoder().encode("<html><script>alert(1)</script></html>");
  const uploaded = await upload(fake, html, owner, "image/jpeg");
  assert.ok(uploaded.ok, await uploaded.text());
  const response = await finalize(fake.media_id, owner);
  const body = await response.json();
  assert.equal(response.status, 200, JSON.stringify(body));
  assert.equal(body.status, "FAILED");
  assert.equal(body.failure_reason, "UNSUPPORTED_TYPE");
});

await check("JPEG مبتور: FAILED بسبب CORRUPT_FILE", async () => {
  const broken = await addImage();
  const uploaded = await upload(broken, jpegWithGps().subarray(0, 40), owner, "image/jpeg");
  assert.ok(uploaded.ok, await uploaded.text());
  const response = await finalize(broken.media_id, owner);
  const body = await response.json();
  assert.equal(body.status, "FAILED");
  assert.equal(body.failure_reason, "CORRUPT_FILE");
});

await check("الزائر لا يقرأ وسيط مسودة من التخزين", async () => {
  const response = await http(`/storage/v1/object/authenticated/${good.bucket}/${good.object_path}`, {
    method: "GET",
  });
  assert.ok(response.status >= 400, `الحالة ${response.status}`);
});

// تنظيف: حذف المسودة (لم ترسل، فحذفها فعلي).
await rpc("delete_listing", { p_listing_id: listingId }, owner);

console.log(`\n${passed} فحصًا ناجحًا`);
