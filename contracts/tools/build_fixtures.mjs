// يولد contracts/fixtures من ردود الخادم الفعلية على الخلفية المحلية — MOBILE-CON-101
//
// يمر بالرحلة كاملة بواجهات العميل: دخول برقم اختباري، إكمال الملف والموافقة،
// إنشاء إعلان ورفع صوره وتثبيتها بدالة media-finalize وإرساله، دخول موظف ببريد
// وكلمة مرور مع تحقق TOTP فعلي (aal2)، اعتماد، ثم قراءة الـviews العامة.
// الأمثلة الناتجة ردود حقيقية لا مكتوبة يدويًا.
//
// المتطلبات: `supabase start` بعد `supabase db reset` (قاعدة نظيفة)، و
// `supabase functions serve` يعمل، وDocker في PATH.
// التشغيل من جذر المستودع: node contracts/tools/build_fixtures.mjs
// حسابات الاختبار وهمية ومحلية؛ لا تكتب أسرار في الأمثلة.
import assert from "node:assert/strict";
import { execFileSync, execSync } from "node:child_process";
import { createHmac } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";

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

const OUT = "contracts/fixtures";
mkdirSync(OUT, { recursive: true });
const save = (name, data) => {
  writeFileSync(`${OUT}/${name}.json`, JSON.stringify(data, null, 2) + "\n");
  console.log(`fixture: ${name}.json`);
};

async function http(path, { token, key = ANON, body, method = "POST", headers = {}, raw = false } = {}) {
  return await fetch(`${API}${path}`, {
    method,
    headers: {
      apikey: key,
      Authorization: `Bearer ${token ?? key}`,
      ...(raw ? {} : { "Content-Type": "application/json" }),
      ...headers,
    },
    body: raw ? body : body === undefined ? undefined : JSON.stringify(body),
  });
}

async function ok(response, what) {
  const text = await response.text();
  assert.ok(response.ok, `${what}: ${response.status} ${text}`);
  return text ? JSON.parse(text) : null;
}

const rpc = async (name, args, token) => ok(await http(`/rest/v1/rpc/${name}`, { token, body: args }), name);
const rpcRaw = (name, args, token) => http(`/rest/v1/rpc/${name}`, { token, body: args });
const read = async (path, token) => ok(await http(`/rest/v1/${path}`, { token, method: "GET" }), path);
const sql = (query) =>
  execFileSync("docker", ["exec", "-i", "supabase_db_nawadir_aliibil", "psql", "-U", "postgres", "-At", "-c", query], {
    encoding: "utf8",
  }).trim();

// TOTP (RFC 6238): SHA-1، 6 أرقام، 30 ثانية.
function totp(secretBase32) {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = "";
  for (const c of secretBase32.replace(/=+$/, "").toUpperCase()) {
    bits += alphabet.indexOf(c).toString(2).padStart(5, "0");
  }
  const key = Buffer.from(bits.match(/.{8}/g).map((b) => parseInt(b, 2)));
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(Date.now() / 30000)));
  const mac = createHmac("sha1", key).update(counter).digest();
  const offset = mac[mac.length - 1] & 0x0f;
  const code = (mac.readUInt32BE(offset) & 0x7fffffff) % 1_000_000;
  return String(code).padStart(6, "0");
}

const ascii = (text) => [...text].map((c) => c.charCodeAt(0));
const segment = (marker, payload) => {
  const length = payload.length + 2;
  return [0xff, marker, (length >> 8) & 0xff, length & 0xff, ...payload];
};
const jpeg = () =>
  new Uint8Array([
    0xff, 0xd8,
    ...segment(0xe0, [...ascii("JFIF\0"), 1, 1, 0, 0, 1, 0, 1, 0, 0]),
    ...segment(0xdb, [0, ...new Array(64).fill(1)]),
    ...segment(0xc0, [8, 0x02, 0x58, 0x03, 0x20, 1, 1, 0x11, 0]),
    ...segment(0xda, [1, 1, 0, 0, 63, 0]), 0x12, 0x34, 0x56, 0xff, 0xd9,
  ]);

// ---------------------------------------------------------------------------
// الزائر
// ---------------------------------------------------------------------------
const settings = await rpc("get_published_settings", {});
save("published-settings", settings);
save("current-policies", await rpc("get_current_policies", {}));

// ---------------------------------------------------------------------------
// المستخدم
// ---------------------------------------------------------------------------
const phone = "+966500000001";
await ok(await http("/auth/v1/otp", { body: { phone } }), "otp");
const session = await ok(await http("/auth/v1/verify", { body: { phone, token: "123456", type: "sms" } }), "verify");
const user = session.access_token;

