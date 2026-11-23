import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/app/theme/app_colors.dart';
import 'package:nawadir_aliibil/app/theme/app_shapes.dart';
import 'package:nawadir_aliibil/app/theme/app_theme.dart';
import 'package:nawadir_aliibil/app/theme/app_typography.dart';

/// نسبة التباين وفق WCAG 2.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('رموز الألوان تطابق ui.css', () {
    test('الوضع الفاتح', () {
      const c = AppColors.light;
      expect(c.bg, const Color(0xFFFFFFFF));
      expect(c.text, const Color(0xFF2D241B));
      expect(c.muted, const Color(0xFF76695C));
      expect(c.gold, const Color(0xFFA77434));
      expect(c.line, const Color(0xFFE8E2D8));
      expect(c.soft, const Color(0xFFF5F1EA));
      expect(c.button, const Color(0xFF2D241B));
      expect(c.info, const Color(0xFF2F6F9F));
      expect(c.error, const Color(0xFFC95D59));
    });

    test('الوضع الداكن', () {
      const c = AppColors.dark;
      expect(c.bg, const Color(0xFF111B1C));
      expect(c.surface, const Color(0xFF202D2D));
      expect(c.text, const Color(0xFFF6EEE0));
      expect(c.gold, const Color(0xFFE4BC7B));
      expect(c.button, const Color(0xFFE4BC7B));
      expect(c.buttonText, const Color(0xFF111B1C));
    });
  });

  group('السمة', () {
    for (final (name, theme, colors) in [
      ('الفاتحة', AppTheme.light, AppColors.light),
      ('الداكنة', AppTheme.dark, AppColors.dark),
    ]) {
      test('$name تحمل امتداد الألوان وخط النص', () {
        expect(theme.extension<AppColors>(), colors);
        expect(theme.scaffoldBackgroundColor, colors.bg);
        expect(theme.textTheme.bodyMedium?.fontFamily, AppTypography.body);
        expect(theme.textTheme.bodyMedium?.fontSize, 15);
        expect(
          theme.textTheme.headlineSmall?.fontFamily,
          AppTypography.display,
        );
      });

      test('$name: لا نص أصغر من الحد الأدنى', () {
        final t = theme.textTheme;
        final styles = [
          t.displaySmall,
          t.headlineSmall,
          t.titleLarge,
          t.titleMedium,
          t.titleSmall,
          t.bodyLarge,
          t.bodyMedium,
          t.bodySmall,
          t.labelLarge,
          t.labelMedium,
          t.labelSmall,
        ];
        for (final style in styles) {
          expect(
            style!.fontSize,
            greaterThanOrEqualTo(AppTypography.minFontSize),
          );
        }
      });

      test('$name: تباين النص الأساسي والثانوي والزر كافٍ للقراءة', () {
        // 4.5 حد WCAG AA للنص العادي.
        expect(contrast(colors.text, colors.bg), greaterThanOrEqualTo(4.5));
        expect(contrast(colors.muted, colors.bg), greaterThanOrEqualTo(4.5));
        expect(
          contrast(colors.buttonText, colors.button),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });

  testWidgets('الأزرار كبسولية وارتفاعها لا يقل عن هدف اللمس', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Column(
              children: [
                FilledButton(onPressed: () {}, child: const Text('متابعة')),
                FilledButton.tonal(
                  onPressed: () {},
                  child: const Text('لاحقًا'),
                ),
                TextButton(onPressed: () {}, child: const Text('تخطي')),
                IconButton(onPressed: () {}, icon: const Icon(Icons.close)),
              ],
            ),
          ),
        ),
      ),
    );

    for (final type in [FilledButton, TextButton, IconButton]) {
      for (final element in find.byType(type).evaluate()) {
        final size = element.size!;
        expect(size.height, greaterThanOrEqualTo(AppShapes.minTouchTarget));
      }
    }

    final filled = tester.widget<FilledButton>(find.byType(FilledButton).first);
    final shape =
        filled.style?.shape ?? AppTheme.light.filledButtonTheme.style!.shape;
    expect(shape!.resolve({}), isA<StadiumBorder>());
  });

  for (final (name, theme, colors) in [
    ('الفاتح', AppTheme.light, AppColors.light),
    ('الداكن', AppTheme.dark, AppColors.dark),
  ]) {
    testWidgets('الوضع $name: الزر الثانوي يختلف لونه عن الرئيسي', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                FilledButton(onPressed: () {}, child: const Text('رئيسي')),
                FilledButton.tonal(
                  onPressed: () {},
                  child: const Text('ثانوي'),
                ),
              ],
            ),
          ),
        ),
      );

      Color background(String label) {
        final material = tester.widget<Material>(
          find
              .ancestor(of: find.text(label), matching: find.byType(Material))
              .first,
        );
        return material.color!;
      }

      expect(background('رئيسي'), colors.button);
      expect(background('ثانوي'), colors.soft);
    });
  }

  testWidgets('حقل الإدخال مملوء وارتفاعه لا يقل عن هدف اللمس', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: TextField(decoration: InputDecoration(hintText: 'الاسم')),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(TextField)).height,
      greaterThanOrEqualTo(AppShapes.minTouchTarget),
    );
    final decoration = AppTheme.light.inputDecorationTheme;
    expect(decoration.filled, isTrue);
    expect(decoration.fillColor, AppColors.light.soft);
  });
}
