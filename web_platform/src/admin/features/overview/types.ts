// شكل رد admin_stats (supabase/migrations/20261123170000_admin_stats.sql، آخر تعريف للدالة)
// ومثال العقد contracts/fixtures/admin-stats.json والمخطط contracts/schemas/admin-stats.schema.json.
// أعداد تجميعية فقط؛ المجموعات كائنات أعداد وقد يضيف الخادم مفاتيح لاحقًا.

export interface AdminStatsPeriod {
  from: string
  to: string
}

export type StatsGroupValues = Record<string, number>

export interface AdminStats {
  period: AdminStatsPeriod
  generated_at: string
  accounts: StatsGroupValues & { total?: number; created?: number; suspended_now?: number }
  listings: StatsGroupValues & {
    submitted?: number
    approved?: number
    hidden?: number
    published_now?: number
    /** ميت بعد TEAM-DEC-013 (INT-008)؛ لا يعرض. */
    rejected?: number
    /** ميت بعد TEAM-DEC-013 (INT-008)؛ لا يعرض. */
    under_review_now?: number
  }
  reports: StatsGroupValues & { opened?: number; closed?: number; open_now?: number }
  ratings: StatsGroupValues & { created?: number; hidden_now?: number; appeals_opened?: number; appeals_open_now?: number }
  follows: StatsGroupValues & { searches_saved?: number; sellers_followed?: number }
  interaction: StatsGroupValues & {
    conversations_started?: number
    messages_sent?: number
    comments_posted?: number
    favorites_added?: number
  }
  /** مجموعات إضافية قد يضيفها الخادم لاحقًا. */
  [group: string]: unknown
}

/** نطاق أيام بتوقيت الرياض (YYYY-MM-DD) كما في حقول التاريخ. */
export interface DayRange {
  from: string
  to: string
}
