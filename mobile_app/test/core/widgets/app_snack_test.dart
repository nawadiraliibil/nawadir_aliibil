import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/app/theme/app_theme.dart';
import 'package:nawadir_aliibil/core/widgets/app_note.dart';
import 'package:nawadir_aliibil/core/widgets/app_snack.dart';

Future<void> _show(WidgetTester tester, String text, AppNoteKind kind) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).showApp(text, kind: kind),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
}

void main() {
  testWidgets('النجاح بأيقونة تأكيد', (tester) async {
    await _show(tester, 'تم الحفظ.', AppNoteKind.success);
    expect(find.text('تم الحفظ.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('الفشل بأيقونة خطأ ورسالة جديدة تستبدل السابقة', (tester) async {
    await _show(tester, 'تم الحفظ.', AppNoteKind.success);
    await tester.tap(find.text('go'));
    await tester.pump();
    await _show(tester, 'تعذّر الحفظ.', AppNoteKind.error);
    expect(find.text('تعذّر الحفظ.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
