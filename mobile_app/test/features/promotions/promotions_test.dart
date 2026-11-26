import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/features/browse/presentation/listing_card_tile.dart';
import 'package:nawadir_aliibil/features/browse/presentation/listing_detail_screen.dart';
import 'package:nawadir_aliibil/features/promotions/data/promotion.dart';
import 'package:nawadir_aliibil/features/promotions/domain/feed_layout.dart';
import 'package:nawadir_aliibil/features/promotions/presentation/promotion_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_rpc.dart';
import '../../helpers/pump_app.dart';

/// بطاقات بحث من مثال العقد بعناوين مرقمة.
Map<String, dynamic> _card(int n) {
  final base = Map<String, dynamic>.from(
    (fixture('search-result') as Map)['items'][0] as Map,
  );
  return base
    ..['listing_id'] = 'listing-$n'
    ..['title'] = 'إعلان رقم $n للإبل'
    ..['offer_type'] = 'FIXED_PRICE'
    ..['auction_starts_at'] = null;
}

Map<String, RpcHandler> _handlers({
  int listings = 10,
  RpcHandler? promotions,
}) => {
  'search_listings': (_) => {
    'items': [for (var i = 0; i < listings; i++) _card(i)],
    'next_cursor': null,
  },
  'list_active_promotions': promotions ?? (_) => fixture('active-promotions'),
};

Finder get _list => find.byType(CustomScrollView).first;

/// يمرر القائمة حتى تظهر البطاقة [finder].
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(finder, _list, const Offset(0, -250));
  await tester.pumpAndSettle();
}

