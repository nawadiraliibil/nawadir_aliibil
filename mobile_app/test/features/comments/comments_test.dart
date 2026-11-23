import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/features/comments/data/comment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/fake_tables.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _comment(
  String id, {
  String? parent,
  String author = 'someone',
  String name = 'سائل',
  bool owner = false,
  String state = 'VISIBLE',
  String? body = 'هل متاحة؟',
  String at = '2026-11-23T09:00:00+00:00',
  String? editedAt,
}) => {
  'comment_id': id,
  'listing_id': 'l1',
  'parent_id': parent,
  'author_id': author,
  'author_display_name': name,
  'is_owner': owner,
  'state': state,
  'body': state == 'VISIBLE' ? body : null,
  'edited_at': editedAt,
  'created_at': at,
};

Map<String, dynamic> _detail({String? ownerId, bool closed = false}) {
  final d = Map<String, dynamic>.from(fixture('listing-detail') as Map);
  final l = Map<String, dynamic>.from(d['listing'] as Map)
    ..['listing_id'] = 'l1'
    ..['comments_closed'] = closed;
  if (ownerId != null) l['owner_id'] = ownerId;
  return d..['listing'] = l;
}

void main() {
  test('الخيوط: الردود تحت رئيسها بالترتيب، واليتيم يُتجاهل', () {
    final all = [
      for (final j in [
        _comment('r2', at: '2026-11-23T10:00:00+00:00'),
        _comment(
          'a1',
          parent: 'r1',
          owner: true,
          at: '2026-11-23T09:30:00+00:00',
        ),
        _comment('r1'),
        _comment('orphan', parent: 'gone'),
      ])
        Comment.fromJson(j),
    ];
    final threads = buildThreads(all);
    expect(threads.map((t) => t.root.id), ['r1', 'r2']);
    expect(threads.first.replies.single.id, 'a1');
  });

  group('الواجهة', () {
    late FakeTables tables;

    setUp(() {
      tables = FakeTables({'public_comments': <Map<String, dynamic>>[]});
    });

    Future<FakeRpc> openDetail(
      WidgetTester tester, {
      Map<String, dynamic>? detail,
      Map<String, RpcHandler>? handlers,
      bool signedIn = true,
    }) async {
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rpc = FakeRpc({
        'get_listing': (_) => detail ?? _detail(),
        ...?handlers,
      });
      await pumpApp(
        tester,
        auth: FakeAuthBackend(signedIn: signedIn),
        rpc: rpc,
        tables: tables,
      );
      await tester.tap(find.text('ناقة مجاهيم للبيع').first);
      await tester.pumpAndSettle();
      return rpc;
    }

    testWidgets('تعرض الخيوط ووسم المعلن والمخفي والمحذوف بلا نص', (
      tester,
    ) async {
      tables.rows['public_comments'] = [
        _comment('r1', body: 'هل يمكن معاينتها؟', name: 'مشتري'),
        _comment(
          'a1',
          parent: 'r1',
          owner: true,
          name: 'صاحب الإعلان',
          body: 'نعم بعد العصر',
          at: '2026-11-23T09:30:00+00:00',
        ),
        _comment('r2', state: 'HIDDEN', at: '2026-11-23T10:00:00+00:00'),
        _comment('r3', state: 'DELETED', at: '2026-11-23T11:00:00+00:00'),
        _comment(
          'r4',
          body: 'تم التعديل',
          editedAt: '2026-11-23T12:30:00+00:00',
          at: '2026-11-23T12:00:00+00:00',
        ),
      ];
      await openDetail(tester);
      expect(find.text('هل يمكن معاينتها؟'), findsOneWidget);
      expect(find.text('نعم بعد العصر'), findsOneWidget);
      expect(find.text('المعلن'), findsOneWidget);
      expect(find.text('أُخفي هذا الرد بقرار الإشراف.'), findsOneWidget);
      expect(find.text('حذف كاتب الرد ردّه.'), findsOneWidget);
      expect(find.text('معدّل'), findsOneWidget);
    });

    testWidgets('فارغة: دعوة لأول سؤال', (tester) async {
      await openDetail(tester);
      expect(find.text('لا ردود بعد. كن أول من يسأل.'), findsOneWidget);
    });

    testWidgets('الزائر: دعوة للدخول بلا حقل كتابة', (tester) async {
      await openDetail(tester, signedIn: false);
      expect(find.byKey(const ValueKey('comments-login')), findsOneWidget);
      expect(find.byKey(const ValueKey('comment-input')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('comments-login')));
      await tester.pumpAndSettle();
      expect(find.text('رقم الجوال'), findsWidgets);
    });

    testWidgets('النشر: نص مقصوص بمعرف طلب، ثم يظهر الرد ويفرغ الحقل', (
      tester,
    ) async {
      final rpc = await openDetail(
        tester,
        handlers: {
          'post_comment': (p) {
            tables.rows['public_comments'] = [
              _comment(
                'new',
                author: 'user-me',
                name: 'أنا',
                body: p!['p_body'] as String?,
              ),
            ];
            return {'id': 'new'};
          },
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('comment-input')),
        '  هل الناقة ملقحة؟  ',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('comment-send')));
      await tester.pumpAndSettle();

      final p = rpc.paramsOf('post_comment').single!;
      expect(p['p_listing_id'], 'l1');
      expect(p['p_body'], 'هل الناقة ملقحة؟');
      expect(p['p_request_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(p.containsKey('p_parent_id'), isFalse);
      expect(find.text('هل الناقة ملقحة؟'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('comment-input')))
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets('الفشل يبقي النص، وإعادة المحاولة بمعرف الطلب نفسه', (
      tester,
    ) async {
      var fail = true;
      final rpc = await openDetail(
        tester,
        handlers: {
          'post_comment': (p) {
            if (fail) throw const PostgrestException(message: 'RATE_LIMITED');
            return {'id': 'new'};
          },
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('comment-input')),
        'سؤال',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('comment-send')));
      await tester.pumpAndSettle();
      expect(find.textContaining('تجاوزت الحد المسموح'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('comment-input')))
            .controller!
            .text,
        'سؤال',
      );

      fail = false;
      await tester.tap(find.byKey(const ValueKey('comment-send')));
      await tester.pumpAndSettle();
      final ids = [
        for (final p in rpc.paramsOf('post_comment')) p!['p_request_id'],
      ];
      expect(ids, hasLength(2));
      expect(ids[0], ids[1]);
    });

    testWidgets('الردود مغلقة: لا حقل كتابة وتظهر الملاحظة', (tester) async {
      await openDetail(tester, detail: _detail(closed: true));
      expect(find.byKey(const ValueKey('comment-input')), findsNothing);
      expect(
        find.text('أغلق المعلن الردود الجديدة على هذا الإعلان.'),
        findsOneWidget,
      );
    });

    testWidgets('إغلاق من الخادم عند النشر: رسالة دون إخفاء ما كتب', (
      tester,
    ) async {
      await openDetail(
        tester,
        handlers: {
          'post_comment': (p) =>
              throw const PostgrestException(message: 'COMMENTS_CLOSED'),
        },
      );
      await tester.enterText(
        find.byKey(const ValueKey('comment-input')),
        'سؤال',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('comment-send')));
      await tester.pumpAndSettle();
      expect(
        find.text('أغلق المعلن الردود الجديدة على هذا الإعلان.'),
        findsOneWidget,
      );
    });

    testWidgets('الكاتب يعدّل ردّه ويحذفه', (tester) async {
      tables.rows['public_comments'] = [
        _comment('mine', author: 'user-me', name: 'أنا', body: 'نص قديم'),
      ];
      final rpc = await openDetail(
        tester,
        handlers: {
          'edit_comment': (p) {
            tables.rows['public_comments'] = [
              _comment(
                'mine',
                author: 'user-me',
                name: 'أنا',
                body: p!['p_body'] as String?,
              ),
            ];
            return {'id': 'mine'};
          },
          'delete_comment': (p) {
            tables.rows['public_comments'] = [
              _comment(
                'mine',
                author: 'user-me',
                name: 'أنا',
                state: 'DELETED',
              ),
            ];
            return {'deleted': true};
          },
        },
      );

      await tester.tap(find.byKey(const ValueKey('comment-menu-mine')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تعديل'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('comment-dialog-input')),
        'نص جديد',
      );
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('edit_comment').single, {
        'p_comment_id': 'mine',
        'p_body': 'نص جديد',
      });
      expect(find.text('نص جديد'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('comment-menu-mine')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف').last);
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('delete_comment').single, {'p_comment_id': 'mine'});
      expect(find.text('حذف كاتب الرد ردّه.'), findsOneWidget);
    });

    testWidgets('ردّ غيري لا قائمة تعديل له', (tester) async {
      tables.rows['public_comments'] = [_comment('other')];
      await openDetail(tester);
      expect(find.byKey(const ValueKey('comment-menu-other')), findsNothing);
    });

    testWidgets('المعلن: لا حقل ابتداء، ويرد على الرد الرئيسي', (tester) async {
      tables.rows['public_comments'] = [_comment('r1', body: 'هل متاحة؟')];
      final rpc = await openDetail(
        tester,
        detail: _detail(ownerId: 'user-me'),
        handlers: {
          'post_comment': (p) => {'id': 'x'},
        },
      );
      expect(find.byKey(const ValueKey('comment-input')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('reply-r1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('comment-dialog-input')),
        'نعم متاحة',
      );
      await tester.tap(find.text('نشر'));
      await tester.pumpAndSettle();
      final p = rpc.paramsOf('post_comment').single!;
      expect(p['p_parent_id'], 'r1');
      expect(p['p_body'], 'نعم متاحة');
    });

    testWidgets('المعلن يغلق الردود الجديدة ويعيد فتحها', (tester) async {
      final rpc = await openDetail(
        tester,
        detail: _detail(ownerId: 'user-me'),
        handlers: {
          'set_comments_closed': (p) => {
            'listing_id': 'l1',
            'comments_closed': p!['p_closed'],
          },
        },
      );
      await tester.tap(find.byKey(const ValueKey('comments-toggle-closed')));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('set_comments_closed').single, {
        'p_listing_id': 'l1',
        'p_closed': true,
      });
    });

    testWidgets('فشل تحميل الردود: إعادة المحاولة', (tester) async {
      tables.failures['public_comments'] = const PostgrestException(
        message: 'x',
      );
      await openDetail(tester);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.text('لا ردود بعد. كن أول من يسأل.'), findsOneWidget);
    });
  });
}
