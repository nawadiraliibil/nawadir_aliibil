import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/core/errors/app_error.dart';
import 'package:nawadir_aliibil/features/account/data/account_models.dart';
import 'package:nawadir_aliibil/features/account/data/account_repository.dart';
import 'package:nawadir_aliibil/features/account/presentation/profile_form.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/pump_app.dart';

Future<void> _openAccountTab(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('حسابي'));
  await tester.pumpAndSettle();
}

Map<String, dynamic> _account(String name) =>
    Map<String, dynamic>.from(fixture(name) as Map);

void main() {
  group('نماذج الحساب', () {
    test('أمثلة العقد تحلل', () {
      final fresh = MyAccount.fromJson(_account('account-new'));
      expect(fresh.needsCompletion, isTrue);
      expect(fresh.pendingPolicies.map((p) => p.kind), ['TERMS', 'PRIVACY']);
      expect(fresh.canPublish, isFalse);

      final ready = MyAccount.fromJson(_account('account-ready'));
      expect(ready.needsCompletion, isFalse);
      expect(ready.canPublish, isTrue);
      expect(ready.isSuspended, isFalse);

      final docs = (fixture('current-policies') as List)
          .map((e) => PolicyDocument.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(docs, hasLength(2));
      expect(docs.first.isPlaceholder, isTrue);
    });

    test('المستودع يرسل معاملات الدوال بأسمائها الفعلية', () async {
      final rpc = FakeRpc({
        'update_my_profile': (_) => <String, dynamic>{},
        'accept_policies': (_) => <String, dynamic>{},
      });
      final repo = AccountRepository(rpc.caller);
      await repo.updateProfile(displayName: 'سالم', regionId: 3);
      await repo.acceptPolicies([1, 2]);
      expect(rpc.paramsOf('update_my_profile'), [
        {'p_display_name': 'سالم', 'p_region_id': 3},
      ]);
      expect(rpc.paramsOf('accept_policies'), [
        {
          'p_document_ids': [1, 2],
        },
      ]);
    });

    test('خطأ الخادم يخرج AppError برمزه', () async {
      final rpc = FakeRpc({
        'get_my_account': (_) => throw const PostgrestException(
          message: 'ACCOUNT_SUSPENDED',
          code: 'P0001',
        ),
      });
      await expectLater(
        AccountRepository(rpc.caller).myAccount(),
        throwsA(
          isA<AppError>().having(
            (e) => e.code,
            'code',
            AppErrorCode.accountSuspended,
          ),
        ),
      );
    });

    test('تحقق الاسم', () {
      expect(validateDisplayName('س'), isNotNull);
      expect(validateDisplayName('  س  '), isNotNull);
      expect(validateDisplayName('سالم'), isNull);
      expect(validateDisplayName('  سالم  '), isNull);
      expect(validateDisplayName('x' * 41), isNotNull);
      expect(validateDisplayName('سا\u0000لم'), isNotNull);
    });
  });

  testWidgets('الزائر يرى دعوة الدخول ويعود إلى حسابه بعد الدخول', (
    tester,
  ) async {
    final auth = FakeAuthBackend();
    final rpc = FakeRpc({'get_my_account': (_) => fixture('account-ready')});
    await pumpApp(tester, auth: auth, rpc: rpc);
    await _openAccountTab(tester);

    expect(find.text('سجّل الدخول'), findsOneWidget);
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '500000001');
    await tester.pump();
    await tester.tap(find.text('إرسال الرمز'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    expect(find.text('معلن تجريبي'), findsOneWidget);
    expect(find.text('تسجيل الخروج'), findsOneWidget);
  });

  testWidgets('حساب جديد: تنبيه إكمال، ولا حفظ دون اسم ومنطقة وموافقتين', (
    tester,
  ) async {
    final rpc = FakeRpc({
      'get_my_account': (_) => fixture('account-new'),
      'update_my_profile': (_) => <String, dynamic>{},
      'accept_policies': (_) => <String, dynamic>{},
    });
    await pumpApp(tester, auth: FakeAuthBackend(signedIn: true), rpc: rpc);
    await _openAccountTab(tester);

    expect(find.text('مستخدم جديد'), findsOneWidget);
    await tester.tap(find.text('إكمال الحساب'));
    await tester.pumpAndSettle();

    // حفظ فارغ: لا استدعاء ولا ينتقل.
    await tester.tap(find.text('حفظ ومتابعة'));
    await tester.pumpAndSettle();
    expect(rpc.paramsOf('update_my_profile'), isEmpty);
    expect(find.text('اختر منطقتك.'), findsOneWidget);
    expect(find.text('الاسم لا يقل عن حرفين.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  سالم  ');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الرياض').last);
    await tester.pumpAndSettle();

    // الاسم والمنطقة بلا موافقة: لا يحفظ.
    await tester.tap(find.text('حفظ ومتابعة'));
    await tester.pumpAndSettle();
    expect(rpc.paramsOf('update_my_profile'), isEmpty);

    await tester.tap(find.text('أوافق على شروط الاستخدام'));
    await tester.tap(find.text('أوافق على سياسة الخصوصية'));
    await tester.pump();

    // بعد الحفظ يعيد الخادم حسابًا مكتملًا.
    rpc.handlers['get_my_account'] = (_) => fixture('account-ready');
    await tester.tap(find.text('حفظ ومتابعة'));
    await tester.pumpAndSettle();

    expect(rpc.paramsOf('update_my_profile'), [
      {'p_display_name': 'سالم', 'p_region_id': 1},
    ]);
    expect(rpc.paramsOf('accept_policies'), [
      {
        'p_document_ids': [1, 2],
      },
    ]);
    expect(find.text('معلن تجريبي'), findsOneWidget);
    expect(find.text('إكمال الحساب'), findsNothing);
  });

  testWidgets('نص الشروط يقرأ قبل الموافقة', (tester) async {
    final rpc = FakeRpc({'get_my_account': (_) => fixture('account-new')});
    await pumpApp(tester, auth: FakeAuthBackend(signedIn: true), rpc: rpc);
    await _openAccountTab(tester);
    await tester.tap(find.text('إكمال الحساب'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('قراءة').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('نص مؤقت لأغراض التطوير'), findsOneWidget);
  });

  testWidgets('خطأ الخادم عند الحفظ يظهر ولا يُغلق النموذج', (tester) async {
    final rpc = FakeRpc({
      'get_my_account': (_) => fixture('account-new'),
      'update_my_profile': (_) => throw const PostgrestException(
        message: 'VALIDATION_FAILED',
        code: 'P0001',
        details: '{"fields": ["display_name"]}',
      ),
    });
    await pumpApp(tester, auth: FakeAuthBackend(signedIn: true), rpc: rpc);
    await _openAccountTab(tester);
    await tester.tap(find.text('إكمال الحساب'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'سالم');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الرياض').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('أوافق على شروط الاستخدام'));
    await tester.tap(find.text('أوافق على سياسة الخصوصية'));
    await tester.pump();
    await tester.tap(find.text('حفظ ومتابعة'));
    await tester.pumpAndSettle();

    expect(find.textContaining('تحقق من البيانات'), findsOneWidget);
    expect(rpc.paramsOf('accept_policies'), isEmpty);
    expect(find.text('حفظ ومتابعة'), findsOneWidget);
  });

  testWidgets(
    'حساب مكتمل: بلا تنبيه، وتعديل الملف يعبّأ مسبقًا ولا يطلب موافقات',
    (tester) async {
      final rpc = FakeRpc({
        'get_my_account': (_) => fixture('account-ready'),
        'update_my_profile': (_) => <String, dynamic>{},
      });
      await pumpApp(tester, auth: FakeAuthBackend(signedIn: true), rpc: rpc);
      await _openAccountTab(tester);

      expect(find.text('إكمال الحساب'), findsNothing);
      expect(find.textContaining('05*****001'), findsOneWidget);

      await tester.tap(find.byTooltip('تعديل الملف'));
      await tester.pumpAndSettle();
      expect(find.text('معلن تجريبي'), findsOneWidget); // الحقل معبأ
      expect(find.textContaining('أوافق'), findsNothing);

      await tester.enterText(find.byType(TextField), 'اسم جديد');
      await tester.tap(find.text('حفظ التغييرات'));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('update_my_profile'), [
        {'p_display_name': 'اسم جديد', 'p_region_id': 1},
      ]);
      expect(rpc.paramsOf('accept_policies'), isEmpty);
    },
  );

  testWidgets('الحساب الموقوف يعرض تنبيه الإيقاف بدل دعوة الإكمال', (
    tester,
  ) async {
    final suspended = _account('account-ready')..['status'] = 'SUSPENDED';
    final rpc = FakeRpc({'get_my_account': (_) => suspended});
    await pumpApp(tester, auth: FakeAuthBackend(signedIn: true), rpc: rpc);
    await _openAccountTab(tester);
    expect(find.textContaining('الحساب موقوف'), findsOneWidget);
  });

  testWidgets('تسجيل الخروج: الإلغاء لا يخرج، والتأكيد يبطل الجلسة', (
    tester,
  ) async {
    final auth = FakeAuthBackend(signedIn: true);
    final rpc = FakeRpc({'get_my_account': (_) => fixture('account-ready')});
    await pumpApp(tester, auth: auth, rpc: rpc);
    await _openAccountTab(tester);

    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الخروج؟'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 0);

    await tester.tap(find.text('تسجيل الخروج'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الخروج'));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 1);
    expect(find.text('سجّل الدخول'), findsOneWidget);
  });

  testWidgets('فشل تحميل الحساب يعرض إعادة المحاولة', (tester) async {
    var fail = true;
    final rpc = FakeRpc({
      'get_my_account': (_) {
        if (fail) throw const PostgrestException(message: 'INTERNAL_ERROR');
        return fixture('account-ready');
      },
    });
    await pumpApp(tester, auth: FakeAuthBackend(signedIn: true), rpc: rpc);
    await _openAccountTab(tester);
    expect(find.text('تعذّر تحميل حسابك'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('معلن تجريبي'), findsOneWidget);
  });
}
