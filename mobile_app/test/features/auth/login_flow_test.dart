import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/features/auth/data/auth_backend.dart';
import 'package:nawadir_aliibil/features/auth/presentation/otp_screen.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/pump_app.dart';

Future<void> _openLoginFromPost(
  WidgetTester tester,
  FakeAuthBackend auth,
) async {
  await pumpApp(tester, auth: auth);
  await tester.tap(find.bySemanticsLabel('أضف إعلان'));
  await tester.pumpAndSettle();
}

Future<void> _enterPhone(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<void> _submitPhone(WidgetTester tester) async {
  await tester.tap(find.text('إرسال الرمز'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('الزائر يوجَّه من «إعلان» إلى الدخول، والرجوع يعيده للرئيسية', (
    tester,
  ) async {
    final auth = FakeAuthBackend();
    await _openLoginFromPost(tester, auth);

    expect(find.text('رقم الجوال'), findsWidgets);
    expect(find.text('نوع العرض'), findsNothing);

    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();
    expect(find.text('رقم الجوال'), findsNothing);
  });

  testWidgets('المسجّل يفتح «إعلان» مباشرة دون دخول', (tester) async {
    await pumpApp(tester, auth: FakeAuthBackend(signedIn: true));
    await tester.tap(find.bySemanticsLabel('أضف إعلان'));
    await tester.pumpAndSettle();
    expect(find.text('نوع العرض'), findsOneWidget);
  });

  testWidgets('زر الإرسال معطل حتى يصح الرقم، ويرسل بالصيغة الدولية', (
    tester,
  ) async {
    final auth = FakeAuthBackend();
    await _openLoginFromPost(tester, auth);

    FilledButton button() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'إرسال الرمز'),
    );
    expect(button().onPressed, isNull);

    await _enterPhone(tester, '12345');
    expect(button().onPressed, isNull);
    expect(find.textContaining('أدخل رقم جوال سعوديًا'), findsOneWidget);

    await _enterPhone(tester, '0500000001');
    expect(button().onPressed, isNotNull);

    await _submitPhone(tester);
    expect(auth.sentTo, ['+966500000001']);
    expect(find.text('رمز التحقق'), findsOneWidget);
    expect(find.textContaining('05*****001'), findsOneWidget);
  });

  testWidgets('رمز صحيح يفتح الجلسة ويعيد إلى «إعلان جديد»', (tester) async {
    final auth = FakeAuthBackend();
    await _openLoginFromPost(tester, auth);
    await _enterPhone(tester, '500000001');
    await _submitPhone(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    expect(auth.verified, [('+966500000001', '123456')]);
    expect(find.text('نوع العرض'), findsOneWidget);
  });

  testWidgets('رمز خاطئ لا يفتح جلسة ويعرض «تعذر التحقق» ثم يعيد المحاولة', (
    tester,
  ) async {
    final auth = FakeAuthBackend();
    await _openLoginFromPost(tester, auth);
    await _enterPhone(tester, '500000001');
    await _submitPhone(tester);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pumpAndSettle();

    expect(auth.signedIn, isFalse);
    expect(find.text('تعذر التحقق'), findsOneWidget);
    expect(find.text('نوع العرض'), findsNothing);

    await tester.tap(find.text('حاول مجددًا'));
    await tester.pumpAndSettle();
    expect(find.text('رمز التحقق'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('تجاوز الحد في الخادم يعرض رسالته ولا يظهر «تعذر التحقق»', (
    tester,
  ) async {
    final auth = FakeAuthBackend()
      ..verifyFailure = const AuthFailure(AuthFailureKind.rateLimited);
    await _openLoginFromPost(tester, auth);
    await _enterPhone(tester, '500000001');
    await _submitPhone(tester);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    expect(find.textContaining('تجاوزت عدد المحاولات'), findsOneWidget);
    expect(find.text('تعذر التحقق'), findsNothing);
  });

  testWidgets('فشل الإرسال يبقي المستخدم في شاشة الرقم مع رسالة', (
    tester,
  ) async {
    final auth = FakeAuthBackend()
      ..sendFailure = const AuthFailure(AuthFailureKind.network);
    await _openLoginFromPost(tester, auth);
    await _enterPhone(tester, '500000001');
    await _submitPhone(tester);

    expect(find.textContaining('تعذّر الاتصال'), findsOneWidget);
    expect(find.text('رمز التحقق'), findsNothing);
  });

  testWidgets('إعادة الإرسال مقفلة 60 ثانية ثم تعمل', (tester) async {
    final auth = FakeAuthBackend();
    await _openLoginFromPost(tester, auth);
    await _enterPhone(tester, '500000001');
    await _submitPhone(tester);

    expect(find.text('إعادة الإرسال بعد 60 ثانية'), findsOneWidget);
    await tester.pump(const Duration(seconds: 59));
    expect(find.text('إعادة الإرسال بعد 1 ثانية'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('إعادة الإرسال'), findsOneWidget);

    await tester.tap(find.text('إعادة الإرسال'));
    await tester.pump();
    expect(auth.sentTo, ['+966500000001', '+966500000001']);
    // العد يبدأ من جديد.
    expect(
      find.text('إعادة الإرسال بعد ${OtpScreen.resendDelay.inSeconds} ثانية'),
      findsOneWidget,
    );
  });

  testWidgets('تسجيل الخروج يعيد حماية «إعلان»', (tester) async {
    final auth = FakeAuthBackend(signedIn: true);
    await pumpApp(tester, auth: auth);
    await auth.signOut();
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('أضف إعلان'));
    await tester.pumpAndSettle();
    expect(find.text('رقم الجوال'), findsWidgets);
  });

  testWidgets('شاشتا الدخول لا تتجاوزان الحدود في عرض 320 مع تكبير النص', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final auth = FakeAuthBackend();
    await _openLoginFromPost(tester, auth);
    expect(tester.takeException(), isNull);
    await _enterPhone(tester, '500000001');
    await tester.scrollUntilVisible(
      find.text('إرسال الرمز'),
      50,
      scrollable: find
          .ancestor(
            of: find.byType(TextField),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await _submitPhone(tester);
    expect(tester.takeException(), isNull);
  });
}
