import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/features/listing/application/post_controller.dart';
import 'package:nawadir_aliibil/core/settings/published_settings.dart';
import 'package:nawadir_aliibil/features/listing/data/draft_form.dart';
import 'package:nawadir_aliibil/features/listing/data/media_models.dart';
import 'package:nawadir_aliibil/features/listing/domain/draft_validation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/fake_media.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/pump_app.dart';

PublishedSettings get _settings => PublishedSettings.fromJson(
  Map<String, dynamic>.from(fixture('published-settings') as Map),
);

Future<FakeListingServer> _openWizard(
  WidgetTester tester, {
  FakeListingServer? server,
}) async {
  final s = server ?? FakeListingServer();
  await pumpApp(
    tester,
    auth: FakeAuthBackend(signedIn: true),
    rpc: FakeRpc(s.handlers),
    media: FakeMediaBackend(),
    photos: FakePhotoSource(
      gallery: [
        for (var i = 1; i <= 3; i++)
          PickedImage(
            name: '$i.jpg',
            bytes: jpegBytes(seed: i),
          ),
      ],
    ),
  );
  await tester.tap(find.bySemanticsLabel('أضف إعلان'));
  await tester.pumpAndSettle();
  return s;
}

Future<void> _pick(WidgetTester tester, String label, String option) async {
  await tester.tap(_field<DropdownButtonFormField<int>>(label));
  await tester.pumpAndSettle();
  // عناصر القائمة تُبنى كسولًا: نمرر القائمة حتى يظهر الخيار.
  for (var i = 0; i < 10 && find.text(option).evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.text(option).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _pickString(
  WidgetTester tester,
  String label,
  String option,
) async {
  await tester.tap(_field<DropdownButtonFormField<String>>(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.enterText(_field<TextField>(label), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _fillData(WidgetTester tester) async {
  await _type(tester, 'عنوان الإعلان', 'ناقة وضح أصيلة للبيع');
  await _pick(tester, 'السلالة', 'الوضح');
  await _pickString(tester, 'الجنس', 'أنثى');
  await _type(tester, 'العمر · شهر', '٣٦');
}

Future<void> _fillDescription(WidgetTester tester) async {
  await _type(tester, 'الوصف', 'ناقة هادئة الطباع ومعتادة على الحلب');
  await _type(tester, 'الحالة الصحية والعيوب', 'لا توجد عيوب معروفة');
}

void main() {
  group('نموذج المسودة', () {
    test('الفرق يحمل ما تغير فقط ضمن مفاتيح الخطوة', () {
      const saved = DraftForm({'title': 'قديم', 'color': 'سوداء'});
      final form = saved.setAll({'title': 'جديد', 'color': 'بيضاء'});
      expect(form.diff(saved, DraftKeys.data), {
        'title': 'جديد',
        'color': 'بيضاء',
      });
      expect(form.diff(saved, {'title'}), {'title': 'جديد'});
      expect(form.diff(saved, DraftKeys.location), isEmpty);
      // مسح قيمة يرسل null صراحة.
      expect(form.set('color', null).diff(saved, {'color'}), {'color': null});
    });

    test('موعد المزاد يرسل بصيغة ISO بالتوقيت العالمي', () {
      final at = DraftValidation.auctionMoment(DateTime(2026, 12, 1), 18, 30);
      // 18:30 بتوقيت السعودية = 15:30 UTC.
      expect(at, DateTime.utc(2026, 12, 1, 15, 30));
      final patch = const DraftForm().set('auction_starts_at', at).diff(
        const DraftForm(),
        {'auction_starts_at'},
      );
      expect(patch['auction_starts_at'], '2026-12-01T15:30:00.000Z');
    });

    test('التحليل من رد الخادم يطابق مثال العقد', () {
      final o = OwnerListing.fromJson(
        Map<String, dynamic>.from(fixture('listing-owner-draft') as Map),
      );
      expect(o.status, 'DRAFT');
      expect(o.mediaCount, 3);
      expect(o.form.title, 'ناقة مجاهيم للبيع');
      expect(o.form.offerType, DraftForm.offerFixed);
      expect(o.form.price, 25000);
      expect(o.form.ownerDeclaration, isTrue); // أقر قبل الإرسال في المثال
    });
  });

  group('التحقق', () {
    final s = _settings;

    test('السعر', () {
      expect(DraftValidation.parsePrice('48,000'), 48000);
      expect(DraftValidation.parsePrice('٤٨٠٠٠'), 48000);
      expect(DraftValidation.parsePrice('1250.5'), 1250.5);
      expect(DraftValidation.parsePrice('1.234'), isNull); // ثلاث منازل
      expect(DraftValidation.parsePrice('abc'), isNull);
      expect(DraftValidation.parsePrice('-5'), isNull);
      expect(DraftValidation.price(const DraftForm({'price': 0})), isNotEmpty);
      expect(DraftValidation.price(const DraftForm({'price': 25000})), isEmpty);
    });

    test('بيانات الإبل: حدود العنوان والعمر و«أخرى» تتطلب اسم السلالة', () {
      const ok = DraftForm({
        'title': 'ناقة وضح أصيلة للبيع',
        'breed_id': 2,
        'sex': 'FEMALE',
        'age_months': 36,
      });
      expect(DraftValidation.data(ok, s), isEmpty);
      expect(
        DraftValidation.data(ok.set('title', 'قصير'), s),
        contains('title'),
      );
      expect(
        DraftValidation.data(ok.set('age_months', 601), s),
        contains('age_months'),
      );
      expect(
        DraftValidation.data(ok.set('age_months', 0), s),
        contains('age_months'),
      );
      // السلالة «أخرى» (13) تتطلب نصًا.
      final other = ok.set('breed_id', 13);
      expect(DraftValidation.data(other, s), contains('breed_note'));
      expect(DraftValidation.data(other.set('breed_note', 'هجين'), s), isEmpty);
    });

    test('المدينة يجب أن تتبع المنطقة', () {
      final riyadhCity = s.lookups.cities.firstWhere((c) => c.regionId == 1);
      final other = s.lookups.regions.firstWhere((r) => r.id != 1);
      expect(
        DraftValidation.location(
          DraftForm({'region_id': 1, 'city_id': riyadhCity.id}),
          s,
        ),
        isEmpty,
      );
      expect(
        DraftValidation.location(
          DraftForm({'region_id': other.id, 'city_id': riyadhCity.id}),
          s,
        ),
        contains('city_id'),
      );
    });

    test('المزاد: موعد قادم ومكان ومدينة', () {
      final now = DateTime.utc(2026, 11, 23, 12);
      final city = s.lookups.cities.firstWhere((c) => c.regionId == 1);
      final ok = DraftForm({
        'auction_region_id': 1,
        'auction_city_id': city.id,
        'auction_venue': 'سوق الإبل',
        'auction_starts_at': DateTime.utc(2026, 12, 1),
        'auction_lat': 24.713552,
        'auction_lng': 46.675297,
      });
      expect(DraftValidation.auction(ok, s, now), isEmpty);
      expect(
        DraftValidation.auction(ok.set('auction_lat', null), s, now),
        contains('auction_location'),
      );
      expect(
        DraftValidation.auction(ok.set('auction_lng', null), s, now),
        contains('auction_location'),
      );
      expect(
        DraftValidation.auction(
          ok.set('auction_starts_at', DateTime.utc(2026, 11, 23, 11)),
          s,
          now,
        ),
        contains('auction_starts_at'),
      );
      expect(
        DraftValidation.auction(ok.set('auction_venue', '  '), s, now),
        contains('auction_venue'),
      );
    });

    test('التواصل: رقمان مستقلان ويلزم أحدهما بصيغة سعودية صالحة', () {
      const ok = DraftForm({'contact_phone': '0500000009'});
      expect(DraftValidation.contact(ok), isEmpty);
      // واتساب وحده يكفي، ويجوز أن يختلف عن رقم الاتصال.
      expect(
        DraftValidation.contact(
          const DraftForm({'contact_whatsapp_phone': '0500000010'}),
        ),
        isEmpty,
      );
      expect(
        DraftValidation.contact(ok.set('contact_whatsapp_phone', '0500000010')),
        isEmpty,
      );
      expect(
        DraftValidation.contact(ok.set('contact_phone', '123')),
        contains('contact_phone'),
      );
      expect(
        DraftValidation.contact(ok.set('contact_whatsapp_phone', '123')),
        contains('contact_whatsapp_phone'),
      );
      expect(
        DraftValidation.contact(const DraftForm({})),
        contains('contact_channels'),
      );
    });
  });

  testWidgets('اختيار نوع العرض ينشئ المسودة ويحفظ النوع بمعرف طلب واحد', (
    tester,
  ) async {
    final server = await _openWizard(tester);
    expect(find.text('نوع العرض'), findsOneWidget);
    expect(find.text('1 / 7'), findsOneWidget);

    await _tap(tester, 'سعر محدد');

    expect(server.createCalls, 1);
    expect(server.patches, [
      {'offer_type': 'FIXED_PRICE'},
    ]);
    expect(find.text('بيانات الإبل'), findsOneWidget);
    expect(find.text('2 / 7'), findsOneWidget);
  });

  testWidgets('مسار السعر المحدد كاملًا يحفظ كل خطوة برقعة صحيحة', (
    tester,
  ) async {
    final server = await _openWizard(tester);
    await _tap(tester, 'سعر محدد');

    // متابعة فارغة: تعرض الأخطاء ولا تحفظ.
    await _tap(tester, 'متابعة');
    expect(server.patches, hasLength(1));
    expect(find.textContaining('عنوان الإعلان من'), findsOneWidget);
    expect(find.text('اختر السلالة.'), findsOneWidget);

    await _fillData(tester);
    await _tap(tester, 'متابعة');
    expect(server.patches[1], {
      'title': 'ناقة وضح أصيلة للبيع',
      'breed_id': 2,
      'sex': 'FEMALE',
      'age_months': 36,
    });

    await _fillDescription(tester);
    await _tap(tester, 'متابعة');
    expect(server.patches[2].keys, {'description', 'health_notes'});

    await _pick(tester, 'المنطقة', 'الرياض');
    await _pick(tester, 'المدينة', 'الدرعية');
    await _tap(tester, 'متابعة');
    expect(server.patches[3], {'region_id': 1, 'city_id': 2});

    // السعر.
    await _tap(tester, 'متابعة');
    expect(find.textContaining('أدخل مبلغًا موجبًا'), findsOneWidget);
    await _type(tester, 'السعر المطلوب · ريال', '48,000');
    await _tap(tester, 'متابعة');
    expect(server.patches[4], {'price': 48000});

    // الصور: خطوة مؤقتة تتيح المتابعة.
    expect(find.text('5 / 7'), findsOneWidget);
    await tester.tap(find.text('إضافة صور'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('من المعرض'));
    await tester.pumpAndSettle();
    await _tap(tester, 'متابعة');

    // التواصل: رقم اتصال ورقم واتساب مختلفان.
    await _type(tester, 'رقم الاتصال', '٠٥٠٠٠٠٠٠٠٩');
    await _type(tester, 'رقم واتساب', '٠٥٠٠٠٠٠٠١٠');
    await _tap(tester, 'معاينة الإعلان');
    expect(server.patches[5], {
      'contact_phone': '0500000009',
      'contact_whatsapp_phone': '0500000010',
    });
    expect(find.text('7 / 7'), findsOneWidget);
    expect(server.createCalls, 1);
  });

  testWidgets('السلالة «أخرى» تظهر حقل الاسم وتخفيه عند تغيير السلالة', (
    tester,
  ) async {
    await _openWizard(tester);
    await _tap(tester, 'سعر محدد');

    await _pick(tester, 'السلالة', 'أخرى');
    expect(_field<TextField>('اسم السلالة'), findsOneWidget);
    // القائمة مفتوحة على «أخرى» في آخرها فيصعب النقر على خيار علوي؛ نستدعي التغيير مباشرة.
    tester
        .widget<DropdownButtonFormField<int>>(
          _field<DropdownButtonFormField<int>>('السلالة'),
        )
        .onChanged!(3);
    await tester.pumpAndSettle();
    expect(_field<TextField>('اسم السلالة'), findsNothing);
  });

  testWidgets('مسار المزاد: موعد مستقبلي ومكان ومدينة', (tester) async {
    // شاشة طويلة ليظهر كل الحقول دون تمرير.
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = await _openWizard(tester);
    await _tap(tester, 'مزاد حضوري');
    await _fillData(tester);
    await _tap(tester, 'متابعة');
    await _fillDescription(tester);
    await _tap(tester, 'متابعة');
    await _pick(tester, 'المنطقة', 'الرياض');
    await _pick(tester, 'المدينة', 'الدرعية');
    await _tap(tester, 'متابعة');

    // خطوة المزاد لا تعرض حقل السعر.
    expect(_field<TextField>('مكان المزاد'), findsOneWidget);
    expect(find.textContaining('السعر المطلوب'), findsNothing);

    await _tap(tester, 'متابعة');
    expect(find.text('اختر تاريخًا ووقتًا قادمين.'), findsOneWidget);
    expect(
      server.patches.where((p) => p.containsKey('auction_venue')),
      isEmpty,
    );

    await _type(tester, 'مكان المزاد', 'سوق الإبل');
    // منتقيا التاريخ والوقت (حواران من Material) لا يُختبران هنا؛ نضبط الموعد
    // بما يضبطانه: لحظة UTC محسوبة من تاريخ ووقت بتوقيت السعودية.
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).last))
        .read(postControllerProvider.notifier)
        .set(
          'auction_starts_at',
          DraftValidation.auctionMoment(DateTime(2099, 1, 5), 18, 30),
        );
    await tester.pumpAndSettle();
    expect(find.text('5/1/2099'), findsOneWidget);
    expect(find.text('6:30 م'), findsOneWidget);
    // بلا موقع على الخريطة لا انتقال: الزر يفتح الخريطة (لا تُختبر هنا).
    await _tap(tester, 'متابعة');
    expect(find.text('حدد موقع المزاد على الخريطة.'), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-location')), findsOneWidget);
    expect(
      server.patches.where((p) => p.containsKey('auction_venue')),
      isEmpty,
    );
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).last))
        .read(postControllerProvider.notifier)
        .setAll({'auction_lat': 24.713552, 'auction_lng': 46.675297});
    await tester.pump();
    expect(find.byKey(const ValueKey('location-preview')), findsOneWidget);
    await _tap(tester, 'متابعة');
    expect(server.patches.last, {
      'auction_region_id': 1,
      'auction_city_id': 2,
      'auction_venue': 'سوق الإبل',
      'auction_starts_at': '2099-01-05T15:30:00.000Z',
      'auction_lat': 24.713552,
      'auction_lng': 46.675297,
    });
    expect(find.text('5 / 7'), findsOneWidget);
    // منتقيا التاريخ والوقت (حواران من Material) لا يُختبران هنا؛ نضبط الموعد    // بما يضبطانه: لحظة UTC محسوبة من تاريخ ووقت بتوقيت السعودية.    ProviderScope.containerOf(      tester.element(find.byType(Scaffold).last),    ).read(postControllerProvider.notifier).set(      'auction_starts_at',      DraftValidation.auctionMoment(DateTime(2099, 1, 5), 18, 30),    );    await tester.pumpAndSettle();    expect(find.text('5/1/2099'), findsOneWidget);    expect(find.text('6:30 م'), findsOneWidget);    await _tap(tester, 'متابعة');    expect(server.patches.last, {      'auction_region_id': 1,      'auction_city_id': 2,      'auction_venue': 'سوق الإبل',      'auction_starts_at': '2099-01-05T15:30:00.000Z',    });    expect(find.text('5 / 7'), findsOneWidget);
  });

  testWidgets('خطأ الخادم يعرض رسالته ويبقى في الخطوة ثم ينجح إعادة الحفظ', (
    tester,
  ) async {
    final server = FakeListingServer();
    await _openWizard(tester, server: server);
    await _tap(tester, 'سعر محدد');
    await _fillData(tester);

    server.failNextSave = const PostgrestException(
      message: 'DRAFT_LIMIT_REACHED',
      code: 'P0001',
      details: '{"limit": 20}',
    );
    await _tap(tester, 'متابعة');
    expect(find.textContaining('بلغت الحد الأقصى من المسودات'), findsOneWidget);
    expect(find.text('بيانات الإبل'), findsOneWidget);

    await _tap(tester, 'متابعة');
    expect(find.text('الوصف والحالة الصحية'), findsOneWidget);
  });

  testWidgets('فشل الإنشاء ثم إعادة المحاولة لا ينشئ مسودة ثانية', (
    tester,
  ) async {
    final server = FakeListingServer();
    var fail = true;
    final handlers = {...server.handlers};
    final create = handlers['create_listing_draft']!;
    handlers['create_listing_draft'] = (p) {
      if (fail) {
        fail = false;
        // الخادم أنشأ المسودة لكن الرد ضاع: المحاولة الثانية بالمعرف نفسه.
        create(p);
        throw const PostgrestException(message: 'INTERNAL_ERROR');
      }
      return create(p);
    };
    await pumpApp(
      tester,
      auth: FakeAuthBackend(signedIn: true),
      rpc: FakeRpc(handlers),
    );
    await tester.tap(find.bySemanticsLabel('أضف إعلان'));
    await tester.pumpAndSettle();

    await _tap(tester, 'سعر محدد');
    expect(find.text('نوع العرض'), findsOneWidget); // بقي في الخطوة
    await _tap(tester, 'سعر محدد');
    expect(find.text('بيانات الإبل'), findsOneWidget);
    expect(server.createRequestIds, hasLength(2));
    expect(server.createRequestIds.toSet(), hasLength(1));
  });

  testWidgets('المغادرة بلا تغييرات تغلق دون سؤال', (tester) async {
    await _openWizard(tester);
    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();
    expect(find.text('نوع العرض'), findsNothing);
  });

  testWidgets('المغادرة بتغييرات: D12 يحفظ أو يتجاهل أو يتابع التحرير', (
    tester,
  ) async {
    final server = await _openWizard(tester);
    await _tap(tester, 'سعر محدد'); // الخطوة 2
    await _type(tester, 'عنوان الإعلان', 'ناقة وضح أصيلة للبيع');

    // رجوع إلى الخطوة 1 ثم مغادرة.
    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();
    expect(find.text('حفظ المسودة؟'), findsOneWidget);

    await tester.tap(find.text('متابعة التحرير'));
    await tester.pumpAndSettle();
    expect(find.text('نوع العرض'), findsOneWidget);

    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ ومغادرة'));
    await tester.pumpAndSettle();
    expect(server.patches.last, containsPair('title', 'ناقة وضح أصيلة للبيع'));
    expect(find.text('نوع العرض'), findsNothing);
  });

  testWidgets('تجاهل التغييرات يغادر دون حفظ', (tester) async {
    final server = await _openWizard(tester);
    await _tap(tester, 'سعر محدد');
    await _type(tester, 'عنوان الإعلان', 'عنوان لن يحفظ');
    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تجاهل التغييرات'));
    await tester.pumpAndSettle();
    expect(find.text('حفظ المسودة؟'), findsNothing);
    expect(server.patches.any((p) => p.containsKey('title')), isFalse);
  });

  testWidgets('لا تتجاوز الخطوات الحدود في عرض 320 مع تكبير النص', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await _openWizard(tester);
    await tester.tap(find.text('سعر محدد'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

/// الحقل [T] داخل خانة التسمية `field:<label>` (التسمية فوق الحقل في التصميم).
Finder _field<T extends Widget>(String label) => find.descendant(
  of: find.byKey(ValueKey('field:$label')),
  matching: find.byType(T),
);
