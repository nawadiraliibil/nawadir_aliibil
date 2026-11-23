import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// رموز الأخطاء كما في `contracts/api/errors.json`، مضافًا إليها رموز جهة العميل.
///
/// اختبار `test/contracts/` يقارن [AppErrorCode.wire] بالعقد فلا ينحرفان.
enum AppErrorCode {
  validationFailed('VALIDATION_FAILED'),
  belowHardMinimum('BELOW_HARD_MINIMUM'),
  appendOnly('APPEND_ONLY'),
  internalError('INTERNAL_ERROR'),
  authRequired('AUTH_REQUIRED'),
  forbidden('FORBIDDEN'),
  accountSuspended('ACCOUNT_SUSPENDED'),
  profileIncomplete('PROFILE_INCOMPLETE'),
  policiesNotAccepted('POLICIES_NOT_ACCEPTED'),
  mfaRequired('MFA_REQUIRED'),
  invalidState('INVALID_STATE'),
  cannotModifySelf('CANNOT_MODIFY_SELF'),
  lastAdmin('LAST_ADMIN'),
  versionImmutable('VERSION_IMMUTABLE'),
  notFound('NOT_FOUND'),
  draftLimitReached('DRAFT_LIMIT_REACHED'),
  mediaLimitReached('MEDIA_LIMIT_REACHED'),
  mediaNotReady('MEDIA_NOT_READY'),
  videoDisabled('VIDEO_DISABLED'),
  rateLimited('RATE_LIMITED'),
  bumpTooEarly('BUMP_TOO_EARLY'),
  auctionTimePassed('AUCTION_TIME_PASSED'),
  versionChanged('VERSION_CHANGED'),
  reasonRequired('REASON_REQUIRED'),
  mediaNotUploaded('MEDIA_NOT_UPLOADED'),
  mediaProcessingFailed('MEDIA_PROCESSING_FAILED'),
  methodNotAllowed('METHOD_NOT_ALLOWED'),
  cannotMessageSelf('CANNOT_MESSAGE_SELF'),
  conversationReadOnly('CONVERSATION_READ_ONLY'),
  commentsClosed('COMMENTS_CLOSED'),
  followLimitReached('FOLLOW_LIMIT_REACHED'),
  ratingNotEligible('RATING_NOT_ELIGIBLE'),
  ratingExists('RATING_EXISTS'),

  /// لا اتصال بالشبكة أو انتهت المهلة. يخص العميل فقط.
  network('NETWORK'),

  /// خطأ غير معروف للعقد. يخص العميل فقط.
  unknown('UNKNOWN');

  const AppErrorCode(this.wire);

  /// القيمة كما يرسلها الخادم.
  final String wire;

  /// رموز العقد وحدها، دون رموز العميل.
  static Iterable<AppErrorCode> get contractCodes =>
      values.where((c) => c != network && c != unknown);

  static AppErrorCode? tryParse(String? wire) {
    for (final code in values) {
      if (code.wire == wire) return code;
    }
    return null;
  }
}

/// خطأ تطبيقي موحد. تحوّل [AppError.from] كل ما يرميه العميل إلى هذا النوع
/// ليتعامل معه كل مستودع وشاشة بالطريقة نفسها.
class AppError implements Exception {
  const AppError(this.code, {this.details = const {}, this.cause});

  final AppErrorCode code;

  /// حقل `details` في رد الخادم بعد فك ترميزه، أو خريطة فارغة.
  final Map<String, dynamic> details;

  /// الاستثناء الأصلي للتشخيص. لا يعرض للمستخدم.
  final Object? cause;

  /// هل يفيد إعادة المحاولة بالطلب نفسه.
  bool get isRetryable =>
      code == AppErrorCode.network ||
      code == AppErrorCode.internalError ||
      code == AppErrorCode.mediaProcessingFailed;

  /// يحوّل أي استثناء إلى [AppError]. يمرر [AppError] كما هو.
  factory AppError.from(Object error) {
    if (error is AppError) return error;
    if (error is PostgrestException) return _fromPostgrest(error);
    if (error is FunctionException) return _fromFunction(error);
    if (error is AuthException) return _fromAuth(error);
    if (error is StorageException) return _fromStorage(error);
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException) {
      return AppError(AppErrorCode.network, cause: error);
    }
    return AppError(AppErrorCode.unknown, cause: error);
  }

  static AppError _fromPostgrest(PostgrestException e) {
    final code = AppErrorCode.tryParse(e.message);
    if (code != null) {
      return AppError(code, details: _decodeDetails(e.details), cause: e);
    }
    // PostgREST نفسه: JWT منتهٍ أو مرفوض.
    if (e.code == 'PGRST301' || e.code == 'PGRST303') {
      return AppError(AppErrorCode.authRequired, cause: e);
    }
    if (e.code == '42501') return AppError(AppErrorCode.forbidden, cause: e);
    return AppError(AppErrorCode.unknown, cause: e);
  }

  static AppError _fromFunction(FunctionException e) {
    final body = e.details;
    if (body is Map) {
      final code = AppErrorCode.tryParse(
        (body['code'] ?? body['error'])?.toString(),
      );
      if (code != null) {
        return AppError(
          code,
          details: _decodeDetails(body['details']),
          cause: e,
        );
      }
    }
    if (e.status == 401) return AppError(AppErrorCode.authRequired, cause: e);
    if (e.status >= 500) return AppError(AppErrorCode.internalError, cause: e);
    return AppError(AppErrorCode.unknown, cause: e);
  }

  static AppError _fromStorage(StorageException e) {
    switch (e.statusCode) {
      case '401':
        return AppError(AppErrorCode.authRequired, cause: e);
      case '403':
        return AppError(AppErrorCode.forbidden, cause: e);
      case '413':
        return AppError(AppErrorCode.validationFailed, cause: e);
      case '503' || '504':
        return AppError(AppErrorCode.network, cause: e);
    }
    return AppError(AppErrorCode.unknown, cause: e);
  }

  static AppError _fromAuth(AuthException e) {
    // الدخول بالهاتف: رمز خاطئ أو منتهٍ، وتجاوز حد الإرسال، يعالجان في شاشتهما
    // برمز الخطأ الأصلي؛ هنا نصنف فقط ما يخص الجلسة والشبكة.
    if (e is AuthRetryableFetchException) {
      return AppError(AppErrorCode.network, cause: e);
    }
    if (e is AuthSessionMissingException || e.statusCode == '401') {
      return AppError(AppErrorCode.authRequired, cause: e);
    }
    if (e.statusCode == '429') {
      return AppError(AppErrorCode.rateLimited, cause: e);
    }
    return AppError(AppErrorCode.unknown, cause: e);
  }

  /// `details` يصل نص JSON من PostgREST وكائنًا من دوال Edge.
  static Map<String, dynamic> _decodeDetails(Object? raw) {
    try {
      final value = raw is String ? jsonDecode(raw) : raw;
      if (value is Map) return Map<String, dynamic>.from(value);
    } on FormatException {
      // نص حر لا JSON: لا تفاصيل.
    }
    return const {};
  }

  @override
  String toString() => 'AppError(${code.wire}, $details)';
}
