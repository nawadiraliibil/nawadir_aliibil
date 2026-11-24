import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nawadir_aliibil/core/location/location_service.dart';
import 'package:nawadir_aliibil/features/browse/data/listing_card.dart';
import 'package:nawadir_aliibil/features/browse/data/listing_detail.dart';
import 'package:nawadir_aliibil/features/browse/presentation/listing_detail_screen.dart';
import 'package:nawadir_aliibil/features/browse/presentation/listing_stats.dart';

import '../../helpers/fake_rpc.dart';
import '../../helpers/pump_app.dart';

// الرياض (وسط) وموقع مزاد يبعد نحو 5.6 كم عنها.
const _here = LatLng(24.7136, 46.6753);
const _auctionLat = 24.7136;
const _auctionLng = 46.7253;

Map<String, dynamic> _auctionCard() {
  final base = Map<String, dynamic>.from(
    (fixture('search-result') as Map)['items'][0] as Map,
  );
  return base
    ..['title'] = 'مزاد ركاب مفتوح'
    ..['offer_type'] = 'IN_PERSON_AUCTION'
    ..['price'] = null
    ..['auction_passed'] = false
    ..['auction_starts_at'] = '2099-01-05T15:30:00+00:00'
    ..['auction_lat'] = _auctionLat
    ..['auction_lng'] = _auctionLng
    ..['view_count'] = 1250
    ..['favorite_count'] = 7;
}

Map<String, dynamic> _auctionDetail() {
  final d = Map<String, dynamic>.from(fixture('listing-detail') as Map);
  final l = Map<String, dynamic>.from(d['listing'] as Map)
    ..['offer_type'] = 'IN_PERSON_AUCTION'
    ..['price'] = null
    ..['auction_passed'] = false
    ..['auction_starts_at'] = '2099-01-05T15:30:00+00:00'
    ..['auction_region_name_ar'] = 'الرياض'
    ..['auction_city_name_ar'] = 'الرياض'
    ..['auction_venue'] = 'ساحة المزاد الكبرى'
    ..['auction_lat'] = _auctionLat
    ..['auction_lng'] = _auctionLng
    ..['view_count'] = 42
    ..['favorite_count'] = 7;
  return d..['listing'] = l;
}

