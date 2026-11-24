import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/core/format/money.dart';
import 'package:nawadir_aliibil/features/chat/application/chat_providers.dart';
import 'package:nawadir_aliibil/features/chat/data/chat_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/fake_tables.dart';
import '../../helpers/pump_app.dart';

const _otherId = 'other-user';

Map<String, dynamic> _conv(
  String id, {
  String name = 'مشتري تجريبي',
  String? title = 'ناقة مجاهيم للبيع',
  bool available = true,
  bool writable = true,
  bool muted = false,
  int unread = 0,
  String? last = 'السلام عليكم',
  String? lastSender = _otherId,
  String? lastAt = '2026-11-23T10:00:00+00:00',
}) {
  final b = Map<String, dynamic>.from(fixture('my-conversation') as Map);
  return b
    ..['conversation_id'] = id
    ..['other_user_id'] = _otherId
    ..['other_display_name'] = name
    ..['listing_available'] = available
    ..['listing_title'] = available ? title : null
    ..['cover_bucket'] = available ? b['cover_bucket'] : null
    ..['cover_path'] = available ? b['cover_path'] : null
    ..['writable'] = writable
    ..['muted'] = muted
    ..['unread_count'] = unread
    ..['last_message_body'] = last
    ..['last_message_sender_id'] = lastSender
    ..['last_message_at'] = lastAt;
}

Map<String, dynamic> _msg(
  String id,
  String body, {
  String sender = _otherId,
  String at = '2026-11-23T10:00:00+00:00',
  String conversation = 'c1',
  String? requestId,
}) => {
  'id': id,
  'conversation_id': conversation,
  'sender_id': sender,
  'body': body,
  'request_id': requestId ?? 'req-$id',
  'created_at': at,
};

Future<void> _openMessagesTab(WidgetTester tester) async {
  await tester.tap(find.text('الرسائل').last);
  await tester.pumpAndSettle();
}

