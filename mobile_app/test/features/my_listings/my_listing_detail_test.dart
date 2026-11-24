import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/core/widgets/app_badge.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/fake_media.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/fake_tables.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _row(
  String id, {
  String status = 'PUBLISHED',
  String? reasonLabel,
  String? reasonText,
  bool hasDraft = false,
  String? nextBumpAt,
}) {
  final base = Map<String, dynamic>.from(fixture('my-listing') as Map);
  return base
    ..['listing_id'] = id
    ..['status'] = status
    ..['title'] = 'ناقة وضح أصيلة'
    ..['has_draft'] = hasDraft
    ..['reason_label_ar'] = reasonLabel
    ..['reason_text'] = reasonText
    ..['next_bump_at'] = nextBumpAt;
}

Future<void> _open(
  WidgetTester tester,
  Map<String, dynamic> row, {
  FakeRpc? rpc,
  double scale = 1,
  Size size = const Size(800, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await pumpApp(
    tester,
    auth: FakeAuthBackend(signedIn: true),
    rpc: rpc ?? FakeRpc({'get_my_account': (_) => fixture('account-ready')}),
    tables: FakeTables({
      'my_listings': [row],
    }),
    media: FakeMediaBackend(),
  );
  await tester.tap(find.bySemanticsLabel('حسابي'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('إعلاناتي'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ناقة وضح أصيلة'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('مرفوض: الشارة والسبب وزر التصحيح وزر إعلاناتي', (tester) async {
    await _open(
      tester,
      _row('r', status: 'REJECTED', reasonLabel: 'صور غير واضحة'),
    );
    expect(find.text('إعلان مرفوض'), findsOneWidget);
    expect(find.widgetWithText(AppBadge, 'مرفوض'), findsOneWidget);
    expect(find.text('صور غير واضحة'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'تصحيح الإعلان'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'إعلاناتي'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ChoiceChip, 'الكل'), findsOneWidget);
  });

  testWidgets('تصحيح المرفوض يستدعي start_listing_edit', (tester) async {
    final rpc = FakeRpc({
      'get_my_account': (_) => fixture('account-ready'),
      'start_listing_edit': (_) => fixture('listing-owner-draft'),
    });
    await _open(tester, _row('r', status: 'REJECTED'), rpc: rpc);
    await tester.tap(find.text('تصحيح الإعلان'));
    await tester.pumpAndSettle();
    expect(rpc.paramsOf('start_listing_edit'), [
      {'p_listing_id': 'r'},
    ]);
  });

  testWidgets('منشور: عرض وتعديل وتجديد معلوماتي', (tester) async {
    await _open(tester, _row('p'));
    expect(find.text('إعلان منشور'), findsOneWidget);
    expect(find.text('عرض الإعلان'), findsOneWidget);
    expect(find.text('تعديل'), findsOneWidget);
    expect(find.text('تجديد الظهور'), findsOneWidget);
    expect(find.text('إيقاف الإعلان وأرشفته'), findsOneWidget);
    expect(find.text('حذف'), findsNothing);
  });

  testWidgets('منشور: التجديد يستدعي bump_listing', (tester) async {
    final calls = <String>[];
    final rpc = FakeRpc({
      'get_my_account': (_) => fixture('account-ready'),
      'bump_listing': (p) {
        calls.add(p!['p_listing_id'] as String);
        return {'listing_id': p['p_listing_id']};
      },
    });
    await _open(tester, _row('p'), rpc: rpc);
    await tester.tap(find.text('تجديد الظهور'));
    await tester.pumpAndSettle();
    expect(calls, ['p']);
    expect(find.text('جُدد ظهور إعلانك.'), findsOneWidget);
  });

  testWidgets('منشور: الأرشفة بتأكيد تستدعي archive_listing، والإلغاء لا', (
    tester,
  ) async {
    final calls = <String>[];
    final rpc = FakeRpc({
      'get_my_account': (_) => fixture('account-ready'),
      'archive_listing': (p) {
        calls.add(p!['p_listing_id'] as String);
        return {'listing_id': p['p_listing_id']};
      },
    });
    await _open(tester, _row('p'), rpc: rpc);

    await tester.tap(find.text('إيقاف الإعلان وأرشفته'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.tap(find.text('إيقاف الإعلان وأرشفته'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('archive-confirm')));
    await tester.pumpAndSettle();
    expect(calls, ['p']);
    expect(find.text('أُرشف الإعلان.'), findsOneWidget);
  });

  testWidgets('منشور: موعد التجديد القادم يظهر', (tester) async {
    await _open(tester, _row('p', nextBumpAt: '2099-01-05T15:30:00+00:00'));
    expect(find.textContaining('يتاح 5/1/2099 6:30 م'), findsOneWidget);
  });

  testWidgets('مؤرشف: ملاحظة وتعديل', (tester) async {
    await _open(tester, _row('a', status: 'ARCHIVED'));
    expect(find.text('إعلان مؤرشف'), findsOneWidget);
    expect(find.textContaining('الإعلان مؤرشف'), findsOneWidget);
    expect(find.text('تعديل'), findsOneWidget);
  });

  testWidgets('مخفي إداريًا: السبب وبلا إعادة نشر', (tester) async {
    await _open(tester, _row('h', status: 'HIDDEN', reasonLabel: 'مخالفة'));
    expect(find.text('إعلان مخفي'), findsOneWidget);
    expect(find.text('مخالفة'), findsOneWidget);
    expect(find.textContaining('أخفته الإدارة عن الجمهور'), findsOneWidget);
    expect(find.text('تعديل'), findsNothing);
  });

  testWidgets('مسودة: متابعة وحذف يعيد للقائمة', (tester) async {
    final rpc = FakeRpc({
      'get_my_account': (_) => fixture('account-ready'),
      'delete_listing': (p) => {
        'listing_id': p!['p_listing_id'],
        'deleted': true,
        'delete_objects': <Map<String, dynamic>>[],
      },
    });
    await _open(tester, _row('d', status: 'DRAFT'), rpc: rpc);
    expect(find.text('متابعة التحرير'), findsOneWidget);
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pumpAndSettle();
    expect(rpc.paramsOf('delete_listing'), [
      {'p_listing_id': 'd'},
    ]);
  });

  for (final status in ['REJECTED', 'PUBLISHED', 'HIDDEN']) {
    testWidgets('لا فيض عند 320 وتكبير ×2 ($status)', (tester) async {
      await _open(
        tester,
        _row(
          'x',
          status: status,
          reasonLabel: 'سبب طويل جدًا لاختبار التفاف النص في الشاشة الضيقة',
          hasDraft: status == 'PUBLISHED',
        ),
        scale: 2,
        size: const Size(320, 700),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
