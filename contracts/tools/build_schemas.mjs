// يكتب contracts/schemas (JSON Schema 2020-12) — MOBILE-CON-101
// القيم المغلقة (enums ورموز الأخطاء) تقرأ من api/enums.json وapi/errors.json.
// التشغيل من جذر المستودع: node contracts/tools/build_schemas.mjs
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";

const enums = JSON.parse(readFileSync("contracts/api/enums.json", "utf8"));
const errors = JSON.parse(readFileSync("contracts/api/errors.json", "utf8"));

const BASE = "https://nawadiraliibil.example/contracts/schemas";
const str = { type: "string" };
const int = { type: "integer" };
const bool = { type: "boolean" };
const uuid = { type: "string", format: "uuid" };
const time = { type: "string", format: "date-time" };
const nullable = (schema) => ({ anyOf: [schema, { type: "null" }] });
const en = (name) => ({ enum: enums[name] });
const object = (properties, optional = []) => ({
  type: "object",
  additionalProperties: false,
  required: Object.keys(properties).filter((k) => !optional.includes(k)),
  properties,
});
const positive = { type: "integer", minimum: 1 };

const schemas = {
  // رد PostgREST عند خطأ دالة: الرمز في message والتفاصيل نص JSON في details.
  error: {
    title: "خطأ دالة",
    ...object({
      code: { const: errors.format.sqlstate },
      message: { enum: Object.keys(errors.errors) },
      details: nullable({ ...str, description: "نص JSON لكائن التفاصيل" }),
      hint: nullable(str),
    }),
  },

  "published-settings": {
    title: "رد get_published_settings",
    ...object({
      version: positive,
      published_at: time,
      settings: object({
        listing: object({
          title_min: positive, title_max: positive,
          description_min: positive, description_max: positive,
          daily_new_limit: positive, open_drafts_max: positive,
        }),
        media: object({
          images_min: positive, images_max: positive, image_max_bytes: positive,
          image_mime_types: { type: "array", minItems: 1, items: { enum: ["image/jpeg", "image/png"] } },
          video_enabled: bool, video_max_seconds: positive, video_max_bytes: positive,
        }),
        interaction: object({ message_max: positive, comment_max: positive, rating_max: positive }),
        rate_limits: object({
          messages_per_minute: positive, new_conversations_per_hour: positive,
          comments_per_minute: positive, reports_per_day: positive,
        }),
        follows: object({ saved_searches_max: positive, followed_sellers_max: positive }),
        bump: object({ interval_hours: { type: "integer", minimum: 24 } }),
      }),
      lookups: object({
        regions: { type: "array", items: object({ id: int, name_ar: str }) },
        cities: { type: "array", items: object({ id: int, region_id: int, name_ar: str }) },
        breeds: { type: "array", items: object({ id: int, name_ar: str, requires_note: bool }) },
      }),
    }),
  },

  account: {
    title: "رد get_my_account وupdate_my_profile وaccept_policies",
    ...object({
      id: uuid,
      display_name: nullable(str),
      region_id: nullable(int),
      avatar_path: nullable(str),
      status: en("account_status"),
      created_at: time,
      profile_complete: bool,
      pending_policies: {
        type: "array",
        items: object({ id: int, kind: en("policy_kind"), version: positive, title: str }),
      },
      can_publish: bool,
    }),
  },

  "listing-draft-patch": {
    title: "p_patch في save_listing_draft",
    description: "المفتاح الغائب لا يتغير، وnull يمسح القيمة. الحدود العليا للنصوص من الإعدادات المنشورة.",
    type: "object",
    additionalProperties: false,
    properties: {
      title: nullable(str),
      description: nullable(str),
      breed_id: nullable(int),
      breed_note: nullable({ ...str, maxLength: 80 }),
      sex: nullable(en("animal_sex")),
      age_months: nullable({ type: "integer", minimum: 1, maximum: 600 }),
      color: nullable({ ...str, maxLength: 60 }),
      region_id: nullable(int),
      city_id: nullable(int),
      health_notes: nullable({ ...str, maxLength: 2000 }),
      owner_declaration: bool,
      offer_type: nullable(en("offer_type")),
      price: nullable({ type: "number", exclusiveMinimum: 0, multipleOf: 0.01 }),
      auction_region_id: nullable(int),
      auction_city_id: nullable(int),
      auction_venue: nullable({ ...str, maxLength: 300 }),
      auction_starts_at: nullable({ ...time, description: "ISO 8601 بمنطقة زمنية؛ يحفظ UTC" }),
      auction_lat: nullable({ type: "number", minimum: -90, maximum: 90, description: "خط عرض موقع المزاد؛ يرسل مع auction_lng ويلزم عند الإرسال للمزاد (1.3.0)" }),
      auction_lng: nullable({ type: "number", minimum: -180, maximum: 180, description: "خط طول موقع المزاد؛ يرسل مع auction_lat (1.3.0)" }),
      contact_phone: nullable({ ...str, description: "رقم الاتصال: 05XXXXXXXX أو ‎+9665XXXXXXXX" }),
      contact_whatsapp_phone: nullable({ ...str, description: "رقم واتساب المستقل: 05XXXXXXXX أو ‎+9665XXXXXXXX (TEAM-DEC-012)" }),
      contact_call_enabled: { ...bool, description: "قديم ومشتق: contact_phone غير فارغ؛ يُتجاهل في patch ويحوَّل" },
      contact_whatsapp_enabled: { ...bool, description: "قديم ومشتق: contact_whatsapp_phone غير فارغ؛ يُتجاهل في patch ويحوَّل" },
    },
  },

  "listing-owner": {
    title: "رد دوال المعلن على الإعلان",
    ...object({
      listing: object({
        id: uuid,
        status: en("listing_status"),
        current_version_id: nullable(uuid),
        published_version_id: nullable(uuid),
        has_draft: bool,
        first_submitted_at: nullable(time),
        first_published_at: nullable(time),
        last_published_at: nullable(time),
        last_bumped_at: nullable(time),
        next_bump_at: nullable(time),
        status_changed_at: time,
        created_at: time,
      }),
      version: nullable(object({
        id: uuid, listing_id: uuid, version_no: positive, status: en("listing_version_status"),
        title: nullable(str), description: nullable(str),
        breed_id: nullable(int), breed_note: nullable(str),
        sex: nullable(en("animal_sex")), age_months: nullable(int), color: nullable(str),
        region_id: nullable(int), city_id: nullable(int),
        health_notes: nullable(str), owner_declaration_at: nullable(time),
        offer_type: nullable(en("offer_type")), price: nullable({ type: "number" }),
        auction_region_id: nullable(int), auction_city_id: nullable(int),
        auction_venue: nullable(str), auction_starts_at: nullable(time),
        auction_lat: nullable({ type: "number" }), auction_lng: nullable({ type: "number" }),
        contact_phone: nullable(str), contact_whatsapp_phone: nullable(str),
        contact_call_enabled: bool, contact_whatsapp_enabled: bool,
        contact_consent_at: nullable(time),
        settings_version: nullable(int), content_hash: nullable(str),
        submitted_at: nullable(time), decided_at: nullable(time),
        created_at: time, updated_at: time,
      })),
      media: {
        type: "array",
        items: object({
          id: uuid, kind: en("media_kind"), status: en("media_status"),
          bucket: str, object_path: str,
          mime_type: nullable(str), size_bytes: nullable(int),
          width: nullable(int), height: nullable(int), duration_seconds: nullable({ type: "number" }),
          sort_order: int, is_cover: bool,
          failure_reason: nullable({ enum: errors.media_failure_reasons.values }),
        }),
      },
    }),
  },

  "public-listing-card": {
    title: "صف من public_listing_cards",
    ...object({
      listing_id: uuid, owner_id: uuid, owner_display_name: str,
      title: str, offer_type: en("offer_type"),
      price: nullable({ type: "number" }), auction_starts_at: nullable(time), auction_passed: bool,
      breed_id: int, breed_name_ar: str, breed_note: nullable(str),
      sex: en("animal_sex"), age_months: int,
      region_id: int, region_name_ar: str, city_id: int, city_name_ar: str,
      cover_bucket: nullable(str), cover_path: nullable(str),
      first_published_at: time, visibility_updated_at: time, public_ref: str,
      auction_lat: nullable({ type: "number" }), auction_lng: nullable({ type: "number" }),
      view_count: int, favorite_count: int,
    }),
  },

  "public-listing-details": {
    title: "صف من public_listing_details",
    ...object({
      listing_id: uuid, owner_id: uuid, owner_display_name: str, owner_joined_at: time,
      title: str, description: str, offer_type: en("offer_type"),
      price: nullable({ type: "number" }),
      auction_region_id: nullable(int), auction_region_name_ar: nullable(str),
      auction_city_id: nullable(int), auction_city_name_ar: nullable(str),
      auction_venue: nullable(str), auction_starts_at: nullable(time), auction_passed: bool,
      breed_id: int, breed_name_ar: str, breed_note: nullable(str),
      sex: en("animal_sex"), age_months: int, color: nullable(str), health_notes: str,
      region_id: int, region_name_ar: str, city_id: int, city_name_ar: str,
      contact_phone: nullable(str), contact_whatsapp_phone: nullable(str),
      contact_call_enabled: bool, contact_whatsapp_enabled: bool,
      first_published_at: time, published_version_at: time, visibility_updated_at: time, public_ref: str,
      auction_lat: nullable({ type: "number" }), auction_lng: nullable({ type: "number" }),
      view_count: int, favorite_count: int,
    }),
  },

  // عنصر نتيجة البحث: أعمدة البطاقة نفسها.
  "search-result": {
    title: "رد search_listings",
    ...object({
      items: { type: "array", items: { $ref: `${BASE}/public-listing-card.schema.json` } },
      next_cursor: nullable({
        type: "object",
        description: "يمرر كما هو في p_cursor للصفحة التالية مع المرشحات والفرز نفسها",
        additionalProperties: false,
        properties: { ts: time, price: nullable({ type: "number" }), id: uuid },
        required: ["id"],
      }),
    }),
  },

  "listing-detail": {
    title: "رد get_listing",
    ...object({
      listing: { $ref: `${BASE}/public-listing-details.schema.json` },
      media: {
        type: "array",
        items: object({
          media_id: uuid, kind: en("media_kind"), bucket: str, object_path: str, mime_type: str,
          width: nullable(int), height: nullable(int), duration_seconds: nullable({ type: "number" }),
          sort_order: int, is_cover: bool,
        }),
      },
      is_favorite: bool,
    }),
  },

  "my-favorite": {
    title: "صف من my_favorites",
    description: "available=false: الإعلان لم يعد منشورًا؛ بقية الأعمدة فارغة.",
    ...object({
      listing_id: uuid, saved_at: time, available: bool,
      owner_id: nullable(uuid), owner_display_name: nullable(str),
      title: nullable(str), offer_type: nullable(en("offer_type")),
      price: nullable({ type: "number" }), auction_starts_at: nullable(time), auction_passed: nullable(bool),
      breed_id: nullable(int), breed_name_ar: nullable(str), breed_note: nullable(str),
      sex: nullable(en("animal_sex")), age_months: nullable(int),
      region_id: nullable(int), region_name_ar: nullable(str), city_id: nullable(int), city_name_ar: nullable(str),
      cover_bucket: nullable(str), cover_path: nullable(str), public_ref: nullable(str),
      auction_lat: nullable({ type: "number" }), auction_lng: nullable({ type: "number" }),
      view_count: nullable(int), favorite_count: nullable(int),
    }),
  },

  "my-conversation": {
    title: "صف من my_conversations",
    description: "listing_available=false: الإعلان لم يعد منشورًا وعنوانه وغلافه فارغان. writable=false: للقراءة فقط.",
    ...object({
      conversation_id: uuid, listing_id: uuid,
      my_role: { enum: ["BUYER", "SELLER"] },
      other_user_id: uuid, other_display_name: nullable(str),
      listing_available: bool, listing_title: nullable(str),
      cover_bucket: nullable(str), cover_path: nullable(str),
      writable: bool, muted: bool,
      last_message_at: nullable(time), last_message_body: nullable(str), last_message_sender_id: nullable(uuid),
      unread_count: int, created_at: time,
    }),
  },

  message: {
    title: "صف من messages",
    ...object({
      id: uuid, conversation_id: uuid, sender_id: uuid, body: str, request_id: uuid, created_at: time,
    }),
  },

  "public-comment": {
    title: "صف من public_comments",
    description: "state=HIDDEN أو DELETED: body فارغ.",
    ...object({
      comment_id: uuid, listing_id: uuid, parent_id: nullable(uuid), author_id: uuid,
      author_display_name: nullable(str), is_owner: bool,
      state: { enum: ["VISIBLE", "HIDDEN", "DELETED"] },
      body: nullable(str), edited_at: nullable(time), created_at: time,
    }),
  },

  "report-status": {
    title: "رد get_report_status",
    ...object({
      report_id: uuid, ref: str,
      status: { enum: ["OPEN", "IN_REVIEW", "CLOSED"] },
      target_type: { enum: ["LISTING", "ACCOUNT", "MESSAGE", "COMMENT"] },
      created_at: time, closed_at: nullable(time), response_text: nullable(str),
    }),
  },

  "my-saved-search": {
    title: "صف من my_saved_searches",
    ...object({ id: uuid, name: nullable(str), filters: { type: "object" }, created_at: time }),
  },

  "my-follow": {
    title: "صف من my_follows",
    ...object({
      user_id: uuid, display_name: nullable(str), region_id: nullable(int), region_name_ar: nullable(str),
      followed_at: time, published_listings_count: int,
    }),
  },

  "public-rating": {
    title: "صف من public_ratings",
    description: "التقييمات الظاهرة فقط؛ المخفي لا يظهر ولا يدخل في المتوسط.",
    ...object({
      rating_id: uuid, seller_id: uuid, rater_id: uuid, rater_display_name: nullable(str),
      score: { type: "integer", minimum: 1, maximum: 5 }, body: nullable(str),
      reply_body: nullable(str), reply_at: nullable(time), edited_at: nullable(time), created_at: time,
    }),
  },

  "my-received-rating": {
    title: "صف من my_received_ratings",
    ...object({
      rating_id: uuid, rater_id: uuid, rater_display_name: nullable(str),
      score: { type: "integer", minimum: 1, maximum: 5 }, body: nullable(str),
      status: { enum: ["VISIBLE", "HIDDEN"] }, reply_body: nullable(str),
      appeal_id: nullable(uuid), appeal_status: nullable({ enum: ["OPEN", "ACCEPTED", "REJECTED"] }),
      edited_at: nullable(time), created_at: time,
    }),
  },

  "rating-eligibility": {
    title: "رد get_rating_eligibility",
    ...object({
      eligible: bool,
      reason: { enum: ["SELF", "ALREADY_RATED", "BLOCKED", "NO_CONVERSATION", "NO_EXCHANGE"] },
      rating_id: uuid,
    }, ["reason", "rating_id"]),
  },

  "admin-stats": {
    title: "رد admin_stats",
    description: "أعداد تجميعية فقط.",
    type: "object",
    required: ["period", "generated_at", "accounts", "listings", "reports", "interaction", "follows", "ratings"],
    properties: {
      period: object({ from: time, to: time }), generated_at: time,
      accounts: { type: "object" }, listings: { type: "object" }, reports: { type: "object" },
      interaction: { type: "object" }, follows: { type: "object" }, ratings: { type: "object" },
    },
  },

  notification: {
    title: "صف من notifications",
    ...object({
      id: uuid, recipient_id: uuid,
      category: en("notification_category"),
      event: { enum: [
        "listing.approved", "listing.rejected", "listing.hidden", "listing.unhidden",
        "account.suspended", "account.reactivated",
        "message.received", "comment.created", "comment.replied", "follow.new_listing", "report.closed",
        "rating.received", "rating.replied", "rating.appeal_decided",
      ] },
      resource_type: { enum: ["listing", "account", "conversation", "report", "rating"] },
      resource_id: str,
      payload: { type: "object" },
      dedupe_key: str,
      read_at: nullable(time),
      created_at: time,
    }),
  },
};

mkdirSync("contracts/schemas", { recursive: true });
for (const [name, schema] of Object.entries(schemas)) {
  const document = {
    $schema: "https://json-schema.org/draft/2020-12/schema",
    $id: `${BASE}/${name}.schema.json`,
    ...schema,
  };
  writeFileSync(`contracts/schemas/${name}.schema.json`, JSON.stringify(document, null, 2) + "\n");
  console.log(`schema: ${name}.schema.json`);
}
