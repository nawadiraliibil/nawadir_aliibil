import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/core/config/env.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/pump_app.dart';

const _prodEnv = Env(
  supabaseUrl: 'https://example.supabase.co',
  supabasePublishableKey: 'sb_publishable_x',
  appEnv: 'prod',
);

Future<void> _openLogin(
  WidgetTester tester,
  FakeAuthBackend auth, {
  Env? env,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(tester, auth: auth, env: env ?? configuredEnv);
  await tester.tap(find.bySemanticsLabel('أضف إعلان'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('الدخول البديل يظهر في بيئة dev ويفتح الجلسة ويعيد إلى الوجهة', (
    tester,
  ) async {
    final auth = FakeAuthBackend();
    await _openLogin(tester, auth);

    expect(find.text('دخول للتطوير (بريد)'), findsOneWidget);
    await tester.tap(find.text('دخول للتطوير (بريد)'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'البريد'),
      'dev@x.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور'),
      'dev-pass',
    );
    await tester.tap(find.text('دخول للتطوير'));
    await tester.pumpAndSettle();

    expect(auth.passwordLogins, [('dev@x.test', 'dev-pass')]);
    expect(find.text('نوع العرض'), findsOneWidget); // عاد إلى «إعلان جديد»
  });

  testWidgets('كلمة مرور خاطئة تعرض رسالة ولا تفتح جلسة', (tester) async {
    final auth = FakeAuthBackend();
    await _openLogin(tester, auth);
    await tester.tap(find.text('دخول للتطوير (بريد)'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'البريد'),
      'dev@x.test',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'كلمة المرور'),
      'bad',
    );
    await tester.tap(find.text('دخول للتطوير'));
    await tester.pumpAndSettle();
    expect(find.text('بيانات الدخول غير صحيحة.'), findsOneWidget);
    expect(auth.signedIn, isFalse);
  });

  testWidgets('خارج بيئة dev لا يظهر الدخول البديل إطلاقًا', (tester) async {
    await _openLogin(tester, FakeAuthBackend(), env: _prodEnv);
    expect(find.text('دخول للتطوير (بريد)'), findsNothing);
    expect(find.text('رقم الجوال'), findsWidgets);
  });
}
