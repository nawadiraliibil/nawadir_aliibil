import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/core/push/push_service.dart';
import 'package:nawadir_aliibil/features/notifications/data/app_notification.dart';
import 'package:nawadir_aliibil/features/notifications/presentation/notifications_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/fake_tables.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _n(
  String id,
  String event, {
  String category = 'LISTING_STATUS',
  String resourceType = 'listing',
  String resourceId = 'l1',
  Map<String, dynamic> payload = const {},
  String? readAt,
  String at = '2026-11-23T09:00:00+00:00',
}) => {
  'id': id,
  'recipient_id': 'user-me',
  'category': category,
  'event': event,
  'resource_type': resourceType,
  'resource_id': resourceId,
  'payload': payload,
  'dedupe_key': id,
  'read_at': readAt,
  'created_at': at,
};

class _FakePush implements PushService {
  _FakePush({this.state = PushPermission.granted});

  @override
  bool get available => true;
  PushPermission state;
  var requests = 0;

  @override
  Future<PushPermission> permission() async => state;

  @override
  Future<PushPermission> requestPermission() async {
    requests++;
    state = PushPermission.granted;
    return state;
  }

  @override
  Future<String?> token() async => 'tok-0123456789abcdefghij';

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  String get platform => 'ANDROID';
}

void main() {
  group('نص الإشعار', () {
    test('إشعار من مثال العقد', () {
      final n = AppNotification.fromJson(
        Map<String, dynamic>.from(
          (fixture('notifications') as List).first as Map,
        ),
      );
      expect(n.title, 'تم نشر إعلانك «ناقة مجاهيم للبيع»');
      expect(n.isUnread, isTrue);
      expect(n.detail, isNull);
    });

    test('الرفض يحمل سببه، والبلاغ المغلق يحمل رد الإدارة', () {
      final rejected = AppNotification.fromJson(
        _n(
          '1',
          'listing.rejected',
          payload: {
            'title': 'ناقة',
            'reason_label_ar': 'بيانات ناقصة',
            'reason_text': 'أضف صورًا أوضح',
          },
        ),
      );
      expect(rejected.title, 'رُفض إعلانك «ناقة»');
      expect(rejected.detail, 'بيانات ناقصة — أضف صورًا أوضح');
      final report = AppNotification.fromJson(
        _n(
          '2',
          'report.closed',
          category: 'REPORTS',
          payload: {'ref': 'R-1001', 'response_text': 'شكرًا'},
        ),
      );
      expect(report.title, 'تم إغلاق بلاغك R-1001');
      expect(report.detail, 'شكرًا');
    });

    test('إشعار الرسالة بلا أي نص خاص، وحدث غير معروف عام', () {
      final m = AppNotification.fromJson(
        _n(
          '3',
          'message.received',
          category: 'MESSAGES',
          payload: {'conversation_id': 'c1'},
        ),
      );
      expect(m.title, 'رسالة جديدة');
      expect(m.detail, isNull);
      expect(AppNotification.fromJson(_n('4', 'x.y')).title, 'إشعار جديد');
    });

    test('وجهة كل إشعار', () {
      String? route(String event, {String id = 'x'}) => notificationRoute(
        AppNotification.fromJson(_n('1', event, resourceId: id)),
      );
      expect(route('message.received', id: 'c9'), '/chat/c9');
      expect(route('follow.new_listing', id: 'l9'), '/listing/l9');
      expect(route('comment.created', id: 'l9'), '/listing/l9');
      expect(route('listing.approved'), '/account/listings');
      expect(route('account.suspended'), isNull);
      expect(route('report.closed'), isNull);
    });
  });

  group('مركز الإشعارات', () {
    late FakeTables tables;

    setUp(() {
      tables = FakeTables({
        'notifications': [
          _n('n1', 'listing.approved', payload: {'title': 'ناقة'}),
          _n(
            'n2',
            'message.received',
            category: 'MESSAGES',
            resourceType: 'conversation',
            resourceId: 'c1',
            at: '2026-11-23T10:00:00+00:00',
          ),
          _n(
            'n3',
            'follow.new_listing',
            category: 'FOLLOWS',
            readAt: '2026-11-23T10:30:00+00:00',
            at: '2026-11-23T08:00:00+00:00',
          ),
        ],
      });
    });

    Future<FakeRpc> openCenter(
      WidgetTester tester, {
      Map<String, RpcHandler>? handlers,
    }) async {
      final rpc = FakeRpc({
        'mark_notifications_read': (p) => 2,
        'get_my_account': (_) => fixture('account-ready'),
        ...?handlers,
      });
      await pumpApp(tester, rpc: rpc, tables: tables);
      await tester.tap(find.byKey(const ValueKey('notification-bell')));
      await tester.pumpAndSettle();
      return rpc;
    }

    testWidgets('الجرس يعرض غير المقروء، والقائمة الأحدث أولًا', (
      tester,
    ) async {
      await pumpApp(tester, tables: tables);
      expect(find.text('2'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('notification-bell')));
      await tester.pumpAndSettle();
      final ys = [
        tester.getTopLeft(find.text('رسالة جديدة')).dy,
        tester.getTopLeft(find.text('تم نشر إعلانك «ناقة»')).dy,
      ];
      expect(ys[0], lessThan(ys[1]));
      expect(find.text('إعلان جديد يطابق متابعتك'), findsOneWidget);
    });

    testWidgets('فتح إشعار: يعلّمه مقروءًا وينقل إلى مورده', (tester) async {
      final rpc = await openCenter(
        tester,
        handlers: {'get_conversation_placeholder': (_) => null},
      );
      await tester.tap(find.byKey(const ValueKey('notification-n1')));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('mark_notifications_read').single, {
        'p_ids': ['n1'],
      });
      // إعلاناتي.
      expect(find.text('إعلاناتي'), findsWidgets);
    });

    testWidgets('تعليم الكل مقروءًا يرسل غير المقروء فقط', (tester) async {
      final rpc = await openCenter(tester);
      await tester.tap(find.byKey(const ValueKey('mark-all-read')));
      await tester.pumpAndSettle();
      final ids =
          (rpc.paramsOf('mark_notifications_read').single!['p_ids'] as List)
              .toSet();
      expect(ids, {'n1', 'n2'});
      expect(find.byKey(const ValueKey('mark-all-read')), findsNothing);
    });

    testWidgets('فشل التعليم يرتد ويظهر خطأ', (tester) async {
      await openCenter(
        tester,
        handlers: {
          'mark_notifications_read': (_) =>
              throw const PostgrestException(message: 'INTERNAL_ERROR'),
        },
      );
      await tester.tap(find.byKey(const ValueKey('mark-all-read')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mark-all-read')), findsOneWidget);
      expect(find.textContaining('حدث خطأ'), findsOneWidget);
    });

    testWidgets('فارغ: حالة فراغ', (tester) async {
      tables.rows['notifications'] = [];
      await openCenter(tester);
      expect(find.text('لا إشعارات'), findsOneWidget);
    });

    testWidgets('الزائر: دعوة للدخول', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthBackend(signedIn: false),
        tables: tables,
      );
      await tester.tap(find.byKey(const ValueKey('notification-bell')));
      await tester.pumpAndSettle();
      expect(find.text('سجّل الدخول لمتابعة إشعاراتك'), findsOneWidget);
    });

    testWidgets('فشل التحميل: إعادة المحاولة', (tester) async {
      tables.failures['notifications'] = const PostgrestException(message: 'x');
      await pumpApp(tester, tables: tables);
      await tester.tap(find.byKey(const ValueKey('notification-bell')));
      await tester.pumpAndSettle();
      expect(find.text('تعذّر تحميل الإشعارات'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.text('رسالة جديدة'), findsOneWidget);
    });
  });

  group('إعدادات الإشعارات', () {
    late FakeTables tables;

    setUp(() {
      tables = FakeTables({
        'notifications': <Map<String, dynamic>>[],
        'my_notification_preferences': [
          for (final c in [
            'LISTING_STATUS',
            'MESSAGES',
            'COMMENTS',
            'FOLLOWS',
            'REPORTS',
            'ACCOUNT',
            'RATINGS',
          ])
            {'category': c, 'push_enabled': c != 'MESSAGES'},
        ],
      });
    });

    Future<FakeRpc> openSettings(
      WidgetTester tester, {
      PushService? push,
      Map<String, RpcHandler>? handlers,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rpc = FakeRpc({
        'get_my_account': (_) => fixture('account-ready'),
        ...?handlers,
      });
      await pumpApp(
        tester,
        rpc: rpc,
        tables: tables,
        extraOverrides: [
          if (push != null) pushServiceProvider.overrideWithValue(push),
        ],
      );
      await tester.tap(find.text('حسابي').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('الإشعارات'));
      await tester.pumpAndSettle();
      return rpc;
    }

    testWidgets('كل الفئات بقيمها، والدفع غير مهيأ يُشرح دون تعطيل المركز', (
      tester,
    ) async {
      await openSettings(tester);
      expect(find.byKey(const ValueKey('pref-MESSAGES')), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const ValueKey('pref-MESSAGES')))
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const ValueKey('pref-FOLLOWS')))
            .value,
        isTrue,
      );
      expect(
        find.textContaining('الإشعارات الفورية غير مفعلة على هذا الجهاز'),
        findsOneWidget,
      );
    });

    testWidgets('التبديل يستدعي الدالة', (tester) async {
      final rpc = await openSettings(
        tester,
        handlers: {
          'set_notification_preference': (p) => {
            'category': p!['p_category'],
            'push_enabled': p['p_push_enabled'],
          },
        },
      );
      await tester.tap(find.byKey(const ValueKey('pref-FOLLOWS')));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('set_notification_preference').single, {
        'p_category': 'FOLLOWS',
        'p_push_enabled': false,
      });
    });

    testWidgets('فشل الحفظ برسالة', (tester) async {
      await openSettings(
        tester,
        handlers: {
          'set_notification_preference': (p) =>
              throw const PostgrestException(message: 'INTERNAL_ERROR'),
        },
      );
      await tester.tap(find.byKey(const ValueKey('pref-FOLLOWS')));
      await tester.pumpAndSettle();
      expect(find.textContaining('حدث خطأ'), findsOneWidget);
    });

    testWidgets('إذن مرفوض: ملاحظة، والمركز يعمل', (tester) async {
      await openSettings(tester, push: _FakePush(state: PushPermission.denied));
      expect(find.textContaining('إذن الإشعارات مرفوض'), findsOneWidget);
      expect(find.byKey(const ValueKey('enable-push')), findsNothing);
    });

    testWidgets('إذن غير محسوم: زر السماح يطلب الإذن ويسجل الرمز', (
      tester,
    ) async {
      final push = _FakePush(state: PushPermission.notDetermined);
      final rpc = await openSettings(
        tester,
        push: push,
        handlers: {
          'register_device_token': (p) => {'registered': true},
        },
      );
      await tester.tap(find.byKey(const ValueKey('enable-push')));
      await tester.pumpAndSettle();
      expect(push.requests, 1);
      expect(rpc.paramsOf('register_device_token').single, {
        'p_token': 'tok-0123456789abcdefghij',
        'p_platform': 'ANDROID',
      });
    });
  });

  group('تسجيل الجهاز', () {
    PushRegistrar registrar(PushService push, FakeRpc rpc) =>
        PushRegistrar(push, rpc.caller);

    test('مع الإذن يسجل الرمز، وبدونه لا', () async {
      final rpc = FakeRpc({
        'register_device_token': (p) => {'registered': true},
      });
      expect(await registrar(_FakePush(), rpc).register(), isTrue);
      expect(
        rpc.paramsOf('register_device_token').single!['p_token'],
        'tok-0123456789abcdefghij',
      );
      final rpc2 = FakeRpc();
      expect(
        await registrar(
          _FakePush(state: PushPermission.denied),
          rpc2,
        ).register(),
        isFalse,
      );
      expect(
        await registrar(const NoopPushService(), rpc2).register(),
        isFalse,
      );
      expect(rpc2.calls.where((c) => c.$1 == 'register_device_token'), isEmpty);
    });

    test('فشل الخادم لا يرمي', () async {
      final rpc = FakeRpc({
        'register_device_token': (p) =>
            throw const PostgrestException(message: 'INTERNAL_ERROR'),
      });
      expect(await registrar(_FakePush(), rpc).register(), isFalse);
    });

    test('إلغاء التسجيل بالرمز المسجل، ودون دفع لا شيء', () async {
      final rpc = FakeRpc({
        'register_device_token': (p) => {'registered': true},
        'unregister_device_token': (p) => {'unregistered': true},
      });
      final r = registrar(_FakePush(), rpc);
      await r.register();
      await r.unregister();
      expect(rpc.paramsOf('unregister_device_token').single, {
        'p_token': 'tok-0123456789abcdefghij',
      });
      final rpc2 = FakeRpc();
      await registrar(const NoopPushService(), rpc2).unregister();
      expect(
        rpc2.calls.where((c) => c.$1 == 'unregister_device_token'),
        isEmpty,
      );
    });

    testWidgets('الخروج يلغي تسجيل الجهاز قبل إبطال الجلسة', (tester) async {
      final auth = FakeAuthBackend(signedIn: true);
      final rpc = FakeRpc({
        'get_my_account': (_) => fixture('account-ready'),
        'unregister_device_token': (p) => {'unregistered': true},
      });
      await pumpApp(
        tester,
        auth: auth,
        rpc: rpc,
        extraOverrides: [pushServiceProvider.overrideWithValue(_FakePush())],
      );
      await tester.tap(find.text('حسابي').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسجيل الخروج'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الخروج'));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('unregister_device_token'), hasLength(1));
      expect(auth.signOutCalls, 1);
    });
  });
}
