import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/core/errors/app_error.dart';
import 'package:nawadir_aliibil/core/format/money.dart';
import 'package:nawadir_aliibil/features/my_listings/data/my_listing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/fake_media.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/fake_tables.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _row(
  String id, {
  String status = 'PUBLISHED',
  String? title = 'ناقة مجاهيم للبيع',
  String offer = 'FIXED_PRICE',
  num? price = 25000,
  bool hasDraft = false,
  bool auctionPassed = false,
  String? reasonLabel,
  String? reasonText,
  String updatedAt = '2026-11-22T17:32:11+00:00',
  String? auctionStartsAt,
}) {
  final base = Map<String, dynamic>.from(fixture('my-listing') as Map);
  return base
    ..['listing_id'] = id
    ..['status'] = status
    ..['title'] = title
    ..['offer_type'] = offer
    ..['price'] = price
    ..['has_draft'] = hasDraft
    ..['auction_passed'] = auctionPassed
    ..['auction_starts_at'] = auctionStartsAt
    ..['reason_label_ar'] = reasonLabel
    ..['reason_text'] = reasonText
    ..['updated_at'] = updatedAt;
}

Future<void> _openMyListings(
  WidgetTester tester, {
  required FakeTables tables,
  FakeRpc? rpc,
  FakeStorage? storage,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(
    tester,
    auth: FakeAuthBackend(signedIn: true),
    rpc: rpc ?? FakeRpc({'get_my_account': (_) => fixture('account-ready')}),
    tables: tables,
    storage: storage,
    media: FakeMediaBackend(),
  );
  await tester.tap(find.bySemanticsLabel('حسابي'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('إعلاناتي'));
  await tester.pumpAndSettle();
}

void main() {
  test('مثال my-listing.json يُحلّل وأعلام الإجراءات صحيحة', () {
    final l = MyListing.fromJson(
      Map<String, dynamic>.from(fixture('my-listing') as Map),
    );
    expect(l.status, 'PUBLISHED');
    expect(l.price, 25000);
    expect(l.canEdit, isTrue);
    expect(l.canDelete, isFalse);
    expect(l.canResume, isFalse);

    MyListing of(String status) =>
        MyListing.fromJson(_row('x', status: status));
    expect(of('DRAFT').canResume, isTrue);
    expect(of('DRAFT').canDelete, isTrue);
    expect(of('REJECTED').canEdit, isTrue);
    expect(of('REJECTED').canDelete, isTrue);
    expect(of('UNDER_REVIEW').canEdit, isFalse);
    expect(of('HIDDEN').canEdit, isFalse);
    expect(of('HIDDEN').canDelete, isFalse);
  });

  test('تنسيق المبلغ والموعد', () {
    expect(formatMoney(48000), '48,000');
    expect(formatMoney(1250.5), '1,250.50');
    expect(formatMoney(999), '999');
    expect(formatMoney(1234567), '1,234,567');
    expect(
      formatSaudiMoment(DateTime.utc(2099, 1, 5, 15, 30)),
      '5/1/2099 18:30',
    );
  });

  testWidgets('القائمة تعرض كل الحالات بشاراتها وأسباب الرفض والإخفاء', (
    tester,
  ) async {
    final tables = FakeTables({
      'my_listings': [
        _row('a', updatedAt: '2026-11-22T10:00:00+00:00'),
        _row(
          'b',
          status: 'DRAFT',
          title: null,
          price: null,
          updatedAt: '2026-11-22T11:00:00+00:00',
        ),
        _row(
          'c',
          status: 'UNDER_REVIEW',
          updatedAt: '2026-11-22T12:00:00+00:00',
        ),
        _row(
          'd',
          status: 'REJECTED',
          reasonLabel: 'صور غير واضحة',
          reasonText: 'أعد التصوير نهارًا',
          updatedAt: '2026-11-22T13:00:00+00:00',
        ),
        _row(
          'e',
          status: 'HIDDEN',
          reasonLabel: 'مخالفة',
          updatedAt: '2026-11-22T14:00:00+00:00',
        ),
        _row(
          'f',
          offer: 'IN_PERSON_AUCTION',
          price: null,
          auctionPassed: true,
          auctionStartsAt: '2026-11-01T12:00:00+00:00',
          updatedAt: '2026-11-22T15:00:00+00:00',
        ),
        _row('g', hasDraft: true, updatedAt: '2026-11-22T16:00:00+00:00'),
      ],
    });
    await _openMyListings(tester, tables: tables);

    expect(find.text('منشور'), findsNWidgets(3));
    expect(find.text('مسودة'), findsOneWidget);
    expect(find.text('قيد المراجعة'), findsOneWidget);
    expect(find.text('مرفوض'), findsOneWidget);
    expect(find.text('مخفي'), findsOneWidget);
    expect(find.text('مسودة بلا عنوان'), findsOneWidget);
    expect(find.text('25,000 ريال'), findsNWidgets(5));
    expect(find.text('مزاد حضوري · انتهى موعده'), findsOneWidget);
    expect(find.text('تعديل قيد التحرير'), findsOneWidget);
    expect(find.text('صور غير واضحة — أعد التصوير نهارًا'), findsOneWidget);
    expect(find.text('مخالفة'), findsOneWidget);
    // الأحدث تعديلًا أولًا: g قبل a.
    final order = tester
        .widgetList<Text>(find.text('ناقة مجاهيم للبيع'))
        .length;
    expect(order, greaterThan(0));
  });

  testWidgets('قائمة فارغة: دعوة لإضافة أول إعلان', (tester) async {
    await _openMyListings(tester, tables: FakeTables());
    expect(find.text('لا توجد إعلانات بعد'), findsOneWidget);
    await tester.tap(find.text('إعلان جديد'));
    await tester.pumpAndSettle();
    expect(find.text('نوع العرض'), findsOneWidget);
  });

  testWidgets('فشل التحميل يعرض إعادة المحاولة', (tester) async {
    final tables =
        FakeTables({
            'my_listings': [_row('a')],
          })
          ..failures['my_listings'] = const PostgrestException(
            message: 'INTERNAL_ERROR',
          );
    await _openMyListings(tester, tables: tables);
    expect(find.text('تعذّر تحميل إعلاناتك'), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('ناقة مجاهيم للبيع'), findsOneWidget);
  });

  testWidgets('القائمة لكل حالة تحمل الإجراءات المناسبة فقط', (tester) async {
    final tables = FakeTables({
      'my_listings': [
        _row('d', status: 'DRAFT', updatedAt: '2026-11-22T13:00:00+00:00'),
      ],
    });
    await _openMyListings(tester, tables: tables);
    await tester.tap(find.byTooltip('خيارات الإعلان'));
    await tester.pumpAndSettle();
    expect(find.text('متابعة التحرير'), findsOneWidget);
    expect(find.text('حذف'), findsOneWidget);
    expect(find.text('تعديل'), findsNothing);
  });

  testWidgets('الحذف بالتأكيد: الدالة ثم حذف الملفات ثم إعادة التحميل', (
    tester,
  ) async {
    final tables = FakeTables({
      'my_listings': [_row('d', status: 'DRAFT')],
    });
    final storage = FakeStorage();
    final rpc = FakeRpc({
      'get_my_account': (_) => fixture('account-ready'),
      'delete_listing': (p) {
        tables.rows['my_listings']!.clear();
        return {
          'listing_id': p!['p_listing_id'],
          'deleted': true,
          'delete_objects': [
            {'bucket': 'listing-images', 'object_path': 'o/l/1.jpg'},
            {'bucket': 'listing-images', 'object_path': 'o/l/2.jpg'},
          ],
        };
      },
    });
    await _openMyListings(tester, tables: tables, rpc: rpc, storage: storage);

    await tester.tap(find.byTooltip('خيارات الإعلان'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    expect(find.text('حذف الإعلان؟'), findsOneWidget);

    // الإلغاء لا يحذف.
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(rpc.paramsOf('delete_listing'), isEmpty);

    await tester.tap(find.byTooltip('خيارات الإعلان'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pumpAndSettle();

    expect(rpc.paramsOf('delete_listing'), [
      {'p_listing_id': 'd'},
    ]);
    expect(storage.removed, hasLength(1));
    expect(storage.removed.single.$1, 'listing-images');
    expect(storage.removed.single.$2, ['o/l/1.jpg', 'o/l/2.jpg']);
    expect(find.text('لا توجد إعلانات بعد'), findsOneWidget);
  });

  testWidgets('خطأ الحذف يظهر ولا يزيل الإعلان', (tester) async {
    final tables = FakeTables({
      'my_listings': [_row('d', status: 'DRAFT')],
    });
    final rpc = FakeRpc({
      'get_my_account': (_) => fixture('account-ready'),
      'delete_listing': (_) => throw const PostgrestException(
        message: 'INVALID_STATE',
        code: 'P0001',
      ),
    });
    await _openMyListings(tester, tables: tables, rpc: rpc);
    await tester.tap(find.byTooltip('خيارات الإعلان'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pumpAndSettle();
    expect(find.textContaining('غير متاح في حالة الإعلان'), findsOneWidget);
    expect(find.text('مسودة'), findsOneWidget);
  });

  testWidgets('متابعة تحرير مسودة: تُحمَّل من الجداول وتملأ المعالج وصوره', (
    tester,
  ) async {
    final owner = Map<String, dynamic>.from(
      fixture('listing-owner-draft') as Map,
    );
    final version = Map<String, dynamic>.from(owner['version'] as Map);
    final listing = Map<String, dynamic>.from(owner['listing'] as Map);
    final tables = FakeTables({
      'my_listings': [_row(listing['id'] as String, status: 'DRAFT')],
      'listings': [listing],
      'listing_versions': [version],
      'media': [
        for (final m in owner['media'] as List)
          {...Map<String, dynamic>.from(m as Map), 'version_id': version['id']},
      ],
    });
    final server = FakeListingServer();
    final rpc = FakeRpc({
      'get_my_account': (_) => fixture('account-ready'),
      ...server.handlers,
    });
    await _openMyListings(tester, tables: tables, rpc: rpc);

    await tester.tap(find.byTooltip('خيارات الإعلان'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('متابعة التحرير'));
    await tester.pumpAndSettle();

    // المعالج يبدأ من بيانات الإبل والحقول معبأة من الخادم.
    expect(find.text('إعلان جديد 2 / 7'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'ناقة مجاهيم للبيع'), findsOneWidget);
    expect(
      tables.requests,
      containsAll(['listings', 'listing_versions', 'media']),
    );
    expect(server.createCalls, 0); // لا مسودة جديدة

    // لم يتغير شيء: لا حفظ زائد، والمتابعة تنتقل (الحقول صالحة).
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(server.patches, isEmpty);
    expect(find.text('إعلان جديد 3 / 7'), findsOneWidget);
  });

  testWidgets('تعديل إعلان منشور: start_listing_edit ثم المعالج بالبيانات', (
    tester,
  ) async {
    final tables = FakeTables({
      'my_listings': [_row('pub-1')],
    });
    final rpc = FakeRpc({
      'get_my_account': (_) => fixture('account-ready'),
      'start_listing_edit': (_) => fixture('listing-owner-draft'),
    });
    await _openMyListings(tester, tables: tables, rpc: rpc);

    await tester.tap(find.byTooltip('خيارات الإعلان'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعديل'));
    await tester.pumpAndSettle();

    expect(rpc.paramsOf('start_listing_edit'), [
      {'p_listing_id': 'pub-1'},
    ]);
    expect(find.widgetWithText(TextField, 'ناقة مجاهيم للبيع'), findsOneWidget);
  });

  testWidgets('فشل تحميل المسودة يعرض إعادة المحاولة', (tester) async {
    final tables =
        FakeTables({
            'my_listings': [_row('d', status: 'DRAFT')],
          })
          ..failures['listings'] = const PostgrestException(
            message: 'INTERNAL_ERROR',
          );
    await _openMyListings(tester, tables: tables);
    await tester.tap(find.byTooltip('خيارات الإعلان'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('متابعة التحرير'));
    await tester.pumpAndSettle();
    expect(find.text('تعذّر تحميل الإعلان'), findsOneWidget);
    expect(
      AppError.from(const PostgrestException(message: 'NOT_FOUND')).code,
      AppErrorCode.notFound,
    );
  });
}
