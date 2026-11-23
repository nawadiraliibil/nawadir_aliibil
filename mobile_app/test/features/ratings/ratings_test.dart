import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/features/ratings/data/rating_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/fake_tables.dart';
import '../../helpers/pump_app.dart';

const _sellerId = 'seller-1';

Map<String, dynamic> _pub({
  String id = 'r1',
  String rater = 'rater-1',
  String name = 'مشتري',
  int score = 4,
  String? body = 'تعامل ممتاز',
  String? reply,
  String? editedAt,
  String at = '2026-11-23T09:00:00+00:00',
}) => {
  'rating_id': id,
  'seller_id': _sellerId,
  'rater_id': rater,
  'rater_display_name': name,
  'score': score,
  'body': body,
  'reply_body': reply,
  'reply_at': null,
  'edited_at': editedAt,
  'created_at': at,
};

Map<String, dynamic> _received({
  String id = 'r1',
  String status = 'VISIBLE',
  String? reply,
  String? appealId,
  String? appealStatus,
  String body = 'تقييم ما',
}) => {
  'rating_id': id,
  'rater_id': 'rater-1',
  'rater_display_name': 'مشتري',
  'score': 2,
  'body': body,
  'status': status,
  'reply_body': reply,
  'appeal_id': appealId,
  'appeal_status': appealStatus,
  'edited_at': null,
  'created_at': '2026-11-23T09:00:00+00:00',
};

Map<String, dynamic> _profile({num? avg = 4, int count = 1}) => {
  ...Map<String, dynamic>.from(fixture('public-profile') as Map),
  'id': _sellerId,
  'display_name': 'صاحب الإعلان',
  'rating_avg': avg,
  'rating_count': count,
};

Map<String, dynamic> _detail() {
  final d = Map<String, dynamic>.from(fixture('listing-detail') as Map);
  final l = Map<String, dynamic>.from(d['listing'] as Map)
    ..['owner_id'] = _sellerId
    ..['owner_display_name'] = 'صاحب الإعلان';
  return d..['listing'] = l;
}

