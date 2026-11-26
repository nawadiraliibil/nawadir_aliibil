// أشكال ردود دوال الإعلانات كما في الترحيلات (آخر تعريف) وأمثلة العقد:
// admin_list_listings (20261124100000_direct_publish.sql) ← contracts/fixtures/admin-list-listings.json
// admin_get_listing_review (20261122230000_listing_admin_rpcs.sql) ← contracts/fixtures/admin-listing-review.json
// admin_hide_listing / admin_unhide_listing تعيدان listing_admin_json ← contracts/fixtures/admin-unhidden-listing.json
// القيم النصية للتعدادات تبقى string لأن أمثلة JSON تستورد بأنواع موسعة.

export interface StorageRef {
  bucket: string
  object_path: string
}

/** عنصر من admin_list_listings. */
export interface AdminListingItem {
  listing_id: string
  public_ref: string
  status: string
  version_id: string | null
  version_no: number | null
  published_version_id: string | null
  has_draft: boolean
  title: string | null
  offer_type: string | null
  price: number | null
  auction_starts_at: string | null
  region_id: number | null
  city_id: number | null
  owner_id: string
  owner_display_name: string | null
  owner_status: string | null
  first_published_at: string | null
  last_published_at: string | null
  status_changed_at: string
  deleted_at: string | null
  created_at: string
  hide_reason_code: string | null
  hide_reason_text: string | null
  hidden_at: string | null
  cover: StorageRef | null
}

/** private.listing_admin_json. */
export interface ListingAdmin {
  id: string
  owner_id: string
  status: string
  current_version_id: string | null
  published_version_id: string | null
  first_submitted_at: string | null
  first_published_at: string | null
  published_version_at: string | null
  last_published_at: string | null
  last_bumped_at: string | null
  visibility_updated_at: string | null
  status_changed_at: string
  deleted_at: string | null
  created_at: string
}

/** صف listing_versions دون submit_request_id. */
export interface ListingVersion {
  id: string
  listing_id: string
  version_no: number
  status: string
  title: string | null
  description: string | null
  breed_id: number | null
  breed_note: string | null
  sex: string | null
  age_months: number | null
  color?: string | null
  health_notes?: string | null
  region_id: number | null
  city_id: number | null
  offer_type: string | null
  price: number | null
  auction_region_id: number | null
  auction_city_id: number | null
  auction_venue: string | null
  auction_starts_at: string | null
  /** من 1.3.0؛ قد يغيب في ردود أقدم. */
  auction_lat?: number | null
  auction_lng?: number | null
  /** INT-007: أي الرقمين قد يكون فارغًا؛ لا يفترض وجود contact_phone. */
  contact_phone?: string | null
  contact_whatsapp_phone?: string | null
  /** قيم مشتقة للتوافق؛ ليست مدخلات. */
  contact_call_enabled?: boolean | null
  contact_whatsapp_enabled?: boolean | null
  contact_consent_at?: string | null
  owner_declaration_at?: string | null
  content_hash: string | null
  settings_version?: number | null
  created_at: string
  updated_at?: string | null
  submitted_at: string | null
  decided_at: string | null
}

/** private.version_media_json. */
export interface ListingMedia {
  id: string
  kind: string
  status: string
  bucket: string
  object_path: string
  mime_type: string | null
  size_bytes: number | null
  width: number | null
  height: number | null
  duration_seconds: number | null
  sort_order: number
  is_cover: boolean
}

export interface ListingOwner {
  id: string
  display_name: string | null
  region_id: number | null
  status: string
  created_at: string
}

export interface ListingReview {
  id: number
  version_id: string | null
  decision: string
  reason_code: string | null
  reason_text: string | null
  moderator_id: string | null
  created_at: string
}

/** admin_get_listing_review. published_version لا يعاد إلا إذا اختلف عن version (مسودة تعديل خاصة). */
export interface ListingReviewPayload {
  listing: ListingAdmin
  version: ListingVersion | null
  media: ListingMedia[] | null
  published_version: ListingVersion | null
  published_media: ListingMedia[] | null
  owner: ListingOwner | null
  reviews: ListingReview[] | null
}

/** قراءات إضافية اختيارية من الجداول المسموحة للموظف. */
export interface ListingExtras {
  public_ref: string | null
  comments_closed: boolean | null
  view_count: number | null
  favorite_count: number | null
}

export interface LookupNames {
  breeds: Map<number, string>
  regions: Map<number, string>
  cities: Map<number, string>
}

export interface ListCursor {
  changed_at: string
  id: string
}

export interface ListFilters {
  status: string
  q: string
}
