import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthFailureKind {
  /// الرمز خاطئ أو منتهٍ أو مستهلك.
  invalidCode,

  /// تجاوز حد الإرسال أو التحقق في الخادم.
  rateLimited,

  /// الخادم رفض الرقم.
  invalidPhone,

  /// لا اتصال.
  network,

  /// تعذر الإرسال أو سبب غير معروف.
  unavailable,
}

class AuthFailure implements Exception {
  const AuthFailure(this.kind, [this.cause]);

  final AuthFailureKind kind;
  final Object? cause;

  @override
  String toString() => 'AuthFailure($kind)';
}

/// واجهة الدخول التي تعتمد عليها الشاشات. تُستبدل في الاختبارات.
abstract class AuthBackend {
  bool get isSignedIn;

  /// هاتف الدخول للجلسة الحالية (أرقام فقط، مثل 9665XXXXXXXX)، أو null.
  String? get phone;

  /// معرف المستخدم صاحب الجلسة، أو null.
  String? get userId;

  /// يبث عند كل تغير في حالة الدخول.
  Stream<bool> get signedInChanges;

  /// يطلب رمزًا لمرة واحدة بالرسائل النصية. يرمي [AuthFailure].
  Future<void> sendOtp(String phoneE164);

  /// يتحقق من الرمز ويفتح الجلسة. يرمي [AuthFailure].
  Future<void> verifyOtp(String phoneE164, String code);

  /// دخول بالبريد وكلمة المرور. **للتطوير فقط**: يخفيه التطبيق خارج بيئة `dev`.
  Future<void> signInWithPassword(String email, String password);

  /// يبطل الجلسة في الخادم ويمحوها من الجهاز.
  Future<void> signOut();
}

class SupabaseAuthBackend implements AuthBackend {
  SupabaseAuthBackend(this._auth);

  final GoTrueClient _auth;

  @override
  bool get isSignedIn => _auth.currentSession != null;

  @override
  String? get phone => _auth.currentUser?.phone;

  @override
  String? get userId => _auth.currentUser?.id;

  @override
  Stream<bool> get signedInChanges =>
      _auth.onAuthStateChange.map((s) => s.session != null);

  @override
  Future<void> sendOtp(String phoneE164) =>
      _guard(() => _auth.signInWithOtp(phone: phoneE164));

  @override
  Future<void> verifyOtp(String phoneE164, String code) => _guard(
    () => _auth.verifyOTP(phone: phoneE164, token: code, type: OtpType.sms),
  );

  @override
  Future<void> signInWithPassword(String email, String password) =>
      _guard(() => _auth.signInWithPassword(email: email, password: password));

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  static Future<void> _guard(Future<void> Function() run) async {
    try {
      await run();
    } on AuthException catch (e) {
      throw classify(e);
    } on SocketException catch (e) {
      throw AuthFailure(AuthFailureKind.network, e);
    } on TimeoutException catch (e) {
      throw AuthFailure(AuthFailureKind.network, e);
    }
  }

  /// يصنف رد المصادقة. الحدود تفرض في الخادم؛ العميل يعرض نتيجتها فقط.
  static AuthFailure classify(AuthException e) {
    if (e is AuthRetryableFetchException) {
      return AuthFailure(AuthFailureKind.network, e);
    }
    final code = e.code ?? '';
    final status = e.statusCode ?? '';
    if (code.startsWith('over_') ||
        code == 'sms_send_rate_limit' ||
        status == '429') {
      return AuthFailure(AuthFailureKind.rateLimited, e);
    }
    // الخادم يعيد `otp_expired` للرمز الخاطئ والمنتهي والمستهلك معًا.
    if (code == 'otp_expired') {
      return AuthFailure(AuthFailureKind.invalidCode, e);
    }
    if (code == 'validation_failed' || code == 'phone_not_confirmed') {
      return AuthFailure(AuthFailureKind.invalidPhone, e);
    }
    return AuthFailure(AuthFailureKind.unavailable, e);
  }
}