save("account-new", await rpc("get_my_account", {}, user));
const invalid = await rpcRaw("update_my_profile", { p_display_name: "أ", p_region_id: 1 }, user);
assert.equal(invalid.status, 400);
save("error-validation-failed", await invalid.json());

await rpc("update_my_profile", { p_display_name: "معلن تجريبي", p_region_id: 1 }, user);
const policies = await rpc("get_current_policies", {});
save("account-ready", await rpc("accept_policies", { p_document_ids: policies.map((p) => p.id) }, user));

const draft = await rpc("create_listing_draft", { p_request_id: crypto.randomUUID() }, user);
const listingId = draft.listing.id;
const city = settings.lookups.cities.find((c) => c.region_id === 1);
const breed = settings.lookups.breeds.find((b) => !b.requires_note);
const patch = {
  title: "ناقة مجاهيم للبيع",
  description: "ناقة مجاهيم عمرها أربع سنوات، هادئة الطباع ومعتادة على الحلب.",
  breed_id: breed.id,
  sex: "FEMALE",
  age_months: 48,
  color: "سوداء",
  region_id: 1,
  city_id: city.id,
  health_notes: "لا توجد عيوب معروفة",
  owner_declaration: true,
  offer_type: "FIXED_PRICE",
  price: 25000,
  contact_phone: "0500000009",
  contact_call_enabled: true,
  contact_whatsapp_enabled: true,
};
save("listing-draft-patch", patch);
await rpc("save_listing_draft", { p_listing_id: listingId, p_patch: patch }, user);

const media = [];
for (let i = 0; i < 3; i++) {
  const m = await rpc("add_listing_media", {
    p_listing_id: listingId, p_kind: "IMAGE", p_mime_type: "image/jpeg", p_size_bytes: 1000,
  }, user);
  if (i === 0) save("add-listing-media", m);
  await ok(await http(`/storage/v1/object/${m.bucket}/${m.object_path}`, {
    token: user, body: jpeg(), raw: true, headers: { "Content-Type": "image/jpeg" },
  }), "upload");
  const done = await ok(await http("/functions/v1/media-finalize", { token: user, body: { media_id: m.media_id } }), "media-finalize");
  assert.equal(done.status, "READY");
  if (i === 0) save("media-finalize", done);
  media.push(m.media_id);
}
save("listing-owner-draft", await rpc("arrange_listing_media", {
  p_listing_id: listingId, p_media_ids: media, p_cover_id: media[0],
}, user));
save("listing-owner-submitted", await rpc("submit_listing", {
  p_listing_id: listingId, p_request_id: crypto.randomUUID(),
}, user));

// ---------------------------------------------------------------------------
// الموظف: بريد وكلمة مرور ثم TOTP فعلي
// ---------------------------------------------------------------------------
const staffEmail = `fixture-admin-${Date.now()}@example.test`;
const staffPassword = `Fx-${crypto.randomUUID()}`;
const staff = await ok(await http("/auth/v1/admin/users", {
  key: SERVICE, body: { email: staffEmail, password: staffPassword, email_confirm: true },
}), "create staff user");
if (sql("select count(*) from public.admin_roles where role = 'ADMIN' and is_active") === "0") {
  sql(`select private.bootstrap_first_admin('${staff.id}')`);
} else {
  // قاعدة غير نظيفة: يمنح الدور مباشرة لحساب الأمثلة المحلي.
  sql(`insert into public.admin_roles (user_id, role) values ('${staff.id}', 'ADMIN')`);
}

const login = await ok(await http("/auth/v1/token?grant_type=password", {
  body: { email: staffEmail, password: staffPassword },
}), "staff login");
const aal1 = login.access_token;

const mfaRequired = await rpcRaw("admin_whoami", {}, aal1);
assert.equal(mfaRequired.status, 400);
const mfaBody = await mfaRequired.json();
assert.equal(mfaBody.message, "MFA_REQUIRED", "جلسة دون TOTP يجب أن ترفض");
save("error-mfa-required", mfaBody);

const factor = await ok(await http("/auth/v1/factors", {
  token: aal1, body: { factor_type: "totp", friendly_name: "fixture" },
}), "enroll totp");
const challenge = await ok(await http(`/auth/v1/factors/${factor.id}/challenge`, { token: aal1 }), "challenge");
const verified = await ok(await http(`/auth/v1/factors/${factor.id}/verify`, {
  token: aal1, body: { challenge_id: challenge.id, code: totp(factor.totp.secret) },
}), "verify totp");
const admin = verified.access_token;

save("admin-whoami", await rpc("admin_whoami", {}, admin));
const queue = await rpc("admin_review_queue", { p_limit: 20 }, admin);
save("admin-review-queue", queue);
const review = await rpc("admin_get_listing_review", { p_listing_id: listingId }, admin);
save("admin-listing-review", review);

