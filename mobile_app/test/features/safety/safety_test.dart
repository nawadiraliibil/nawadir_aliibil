import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/features/safety/data/safety_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/fake_tables.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _detail() {
  final d = Map<String, dynamic>.from(fixture('listing-detail') as Map);
  final l = Map<String, dynamic>.from(d['listing'] as Map)
    ..['listing_id'] = 'l1'
    ..['owner_id'] = 'owner-1'
    ..['owner_display_name'] = 'صاحب الإعلان';
  return d..['listing'] = l;
}

Future<void> _openDetail(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpAndSettle();
  await tester.tap(find.text('إعلان رقم 0 للإبل'));
  await tester.pumpAndSettle();
}

Map<String, dynamic> _card() {
  final b = Map<String, dynamic>.from(
    (fixture('search-result') as Map)['items'][0] as Map,
  );
  return b
    ..['listing_id'] = 'l1'
    ..['title'] = 'إعلان رقم 0 للإبل';
}

FakeRpc _rpc([Map<String, RpcHandler>? extra]) => FakeRpc({
  'search_listings': (_) => {
    'items': [_card()],
    'next_cursor': null,
  },
  'get_listing': (_) => _detail(),
  'submit_report': (p) => fixture('report-submitted'),
  ...?extra,
});

Future<void> _chooseMenu(WidgetTester tester, String key, String item) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

