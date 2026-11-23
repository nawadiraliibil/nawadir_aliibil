import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/app/shell/app_nav_bar.dart';
import 'package:nawadir_aliibil/app/shell/brand_header.dart';
import 'package:nawadir_aliibil/app/theme/app_colors.dart';

import '../../helpers/fake_rpc.dart';
import '../../helpers/pump_app.dart';

/// يضغط وجهة في كبسولة التنقل بتسميتها.
Future<void> tapDestination(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(AppNavBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('الكبسولة تعرض الوجهات الأربع وزر «إعلان»', (tester) async {
    await pumpApp(tester);

    for (final label in ['الرئيسية', 'المفضلة', 'الرسائل', 'حسابي', 'إعلان']) {
      expect(
        find.descendant(of: find.byType(AppNavBar), matching: find.text(label)),
        findsOneWidget,
      );
    }
  });

  testWidgets('تبديل التبويب يغير المحتوى ولا يعيد بناء الشريط أو يحركه', (
    tester,
  ) async {
    await pumpApp(
      tester,
      rpc: FakeRpc({'get_my_account': (_) => fixture('account-ready')}),
    );

    final barBefore = tester.renderObject(find.byType(AppNavBar));
    final rectBefore = tester.getRect(find.byType(AppNavBar));
    expect(find.byKey(const ValueKey('home-search')), findsOneWidget);

    for (final label in ['المفضلة', 'الرسائل', 'حسابي']) {
      await tapDestination(tester, label);

      if (label == 'حسابي') {
        // شاشة الحساب الفعلية (MOBILE-APP-106) لا شاشة مؤقتة.
        expect(find.text('تسجيل الخروج'), findsOneWidget);
      } else if (label == 'المفضلة') {
        // شاشة المفضلة الفعلية (MOBILE-APP-201).
        expect(find.text('لا توجد إعلانات محفوظة'), findsOneWidget);
      } else {
        // شاشة الرسائل الفعلية (MOBILE-APP-301).
        expect(find.text('لا توجد محادثات بعد'), findsOneWidget);
      }
      // العنصر نفسه في الموضع نفسه وبالأبعاد نفسها.
      expect(
        identical(tester.renderObject(find.byType(AppNavBar)), barBefore),
        isTrue,
      );
      expect(tester.getRect(find.byType(AppNavBar)), rectBefore);
    }
  });

  testWidgets('الوجهة المختارة تتلون بالذهبي ويعلن عنها لقارئ الشاشة', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapDestination(tester, 'الرسائل');

    Color labelColor(String label) => tester
        .widget<Text>(
          find.descendant(
            of: find.byType(AppNavBar),
            matching: find.text(label),
          ),
        )
        .style!
        .color!;

    expect(labelColor('الرسائل'), AppColors.light.gold);
    expect(labelColor('الرئيسية'), AppColors.light.muted);
    expect(
      // عنوان شاشة الرسائل يحمل التسمية نفسها؛ المقصود وجهة الكبسولة.
      tester.getSemantics(
        find.descendant(
          of: find.byType(AppNavBar),
          matching: find.bySemanticsLabel('الرسائل'),
        ),
      ),
      isSemantics(
        label: 'الرسائل',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('زر «إعلان» يفتح شاشة كاملة خارج الهيكل والرجوع يعيد التبويب', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapDestination(tester, 'المفضلة');

    await tester.tap(find.bySemanticsLabel('أضف إعلان'));
    await tester.pumpAndSettle();

    expect(find.text('نوع العرض'), findsOneWidget);
    expect(find.byType(AppNavBar).hitTestable(), findsNothing);

    // `tester.pageBack()` يبحث عن تلميح إنجليزي، والتطبيق عربي.
    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();

    expect(find.text('لا توجد إعلانات محفوظة'), findsOneWidget);
    expect(find.byType(AppNavBar).hitTestable(), findsOneWidget);
  });

  testWidgets('محتوى التبويب لا يختبئ تحت الشريط العائم', (tester) async {
    await pumpApp(tester);

    final navTop = tester.getRect(find.byType(AppNavBar)).top;
    final contentBottom = tester
        .getRect(find.byKey(const ValueKey('home-search')))
        .bottom;
    expect(contentBottom, lessThan(navTop));
  });

  testWidgets('الشريط لا يتجاوز حدوده في أضيق عرض مع تكبير النص', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpApp(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(BrandHeader), findsOneWidget);
    final bar = tester.getRect(find.byType(AppNavBar));
    expect(bar.left, greaterThanOrEqualTo(0));
    expect(bar.right, lessThanOrEqualTo(320));
  });
}
