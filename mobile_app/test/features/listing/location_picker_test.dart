import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nawadir_aliibil/app/theme/app_theme.dart';
import 'package:nawadir_aliibil/core/location/location_service.dart';
import 'package:nawadir_aliibil/features/listing/presentation/location_picker_screen.dart';

/// يفتح الشاشة من صفحة سابقة ليُلتقط ما تعيده عند التأكيد.
Future<void> _open(
  WidgetTester tester, {
  required DeviceLocator locator,
  LatLng? initial,
  required void Function(LatLng?) onResult,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [deviceLocatorProvider.overrideWithValue(locator)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => onResult(
                await Navigator.of(context).push<LatLng>(
                  MaterialPageRoute(
                    builder: (_) => LocationPickerScreen(initial: initial),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  const saved = LatLng(24.7, 46.7);
  const mine = LatLng(21.5, 39.2);

  testWidgets('تأكيد الموقع يعيد النقطة الأولية دون تحريك', (tester) async {
    LatLng? result;
    await _open(
      tester,
      locator: ({askPermission = true}) async => null,
      initial: saved,
      onResult: (v) => result = v,
    );
    await tester.tap(find.byKey(const ValueKey('confirm-location')));
    await tester.pumpAndSettle();
    expect(result?.latitude, closeTo(saved.latitude, 1e-6));
    expect(result?.longitude, closeTo(saved.longitude, 1e-6));
    expect(find.byType(LocationPickerScreen), findsNothing);
  });

  testWidgets('زر موقعي الحالي ينقل الدبوس ثم يؤكد الموقع الجديد', (
    tester,
  ) async {
    LatLng? result;
    var calls = 0;
    await _open(
      tester,
      locator: ({askPermission = true}) async {
        calls++;
        return mine;
      },
      initial: saved,
      onResult: (v) => result = v,
    );
    await tester.tap(find.byKey(const ValueKey('use-my-location')));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.tap(find.byKey(const ValueKey('confirm-location')));
    await tester.pumpAndSettle();
    expect(result?.latitude, closeTo(mine.latitude, 1e-6));
    expect(result?.longitude, closeTo(mine.longitude, 1e-6));
  });

  testWidgets('تعذر تحديد الموقع: رسالة وتبقى النقطة كما هي', (tester) async {
    LatLng? result;
    await _open(
      tester,
      locator: ({askPermission = true}) async => null,
      initial: saved,
      onResult: (v) => result = v,
    );
    await tester.tap(find.byKey(const ValueKey('use-my-location')));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('تعذر تحديد موقعك'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-location')));
    await tester.pumpAndSettle();
    expect(result?.latitude, closeTo(saved.latitude, 1e-6));
  });

  testWidgets('بلا موقع محفوظ: يبدأ بموقع الجهاز تلقائيًا', (tester) async {
    LatLng? result;
    await _open(
      tester,
      locator: ({askPermission = true}) async => mine,
      onResult: (v) => result = v,
    );
    await tester.tap(find.byKey(const ValueKey('confirm-location')));
    await tester.pumpAndSettle();
    expect(result?.latitude, closeTo(mine.latitude, 1e-6));
  });
}