void main() {
  group('المسافة والعدّادات', () {
    test('المسافة بين نقطتين والصياغة', () {
      expect(distanceKm(_here, _here), closeTo(0, 1e-9));
      expect(
        distanceKm(_here, const LatLng(_auctionLat, _auctionLng)),
        closeTo(5.05, 0.1),
      );
      expect(formatDistance(0.85), '850 م');
      expect(formatDistance(3.24), '3.2 كم');
      expect(formatDistance(42.4), '42 كم');
    });

    test('العدد المختصر', () {
      expect(formatCount(0), '0');
      expect(formatCount(950), '950');
      expect(formatCount(1250), '1.3K');
      expect(formatCount(2000), '2K');
      expect(formatCount(15400), '15K');
      expect(formatCount(3400000), '3.4M');
    });

    test('البطاقة والتفاصيل تحلل الحقول الجديدة وتتسامح مع غيابها', () {
      final card = ListingCard.fromJson(_auctionCard());
      expect(card.hasAuctionLocation, isTrue);
      expect(card.auctionLat, _auctionLat);
      expect(card.viewCount, 1250);
      expect(card.favoriteCount, 7);

      final old = _auctionCard()
        ..remove('auction_lat')
        ..remove('auction_lng')
        ..remove('view_count')
        ..remove('favorite_count');
      final legacy = ListingCard.fromJson(old);
      expect(legacy.hasAuctionLocation, isFalse);
      expect(legacy.viewCount, 0);

      final detail = ListingDetail.fromJson(_auctionDetail());
      expect(detail.hasAuctionLocation, isTrue);
      expect(detail.viewCount, 42);
      // تبديل الإعجاب يعدل العدد محليًا.
      expect(detail.withFavorite(!detail.isFavorite).favoriteCount, 8);
    });
  });

  group('بطاقة المزاد', () {
    late SemanticsHandle semantics;
    setUp(
      () => semantics = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics(),
    );
    tearDown(() => semantics.dispose());

    testWidgets('البعد عن المتصفح والإعجابات والمشاهدات والمشاركة', (
      tester,
    ) async {
      final shared = <(String, String)>[];
      await pumpApp(
        tester,
        deviceLocation: _here,
        rpc: FakeRpc({
          'search_listings': (_) => {
            'items': [_auctionCard()],
            'next_cursor': null,
          },
        }),
        extraOverrides: [
          shareTextProvider.overrideWithValue((text, subject) async {
            shared.add((text, subject));
          }),
        ],
      );

      expect(find.text('مزاد ركاب مفتوح'), findsWidgets);
      expect(find.textContaining('يبعد 5.1 كم عنك'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('7 إعجاب')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('1250 مشاهدة')), findsWidgets);
      expect(find.text('1.3K'), findsOneWidget);

      await tester.tap(find.byTooltip('مشاركة').first);
      await tester.pump();
      // دون نطاق مضبوط: العنوان وحده بلا رابط.
      expect(shared.single, ('مزاد ركاب مفتوح', 'مزاد ركاب مفتوح'));
    });

    testWidgets('دون إذن الموقع لا تظهر المسافة ويبقى الباقي', (tester) async {
      await pumpApp(
        tester,
        rpc: FakeRpc({
          'search_listings': (_) => {
            'items': [_auctionCard()],
            'next_cursor': null,
          },
        }),
      );
      expect(find.textContaining('يبعد'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('7 إعجاب')), findsWidgets);
    });

    testWidgets('السعر المحدد: عدّادات بلا مسافة', (tester) async {
      await pumpApp(tester, deviceLocation: _here, extraOverrides: []);
      expect(find.textContaining('يبعد'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('7 إعجاب')), findsWidgets);
    });
  });

  group('تفاصيل المزاد', () {
    late SemanticsHandle semantics;
    setUp(
      () => semantics = TestWidgetsFlutterBinding.ensureInitialized()
          .ensureSemantics(),
    );
    tearDown(() => semantics.dispose());

    testWidgets('خريطة الموقع والمسافة والعدّادات وتسجيل مشاهدة واحدة', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final opened = <Uri>[];
      final rpc = FakeRpc({
        'get_listing': (_) => _auctionDetail(),
        'search_listings': (_) => {
          'items': [_auctionCard()],
          'next_cursor': null,
        },
      });
      await pumpApp(
        tester,
        deviceLocation: _here,
        rpc: rpc,
        extraOverrides: [
          externalLauncherProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
      );
      await tester.tap(find.text('مزاد ركاب مفتوح').first);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('auction-map')), findsOneWidget);
      expect(find.textContaining('يبعد 5.1 كم عنك'), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('42 مشاهدة')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('7 إعجاب')), findsWidgets);
      expect(
        rpc.paramsOf('record_listing_view').toList(),
        hasLength(1),
        reason: 'مشاهدة واحدة لكل فتح',
      );
      // معرف الجهاز يمرر ليحسب الخادم الزائر مرة واحدة.
      expect(
        rpc.paramsOf('record_listing_view').single!['p_device_id'],
        isA<String>(),
      );

      await tester.tap(find.byKey(const ValueKey('auction-directions')));
      await tester.pumpAndSettle();
      expect(opened.single.host, 'www.google.com');
      expect(
        opened.single.queryParameters['query'],
        '$_auctionLat,$_auctionLng',
      );
    });

    testWidgets('مزاد قديم بلا إحداثيات: لا خريطة', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final d = _auctionDetail();
      (d['listing'] as Map)
        ..['auction_lat'] = null
        ..['auction_lng'] = null;
      await pumpApp(tester, rpc: FakeRpc({'get_listing': (_) => d}));
      await tester.tap(find.text('ناقة مجاهيم للبيع').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('auction-map')), findsNothing);
      expect(find.text('المزايدة حضورية خارج التطبيق.'), findsOneWidget);
    });
  });
}
