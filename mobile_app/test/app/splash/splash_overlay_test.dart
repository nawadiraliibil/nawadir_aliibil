import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/app/app.dart';
import 'package:nawadir_aliibil/app/shell/app_nav_bar.dart';
import 'package:nawadir_aliibil/app/splash/splash_handoff.dart';
import 'package:nawadir_aliibil/app/splash/splash_overlay.dart';
import 'package:nawadir_aliibil/core/config/env.dart';

import '../../helpers/pump_app.dart';

/// متحكم الحركة يعدّها منتهية بعد تجاوز مدتها لا عند بلوغها تمامًا، فيلزم
/// إطار إضافي بعد نهاية كل حركة.
const afterEnd = Duration(milliseconds: 1);

SplashHandoff handoffOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(NawadirApp)),
).read(splashHandoffProvider);

/// صورة شعار شاشة البداية. تتميز عن شعار الترويسة بأنها تحمل تسمية دلالية.
Finder splashEmblem() => find.byWidgetPredicate(
  (widget) => widget is Image && widget.semanticLabel == 'نوادر الإبل',
);

/// مستطيل الشعار المتحرك أثناء الانتقال وبعد الهبوط.
Rect emblemRect(WidgetTester tester) => tester.getRect(
  find.ancestor(of: splashEmblem(), matching: find.byType(Positioned)).first,
);

void main() {
  testWidgets('عند الفتح: الشعار وسطر الحالة ظاهران وشعار الترويسة مخفي', (
    tester,
  ) async {
    await pumpAppAtSplash(tester);

    expect(find.text('جارٍ التحميل'), findsOneWidget);
    expect(handoffOf(tester).logoVisible.value, isFalse);

    // الغطاء يمنع الضغط على ما تحته.
    await tester.tap(find.byType(AppNavBar), warnIfMissed: false);
    await tester.pump();
    expect(find.byKey(const ValueKey('home-search')), findsOneWidget);

    await tester.pump(SplashOverlay.hold);
    await tester.pumpAndSettle();
  });

  testWidgets('يبقى ثانية كاملة قبل بدء الانتقال', (tester) async {
    await pumpAppAtSplash(tester);

    await tester.pump(const Duration(milliseconds: 990));
    expect(find.text('جارٍ التحميل'), findsOneWidget);
    expect(find.byType(Positioned), findsWidgets);
    expect(handoffOf(tester).logoVisible.value, isFalse);

    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();
  });

  testWidgets('الشعار يهبط على شعار الترويسة في 720ms ثم يظهر شعارها', (
    tester,
  ) async {
    await pumpAppAtSplash(tester);
    final handoff = handoffOf(tester);
    final target = handoff.targetRect()!;
    final screen = tester.getSize(find.byType(NawadirApp));

    // بدء الانتقال: الشعار في وسط الشاشة أفقيًا وبحجمه الكبير.
    await tester.pump(SplashOverlay.hold);
    await tester.pump();
    final start = emblemRect(tester);
    expect(start.center.dx, moreOrLessEquals(screen.width / 2, epsilon: 0.5));
    expect(start.width, greaterThanOrEqualTo(132));

    // منتصف الانتقال: بين الموضعين وأصغر من البداية.
    await tester.pump(const Duration(milliseconds: 360));
    final mid = emblemRect(tester);
    expect(mid.width, lessThan(start.width));
    expect(mid.width, greaterThan(target.width));
    expect(handoff.logoVisible.value, isFalse);

    // نهاية الانتقال: مطابق لمستطيل شعار الترويسة، ويظهر شعارها.
    await tester.pump(const Duration(milliseconds: 360));
    final end = emblemRect(tester);
    expect(end.left, moreOrLessEquals(target.left, epsilon: 0.01));
    expect(end.top, moreOrLessEquals(target.top, epsilon: 0.01));
    expect(end.width, moreOrLessEquals(target.width, epsilon: 0.01));
    expect(
      handoff.logoVisible.value,
      isFalse,
      reason: 'يظهر بعد اكتمال الهبوط',
    );

    await tester.pump(afterEnd);
    expect(handoff.logoVisible.value, isTrue);
    expect(emblemRect(tester), end, reason: 'يتلاشى في موضع الهبوط');

    // بعد تلاشي الشعار تزول الطبقة كاملة ويعود التفاعل.
    await tester.pump(SplashOverlay.settle);
    await tester.pump(afterEnd);
    expect(find.text('جارٍ التحميل'), findsNothing);
    expect(splashEmblem(), findsNothing);

    await tester.tap(
      find.descendant(
        of: find.byType(AppNavBar),
        matching: find.text('المفضلة'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('لا توجد إعلانات محفوظة'), findsOneWidget);
  });

  testWidgets('مع «تقليل الحركة»: تلاشٍ قصير دون انتقال مكاني', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await pumpAppAtSplash(tester);
    final handoff = handoffOf(tester);

    await tester.pump(SplashOverlay.hold);
    await tester.pump();
    // شعار الترويسة يظهر فورًا، ولا نسخة متحركة من الشعار.
    expect(handoff.logoVisible.value, isTrue);
    expect(
      find.descendant(
        of: find.byType(SplashOverlay),
        matching: find.byType(Positioned),
      ),
      findsNWidgets(
        tester
                .widgetList(
                  find.descendant(
                    of: find.byType(AppNavBar),
                    matching: find.byType(Positioned),
                  ),
                )
                .length +
            1,
      ),
      reason: 'لا Positioned لشعار متحرك؛ الموجود هو موضع شريط التنقل فقط',
    );

    // التلاشي يستغرق 200ms كاملة ولا يُقصَّر.
    await tester.pump(const Duration(milliseconds: 190));
    expect(find.text('جارٍ التحميل'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(afterEnd);
    expect(find.text('جارٍ التحميل'), findsNothing);
  });

  testWidgets('دون رئيسية معروضة: يتلاشى المشهد ولا يتعطل', (tester) async {
    await pumpAppAtSplash(
      tester,
      env: const Env(supabaseUrl: '', supabasePublishableKey: ''),
    );
    expect(handoffOf(tester).targetRect(), isNull);

    await tester.pump(SplashOverlay.hold);
    await tester.pump();
    await tester.pump(SplashOverlay.reducedFade);
    await tester.pump(afterEnd);

    expect(tester.takeException(), isNull);
    expect(find.text('جارٍ التحميل'), findsNothing);
    expect(find.text('إعداد البيئة ناقص'), findsOneWidget);
  });
}
