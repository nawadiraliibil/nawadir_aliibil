import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_service.dart';

/// تنفيذ [PushService] الحقيقي فوق Firebase Cloud Messaging (INT-006).
///
/// لا يُنشأ إلا بعد نجاح [FirebasePushService.tryCreate]؛ دون ملف الإعداد
/// (`google-services.json` في Android) يعاد `null` فيبقى [NoopPushService].
class FirebasePushService implements PushService {
  FirebasePushService._(this._messaging);

  final FirebaseMessaging _messaging;

  /// يهيئ Firebase من ملف الإعداد الأصلي للمنصة. أي فشل (ملف غائب، خدمات Google
  /// غير متاحة) يعيد `null` ولا يعطل تشغيل التطبيق.
  static Future<FirebasePushService?> tryCreate() async {
    try {
      await Firebase.initializeApp();
      return FirebasePushService._(FirebaseMessaging.instance);
    } on Object catch (e) {
      debugPrint('Firebase غير مهيأ؛ الدفع معطل: $e');
      return null;
    }
  }

  @override
  bool get available => true;

  @override
  String get platform => Platform.isIOS ? 'IOS' : 'ANDROID';

  static PushPermission _map(AuthorizationStatus s) => switch (s) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PushPermission.granted,
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notDetermined,
  };

  @override
  Future<PushPermission> permission() async =>
      _map((await _messaging.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermission> requestPermission() async =>
      _map((await _messaging.requestPermission()).authorizationStatus);

  // الدالتان متروكتان في الإصدار 17 لصالح register/onRegistered (معرّف تثبيت
  // FID لنموذج إرسال مباشر). `push-dispatch` ترسل عبر FCM HTTP v1 برمز تسجيل،
  // وهذا ما تعيده الدالتان، فنبقيهما عمدًا.
  @override
  // ignore: deprecated_member_use
  Future<String?> token() => _messaging.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}