const stale = await rpcRaw("admin_approve_listing_version", {
  p_listing_id: listingId, p_version_id: review.version.id, p_content_hash: "0".repeat(64),
}, admin);
save("error-version-changed", await stale.json());

save("admin-approved-listing", await rpc("admin_approve_listing_version", {
  p_listing_id: listingId, p_version_id: review.version.id, p_content_hash: review.version.content_hash,
}, admin));

const forbidden = await rpcRaw("admin_review_queue", {}, user);
save("error-forbidden", await forbidden.json());

// ---------------------------------------------------------------------------
// القراءة العامة والخاصة بعد النشر
// ---------------------------------------------------------------------------
save("public-listing-card", (await read(`public_listing_cards?listing_id=eq.${listingId}`))[0]);
save("public-listing-details", (await read(`public_listing_details?listing_id=eq.${listingId}`))[0]);
save("public-listing-media", await read(`public_listing_media?listing_id=eq.${listingId}&order=sort_order`));
save("public-profile", (await read(`public_profiles?id=eq.${draft.version ? session.user.id : session.user.id}`))[0]);
save("my-listing", (await read(`my_listings?listing_id=eq.${listingId}`, user))[0]);
save("notifications", await read("notifications?order=created_at.desc", user));

// ---------------------------------------------------------------------------
// البحث والتفاصيل والمفضلة والمشاركة (العقد 0.2.0)
// ---------------------------------------------------------------------------
save("search-result", await rpc("search_listings", { p_query: "ناقة", p_limit: 20 }));
save("listing-detail", await rpc("get_listing", { p_listing_id: listingId }));
save("favorite-added", await rpc("add_favorite", { p_listing_id: listingId }, user));
save("my-favorite", (await read(`my_favorites?listing_id=eq.${listingId}`, user))[0]);
save("favorite-removed", await rpc("remove_favorite", { p_listing_id: listingId }, user));
const missing = await rpcRaw("get_listing", { p_listing_id: "00000000-0000-0000-0000-000000000099" });
save("error-not-found", await missing.json());
const bad = await rpcRaw("search_listings", { p_price_min: 5000, p_price_max: 100 });
save("error-search-validation", await bad.json());

// ---------------------------------------------------------------------------
// المحادثات والردود والحظر والبلاغات والمتابعات والدفع (العقد 0.3.0)
// ---------------------------------------------------------------------------
const buyerPhone = "+966500000002";
await ok(await http("/auth/v1/otp", { body: { phone: buyerPhone } }), "otp buyer");
const buyerSession = await ok(
  await http("/auth/v1/verify", { body: { phone: buyerPhone, token: "123456", type: "sms" } }), "verify buyer");
const buyer = buyerSession.access_token;
await rpc("update_my_profile", { p_display_name: "مشتري تجريبي", p_region_id: 1 }, buyer);
await rpc("accept_policies", { p_document_ids: policies.map((p) => p.id) }, buyer);
const sellerId = session.user.id;

// محادثة: المشتري يبدأ ويكتب، والمعلن يقرأ ويرد.
const started = await rpc("start_conversation", { p_listing_id: listingId }, buyer);
save("conversation-started", started);
const conversationId = started.conversation_id;
const firstMessage = await rpc("send_message", {
  p_conversation_id: conversationId, p_body: "السلام عليكم، هل الناقة ما زالت متاحة؟", p_request_id: crypto.randomUUID(),
}, buyer);
save("message-sent", firstMessage);
save("my-conversation", (await read(`my_conversations?conversation_id=eq.${conversationId}`, user))[0]);
save("conversation-messages", await read(`messages?conversation_id=eq.${conversationId}&order=created_at`, user));
save("conversation-read", await rpc("mark_conversation_read", { p_conversation_id: conversationId }, user));
await rpc("send_message", {
  p_conversation_id: conversationId, p_body: "وعليكم السلام، نعم متاحة.", p_request_id: crypto.randomUUID(),
}, user);
save("conversation-muted", await rpc("set_conversation_muted", { p_conversation_id: conversationId, p_muted: true }, buyer));
await rpc("set_conversation_muted", { p_conversation_id: conversationId, p_muted: false }, buyer);

// ردود عامة
const comment = await rpc("post_comment", {
  p_listing_id: listingId, p_body: "هل يمكن معاينتها غدًا؟", p_request_id: crypto.randomUUID(),
}, buyer);
save("comment-posted", comment);
await rpc("post_comment", {
  p_listing_id: listingId, p_body: "نعم بعد العصر.", p_request_id: crypto.randomUUID(), p_parent_id: comment.id,
}, user);
save("public-comments", await read(`public_comments?listing_id=eq.${listingId}&order=created_at`));
await rpc("set_comments_closed", { p_listing_id: listingId, p_closed: true }, user);
const closed = await rpcRaw("post_comment", {
  p_listing_id: listingId, p_body: "بعد الإغلاق", p_request_id: crypto.randomUUID(),
}, buyer);
save("error-comments-closed", await closed.json());
await rpc("set_comments_closed", { p_listing_id: listingId, p_closed: false }, user);

