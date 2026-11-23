import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/core/config/env.dart';
import 'package:nawadir_aliibil/core/errors/app_error.dart';
import 'package:nawadir_aliibil/features/browse/data/listing_card.dart';
import 'package:nawadir_aliibil/features/browse/domain/labels.dart';
import 'package:nawadir_aliibil/features/browse/presentation/listing_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/fake_tables.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _card(int n) {
  final base = Map<String, dynamic>.from(
    (fixture('search-result') as Map)['items'][0] as Map,
  );
  return base
    ..['listing_id'] = 'listing-$n'
    ..['title'] = 'إعلان رقم $n للإبل';
}

/// خادم بحث مزيف: صفحات بالمؤشر، ويسجل المعاملات.
class _SearchServer {
  _SearchServer({this.pages = 1});

  final int pages;
  static const perPage = 8;
  final requests = <Map<String, dynamic>?>[];
  Object? failOnPage;

  dynamic handle(Map<String, dynamic>? p) {
    requests.add(p);
    final page = (p?['p_cursor'] as Map?)?['page'] as int? ?? 0;
    if (failOnPage == page) {
      failOnPage = null;
      throw const PostgrestException(message: 'INTERNAL_ERROR');
    }
    return {
      'items': [for (var i = 0; i < perPage; i++) _card(page * perPage + i)],
      'next_cursor': page + 1 < pages ? {'page': page + 1, 'id': 'x'} : null,
    };
  }

  Map<String, RpcHandler> get handlers => {'search_listings': handle};
}

Finder get _list => find.byType(CustomScrollView).first;