void main() {
  group('نماذج', () {
    test('محادثة من مثال العقد', () {
      final c = Conversation.fromJson(
        Map<String, dynamic>.from(fixture('my-conversation') as Map),
      );
      expect(c.isBuyer, isFalse);
      expect(c.writable, isTrue);
      expect(c.displayName, 'مشتري تجريبي');
    });

    test('دمج الرسائل: لا تكرار، والمحلية تُستبدل بمعرف الطلب', () {
      final local = ChatMessage(
        id: 'local-r1',
        senderId: 'me',
        body: 'مرحبا',
        createdAt: DateTime.utc(2026),
        requestId: 'r1',
        state: SendState.sending,
      );
      final server = ChatMessage(
        id: 'srv-1',
        senderId: 'me2',
        body: 'مرحبا',
        createdAt: DateTime.utc(2026),
        requestId: 'r1',
      );
      final merged = mergeMessage([local], server);
      expect(merged.single.id, 'srv-1');
      expect(mergeMessage(merged, server), merged);
      expect(
        mergeMessage(
          merged,
          ChatMessage(
            id: 'srv-2',
            senderId: 'x',
            body: 'ب',
            createdAt: DateTime.utc(2026),
            requestId: 'r2',
          ),
        ),
        hasLength(2),
      );
    });

    test('وقت قصير بتوقيت السعودية', () {
      final now = DateTime.utc(2026, 11, 23, 12);
      expect(
        formatShortTime(DateTime.utc(2026, 11, 23, 15, 30), now: now),
        '6:30 م',
      );
      expect(formatShortTime(DateTime.utc(2026, 11, 20, 9), now: now), '20/11');
    });
  });

  group('قائمة المحادثات', () {
    testWidgets('الزائر يُدعى للدخول', (tester) async {
      await pumpApp(tester, auth: FakeAuthBackend(signedIn: false));
      await _openMessagesTab(tester);
      expect(find.text('سجّل الدخول لمراسلة المعلنين'), findsOneWidget);
    });

    testWidgets('الأحدث نشاطًا أولًا مع غير المقروء وآخر رسالة', (
      tester,
    ) async {
      final tables = FakeTables({
        'my_conversations': [
          _conv('c-old', name: 'قديم', lastAt: '2026-11-20T10:00:00+00:00'),
          _conv('c-new', name: 'جديد', unread: 3, last: 'هل ما زالت متاحة؟'),
          _conv(
            'c-mine',
            name: 'ثالث',
            lastSender: 'user-me',
            last: 'تفضل',
            lastAt: '2026-11-22T10:00:00+00:00',
          ),
        ],
      });
      await pumpApp(tester, tables: tables);
      await _openMessagesTab(tester);

      final names = [
        for (final n in ['جديد', 'ثالث', 'قديم'])
          tester.getTopLeft(find.text(n)).dy,
      ];
      expect(names, orderedEquals([...names]..sort()));
      expect(find.text('هل ما زالت متاحة؟'), findsOneWidget);
      expect(find.text('أنت: تفضل'), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-badge')), findsOneWidget);
      // شارة الشريط السفلي بمجموع غير المقروء.
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('إعلان لم يعد متاحًا: لا عنوان ولا غلاف', (tester) async {
      final tables = FakeTables({
        'my_conversations': [_conv('c1', available: false)],
      });
      await pumpApp(tester, tables: tables);
      await _openMessagesTab(tester);
      expect(find.text('الإعلان غير متاح'), findsOneWidget);
      expect(find.text('ناقة مجاهيم للبيع'), findsNothing);
    });

    testWidgets('البحث المحلي بالاسم أو العنوان، بلا استدعاء خادم', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final tables = FakeTables({
        'my_conversations': [
          _conv('c1', name: 'سالم', title: 'ناقة مجاهيم'),
          _conv('c2', name: 'ماجد', title: 'حاشي أصيل'),
        ],
      });
      await pumpApp(tester, tables: tables);
      await _openMessagesTab(tester);
      final reads = tables.requests.length;
      final search = find.byKey(const ValueKey('conversations-search'));

      await tester.enterText(search, 'سالم');
      await tester.pump();
      expect(find.text('سالم'), findsWidgets);
      expect(find.text('ماجد'), findsNothing);

      await tester.enterText(search, 'حاشي');
      await tester.pump();
      expect(find.text('ماجد'), findsOneWidget);
      expect(find.text('سالم'), findsNothing);

      await tester.enterText(search, 'لا يوجد');
      await tester.pump();
      expect(find.text('لا نتائج مطابقة'), findsOneWidget);
      expect(tables.requests.length, reads);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('مسح البحث'));
      await tester.pump();
      expect(find.text('سالم'), findsOneWidget);
      expect(find.text('ماجد'), findsOneWidget);
    });

    testWidgets('فارغة: حالة فراغ بإجراء', (tester) async {
      await pumpApp(tester);
      await _openMessagesTab(tester);
      expect(find.text('لا توجد محادثات بعد'), findsOneWidget);
    });
  });

  group('المحادثة', () {
    late FakeTables tables;
    late StreamController<Map<String, dynamic>> realtime;

    setUp(() {
      realtime = StreamController<Map<String, dynamic>>.broadcast();
      tables = FakeTables({
        'my_conversations': [_conv('c1', unread: 2)],
        'messages': [
          _msg('m1', 'السلام عليكم', at: '2026-11-23T09:00:00+00:00'),
          _msg('m2', 'هل ما زالت متاحة؟', at: '2026-11-23T09:01:00+00:00'),
        ],
      });
    });

    tearDown(() => realtime.close());

    Future<FakeRpc> open(
      WidgetTester tester, {
      Map<String, RpcHandler>? handlers,
    }) async {
      final rpc = FakeRpc({
        'mark_conversation_read': (p) => {
          'conversation_id': 'c1',
          'read_at': 'x',
        },
        'send_message': (p) => {
          'id': 'srv-${DateTime.now().microsecondsSinceEpoch}',
          'conversation_id': 'c1',
          'sender_id': 'user-me',
          'body': p!['p_body'],
          'created_at': '2026-11-23T10:05:00+00:00',
        },
        ...?handlers,
      });
      await pumpApp(
        tester,
        rpc: rpc,
        tables: tables,
        messageInserts: realtime.stream,
      );
      await _openMessagesTab(tester);
      await tester.tap(find.text('مشتري تجريبي'));
      await tester.pumpAndSettle();
      return rpc;
    }

    testWidgets('تعرض الرسائل وتعلّم المحادثة مقروءة', (tester) async {
      final rpc = await open(tester);
      expect(find.text('السلام عليكم'), findsWidgets);
      expect(find.text('هل ما زالت متاحة؟'), findsWidgets);
      expect(rpc.paramsOf('mark_conversation_read').single, {
        'p_conversation_id': 'c1',
      });
    });

    testWidgets('الإرسال: نص مقصوص بمعرف طلب، ثم يظهر مرسلًا ويفرغ الحقل', (
      tester,
    ) async {
      final rpc = await open(tester);
      await tester.enterText(
        find.byKey(const ValueKey('chat-input')),
        '  سأعاينها غدًا  ',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-send')));
      await tester.pumpAndSettle();

      final p = rpc.paramsOf('send_message').single!;
      expect(p['p_conversation_id'], 'c1');
      expect(p['p_body'], 'سأعاينها غدًا');
      expect(p['p_request_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(find.text('سأعاينها غدًا'), findsOneWidget);
      expect(find.text('جارٍ الإرسال…'), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('chat-input')))
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets('الفشل ثم إعادة المحاولة بمعرف الطلب نفسه، دون رسالة مكررة', (
      tester,
    ) async {
      var fail = true;
      final rpc = await open(
        tester,
        handlers: {
          'send_message': (p) {
            if (fail) throw const PostgrestException(message: 'INTERNAL_ERROR');
            return {
              'id': 'srv-1',
              'conversation_id': 'c1',
              'sender_id': 'user-me',
              'body': p!['p_body'],
              'created_at': '2026-11-23T10:05:00+00:00',
            };
          },
        },
      );
      await tester.enterText(find.byKey(const ValueKey('chat-input')), 'تجربة');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-send')));
      await tester.pumpAndSettle();
      expect(find.text('تعذّر الإرسال'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();

      final ids = [
        for (final p in rpc.paramsOf('send_message')) p!['p_request_id'],
      ];
      expect(ids, hasLength(2));
      expect(ids[0], ids[1]);
      expect(find.text('تجربة'), findsOneWidget);
      expect(find.text('تعذّر الإرسال'), findsNothing);
    });

    testWidgets('حذف رسالة فاشلة يزيلها من العرض', (tester) async {
      await open(
        tester,
        handlers: {
          'send_message': (p) =>
              throw const PostgrestException(message: 'INTERNAL_ERROR'),
        },
      );
      await tester.enterText(find.byKey(const ValueKey('chat-input')), 'فاشلة');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-send')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      expect(find.text('فاشلة'), findsNothing);
    });

    testWidgets('رسالة واردة عبر Realtime تظهر، ولا تتكرر', (tester) async {
      await open(tester);
      final incoming = _msg('m3', 'وصلت للتو', at: '2026-11-23T10:10:00+00:00');
      realtime.add(incoming);
      await tester.pumpAndSettle();
      expect(find.text('وصلت للتو'), findsOneWidget);
      realtime.add(incoming);
      await tester.pumpAndSettle();
      expect(find.text('وصلت للتو'), findsOneWidget);
      // رسالة محادثة أخرى لا تظهر هنا.
      realtime.add(_msg('m9', 'محادثة أخرى', conversation: 'c-other'));
      await tester.pumpAndSettle();
      expect(find.text('محادثة أخرى'), findsNothing);
    });

    testWidgets('رسالتي الواصلة من Realtime تحل محل نسختها المحلية', (
      tester,
    ) async {
      final rpc = await open(
        tester,
        handlers: {
          'send_message': (p) => {
            'id': 'srv-x',
            'conversation_id': 'c1',
            'sender_id': 'user-me',
            'body': p!['p_body'],
            'created_at': '2026-11-23T10:05:00+00:00',
          },
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('chat-input')),
        'مرة واحدة',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chat-send')));
      await tester.pumpAndSettle();
      final requestId = rpc.paramsOf('send_message').single!['p_request_id'];
      realtime.add(
        _msg(
          'srv-x',
          'مرة واحدة',
          sender: 'user-me',
          requestId: requestId as String,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('مرة واحدة'), findsOneWidget);
    });

    testWidgets('طول الرسالة فوق الحد يعطل الإرسال', (tester) async {
      await open(tester);
      await tester.enterText(
        find.byKey(const ValueKey('chat-input')),
        'أ' * 2001,
      );
      await tester.pump();
      final send = tester.widget<IconButton>(
        find.byKey(const ValueKey('chat-send')),
      );
      expect(send.onPressed, isNull);
      expect(find.text('الحد 2000 حرفًا.'), findsOneWidget);
    });

    testWidgets('كتم التنبيهات يستدعي الدالة ويبدّل الزر', (tester) async {
      final rpc = await open(
        tester,
        handlers: {
          'set_conversation_muted': (p) => {
            'conversation_id': 'c1',
            'muted': p!['p_muted'],
          },
        },
      );
      await tester.tap(find.byKey(const ValueKey('chat-mute')));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('set_conversation_muted').single, {
        'p_conversation_id': 'c1',
        'p_muted': true,
      });
      expect(find.byTooltip('إلغاء كتم التنبيهات'), findsOneWidget);
    });

    testWidgets('للقراءة فقط: لا حقل كتابة ويظهر التنبيه', (tester) async {
      tables.rows['my_conversations'] = [_conv('c1', writable: false)];
      await open(tester);
      expect(find.byKey(const ValueKey('chat-input')), findsNothing);
      expect(
        find.text('هذه المحادثة للقراءة فقط ولا تقبل رسائل جديدة.'),
        findsOneWidget,
      );
      expect(find.text('السلام عليكم'), findsWidgets);
    });

    testWidgets('فشل تحميل الرسائل: إعادة المحاولة', (tester) async {
      tables.failures['messages'] = const PostgrestException(message: 'x');
      await open(tester);
      expect(find.text('تعذّر تحميل الرسائل'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.text('السلام عليكم'), findsWidgets);
    });
  });

  group('بدء المحادثة من الإعلان', () {
    Map<String, dynamic> detail({String? ownerId}) {
      final d = Map<String, dynamic>.from(fixture('listing-detail') as Map);
      final l = Map<String, dynamic>.from(d['listing'] as Map);
      if (ownerId != null) l['owner_id'] = ownerId;
      return d..['listing'] = l;
    }

    Future<void> openDetail(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ناقة مجاهيم للبيع').first);
      await tester.pumpAndSettle();
    }

    testWidgets('الزر يبدأ المحادثة ويفتحها', (tester) async {
      final rpc = FakeRpc({
        'search_listings': (_) => fixture('search-result'),
        'get_listing': (_) => detail(),
        'start_conversation': (p) => {'conversation_id': 'c1', 'created': true},
        'mark_conversation_read': (_) => {'conversation_id': 'c1'},
      });
      final tables = FakeTables({
        'my_conversations': [_conv('c1')],
        'messages': <Map<String, dynamic>>[],
      });
      await pumpApp(tester, rpc: rpc, tables: tables);
      await openDetail(tester);
      await tester.tap(find.byKey(const ValueKey('contact-message')));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('start_conversation').single, {
        'p_listing_id':
            (fixture('listing-detail') as Map)['listing']['listing_id'],
      });
      expect(find.text('ابدأ المحادثة بإرسال رسالة.'), findsOneWidget);
    });

    testWidgets('إعلاني: لا زر مراسلة', (tester) async {
      final rpc = FakeRpc({
        'search_listings': (_) => fixture('search-result'),
        'get_listing': (_) => detail(ownerId: 'user-me'),
      });
      await pumpApp(tester, rpc: rpc);
      await openDetail(tester);
      expect(find.byKey(const ValueKey('contact-message')), findsNothing);
    });

    testWidgets('الزائر: يوجَّه إلى الدخول', (tester) async {
      final rpc = FakeRpc({
        'search_listings': (_) => fixture('search-result'),
        'get_listing': (_) => detail(),
      });
      await pumpApp(tester, auth: FakeAuthBackend(signedIn: false), rpc: rpc);
      await openDetail(tester);
      await tester.tap(find.byKey(const ValueKey('contact-message')));
      await tester.pumpAndSettle();
      expect(find.text('رقم الجوال'), findsWidgets);
      expect(rpc.paramsOf('start_conversation'), isEmpty);
    });

    testWidgets('إعلان لم يعد متاحًا عند البدء: رسالة دون كشف السبب', (
      tester,
    ) async {
      final rpc = FakeRpc({
        'search_listings': (_) => fixture('search-result'),
        'get_listing': (_) => detail(),
        'start_conversation': (_) =>
            throw const PostgrestException(message: 'NOT_FOUND'),
      });
      await pumpApp(tester, rpc: rpc);
      await openDetail(tester);
      await tester.tap(find.byKey(const ValueKey('contact-message')));
      await tester.pumpAndSettle();
      expect(find.text('الإعلان لم يعد متاحًا.'), findsOneWidget);
    });
  });
}
