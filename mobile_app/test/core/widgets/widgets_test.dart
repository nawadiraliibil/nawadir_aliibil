import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/app/theme/app_colors.dart';
import 'package:nawadir_aliibil/app/theme/app_theme.dart';
import 'package:nawadir_aliibil/core/widgets/app_badge.dart';
import 'package:nawadir_aliibil/core/widgets/app_note.dart';
import 'package:nawadir_aliibil/core/widgets/empty_state.dart';
import 'package:nawadir_aliibil/core/widgets/section_title.dart';
import 'package:nawadir_aliibil/core/widgets/wasm_ring.dart';

Widget host(Widget child, {ThemeData? theme, double width = 360}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

/// خلفية الشارة: أول `DecoratedBox` تحتها. شارتا المزاد والسعر تحويان علامة
/// مزخرفة أخرى في الداخل.
Color badgeBackground(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byType(AppBadge),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as ShapeDecoration).color!;
}

void main() {
  group('AppBadge', () {
    testWidgets('شارة المزاد زرقاء وشارة السعر ذهبية', (tester) async {
      await tester.pumpWidget(
        host(const AppBadge(label: 'مزاد حضوري', kind: AppBadgeKind.auction)),
      );
      expect(find.text('مزاد حضوري'), findsOneWidget);
      expect(badgeBackground(tester), AppColors.light.tintBlue);

      await tester.pumpWidget(
        host(const AppBadge(label: 'سعر محدد', kind: AppBadgeKind.fixedPrice)),
      );
      expect(badgeBackground(tester), AppColors.light.tintGold);
    });

    testWidgets('تتبع ألوان الوضع الداكن', (tester) async {
      await tester.pumpWidget(
        host(
          const AppBadge(label: 'منشور', kind: AppBadgeKind.success),
          theme: AppTheme.dark,
        ),
      );
      expect(badgeBackground(tester), AppColors.dark.tintGreen);
    });

    testWidgets('نص طويل في عرض ضيق لا يتجاوز حدوده', (tester) async {
      await tester.pumpWidget(
        host(
          const AppBadge(
            label: 'حالة طويلة جدًا لا تتسع لها المساحة المتاحة في السطر',
            kind: AppBadgeKind.pending,
          ),
          width: 120,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('SectionTitle يعرض الحلقة والعنوان كترويسة والإجراء', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      host(
        SectionTitle(
          'مزادات قريبة',
          trailing: TextButton(
            onPressed: () => tapped = true,
            child: const Text('عرض الكل'),
          ),
        ),
      ),
    );

    expect(find.byType(WasmRing), findsOneWidget);
    expect(
      tester.getSemantics(find.text('مزادات قريبة')),
      matchesSemantics(label: 'مزادات قريبة', isHeader: true),
    );
    await tester.tap(find.text('عرض الكل'));
    expect(tapped, isTrue);
  });

  testWidgets('AppNote يعرض الرسالة بلون نوعها', (tester) async {
    await tester.pumpWidget(
      host(const AppNote('تعذر حفظ الإعلان', kind: AppNoteKind.error)),
    );
    expect(find.text('تعذر حفظ الإعلان'), findsOneWidget);
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(AppNote),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((box.decoration as BoxDecoration).color, AppColors.light.tintRed);
  });

  group('EmptyState', () {
    testWidgets('يعرض العنوان والوصف وينفذ الإجراء', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        host(
          EmptyState(
            icon: Icons.wifi_off,
            title: 'لا يوجد اتصال',
            message: 'تحقق من الشبكة ثم أعد المحاولة.',
            actionLabel: 'إعادة المحاولة',
            onAction: () => retried++,
          ),
        ),
      );

      expect(find.text('لا يوجد اتصال'), findsOneWidget);
      expect(find.text('تحقق من الشبكة ثم أعد المحاولة.'), findsOneWidget);
      await tester.tap(find.text('إعادة المحاولة'));
      expect(retried, 1);
    });

    testWidgets('دون إجراء لا يظهر زر', (tester) async {
      await tester.pumpWidget(
        host(const EmptyState(icon: Icons.inbox, title: 'لا إعلانات بعد')),
      );
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('لا يتجاوز حدوده في شاشة قصيرة مع تكبير النص', (tester) async {
      tester.view.physicalSize = const Size(320, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: EmptyState(
                  icon: Icons.wifi_off,
                  title: 'لا يوجد اتصال بالإنترنت حاليًا',
                  message:
                      'تحقق من اتصال الشبكة أو بيانات الجوال ثم أعد المحاولة.',
                  actionLabel: 'إعادة المحاولة',
                  onAction: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