// بلاغ عن رسالة وإغلاقه
const report = await rpc("submit_report", {
  p_target_type: "MESSAGE", p_target_id: (await read(`messages?conversation_id=eq.${conversationId}&sender_id=eq.${sellerId}`, buyer))[0].id,
  p_reason: "ABUSE", p_description: "ألفاظ غير لائقة", p_request_id: crypto.randomUUID(),
}, buyer);
save("report-submitted", report);
save("report-status", await rpc("get_report_status", { p_report_id: report.report_id }, buyer));
save("admin-report-evidence", await rpc("admin_get_report_evidence", { p_report_id: report.report_id }, admin));
save("admin-report-assigned", await rpc("admin_assign_report", { p_report_id: report.report_id }, admin));
save("admin-report-closed", await rpc("admin_close_report", {
  p_report_id: report.report_id, p_close_reason: "NO_VIOLATION", p_response_text: "راجعنا الرسالة ولم نجد مخالفة.",
  p_internal_note: "محتوى عادي",
}, admin));

// الحظر
save("block-user", await rpc("block_user", { p_user_id: sellerId }, buyer));
save("my-blocks", await read("my_blocks", buyer));
const blocked = await rpcRaw("send_message", {
  p_conversation_id: conversationId, p_body: "رسالة بعد الحظر", p_request_id: crypto.randomUUID(),
}, user);
save("error-conversation-read-only", await blocked.json());
await rpc("unblock_user", { p_user_id: sellerId }, buyer);

// المتابعات
save("saved-search", await rpc("save_search", { p_filters: { query: "ناقة", region_id: 1 }, p_name: "نوق الرياض" }, buyer));
save("my-saved-search", (await read("my_saved_searches", buyer))[0]);
save("follow-seller", await rpc("follow_seller", { p_user_id: sellerId }, buyer));
save("my-follow", (await read("my_follows", buyer))[0]);

// الإشعارات والدفع
save("notification-preferences", await read("my_notification_preferences", buyer));
save("notification-preference-set", await rpc("set_notification_preference", {
  p_category: "MESSAGES", p_push_enabled: false,
}, buyer));
save("device-registered", await rpc("register_device_token", {
  p_token: "fixture-device-token-0123456789abcdef", p_platform: "ANDROID",
}, buyer));
save("device-unregistered", await rpc("unregister_device_token", {
  p_token: "fixture-device-token-0123456789abcdef",
}, buyer));
save("notifications-seller", await read("notifications?order=created_at.desc", user));

// ---------------------------------------------------------------------------
// التقييمات وإحصاءات الإدارة (العقد 1.0.0)
// ---------------------------------------------------------------------------
const noExchange = await rpc("get_rating_eligibility", { p_seller_id: sellerId }, buyer);
save("rating-eligibility", noExchange);
const rating = await rpc("submit_rating", {
  p_seller_id: sellerId, p_score: 4, p_body: "تعامل محترم وسريع.", p_declaration: true,
  p_request_id: crypto.randomUUID(),
}, buyer);
save("rating-submitted", rating);
const notEligible = await rpcRaw("submit_rating", {
  p_seller_id: buyerSession.user.id, p_score: 5, p_body: null, p_declaration: true,
  p_request_id: crypto.randomUUID(),
}, user);
save("error-rating-not-eligible", await notEligible.json());
save("rating-replied", await rpc("reply_to_rating", { p_rating_id: rating.rating_id, p_body: "شكرًا لك." }, user));
save("public-ratings", await read(`public_ratings?seller_id=eq.${sellerId}`));
save("my-received-ratings", await read("my_received_ratings", user));
save("public-profile-rated", (await read(`public_profiles?id=eq.${sellerId}`))[0]);
const appeal = await rpc("appeal_rating", { p_rating_id: rating.rating_id, p_reason: "لم يحدث تعامل فعلي" }, user);
save("rating-appealed", appeal);
save("admin-appeal-decided", await rpc("admin_decide_rating_appeal", {
  p_appeal_id: appeal.appeal_id, p_decision: "REJECTED", p_note: "التقييم مطابق للسجل",
}, admin));
save("admin-stats", await rpc("admin_stats", {}, admin));

const early = await rpcRaw("bump_listing", { p_listing_id: listingId }, user);
save("error-bump-too-early", await early.json());

console.log("\nاكتمل توليد الأمثلة.");