void main() {
  group('البيانات', () {
    test('العمر يقرأ بالعربية', () {
      expect(ageLabel(1), 'شهر');
      expect(ageLabel(2), 'شهران');
      expect(ageLabel(8), '8 أشهر');
      expect(ageLabel(12), 'سنة');
      expect(ageLabel(24), 'سنتان');
      expect(ageLabel(48), '4 سنوات');
      expect(ageLabel(38), '3 سنوات و2 شهران'.replaceAll('2 شهران', 'شهران'));
      expect(localPhone('+966500000009'), '0500000009');
    });

    test('المرشحات الفارغة لا ترسل، والفرز والحد يرسلان دائمًا', () {
      expect(const SearchFilters().toParams(limit: 20), {
        'p_sort': 'NEWEST_VISIBLE',
        'p_limit': 20,
      });
      final f = const SearchFilters().copyWith(
        query: '  ناقة ',
        regionId: 1,
        priceMin: 100,
        sort: SearchSort.priceAsc,
      );
      expect(f.toParams(limit: 20, cursor: {'id': 'a'}), {
        'p_query': 'ناقة',
        'p_region_id': 1,
        'p_price_min': 100,
        'p_sort': 'PRICE_ASC',
        'p_limit': 20,
        'p_cursor': {'id': 'a'},
      });
      expect(f.activeCount, 2);
      // الإفراغ الصريح يختلف عن الإبقاء.
      expect(f.copyWith(regionId: null).regionId, isNull);
      expect(f.copyWith(sort: SearchSort.priceDesc).regionId, 1);
      expect(
        const SearchFilters(regionId: 1),
        const SearchFilters(regionId: 1),
      );
    });

    test('بطاقة من مثال العقد تُحلَّل', () {
      final page = SearchPage.fromJson(
        Map<String, dynamic>.from(fixture('search-result') as Map),
      );
      expect(page.items.single.title, 'ناقة مجاهيم للبيع');
      expect(page.items.single.isAuction, isFalse);
      expect(page.nextCursor, isNull);
    });
  });

  group('الرئيسية', () {
    testWidgets('الزائر يتصفح دون دخول ويرى البطاقات', (tester) async {
      final server = _SearchServer();
      await pumpApp(
        tester,
        auth: FakeAuthBackend(signedIn: false),
        rpc: FakeRpc(server.handlers),
      );

      expect(find.text('إعلان رقم 0 للإبل'), findsOneWidget);
      expect(find.text('25,000 ريال'), findsWidgets);
      expect(server.requests.single, {
        'p_sort': 'NEWEST_VISIBLE',
        'p_limit': 20,
      });
    });

    testWidgets('لا نتائج: حالة فراغ تتيح مسح المرشحات', (tester) async {
      final rpc = FakeRpc({
        'search_listings': (p) => {'items': <dynamic>[], 'next_cursor': null},
      });
      await pumpApp(tester, rpc: rpc);
      expect(find.text('لا توجد إعلانات مطابقة'), findsOneWidget);
      // لا مرشحات مطبقة فلا زر مسح.
      expect(find.text('مسح المرشحات'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('home-search')), 'جمل');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('search_listings').last!['p_query'], 'جمل');
      expect(find.text('مسح المرشحات'), findsOneWidget);

      await tester.tap(find.text('مسح المرشحات'));
      await tester.pumpAndSettle();
      expect(
        rpc.paramsOf('search_listings').last!.containsKey('p_query'),
        isFalse,
      );
    });

    testWidgets('البحث يرسل النص مقصوصًا ويبدأ من أول النتائج', (tester) async {
      final server = _SearchServer();
      await pumpApp(tester, rpc: FakeRpc(server.handlers));
      await tester.enterText(
        find.byKey(const ValueKey('home-search')),
        '  ناقة  ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(server.requests.last!['p_query'], 'ناقة');
      expect(server.requests.last!.containsKey('p_cursor'), isFalse);
    });

    testWidgets('الدفعة التالية بالمؤشر نفسه دون تكرار', (tester) async {
      final server = _SearchServer(pages: 3);
      await pumpApp(tester, rpc: FakeRpc(server.handlers));
      expect(server.requests, hasLength(1));

      await tester.drag(_list, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(server.requests, hasLength(greaterThanOrEqualTo(2)));
      expect(server.requests[1]!['p_cursor'], {'page': 1, 'id': 'x'});

      await tester.drag(_list, const Offset(0, -6000));
      await tester.pumpAndSettle();
      await tester.drag(_list, const Offset(0, -6000));
      await tester.pumpAndSettle();
      final cursors = [for (final r in server.requests) r?['p_cursor']];
      // كل مؤشر طُلب مرة واحدة.
      expect(cursors.toSet().length, cursors.length);
      expect(cursors.last, {'page': 2, 'id': 'x'});
      // الأخيرة بلا مؤشر تالٍ فلا طلب بعدها.
      expect(server.requests, hasLength(3));
    });

    testWidgets('فشل الدفعة التالية يبقي ما عُرض ويتيح إعادة المحاولة', (
      tester,
    ) async {
      final server = _SearchServer(pages: 2)..failOnPage = 1;
      await pumpApp(tester, rpc: FakeRpc(server.handlers));

      await tester.drag(_list, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      await tester.drag(_list, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.text('إعلان رقم 7 للإبل'), findsOneWidget);

      await tester.ensureVisible(find.text('إعادة المحاولة'));
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      await tester.drag(_list, const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(find.text('إعلان رقم 15 للإبل'), findsOneWidget);
    });

    testWidgets('فشل التحميل الأول: رسالة وإعادة محاولة', (tester) async {
      var fail = true;
      final rpc = FakeRpc({
        'search_listings': (p) {
          if (fail) throw const PostgrestException(message: 'INTERNAL_ERROR');
          return {
            'items': [_card(1)],
            'next_cursor': null,
          };
        },
      });
      await pumpApp(tester, rpc: rpc);
      expect(find.text('تعذّر تحميل الإعلانات'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.text('إعلان رقم 1 للإبل'), findsOneWidget);
    });
  });

  group('المرشحات', () {
    Future<void> openSheet(WidgetTester tester) async {
      // طول يكفي لبناء كل حقول الورقة دون تمرير.
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.tap(find.byKey(const ValueKey('home-filters')));
      await tester.pumpAndSettle();
    }

    testWidgets('تطبيق النوع والجنس والفرز ونطاق العمر', (tester) async {
      final server = _SearchServer();
      await pumpApp(tester, rpc: FakeRpc(server.handlers));
      await openSheet(tester);

      await tester.tap(find.text('مزاد حضوري'));
      await tester.tap(find.text('ذكر'));
      await tester.tap(find.text('السعر: من الأقل'));
      await tester.enterText(
        find.byKey(const ValueKey('filter-age-min')),
        '12',
      );
      await tester.enterText(
        find.byKey(const ValueKey('filter-age-max')),
        '٣٦',
      );
      await tester.tap(find.text('تطبيق'));
      await tester.pumpAndSettle();

      expect(server.requests.last, {
        'p_offer_type': 'IN_PERSON_AUCTION',
        'p_sex': 'MALE',
        'p_age_min': 12,
        'p_age_max': 36,
        'p_sort': 'PRICE_ASC',
        'p_limit': 20,
      });
      // العلامة تعد المرشحات المطبقة: النوع والجنس والعمر.
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('نطاق معكوس يمنع التطبيق برسالة ولا يرسل', (tester) async {
      final server = _SearchServer();
      await pumpApp(tester, rpc: FakeRpc(server.handlers));
      await openSheet(tester);

      await tester.enterText(
        find.byKey(const ValueKey('filter-price-min')),
        '5000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('filter-price-max')),
        '100',
      );
      await tester.tap(find.text('تطبيق'));
      await tester.pumpAndSettle();

      expect(find.text('الحد الأدنى للسعر أكبر من الأعلى.'), findsOneWidget);
      expect(server.requests, hasLength(1));
    });

    testWidgets('نطاق السعر يعطل نوع «مزاد» لأنه يستبعد المزادات', (
      tester,
    ) async {
      final server = _SearchServer();
      await pumpApp(tester, rpc: FakeRpc(server.handlers));
      await openSheet(tester);

      await tester.enterText(
        find.byKey(const ValueKey('filter-price-min')),
        '1000',
      );
      await tester.pump();
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'مزاد حضوري'),
      );
      expect(chip.onSelected, isNull);
      await tester.tap(find.text('تطبيق'));
      await tester.pumpAndSettle();
      expect(server.requests.last!['p_price_min'], 1000);
    });

    testWidgets('المدينة تتبع المنطقة وتمسح بتغييرها', (tester) async {
      final server = _SearchServer();
      await pumpApp(tester, rpc: FakeRpc(server.handlers));
      await openSheet(tester);

      // دون منطقة: قائمة المدن معطلة.
      final city = tester.widget<DropdownButtonFormField<int?>>(
        find.byKey(const ValueKey('filter-city-null')),
      );
      expect(city.onChanged, isNull);

      await tester.tap(find.byKey(const ValueKey('filter-region')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الرياض').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-city-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الرياض').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('تطبيق'));
      await tester.pumpAndSettle();
      expect(server.requests.last!['p_region_id'], 1);
      expect(server.requests.last!['p_city_id'], isNotNull);
    });
  });

  group('التفاصيل', () {
    Map<String, dynamic> detail({bool call = true, bool whatsapp = true}) {
      final d = Map<String, dynamic>.from(fixture('listing-detail') as Map);
      final l = Map<String, dynamic>.from(d['listing'] as Map)
        ..['contact_call_enabled'] = call
        ..['contact_whatsapp_enabled'] = whatsapp;
      return d..['listing'] = l;
    }

    Future<void> open(WidgetTester tester) async {
      // طول يكفي لبناء كل أقسام التفاصيل دون تمرير.
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();
      await tester.tap(find.text('إعلان رقم 0 للإبل'));
      await tester.pumpAndSettle();
    }

    testWidgets('تعرض المواصفات والوصف وإفادة المعلن وأزرار القنوات المفعلة', (
      tester,
    ) async {
      final server = _SearchServer();
      final rpc = FakeRpc({...server.handlers, 'get_listing': (_) => detail()});
      await pumpApp(tester, auth: FakeAuthBackend(signedIn: false), rpc: rpc);
      await open(tester);

      expect(rpc.paramsOf('get_listing').single, {'p_listing_id': 'listing-0'});
      expect(find.text('ناقة مجاهيم للبيع'), findsOneWidget);
      expect(find.text('25,000 ريال'), findsOneWidget);
      expect(find.text('4 سنوات'), findsOneWidget);
      expect(find.text('المجاهيم'), findsOneWidget);
      expect(find.textContaining('إفادة من المعلن'), findsOneWidget);
      expect(find.byKey(const ValueKey('contact-call')), findsOneWidget);
      expect(find.byKey(const ValueKey('contact-whatsapp')), findsOneWidget);
    });

    testWidgets('القناة غير المفعلة لا يظهر زرها، وإن عُطلتا لا شريط', (
      tester,
    ) async {
      var d = detail(call: false);
      final server = _SearchServer();
      final rpc = FakeRpc({...server.handlers, 'get_listing': (_) => d});
      await pumpApp(tester, rpc: rpc);
      await open(tester);
      expect(find.byKey(const ValueKey('contact-call')), findsNothing);
      expect(find.byKey(const ValueKey('contact-whatsapp')), findsOneWidget);

      d = detail(call: false, whatsapp: false);
      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();
      await open(tester);
      expect(find.byKey(const ValueKey('contact-call')), findsNothing);
      expect(find.byKey(const ValueKey('contact-whatsapp')), findsNothing);
    });

    testWidgets('الاتصال والواتساب يفتحان الرابط الصحيح', (tester) async {
      final server = _SearchServer();
      final launched = <Uri>[];
      final rpc = FakeRpc({...server.handlers, 'get_listing': (_) => detail()});
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
      await open(tester);

      await tester.tap(find.byKey(const ValueKey('contact-call')));
      await tester.tap(find.byKey(const ValueKey('contact-whatsapp')));
      await tester.pumpAndSettle();
      expect(launched[0].toString(), startsWith('tel:+9665'));
      expect(launched[1].host, 'wa.me');
      expect(launched[1].path, matches(r'^/9665\d{8}$'));
    });

    testWidgets('تعذر فتح الرابط يظهر رسالة', (tester) async {
      final server = _SearchServer();
      final rpc = FakeRpc({...server.handlers, 'get_listing': (_) => detail()});
      await pumpApp(
        tester,
        rpc: rpc,
        extraOverrides: [
          externalLauncherProvider.overrideWithValue((u) async => false),
        ],
      );
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('contact-call')));
      await tester.pumpAndSettle();
      expect(find.text('تعذّر فتح التطبيق. حاول مرة أخرى.'), findsOneWidget);
    });

    testWidgets('غير المنشور: «الإعلان غير متاح» دون أي سبب', (tester) async {
      final server = _SearchServer();
      final rpc = FakeRpc({
        ...server.handlers,
        'get_listing': (_) =>
            throw const PostgrestException(message: 'NOT_FOUND'),
      });
      await pumpApp(tester, rpc: rpc);
      await open(tester);
      expect(find.text('الإعلان غير متاح'), findsOneWidget);
      expect(find.textContaining('مخفي'), findsNothing);
      expect(find.byKey(const ValueKey('contact-call')), findsNothing);
    });

    testWidgets('المعرض: عدد الصور والتكبير بالنقر', (tester) async {
      final server = _SearchServer();
      final rpc = FakeRpc({...server.handlers, 'get_listing': (_) => detail()});
      await pumpApp(tester, rpc: rpc);
      await open(tester);

      expect(find.byKey(const ValueKey('gallery')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('gallery')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('viewer')), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsWidgets);
    });

    testWidgets('المزاد: الموعد والمكان بتوقيت السعودية، والماضي منبه', (
      tester,
    ) async {
      final server = _SearchServer();
      Map<String, dynamic> auction({required bool passed}) {
        final d = detail();
        final l = Map<String, dynamic>.from(d['listing'] as Map)
          ..['offer_type'] = 'IN_PERSON_AUCTION'
          ..['price'] = null
          ..['auction_passed'] = passed
          ..['auction_starts_at'] = '2099-01-05T15:30:00+00:00'
          ..['auction_region_name_ar'] = 'الرياض'
          ..['auction_city_name_ar'] = 'الرياض'
          ..['auction_venue'] = 'ساحة المزاد الكبرى';
        return d..['listing'] = l;
      }

      var passed = false;
      final rpc = FakeRpc({
        ...server.handlers,
        'get_listing': (_) => auction(passed: passed),
      });
      await pumpApp(tester, rpc: rpc);
      await open(tester);
      expect(find.textContaining('5/1/2099 18:30'), findsWidgets);
      expect(find.textContaining('ساحة المزاد الكبرى'), findsOneWidget);

      passed = true;
      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();
      await open(tester);
      expect(find.text('مضى موعد هذا المزاد.'), findsOneWidget);
    });
  });

  group('المشاركة', () {
    test('الرابط الثابت من النطاق والمعرف العام فقط', () {
      expect(
        listingShareLink('https://nawadir.example/', 'abcd2345'),
        'https://nawadir.example/l/abcd2345',
      );
      expect(listingShareLink('', 'abcd2345'), isNull);
      expect(listingShareLink('https://x.example', null), isNull);
    });

    testWidgets('زر المشاركة يظهر مع النطاق ويرسل العنوان والرابط', (
      tester,
    ) async {
      final shared = <(String, String)>[];
      final server = _SearchServer();
      final rpc = FakeRpc({
        ...server.handlers,
        'get_listing': (_) => fixture('listing-detail'),
      });
      await pumpApp(
        tester,
        env: const Env(
          supabaseUrl: 'https://example.supabase.co',
          supabasePublishableKey: 'sb_publishable_x',
          shareBaseUrl: 'https://nawadir.example',
        ),
        rpc: rpc,
        extraOverrides: [
          shareTextProvider.overrideWithValue((text, subject) async {
            shared.add((text, subject));
          }),
        ],
      );
      await tester.tap(find.text('إعلان رقم 0 للإبل'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('share')));
      await tester.pumpAndSettle();

      expect(
        shared.single.$1,
        startsWith('ناقة مجاهيم للبيع\nhttps://nawadir.example/l/'),
      );
      // لا هاتف ولا بيانات خاصة في النص المشارك.
      expect(shared.single.$1, isNot(contains('966')));
    });

    testWidgets('دون نطاق مضبوط لا يظهر زر المشاركة', (tester) async {
      final server = _SearchServer();
      final rpc = FakeRpc({
        ...server.handlers,
        'get_listing': (_) => fixture('listing-detail'),
      });
      await pumpApp(tester, rpc: rpc);
      await tester.tap(find.text('إعلان رقم 0 للإبل'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('share')), findsNothing);
    });
  });

  group('ملف المعلن', () {
    Future<void> openOwner(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.tap(find.text('إعلان رقم 0 للإبل'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('owner-row')));
      await tester.pumpAndSettle();
    }

    testWidgets('يعرض الاسم والمنطقة وإعلانات المعلن وحده', (tester) async {
      final server = _SearchServer();
      final rpc = FakeRpc({
        ...server.handlers,
        'get_listing': (_) => fixture('listing-detail'),
      });
      final tables = FakeTables({
        'public_profiles': [fixture('public-profile') as Map<String, dynamic>],
      });
      await pumpApp(
        tester,
        auth: FakeAuthBackend(signedIn: false),
        rpc: rpc,
        tables: tables,
      );
      await openOwner(tester);

      expect(find.text('معلن تجريبي'), findsWidgets);
      expect(find.textContaining('1 إعلانًا منشورًا'), findsOneWidget);
      expect(
        server.requests.last!['p_owner_id'],
        (fixture('public-profile') as Map)['id'],
      );
      expect(find.text('إعلان رقم 0 للإبل'), findsOneWidget);
    });

    testWidgets('ملف غير موجود: «الملف غير متاح»', (tester) async {
      final server = _SearchServer();
      final rpc = FakeRpc({
        ...server.handlers,
        'get_listing': (_) => fixture('listing-detail'),
      });
      await pumpApp(tester, rpc: rpc, tables: FakeTables());
      await openOwner(tester);
      expect(find.text('الملف غير متاح'), findsOneWidget);
    });
  });

  group('المفضلة', () {
    Map<String, dynamic> favRow(int n, {bool available = true}) {
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

    testWidgets('الزائر يضغط القلب فيوجَّه إلى الدخول', (tester) async {
      final server = _SearchServer();
      await pumpApp(
        tester,
        auth: FakeAuthBackend(signedIn: false),
        rpc: FakeRpc(server.handlers),
      );
      await tester.tap(find.byTooltip('حفظ في المفضلة').first);
      await tester.pumpAndSettle();
      expect(find.text('رقم الجوال'), findsWidgets);
    });

    testWidgets('الحفظ يستدعي الدالة ثم يعيد القراءة فيصير القلب ممتلئًا', (
      tester,
    ) async {
      final server = _SearchServer();
      final tables = FakeTables({'my_favorites': <Map<String, dynamic>>[]});
      final rpc = FakeRpc({
        ...server.handlers,
        'add_favorite': (p) {
          tables.rows['my_favorites'] = [favRow(0)];
          return {'listing_id': p!['p_listing_id'], 'saved_at': 'x'};
        },
      });
      await pumpApp(tester, rpc: rpc, tables: tables);

      await tester.tap(find.byTooltip('حفظ في المفضلة').first);
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('add_favorite').single, {
        'p_listing_id': 'listing-0',
      });
      expect(find.byTooltip('إزالة من المفضلة'), findsOneWidget);
    });

    testWidgets('إعلان لم يعد متاحًا عند الحفظ: رسالة دون كشف السبب', (
      tester,
    ) async {
      final server = _SearchServer();
      final rpc = FakeRpc({
        ...server.handlers,
        'add_favorite': (_) =>
            throw const PostgrestException(message: 'NOT_FOUND'),
      });
      await pumpApp(tester, rpc: rpc);
      await tester.tap(find.byTooltip('حفظ في المفضلة').first);
      await tester.pumpAndSettle();
      expect(find.text('الإعلان لم يعد متاحًا.'), findsOneWidget);
      expect(find.byTooltip('إزالة من المفضلة'), findsNothing);
    });

    testWidgets('تبويب المفضلة: المتاح بمحتواه وغير المتاح بلا محتوى ويُزال', (
      tester,
    ) async {
      final server = _SearchServer();
      final tables = FakeTables({
        'my_favorites': [favRow(1), favRow(2, available: false)],
      });
      final rpc = FakeRpc({
        ...server.handlers,
        'remove_favorite': (p) {
          tables.rows['my_favorites'] = [favRow(1)];
          return {'listing_id': p!['p_listing_id'], 'removed': true};
        },
      });
      await pumpApp(tester, rpc: rpc, tables: tables);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar).evaluate().isEmpty
              ? find.byType(Scaffold).first
              : find.byType(NavigationBar),
          matching: find.text('المفضلة'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ناقة مجاهيم للبيع'), findsOneWidget);
      expect(find.text('الإعلان غير متاح'), findsOneWidget);

      await tester.tap(find.text('إزالة'));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('remove_favorite').single, {
        'p_listing_id': 'listing-2',
      });
      expect(find.text('الإعلان غير متاح'), findsNothing);
      expect(find.text('ناقة مجاهيم للبيع'), findsOneWidget);
    });

    testWidgets('الزائر في تبويب المفضلة: دعوة لتسجيل الدخول', (tester) async {
      final server = _SearchServer();
      await pumpApp(
        tester,
        auth: FakeAuthBackend(signedIn: false),
        rpc: FakeRpc(server.handlers),
      );
      await tester.tap(find.text('المفضلة').last);
      await tester.pumpAndSettle();
      expect(find.text('سجّل الدخول لحفظ إعلاناتك'), findsOneWidget);
    });
  });

  test('رد لا يطابق العقد يرمي TypeError لتحوله الطبقة إلى خطأ غير معروف', () {
    expect(() => SearchPage.fromJson({'items': 5}), throwsA(isA<TypeError>()));
    expect(AppError.from(StateError('x')).code, AppErrorCode.unknown);
  });
}
