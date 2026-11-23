import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/rpc.dart';

/// حالة إذن الإشعارات الفورية على الجهاز.
enum PushPermission { granted, denied, notDetermined }

/// مصدر رمز الدفع على الجهاز (FCM). يُستبدل في الاختبارات.
///
/// التنفيذ الحقيقي بـ`firebase_messaging` ينتظر مشروع Firebase وملف
/// `google-services.json` (INT-006). إلى ذلك يستعمل [NoopPushService]: مركز
/// الإشعارات داخل التطبيق يعمل دون الدفع (AD-FR-016).
abstract class PushService {
  /// هل الدفع مهيأ على هذا البناء؟
  bool get available;

  Future<PushPermission> permission();

  /// يطلب الإذن من المستخدم.
  Future<PushPermission> requestPermission();

  /// رمز الجهاز الحالي، أو `null` دون إذن أو تهيئة.
  Future<String?> token();

  /// رمز جديد بعد تجديد المزود له.
  Stream<String> get onTokenRefresh;

  /// منصة الجهاز: `ANDROID` أو `IOS`.
  String get platform;
}

/// دفع غير مهيأ: لا رمز ولا إذن.
class NoopPushService implements PushService {
  const NoopPushService();

  @override
  bool get available => false;

  @override
  Future<PushPermission> permission() async => PushPermission.notDetermined;

  @override
  Future<PushPermission> requestPermission() async => PushPermission.denied;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  String get platform => 'ANDROID';
}

final pushServiceProvider = Provider<PushService>(
  (ref) => const NoopPushService(),
);

/// يسجل رمز جهاز صاحب الجلسة في الخادم ويلغيه عند الخروج (AD-FR-027).
/// رفض الإذن أو غياب الدفع لا يعطل شيئًا آخر: تُتجاهل الأخطاء ويستمر المركز.
class PushRegistrar {
  PushRegistrar(this._push, this._rpc);

  final PushService _push;
  final RpcCaller _rpc;

  String? _registered;

  /// يسجل الرمز إن كان الإذن ممنوحًا. يعيد `true` عند التسجيل.
  Future<bool> register() async {
    if (!_push.available) return false;
    try {
      if (await _push.permission() != PushPermission.granted) return false;
      final token = await _push.token();
      if (token == null) return false;
      await guardRpc(
        () => _rpc(
          'register_device_token',
          params: {'p_token': token, 'p_platform': _push.platform},
        ),
      );
      _registered = token;
      return true;
    } on Object {
      return false;
    }
  }

  /// يطلب الإذن ثم يسجل الرمز.
  Future<PushPermission> enable() async {
    if (!_push.available) return PushPermission.denied;
    final p = await _push.requestPermission();
    if (p == PushPermission.granted) await register();
    return p;
  }

  /// يلغي تسجيل الجهاز قبل الخروج. الفشل لا يمنع الخروج.
  Future<void> unregister() async {
    final token = _registered ?? await _safeToken();
    if (token == null) return;
    try {
      await guardRpc(
        () => _rpc('unregister_device_token', params: {'p_token': token}),
      );
      _registered = null;
    } on Object {
      // الرمز ينتقل لمن يدخل بعده على الجهاز، ويعطله المزود إن صار غير صالح.
    }
  }

  Future<String?> _safeToken() async {
    try {
      return _push.available ? await _push.token() : null;
    } on Object {
      return null;
    }
  }
}

final pushRegistrarProvider = Provider<PushRegistrar>(
  (ref) =>
      PushRegistrar(ref.watch(pushServiceProvider), ref.watch(rpcProvider)),
);