void main() {
  group('ترتيب القائمة', () {
    test('دعاية بعد كل N إعلانًا بالتدوير، ولا دعاية قبل أول N', () {
      expect(buildFeed(listingCount: 5, promotionCount: 2, interval: 2), const [
        ListingEntry(0),
        ListingEntry(1),
        PromotionEntry(0),
        ListingEntry(2),
        ListingEntry(3),
        PromotionEntry(1),
        ListingEntry(4),
      ]);
      expect(buildFeed(listingCount: 7, promotionCount: 1, interval: 8), [
        for (var i = 0; i < 7; i++) ListingEntry(i),
      ], reason: 'قائمة أقصر من N بلا دعايات');
      expect(buildFeed(listingCount: 9, promotionCount: 0, interval: 4), [
        for (var i = 0; i < 9; i++) ListingEntry(i),
      ]);
      // التدوير: الموضع الثالث يعود إلى الدعاية الأولى.
      final rotated = buildFeed(
        listingCount: 12,
        promotionCount: 2,
        interval: 4,
      );
      expect(rotated.whereType<PromotionEntry>().map((e) => e.index), [
        0,
        1,
        0,
      ]);
    });
  });

  group('العقد', () {
    test('يقرأ مثال active-promotions ويبني روابط الإجراءات', () {
      final active = ActivePromotions.fromJson(
        Map<String, dynamic>.from(fixture('active-promotions') as Map),
      );
      expect(active.enabled, isTrue);
      expect(active.feedInterval, 8);
      expect(active.items, hasLength(2));
      final url = active.items[0];
      expect(url.action, PromotionAction.url);
      expect(url.actionUri.toString(), 'https://example.com/offers/camel-feed');
      expect(url.actionLabel, 'زيارة الموقع');
      final wa = active.items[1];
      expect(wa.action, PromotionAction.whatsapp);
      expect(wa.actionUri.toString(), 'https://wa.me/966551234567');
      expect(wa.body, isNull);
    });

    test('روابط غير آمنة أو إجراء «عرض فقط» بلا زر', () {
      Promotion p(PromotionAction a, String? v) => Promotion(
        id: 'x',
        title: 't',
        advertiserName: 'a',
        imagePath: 'p',
        action: a,
        actionValue: v,
      );
      expect(p(PromotionAction.url, 'http://example.com').actionUri, isNull);
      expect(p(PromotionAction.url, 'javascript:alert(1)').actionUri, isNull);
      expect(
        p(PromotionAction.call, '+966551234567').actionUri.toString(),
        'tel:+966551234567',
      );
      expect(p(PromotionAction.none, null).actionUri, isNull);
      expect(p(PromotionAction.none, null).actionLabel, isNull);
    });
  });

  group('الرئيسية', () {
    testWidgets('الدعاية تظهر بعد الإعلان الثامن بشارة «إعلان ممول»', (
      tester,
    ) async {
      final rpc = FakeRpc(_handlers());
      await pumpApp(tester, rpc: rpc);

      expect(rpc.paramsOf('list_active_promotions').first, {
        'p_placement': 'HOME_FEED',
      });
      final promo = find.byKey(const ValueKey('promotion-slot-8'));
      await _scrollTo(tester, promo);
      expect(
        find.descendant(of: promo, matching: find.text('إعلان ممول')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: promo,
          matching: find.text('أعلاف الصحراء — خصم 15٪'),
        ),
        findsOneWidget,
      );
      // بين الإعلانين الثامن والتاسع.
      final y = tester.getTopLeft(promo).dy;
      expect(tester.getTopLeft(find.text('إعلان رقم 7 للإبل')).dy, lessThan(y));
      expect(
        tester.getTopLeft(find.text('إعلان رقم 8 للإبل')).dy,
        greaterThan(y),
      );
      // دعاية واحدة لعشرة إعلانات بفاصل 8.
      expect(find.byType(PromotionCard), findsOneWidget);
    });

    testWidgets('الضغط يسجل نقرًا ويفتح الرابط، والظهور يسجل مرة واحدة', (
      tester,
    ) async {
      final launched = <Uri>[];
      final rpc = FakeRpc(_handlers());
      await pumpApp(
        tester,
        rpc: rpc,
        extraOverrides: [
          externalLauncherProvider.overrideWithValue((u) async {
            launched.add(u);
            return true;
          }),
        ],
      );
      final promo = find.byKey(const ValueKey('promotion-slot-8'));
      await _scrollTo(tester, promo);
      await tester.pump(promotionImpressionDelay);
      await tester.pumpAndSettle();

      final id = (fixture('active-promotions') as Map)['items'][0]['id'];
      final events = rpc.paramsOf('record_promotion_event').toList();
      expect(events, hasLength(1));
      expect(events.single!['p_promotion_id'], id);
      expect(events.single!['p_kind'], 'IMPRESSION');
      expect(events.single!['p_device_id'], isA<String>());

      await tester.tap(
        find.descendant(of: promo, matching: find.text('زيارة الموقع')),
      );
      await tester.pumpAndSettle();
      expect(
        launched.single.toString(),
        'https://example.com/offers/camel-feed',
      );
      expect(rpc.paramsOf('record_promotion_event').map((p) => p!['p_kind']), [
        'IMPRESSION',
        'CLICK',
      ]);

      // إعادة بناء البطاقة لا تكرر الظهور في الجلسة نفسها.
      await tester.drag(_list, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await _scrollTo(tester, promo);
      await tester.pump(promotionImpressionDelay);
      await tester.pumpAndSettle();
      expect(
        rpc
            .paramsOf('record_promotion_event')
            .where((p) => p!['p_kind'] == 'IMPRESSION'),
        hasLength(1),
      );
    });

    testWidgets('فشل جلب الدعايات لا يعطل القائمة ولا يظهر خطأ', (
      tester,
    ) async {
      await pumpApp(
        tester,
        rpc: FakeRpc(
          _handlers(
            promotions: (_) =>
                throw const PostgrestException(message: 'INTERNAL_ERROR'),
          ),
        ),
      );
      await _scrollTo(tester, find.text('إعلان رقم 9 للإبل'));
      expect(find.byType(PromotionCard), findsNothing);
      expect(find.byType(ListingCardTile), findsWidgets);
      expect(find.textContaining('تعذّر'), findsNothing);
    });

    testWidgets('الإطفاء من اللوحة يخفي الدعايات', (tester) async {
      await pumpApp(
        tester,
        rpc: FakeRpc(
          _handlers(
            promotions: (_) => {
              ...(fixture('active-promotions') as Map),
              'enabled': false,
              'items': <dynamic>[],
            },
          ),
        ),
      );
      await _scrollTo(tester, find.text('إعلان رقم 9 للإبل'));
      expect(find.byType(PromotionCard), findsNothing);
    });

    testWidgets('العرض المدمج: الدعاية صف كامل بعد ثمانية إعلانات', (
      tester,
    ) async {
      await pumpApp(tester, rpc: FakeRpc(_handlers()));
      await tester.tap(find.byTooltip('عرض مدمج'));
      await tester.pumpAndSettle();

      final promo = find.byKey(const ValueKey('promotion-slot-4'));
      await _scrollTo(tester, promo);
      final card = tester.widget<PromotionCard>(promo);
      expect(card.compact, isTrue);
      // بعرض الصف: أعرض من بطاقة إعلان مدمجة.
      expect(
        tester.getSize(promo).width,
        greaterThan(tester.getSize(find.byType(ListingCardTile).first).width),
      );
    });

    testWidgets('اختيار منطقة يمرر الاستهداف ويبقى في دعايات الرئيسية', (
      tester,
    ) async {
      final rpc = FakeRpc(_handlers());
      await pumpApp(tester, rpc: rpc);
      await tester.tap(find.byKey(const ValueKey('home-region')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الرياض').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('region-apply')));
      await tester.pumpAndSettle();

      expect(rpc.paramsOf('list_active_promotions').last, {
        'p_placement': 'HOME_FEED',
        'p_region_id': 1,
      });
    });
  });
}