void main() {
  group('البيانات', () {
    test('صفوف العقد تُحلَّل', () {
      final p = PublicRating.fromJson(
        Map<String, dynamic>.from(
          (fixture('public-ratings') as List).first as Map,
        ),
      );
      expect(p.score, 4);
      expect(p.replyBody, 'شكرًا لك.');
      final r = ReceivedRating.fromJson(
        Map<String, dynamic>.from(
          (fixture('my-received-ratings') as List).first as Map,
        ),
      );
      expect(r.hidden, isFalse);
      expect(r.canAppeal, isTrue); // لا اعتراض وقت التسجيل
    });

    test('شرح عدم الأهلية بلا ادعاء شراء', () {
      for (final reason in [
        'SELF',
        'BLOCKED',
        'NO_EXCHANGE',
        'NO_CONVERSATION',
        'X',
      ]) {
        final t = RatingEligibility(eligible: false, reason: reason).reasonText;
        expect(t, isNotEmpty);
        expect(t, isNot(contains('شراء')));
      }
    });
  });

  group('شاشة تقييمات المعلن', () {
    late FakeTables tables;

    setUp(() {
      tables = FakeTables({
        'public_profiles': [_profile()],
        'public_ratings': [
          _pub(reply: 'شكرًا لك'),
          _pub(
            id: 'r2',
            rater: 'rater-2',
            name: 'آخر',
            score: 2,
            body: null,
            at: '2026-11-22T09:00:00+00:00',
          ),
        ],
      });
    });

    Future<FakeRpc> open(
      WidgetTester tester, {
      Map<String, dynamic>? eligibility,
      bool signedIn = true,
      Map<String, RpcHandler>? handlers,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rpc = FakeRpc({
        'get_listing': (_) => _detail(),
        'get_rating_eligibility': (_) => eligibility ?? {'eligible': true},
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
      await tester.tap(find.byKey(const ValueKey('owner-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('seller-rating-summary')));
      await tester.pumpAndSettle();
      return rpc;
    }

    testWidgets(
      'الملف يلخص التقييم، والشاشة تعرض المتوسط والردود وملاحظة عدم الشراء',
      (tester) async {
        await open(tester);
        expect(find.text('3.0'), findsOneWidget);
        expect(find.text('2 تقييمًا'), findsOneWidget);
        expect(find.text('تعامل ممتاز'), findsOneWidget);
        expect(find.text('شكرًا لك'), findsOneWidget);
        expect(find.text('رد المعلن'), findsOneWidget);
        expect(find.textContaining('لا يثبت عملية شراء'), findsOneWidget);
      },
    );

    testWidgets(
      'التقييم يشترط درجة وإقرارًا غير مفعل مسبقًا، ثم يرسل بمعرف طلب',
      (tester) async {
        final rpc = await open(
          tester,
          handlers: {
            'submit_rating': (p) => {
              'rating_id': 'new',
              'score': p!['p_score'],
            },
          },
        );
        await tester.tap(find.byKey(const ValueKey('rate-seller')));
        await tester.pumpAndSettle();

        FilledButton submit() => tester.widget<FilledButton>(
          find.byKey(const ValueKey('rating-submit')),
        );
        expect(submit().onPressed, isNull);
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const ValueKey('rating-declaration')),
              )
              .value,
          isFalse,
        );

        await tester.tap(find.byKey(const ValueKey('score-4')));
        await tester.pump();
        expect(submit().onPressed, isNull); // الإقرار ناقص
        expect(find.text('جيد جدًا'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('rating-declaration')));
        await tester.pump();
        await tester.enterText(
          find.byKey(const ValueKey('rating-body')),
          '  رائع  ',
        );
        await tester.pump();
        expect(submit().onPressed, isNotNull);
        await tester.tap(find.byKey(const ValueKey('rating-submit')));
        await tester.pumpAndSettle();

        final p = rpc.paramsOf('submit_rating').single!;
        expect(p['p_seller_id'], _sellerId);
        expect(p['p_score'], 4);
        expect(p['p_body'], 'رائع');
        expect(p['p_declaration'], true);
        expect(p['p_request_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
        expect(find.text('تم نشر تقييمك.'), findsOneWidget);
      },
    );

    testWidgets('الفشل يبقي الورقة، وإعادة الإرسال بمعرف الطلب نفسه', (
      tester,
    ) async {
      var fail = true;
      final rpc = await open(
        tester,
        handlers: {
          'submit_rating': (p) {
            if (fail) throw const PostgrestException(message: 'INTERNAL_ERROR');
            return {'rating_id': 'x'};
          },
        },
      );
      await tester.tap(find.byKey(const ValueKey('rate-seller')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('score-5')));
      await tester.tap(find.byKey(const ValueKey('rating-declaration')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('rating-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('حدث خطأ'), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const ValueKey('rating-submit')));
      await tester.pumpAndSettle();
      final ids = [
        for (final p in rpc.paramsOf('submit_rating')) p!['p_request_id'],
      ];
      expect(ids, hasLength(2));
      expect(ids[0], ids[1]);
    });

    testWidgets('تقييم قائم: رسالة بسيطة للمكرر من الخادم', (tester) async {
      await open(
        tester,
        handlers: {
          'submit_rating': (p) => throw const PostgrestException(
            message: 'RATING_EXISTS',
            details: '{"rating_id":"r1"}',
          ),
        },
      );
      await tester.tap(find.byKey(const ValueKey('rate-seller')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('score-3')));
      await tester.tap(find.byKey(const ValueKey('rating-declaration')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('rating-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('قيّمت هذا المعلن من قبل. يمكنك تعديل تقييمك.'),
        findsOneWidget,
      );
    });

    testWidgets('تعديل تقييمي: دون إقرار، ويرسل edit_rating', (tester) async {
      tables.rows['public_ratings'] = [
        _pub(id: 'mine', rater: 'user-me', name: 'أنا', score: 3, body: 'قديم'),
      ];
      final rpc = await open(
        tester,
        eligibility: {
          'eligible': false,
          'reason': 'ALREADY_RATED',
          'rating_id': 'mine',
        },
        handlers: {
          'edit_rating': (p) => {'rating_id': 'mine'},
        },
      );
      await tester.tap(find.byKey(const ValueKey('edit-my-rating')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rating-declaration')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('score-5')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('rating-body')),
        'محدّث',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('rating-submit')));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('edit_rating').single, {
        'p_rating_id': 'mine',
        'p_score': 5,
        'p_body': 'محدّث',
      });
      expect(find.text('تم حفظ تعديل تقييمك.'), findsOneWidget);
    });

    testWidgets('غير مؤهل: شرح بسيط دون زر تقييم', (tester) async {
      await open(
        tester,
        eligibility: {'eligible': false, 'reason': 'NO_EXCHANGE'},
      );
      expect(find.byKey(const ValueKey('rate-seller')), findsNothing);
      expect(find.text('التقييم غير متاح الآن'), findsOneWidget);
      expect(find.textContaining('يرد المعلن على رسالتك'), findsOneWidget);
    });

    testWidgets('الزائر: دعوة للدخول', (tester) async {
      await open(tester, signedIn: false);
      expect(find.byKey(const ValueKey('rating-login')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rating-login')));
      await tester.pumpAndSettle();
      expect(find.text('رقم الجوال'), findsWidgets);
    });

    testWidgets('البلاغ عن تقييم الآخرين فقط', (tester) async {
      tables.rows['public_ratings'] = [
        _pub(id: 'other'),
        _pub(id: 'mine', rater: 'user-me', name: 'أنا'),
      ];
      final rpc = await open(
        tester,
        eligibility: {'eligible': false, 'reason': 'ALREADY_RATED'},
        handlers: {'submit_report': (p) => fixture('report-submitted')},
      );
      expect(find.byKey(const ValueKey('rating-menu-mine')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('rating-menu-other')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إبلاغ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-reason-ABUSE')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('report-submit')));
      await tester.pumpAndSettle();
      final p = rpc.paramsOf('submit_report').single!;
      expect(p['p_target_type'], 'RATING');
      expect(p['p_target_id'], 'other');
    });

    testWidgets('فشل التحميل: إعادة المحاولة', (tester) async {
      tables.failures['public_ratings'] = const PostgrestException(
        message: 'x',
      );
      await open(tester);
      expect(find.text('تعذّر تحميل التقييمات'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.text('تعامل ممتاز'), findsOneWidget);
    });
  });

  group('تقييماتي كمعلن', () {
    Future<FakeRpc> open(
      WidgetTester tester,
      List<Map<String, dynamic>> rows, {
      Map<String, RpcHandler>? handlers,
    }) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tables = FakeTables({'my_received_ratings': rows});
      final rpc = FakeRpc({
        'get_my_account': (_) => fixture('account-ready'),
        ...?handlers,
      });
      await pumpApp(tester, rpc: rpc, tables: tables);
      await tester.tap(find.text('حسابي').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('تقييماتي كمعلن'));
      await tester.pumpAndSettle();
      return rpc;
    }

    testWidgets('الرد على تقييم: نص منفصل ولا يغير الدرجة', (tester) async {
      final rpc = await open(
        tester,
        [_received()],
        handlers: {
          'reply_to_rating': (p) => {'replied': true},
        },
      );
      expect(find.textContaining('الاعتراض لا يخفي التقييم'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reply-rating-r1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('rating-dialog-input')),
        'شكرًا',
      );
      await tester.tap(find.text('نشر'));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('reply_to_rating').single, {
        'p_rating_id': 'r1',
        'p_body': 'شكرًا',
      });
      expect(find.text('تم نشر ردك.'), findsOneWidget);
    });

    testWidgets('الاعتراض بسبب منفصل، ويُخبر أنه لا يخفي التقييم', (
      tester,
    ) async {
      final rpc = await open(
        tester,
        [_received()],
        handlers: {
          'appeal_rating': (p) => {
            'appeal_id': 'a1',
            'status': 'OPEN',
            'created': true,
          },
        },
      );
      await tester.tap(find.byKey(const ValueKey('appeal-rating-r1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('rating-dialog-input')),
        'لم يحدث تعامل',
      );
      await tester.tap(find.text('إرسال الاعتراض'));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('appeal_rating').single, {
        'p_rating_id': 'r1',
        'p_reason': 'لم يحدث تعامل',
      });
    });

    testWidgets('اعتراض قائم: حالته وبلا زر اعتراض ثانٍ', (tester) async {
      await open(tester, [_received(appealId: 'a1', appealStatus: 'OPEN')]);
      expect(find.text('اعتراضك قيد المراجعة.'), findsOneWidget);
      expect(find.byKey(const ValueKey('appeal-rating-r1')), findsNothing);
    });

    testWidgets('المخفي: شارة ولا رد ولا اعتراض', (tester) async {
      await open(tester, [
        _received(status: 'HIDDEN', appealId: 'a1', appealStatus: 'ACCEPTED'),
      ]);
      expect(find.text('مخفي'), findsOneWidget);
      expect(find.byKey(const ValueKey('reply-rating-r1')), findsNothing);
      expect(find.text('قُبل اعتراضك وأُخفي التقييم.'), findsOneWidget);
    });

    testWidgets('رفض الخادم برسالة', (tester) async {
      await open(
        tester,
        [_received()],
        handlers: {
          'reply_to_rating': (p) =>
              throw const PostgrestException(message: 'INVALID_STATE'),
        },
      );
      await tester.tap(find.byKey(const ValueKey('reply-rating-r1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('rating-dialog-input')),
        'رد',
      );
      await tester.tap(find.text('نشر'));
      await tester.pumpAndSettle();
      expect(
        find.text('هذا الإجراء غير متاح في حالة الإعلان الحالية.'),
        findsOneWidget,
      );
    });

    testWidgets('فارغ: حالة فراغ', (tester) async {
      await open(tester, []);
      expect(find.text('لا تقييمات بعد'), findsOneWidget);
    });
  });
}
