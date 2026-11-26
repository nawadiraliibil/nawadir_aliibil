// أنواع ميزة التقييمات والاعتراضات (AD-FR-036). الأعمدة من contracts/generated/database.types.ts
// وأشكال ردود الدوال من supabase/migrations/20261123160000_ratings.sql وcontracts/fixtures.
import type { Database } from '@contracts/generated/database.types'

type Tables = Database['public']['Tables']

export type SellerRatingRow = Tables['seller_ratings']['Row']
export type RatingHistoryRow = Tables['seller_rating_history']['Row']
export type RatingReplyRow = Tables['rating_replies']['Row']
export type RatingAppealRow = Tables['rating_appeals']['Row']

/** قيم seller_ratings.status (قيد الجدول). */
export type RatingStatus = 'VISIBLE' | 'HIDDEN'
/** قيم rating_appeals.status (قيد الجدول). */
export type AppealStatus = 'OPEN' | 'ACCEPTED' | 'REJECTED'
export type AppealDecision = 'ACCEPTED' | 'REJECTED'

/** صف قائمة التقييمات (أعمدة مختارة من seller_ratings). */
export type RatingListItem = Pick<
  SellerRatingRow,
  'id' | 'rater_id' | 'seller_id' | 'score' | 'body' | 'status' | 'hidden_reason_code' | 'hidden_reason_text' | 'hidden_at' | 'edited_at' | 'created_at'
>

/** صف قائمة الاعتراضات (أعمدة rating_appeals). */
export type AppealListItem = Pick<
  RatingAppealRow,
  'id' | 'rating_id' | 'seller_id' | 'reason' | 'status' | 'decision_note' | 'decided_by' | 'decided_at' | 'created_at'
>

/** درجة التقييم وحالته لصفوف الاعتراضات. */
export type RatingScoreRef = Pick<SellerRatingRow, 'id' | 'score' | 'status'>

/** رد admin_hide_rating / admin_unhide_rating. */
export interface RatingStatusResult {
  rating_id: string
  status: RatingStatus
}

/** رد admin_decide_rating_appeal (contracts/fixtures/admin-appeal-decided.json). */
export interface AppealDecidedResult {
  appeal_id: string
  status: AppealDecision
}

export interface RatingDetail {
  rating: SellerRatingRow
  history: RatingHistoryRow[]
  reply: RatingReplyRow | null
  appeals: RatingAppealRow[]
}
