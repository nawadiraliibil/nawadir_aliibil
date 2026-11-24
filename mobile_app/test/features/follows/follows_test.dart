import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/core/settings/published_settings.dart';
import 'package:nawadir_aliibil/features/browse/data/listing_card.dart';
import 'package:nawadir_aliibil/features/follows/data/follows_repository.dart';
import 'package:nawadir_aliibil/features/follows/presentation/follows_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/fake_tables.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _searchRow({
  String id = 's1',
  String name = 'نوق الرياض',
}) => {
  'id': id,
  'name': name,
  'filters': {'query': 'ناقة', 'region_id': 1},
  'created_at': '2026-11-23T09:00:00+00:00',
};

Map<String, dynamic> _followRow(String id, String name) => {
  'user_id': id,
  'display_name': name,
  'region_id': 1,
  'region_name_ar': 'الرياض',
  'followed_at': '2026-11-23T09:00:00+00:00',
  'published_listings_count': 3,
};

void main() {
  group('البيانات', () {
    test('المرشحات تذهب وتعود دون فرز ولا حقول فارغة', () {
      const f = SearchFilters(
        query: ' ناقة ',
        regionId: 1,
        sex: 'FEMALE',
        ageMin: 12,
        priceMax: 30000,
        sort: SearchSort.priceAsc,
      );
      final saved = savedFiltersOf(f);
      expect(saved, {
        'query': 'ناقة',
        'region_id': 1,
        'sex': 'FEMALE',
        'age_min': 12,
        'price_max': 30000,
      });
      final back = searchFiltersFromSaved(saved);
      expect(back.query, 'ناقة');
      expect(back.regionId, 1);
      expect(back.sort, SearchSort.newestVisible);
      expect(back.priceMax, 30000);
    });

    test('وصف المرشحات بأسماء القوائم', () {
      final settings = PublishedSettings.fromJson(
        Map<String, dynamic>.from(fixture('published-settings') as Map),
      );
      final text = describeFilters(
        const SearchFilters(
          query: 'ناقة',
          regionId: 1,
          offerType: 'FIXED_PRICE',
          ageMin: 12,
        ),
        settings.lookups,
      );
      expect(text, contains('«ناقة»'));
      expect(text, contains(settings.lookups.region(1)!.nameAr));
      expect(text, contains('سعر محدد'));
      expect(text, contains('العمر 12–∞ شهرًا'));
      expect(describeFilters(const SearchFilters(), null), 'كل الإعلانات');
    });

    test('صفوف العقد تُحلَّل', () {
      final s = SavedSearch.fromJson(
        Map<String, dynamic>.from(fixture('my-saved-search') as Map),
      );
      expect(s.filters.query, 'ناقة');
      final f = FollowedSeller.fromJson(
        Map<String, dynamic>.from(fixture('my-follow') as Map),
      );
      expect(f.displayName, 'معلن تجريبي');
    });
  });

  group('متابعة البحث من الرئيسية', () {
    Future<FakeRpc> home(
      WidgetTester tester, {
      Map<String, RpcHandler>? handlers,
      bool signedIn = true,
    }) async {
      final rpc = FakeRpc({
        'save_search': (p) => {'id': 's1', 'created': true},
        ...?handlers,
      });
      await pumpApp(
        tester,
        auth: FakeAuthBackend(signedIn: signedIn),
        rpc: rpc,
      );
      return rpc;
    }

    Future<void> search(WidgetTester tester, String q) async {
      await tester.enterText(find.byKey(const ValueKey('home-search')), q);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
    }

    testWidgets('لا زر دون بحث أو مرشحات', (tester) async {
      await home(tester);
      expect(find.byKey(const ValueKey('follow-search')), findsNothing);
    });

    testWidgets('يحفظ المرشحات المطبقة ويؤكد', (tester) async {
      final rpc = await home(tester);
      await search(tester, 'ناقة');
      await tester.tap(find.byKey(const ValueKey('follow-search')));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('save_search').single, {
        'p_filters': {'query': 'ناقة'},
        'p_name': null,
      });
      expect(find.textContaining('تمت متابعة البحث'), findsOneWidget);
    });

    testWidgets('المحفوظ مسبقًا يُقال صراحة', (tester) async {
      await home(
        tester,
        handlers: {
          'save_search': (p) => {'id': 's1', 'created': false},
        },
      );
      await search(tester, 'ناقة');
      await tester.tap(find.byKey(const ValueKey('follow-search')));
      await tester.pumpAndSettle();
      expect(find.text('هذا البحث محفوظ لديك بالفعل.'), findsOneWidget);
    });

    testWidgets('بلوغ الحد: رسالة بالرقم', (tester) async {
      await home(
        tester,
        handlers: {
          'save_search': (p) => throw const PostgrestException(
            message: 'FOLLOW_LIMIT_REACHED',
            details: '{"kind":"saved_searches","limit":20}',
          ),
        },
      );
      await search(tester, 'ناقة');
      await tester.tap(find.byKey(const ValueKey('follow-search')));
      await tester.pumpAndSettle();
      expect(
        find.text('بلغت الحد الأقصى من عمليات البحث المحفوظة (20).'),
        findsOneWidget,
      );
    });

    testWidgets('الزائر يوجَّه إلى الدخول ولا حفظ', (tester) async {
      final rpc = await home(tester, signedIn: false);
      await search(tester, 'ناقة');
      await tester.tap(find.byKey(const ValueKey('follow-search')));
      await tester.pumpAndSettle();
      expect(find.text('رقم الجوال'), findsWidgets);
      expect(rpc.paramsOf('save_search'), isEmpty);
    });
  });

  group('متابعة المعلن', () {
    Future<(FakeRpc, FakeTables)> seller(
      WidgetTester tester, {
      bool signedIn = true,
      List<Map<String, dynamic>> follows = const [],
    }) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final profile = Map<String, dynamic>.from(
        fixture('public-profile') as Map,
      );
      final tables = FakeTables({
        'public_profiles': [profile],
        'my_follows': [...follows],
      });
      final rpc = FakeRpc({
        'get_listing': (_) => fixture('listing-detail'),
        'follow_seller': (p) {
          tables.rows['my_follows'] = [
            _followRow(p!['p_user_id'] as String, 'معلن تجريبي'),
          ];
          return {'following': true, 'created': true};
        },
        'unfollow_seller': (p) {
          tables.rows['my_follows'] = [];
          return {'following': false};
        },
      });
      await pumpApp(
        tester,
        auth: FakeAuthBackend(signedIn: signedIn),
        rpc: rpc,
        tables: tables,
      );
      await tester.tap(find.text('ناقة مجاهيم للبيع').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tab-owner')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('owner-row')));
      await tester.pumpAndSettle();
      return (rpc, tables);
    }

    testWidgets('متابعة ثم إلغاء المتابعة', (tester) async {
      final (rpc, _) = await seller(tester);
      expect(find.text('متابعة'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('follow-seller')));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('follow_seller').single, {
        'p_user_id': (fixture('public-profile') as Map)['id'],
      });
      expect(find.text('إلغاء المتابعة'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('follow-seller')));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('unfollow_seller'), hasLength(1));
      expect(find.text('متابعة'), findsOneWidget);
    });

    testWidgets('يظهر «إلغاء المتابعة» لمن يتابعه أصلًا', (tester) async {
      await seller(
        tester,
        follows: [
          _followRow(
            (fixture('public-profile') as Map)['id'] as String,
            'معلن',
          ),
        ],
      );
      expect(find.text('إلغاء المتابعة'), findsOneWidget);
    });

    testWidgets('الزائر: الدخول أولًا', (tester) async {
      final (rpc, _) = await seller(tester, signedIn: false);
      await tester.tap(find.byKey(const ValueKey('follow-seller')));
      await tester.pumpAndSettle();
      expect(find.text('رقم الجوال'), findsWidgets);
      expect(rpc.paramsOf('follow_seller'), isEmpty);
    });
  });

  group('شاشة المتابعات', () {
    Future<(FakeRpc, FakeTables)> open(WidgetTester tester) async {
      final tables = FakeTables({
        'my_saved_searches': [_searchRow()],
        'my_follows': [_followRow('u1', 'معلن مفضل')],
      });
      final rpc = FakeRpc({
        'get_my_account': (_) => fixture('account-ready'),
        'delete_saved_search': (p) {
          tables.rows['my_saved_searches'] = [];
          return {'deleted': true};
        },
        'unfollow_seller': (p) {
          tables.rows['my_follows'] = [];
          return {'following': false};
        },
      });
      await pumpApp(tester, rpc: rpc, tables: tables);
      await tester.tap(find.text('حسابي').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('المتابعات'));
      await tester.pumpAndSettle();
      return (rpc, tables);
    }

    testWidgets('عمليات البحث بوصفها، وإلغاء المتابعة', (tester) async {
      final (rpc, _) = await open(tester);
      expect(find.text('نوق الرياض'), findsOneWidget);
      expect(find.textContaining('«ناقة»'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('saved-delete-s1')));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('delete_saved_search').single, {'p_id': 's1'});
      expect(find.text('لا عمليات بحث محفوظة'), findsOneWidget);
    });

    testWidgets('الضغط على بحث يطبقه في الرئيسية', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('saved-s1')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('home-search')),
      );
      expect(field.controller!.text, 'ناقة');
    });

    testWidgets('تبويب المعلنين وإلغاء المتابعة', (tester) async {
      final (rpc, _) = await open(tester);
      await tester.tap(find.text('المعلنون'));
      await tester.pumpAndSettle();
      expect(find.text('معلن مفضل'), findsOneWidget);
      expect(find.textContaining('3 إعلانًا منشورًا'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('unfollow-u1')));
      await tester.pumpAndSettle();
      expect(rpc.paramsOf('unfollow_seller').single, {'p_user_id': 'u1'});
      expect(find.text('لا تتابع معلنين'), findsOneWidget);
    });
  });
}
