import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/features/browse/presentation/listing_card_tile.dart';

import '../../helpers/fake_rpc.dart';
import '../../helpers/fake_tables.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _fav(int n, {bool available = true}) {
  final base = Map<String, dynamic>.from(fixture('my-favorite') as Map);
  if (!available) {
    for (final k in base.keys.toList()) {
      if (k != 'listing_id' && k != 'saved_at') base[k] = null;
    }
    base['available'] = false;
  }
  return base
    ..['listing_id'] = 'listing-$n'
    ..['saved_at'] = '2026-11-22T20:0$n:00+00:00';
}

Future<void> _open(WidgetTester tester, List<Map<String, dynamic>> rows) async {
  tester.view.physicalSize = const Size(320, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpApp(tester, tables: FakeTables({'my_favorites': rows}));
  await tester.tap(find.text('المفضلة').last);
  await tester.pumpAndSettle();
}

bool _compact(WidgetTester tester) => tester
    .widgetList<ListingCardTile>(find.byType(ListingCardTile))
    .every((t) => t.compact);

void main() {
  testWidgets('مبدّل العرض: كبير افتراضيًا ثم مدمج بعمودين ثم عودة', (
    tester,
  ) async {
    await _open(tester, [_fav(1), _fav(2), _fav(3)]);
    expect(find.byType(ListingCardTile), findsNWidgets(3));
    expect(_compact(tester), isFalse);

    await tester.tap(find.byKey(const ValueKey('favorites-view-compact')));
    await tester.pumpAndSettle();
    expect(_compact(tester), isTrue);
    // بطاقتان متجاورتان في الصف الأول.
    final tiles = find.byType(ListingCardTile);
    expect(
      tester.getTopLeft(tiles.at(0)).dy,
      tester.getTopLeft(tiles.at(1)).dy,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('favorites-view-large')));
    await tester.pumpAndSettle();
    expect(_compact(tester), isFalse);
  });

  testWidgets(
    'المدمج: «غير متاح» يبقى صفًا كاملًا ويُزال، بلا فيض عند 320 ×2',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await _open(tester, [_fav(1), _fav(2, available: false), _fav(3)]);
      await tester.tap(find.byKey(const ValueKey('favorites-view-compact')));
      await tester.pumpAndSettle();
      expect(find.text('الإعلان غير متاح'), findsOneWidget);
      expect(find.text('إزالة'), findsOneWidget);
      expect(find.byType(ListingCardTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