void main() {
  group('الإبلاغ', () {
    testWidgets('السبب إلزامي، و«أخرى» تشترط وصفًا، والإرسال بمعرف طلب', (
      tester,
    ) async {
      final rpc = _rpc();
      await pumpApp(tester, rpc: rpc);
      await _openDetail(tester);
      await _chooseMenu(tester, 'detail-menu', 'الإبلاغ عن الإعلان');

      FilledButton submit() => tester.widget<FilledButton>(
        find.byKey(const ValueKey('report-submit')),
      );
      expect(submit().onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('report-reason-OTHER')));
      await tester.pump();
      expect(submit().onPressed, isNull);
      expect(find.text('اكتب التفاصيل (إلزامي)'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('report-description')),
        '  تفاصيل  ',
      );
      await tester.pump();
      expect(submit().onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('report-reason-FRAUD')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('report-submit')));
      await tester.pumpAndSettle();

      final p = rpc.paramsOf('submit_report').single!;
      expect(p['p_target_type'], 'LISTING');
      expect(p['p_target_id'], 'l1');
      expect(p['p_reason'], 'FRAUD');
      expect(p['p_description'], 'تفاصيل');
      expect(p['p_request_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      final ref = (fixture('report-submitted') as Map)['ref'];
      expect(find.text('تم استلام بلاغك. رقمه $ref.'), findsOneWidget);
    });

    testWidgets('بلاغ مفتوح سابق: رسالة مختلفة دون بلاغ جديد', (tester) async {
      final rpc = _rpc({
        'submit_report': (p) => {
          'report_id': 'r',
          'ref': 'R-1001',
          'status': 'OPEN',
          'created': false,
          'duplicate': true,
        },
      });
      await pumpApp(tester, rpc: rpc);
      await _openDetail(tester);
      await _chooseMenu(tester, 'detail-menu', 'الإبلاغ عن المعلن');
      await tester.tap(find.byKey(const ValueKey('report-reason-SPAM')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('report-submit')));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('submit_report').single!['p_target_type'], 'ACCOUNT');
      expect(rpc.paramsOf('submit_report').single!['p_target_id'], 'owner-1');
      expect(
        find.textContaining('لديك بلاغ مفتوح عن هذا الأمر (R-1001)'),
        findsOneWidget,
      );
    });

    testWidgets('الفشل يبقي الورقة، وإعادة الإرسال بمعرف الطلب نفسه', (
      tester,
    ) async {
      var fail = true;
      final rpc = _rpc({
        'submit_report': (p) {
          if (fail) throw const PostgrestException(message: 'RATE_LIMITED');
          return fixture('report-submitted');
        },
      });
      await pumpApp(tester, rpc: rpc);
      await _openDetail(tester);
      await _chooseMenu(tester, 'detail-menu', 'الإبلاغ عن الإعلان');
      await tester.tap(find.byKey(const ValueKey('report-reason-ABUSE')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('report-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('تجاوزت الحد المسموح'), findsOneWidget);
      expect(find.byKey(const ValueKey('report-submit')), findsOneWidget);

      fail = false;
      await tester.tap(find.byKey(const ValueKey('report-submit')));
      await tester.pumpAndSettle();
      final ids = [
        for (final p in rpc.paramsOf('submit_report')) p!['p_request_id'],
      ];
      expect(ids, hasLength(2));
      expect(ids[0], ids[1]);
    });

    testWidgets('الزائر يُوجَّه إلى الدخول', (tester) async {
      final rpc = _rpc();
      await pumpApp(tester, auth: FakeAuthBackend(signedIn: false), rpc: rpc);
      await _openDetail(tester);
      await _chooseMenu(tester, 'detail-menu', 'الإبلاغ عن الإعلان');
      expect(find.text('رقم الجوال'), findsWidgets);
      expect(rpc.paramsOf('submit_report'), isEmpty);
    });

    testWidgets('إعلاني: لا قائمة إبلاغ أو حظر', (tester) async {
      final rpc = _rpc({
        'get_listing': (_) {
          final d = _detail();
          (d['listing'] as Map<String, dynamic>)['owner_id'] = 'user-me';
          return d;
        },
      });
      await pumpApp(tester, rpc: rpc);
      await _openDetail(tester);
      expect(find.byKey(const ValueKey('detail-menu')), findsNothing);
    });
  });

  group('الحظر', () {
    testWidgets('من قائمة الإعلان: تأكيد ثم block_user', (tester) async {
      final rpc = _rpc({
        'block_user': (p) => {'user_id': 'owner-1', 'blocked': true},
      });
      await pumpApp(tester, rpc: rpc);
      await _openDetail(tester);
      await _chooseMenu(tester, 'detail-menu', 'حظر المعلن');
      expect(find.text('حظر صاحب الإعلان؟'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('block_user'), isEmpty);

      await _chooseMenu(tester, 'detail-menu', 'حظر المعلن');
      await tester.tap(find.widgetWithText(FilledButton, 'حظر'));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('block_user').single, {'p_user_id': 'owner-1'});
      expect(find.text('تم حظر صاحب الإعلان.'), findsOneWidget);
    });

    testWidgets('خطأ الخادم برسالة ولا ادعاء نجاح', (tester) async {
      final rpc = _rpc({
        'block_user': (p) =>
            throw const PostgrestException(message: 'INTERNAL_ERROR'),
      });
      await pumpApp(tester, rpc: rpc);
      await _openDetail(tester);
      await _chooseMenu(tester, 'detail-menu', 'حظر المعلن');
      await tester.tap(find.widgetWithText(FilledButton, 'حظر'));
      await tester.pumpAndSettle();
      expect(find.text('تم حظر صاحب الإعلان.'), findsNothing);
      expect(find.textContaining('حدث خطأ'), findsOneWidget);
    });

    testWidgets('شاشة المحظورين: قائمة وإلغاء الحظر وحالة الفراغ', (
      tester,
    ) async {
      final tables = FakeTables({
        'my_blocks': [
          {
            'user_id': 'u1',
            'display_name': 'محظور أول',
            'blocked_at': '2026-11-23T09:00:00+00:00',
          },
        ],
      });
      final rpc = FakeRpc({
        'get_my_account': (_) => fixture('account-ready'),
        'unblock_user': (p) {
          tables.rows['my_blocks'] = [];
          return {'user_id': 'u1', 'blocked': false};
        },
      });
      await pumpApp(tester, rpc: rpc, tables: tables);
      await tester.tap(find.text('حسابي').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('المحظورون'));
      await tester.pumpAndSettle();
      expect(find.text('محظور أول'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('unblock-u1')));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('unblock_user').single, {'p_user_id': 'u1'});
      expect(find.text('لا محظورون'), findsOneWidget);
    });
  });

  group('من المحادثة والردود', () {
    testWidgets('الضغط المطول على رسالة الطرف الآخر يبلّغ عنها', (
      tester,
    ) async {
      final conv = Map<String, dynamic>.from(fixture('my-conversation') as Map)
        ..['conversation_id'] = 'c1'
        ..['other_user_id'] = 'other-user'
        ..['unread_count'] = 0;
      final tables = FakeTables({
        'my_conversations': [conv],
        'messages': [
          {
            'id': 'm1',
            'conversation_id': 'c1',
            'sender_id': 'other-user',
            'body': 'رسالة مسيئة',
            'request_id': 'r1',
            'created_at': '2026-11-23T09:00:00+00:00',
          },
          {
            'id': 'm2',
            'conversation_id': 'c1',
            'sender_id': 'user-me',
            'body': 'رسالتي',
            'request_id': 'r2',
            'created_at': '2026-11-23T09:01:00+00:00',
          },
        ],
      });
      final rpc = _rpc({'mark_conversation_read': (_) => {}});
      await pumpApp(tester, rpc: rpc, tables: tables);
      await tester.tap(find.text('الرسائل').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('مشتري تجريبي'));
      await tester.pumpAndSettle();

      // رسالتي لا تُبلَّغ.
      await tester.longPress(find.text('رسالتي'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('report-submit')), findsNothing);

      await tester.longPress(find.text('رسالة مسيئة'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-reason-ABUSE')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('report-submit')));
      await tester.pumpAndSettle();
      final p = rpc.paramsOf('submit_report').single!;
      expect(p['p_target_type'], 'MESSAGE');
      expect(p['p_target_id'], 'm1');
    });

    testWidgets('حظر من قائمة المحادثة', (tester) async {
      final conv = Map<String, dynamic>.from(fixture('my-conversation') as Map)
        ..['conversation_id'] = 'c1'
        ..['other_user_id'] = 'other-user'
        ..['unread_count'] = 0;
      final tables = FakeTables({
        'my_conversations': [conv],
        'messages': <Map<String, dynamic>>[],
      });
      final rpc = _rpc({
        'mark_conversation_read': (_) => {},
        'block_user': (p) => {'blocked': true},
      });
      await pumpApp(tester, rpc: rpc, tables: tables);
      await tester.tap(find.text('الرسائل').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('مشتري تجريبي'));
      await tester.pumpAndSettle();
      await _chooseMenu(tester, 'chat-menu', 'حظر المستخدم');
      await tester.tap(find.widgetWithText(FilledButton, 'حظر'));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('block_user').single, {'p_user_id': 'other-user'});
    });

    testWidgets('ردّ غيري: «إبلاغ» من قائمته', (tester) async {
      final tables = FakeTables({
        'public_comments': [
          {
            'comment_id': 'k1',
            'listing_id': 'l1',
            'parent_id': null,
            'author_id': 'someone',
            'author_display_name': 'سائل',
            'is_owner': false,
            'state': 'VISIBLE',
            'body': 'رد مزعج',
            'edited_at': null,
            'created_at': '2026-11-23T09:00:00+00:00',
          },
        ],
      });
      final rpc = _rpc();
      await pumpApp(tester, rpc: rpc, tables: tables);
      await _openDetail(tester);
      await tester.tap(find.byKey(const ValueKey('comment-report-menu-k1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إبلاغ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-reason-SPAM')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('report-submit')));
      await tester.pumpAndSettle();
      final p = rpc.paramsOf('submit_report').single!;
      expect(p['p_target_type'], 'COMMENT');
      expect(p['p_target_id'], 'k1');
    });
  });

  test('نتيجة البلاغ تُحلَّل من مثال العقد', () {
    final r = ReceiptParser.parse(
      Map<String, dynamic>.from(fixture('report-submitted') as Map),
    );
    expect(r.ref, startsWith('R-'));
    expect(r.duplicate, isFalse);
  });
}
