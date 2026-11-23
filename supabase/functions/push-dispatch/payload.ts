// نص إشعار الدفع من نوع الحدث فقط — MOBILE-BE-305.
// لا يدخل في النص أي محتوى خاص: لا نص رسائل ولا ردود ولا عناوين إعلانات ولا
// أسباب قرارات (AD-FR-016). التفاصيل تقرأ من مركز الإشعارات بعد فتح التطبيق.

export interface PushJob {
  outbox_id: number;
  notification_id: string;
  category: string;
  event: string;
  resource_type: string;
  resource_id: string;
  tokens: string[];
}

const TITLES: Record<string, string> = {
  "listing.approved": "تم نشر إعلانك",
  "listing.rejected": "تحديث على إعلانك",
  "listing.hidden": "تحديث على إعلانك",
  "listing.unhidden": "أُعيد إظهار إعلانك",
  "account.suspended": "تحديث على حسابك",
  "account.reactivated": "أُعيد تفعيل حسابك",
  "message.received": "رسالة جديدة",
  "comment.created": "رد جديد على إعلانك",
  "comment.replied": "رد على سؤالك",
  "follow.new_listing": "إعلان جديد يهمك",
  "report.closed": "تم إغلاق بلاغك",
};

const BODY = "افتح التطبيق لعرض التفاصيل.";

/** رسالة FCM HTTP v1 لرمز جهاز واحد. حقل data نصوص فقط ويحمل ما يفتح المورد. */
export function buildMessage(job: PushJob, token: string) {
  return {
    message: {
      token,
      notification: {
        title: TITLES[job.event] ?? "إشعار جديد",
        body: BODY,
      },
      data: {
        notification_id: job.notification_id,
        event: job.event,
        resource_type: job.resource_type,
        resource_id: job.resource_id,
      },
      android: { priority: "HIGH" },
    },
  };
}

/** رد FCM الذي يعني أن الرمز لم يعد صالحًا فيعطل. */
export function isInvalidTokenResponse(status: number, body: unknown): boolean {
  if (status === 404) return true;
  const details = (body as { error?: { details?: { errorCode?: string }[] } })?.error?.details;
  return !!details?.some((d) => d.errorCode === "UNREGISTERED" || d.errorCode === "INVALID_ARGUMENT");
}
