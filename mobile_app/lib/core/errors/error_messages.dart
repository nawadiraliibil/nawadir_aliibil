import 'package:intl/intl.dart';

import 'app_error.dart';

/// رسالة عربية للمستخدم لكل خطأ. لا تعرض تفاصيل تقنية ولا أسماء جداول.
String errorMessage(AppError error) {
  final d = error.details;
  switch (error.code) {
    case AppErrorCode.validationFailed:
      return 'تحقق من البيانات المدخلة وحاول مرة أخرى.';
    case AppErrorCode.belowHardMinimum:
      return 'القيمة أقل من الحد المسموح.';
    case AppErrorCode.appendOnly:
      return 'لا يمكن تعديل هذا السجل.';
    case AppErrorCode.internalError:
      return 'حدث خطأ غير متوقع. حاول مرة أخرى بعد قليل.';
    case AppErrorCode.authRequired:
      return 'سجّل الدخول للمتابعة.';
    case AppErrorCode.forbidden:
      return 'لا تملك صلاحية تنفيذ هذا الإجراء.';
    case AppErrorCode.accountSuspended:
      return 'حسابك معلّق ولا يمكنك النشر أو التعديل.';
    case AppErrorCode.profileIncomplete:
      return 'أكمل بيانات حسابك قبل النشر.';
    case AppErrorCode.policiesNotAccepted:
      return 'وافق على الشروط والسياسات المحدّثة للمتابعة.';
    case AppErrorCode.mfaRequired:
      return 'أكمل التحقق الثنائي للمتابعة.';
    case AppErrorCode.invalidState:
      return 'هذا الإجراء غير متاح في حالة الإعلان الحالية.';
    case AppErrorCode.cannotModifySelf:
      return 'لا يمكنك تغيير صلاحياتك بنفسك.';
    case AppErrorCode.lastAdmin:
      return 'لا يمكن سحب صلاحية آخر مدير.';
    case AppErrorCode.versionImmutable:
      return 'لا يمكن تعديل نسخة الإعلان هذه.';
    case AppErrorCode.notFound:
      return 'العنصر غير متاح.';
    case AppErrorCode.draftLimitReached:
      final limit = _int(d['limit']);
      return limit == null
          ? 'بلغت الحد الأقصى من المسودات المفتوحة.'
          : 'بلغت الحد الأقصى من المسودات المفتوحة ($limit).';
    case AppErrorCode.mediaLimitReached:
      final limit = _int(d['limit']);
      final what = d['kind'] == 'VIDEO' ? 'الفيديو' : 'الصور';
      return limit == null
          ? 'بلغت الحد الأقصى من $what.'
          : 'بلغت الحد الأقصى من $what ($limit).';
    case AppErrorCode.mediaNotReady:
      return 'بعض الصور لم يكتمل تجهيزها. انتظر قليلًا أو أعد رفعها.';
    case AppErrorCode.videoDisabled:
      return 'رفع الفيديو غير متاح حاليًا.';
    case AppErrorCode.rateLimited:
      final retry = _time(d['retry_at']);
      return retry == null
          ? 'تجاوزت الحد المسموح. حاول لاحقًا.'
          : 'تجاوزت الحد المسموح. حاول بعد $retry.';
    case AppErrorCode.bumpTooEarly:
      final at = _time(d['eligible_at']);
      return at == null
          ? 'لم تحن مدة تجديد الظهور بعد.'
          : 'يمكنك تجديد الظهور بعد $at.';
    case AppErrorCode.auctionTimePassed:
      return 'مضى موعد المزاد.';
    case AppErrorCode.versionChanged:
      return 'تغيّر الإعلان أثناء المراجعة. حدّث الصفحة وأعد المحاولة.';
    case AppErrorCode.reasonRequired:
      return 'اختر سببًا واكتب التفاصيل عند اختيار «أخرى».';
    case AppErrorCode.mediaNotUploaded:
      return 'لم يكتمل رفع الصورة. أعد المحاولة.';
    case AppErrorCode.mediaProcessingFailed:
      return 'تعذّرت معالجة الصورة. أعد المحاولة.';
    case AppErrorCode.methodNotAllowed:
      return 'حدث خطأ غير متوقع. حاول مرة أخرى بعد قليل.';
    case AppErrorCode.cannotMessageSelf:
      return 'هذا إعلانك؛ لا يمكنك مراسلة نفسك.';
    case AppErrorCode.conversationReadOnly:
      return 'هذه المحادثة للقراءة فقط ولا تقبل رسائل جديدة.';
    case AppErrorCode.commentsClosed:
      return 'أغلق المعلن الردود الجديدة على هذا الإعلان.';
    case AppErrorCode.followLimitReached:
      final limit = _int(d['limit']);
      final what = d['kind'] == 'sellers'
          ? 'المعلنين المتابَعين'
          : 'عمليات البحث المحفوظة';
      return limit == null
          ? 'بلغت الحد الأقصى من $what.'
          : 'بلغت الحد الأقصى من $what ($limit).';
    case AppErrorCode.ratingNotEligible:
      return switch (d['reason']) {
        'SELF' => 'لا يمكنك تقييم نفسك.',
        'BLOCKED' => 'لا يمكن التقييم بسبب الحظر.',
        _ => 'يمكن التقييم بعد تبادل رسائل مع المعلن في محادثة.',
      };
    case AppErrorCode.ratingExists:
      return 'قيّمت هذا المعلن من قبل. يمكنك تعديل تقييمك.';
    case AppErrorCode.network:
      return 'تعذّر الاتصال. تحقق من الإنترنت وحاول مرة أخرى.';
    case AppErrorCode.unknown:
      return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  }
}

/// سبب فشل وسيط (`media.failure_reason`) بنص عربي.
String mediaFailureMessage(String? reason) {
  switch (reason) {
    case 'EMPTY_FILE':
      return 'الملف فارغ.';
    case 'UNSUPPORTED_TYPE':
      return 'نوع الملف غير مدعوم. المسموح JPEG وPNG.';
    case 'FILE_TOO_LARGE':
      return 'حجم الملف أكبر من المسموح.';
    case 'CORRUPT_FILE':
      return 'الملف تالف.';
    case 'VIDEO_TOO_LONG':
      return 'مدة الفيديو أطول من المسموح.';
    case 'VIDEO_PROCESSING_UNAVAILABLE':
      return 'معالجة الفيديو غير متاحة حاليًا.';
    default:
      return 'تعذّر قبول الملف.';
  }
}

int? _int(Object? v) => v is num ? v.toInt() : null;

/// وقت ISO 8601 بتوقيت الجهاز، مثل «٢٣ نوفمبر ٠٥:٣٢ م».
String? _time(Object? v) {
  if (v is! String) return null;
  final t = DateTime.tryParse(v)?.toLocal();
  if (t == null) return null;
  return DateFormat('d MMMM hh:mm a', 'ar').format(t);
}
