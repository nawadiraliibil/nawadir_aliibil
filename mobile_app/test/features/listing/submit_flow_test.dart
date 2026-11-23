import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/core/errors/app_error.dart';
import 'package:nawadir_aliibil/features/listing/application/post_controller.dart';
import 'package:nawadir_aliibil/features/listing/presentation/preview_step.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/pump_app.dart';

const _fixedForm = <String, Object?>{
  'offer_type': 'FIXED_PRICE',
  'title': 'ناقة وضح أصيلة للبيع',
  'breed_id': 2,
  'sex': 'FEMALE',
  'age_months': 36,
  'color': 'وضح',
  'description': 'ناقة هادئة الطباع ومعتادة على الحلب',
  'health_notes': 'لا توجد عيوب معروفة',
  'region_id': 1,
  'city_id': 2,
  'price': 48000,
  'contact_phone': '0500000009',
  'contact_call_enabled': true,
  'contact_whatsapp_enabled': false,
};

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).last));

/// يفتح المعالج، ينشئ المسودة، يعبئ الحقول ويصل إلى المعاينة.
Future<FakeListingServer> _openPreview(
  WidgetTester tester, {
  Map<String, dynamic>? account,
  Map<String, Object?> form = _fixedForm,
  FakeListingServer? server,
}) async {
  // شاشة طويلة: القائمة كسولة ولا تبني ما خارج الإطار.
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = server ?? FakeListingServer();
  final rpc = FakeRpc({
    ...s.handlers,
    'get_my_account': (_) => account ?? fixture('account-ready'),
    'update_my_profile': (_) => <String, dynamic>{},
    'accept_policies': (_) => <String, dynamic>{},
  });
  await pumpApp(tester, auth: FakeAuthBackend(signedIn: true), rpc: rpc);
  await tester.tap(find.bySemanticsLabel('أضف إعلان'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('سعر محدد'));
  await tester.pumpAndSettle();
  final post = _container(tester).read(postControllerProvider.notifier);
  post.setAll(form);
  post.goTo(PostStep.preview);
  await tester.pumpAndSettle();
  return s;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  test('كل حقل يرده الخادم يوجَّه إلى خطوته', () {
    expect(stepForField('title'), PostStep.data);
    expect(stepForField('breed_note'), PostStep.data);
    expect(stepForField('health_notes'), PostStep.description);
    expect(stepForField('city_id'), PostStep.location);
    expect(stepForField('auction_starts_at'), PostStep.details);
    expect(stepForField('price'), PostStep.details);
    expect(stepForField('contact_channels'), PostStep.contact);
    expect(stepForField('images'), PostStep.media);
    expect(stepForField('offer_type'), PostStep.offer);
  });

  testWidgets('المعاينة تعرض بيانات الإعلان بصيغة سعر محدد', (tester) async {
    await _openPreview(tester);
    expect(find.text('إعلان جديد 7 / 7'), findsOneWidget);
    expect(find.text('سعر محدد'), findsOneWidget);
    expect(find.text('ناقة وضح أصيلة للبيع'), findsOneWidget);
    expect(find.text('48,000 ريال'), findsOneWidget);
    expect(find.text('الرياض · الدرعية'), findsOneWidget);
    expect(find.textContaining('36 شهرًا'), findsOneWidget);
    expect(find.textContaining('حسب المعلن'), findsOneWidget);
    expect(find.textContaining('0500000009 · اتصال'), findsOneWidget);
    expect(find.text('معلن تجريبي'), findsOneWidget);
  });

  testWidgets('المعاينة بصيغة المزاد تعرض المكان والموعد بتوقيت السعودية', (
    tester,
  ) async {
    await _openPreview(
      tester,
      form: {
        ..._fixedForm,
        'offer_type': 'IN_PERSON_AUCTION',
        'price': null,
        'auction_region_id': 1,
        'auction_city_id': 2,
        'auction_venue': 'سوق الإبل',
        'auction_starts_at': DateTime.utc(2099, 1, 5, 15, 30),
      },
    );
    expect(find.text('مزاد حضوري'), findsOneWidget);
    expect(find.textContaining('سوق الإبل'), findsOneWidget);
    expect(find.textContaining('5/1/2099 18:30'), findsOneWidget);
    expect(find.textContaining('ريال'), findsNothing);
  });

  testWidgets('لا إرسال قبل الإقرار', (tester) async {
    final server = await _openPreview(tester);
    await _tapText(tester, 'إرسال للمراجعة');
    expect(server.submitRequestIds, isEmpty);
    expect(find.text('أُرسل للمراجعة'), findsNothing);
  });

  testWidgets('الإقرار ثم الإرسال: يحفظ الإقرار ويرسل ويعرض شاشة الإرسال', (
    tester,
  ) async {
    final server = await _openPreview(tester);
    await _tapText(tester, 'أقر بصحة البيانات وأحقيتي في العرض');
    await _tapText(tester, 'إرسال للمراجعة');

    expect(server.patches.last, {'owner_declaration': true});
    expect(server.submitRequestIds, hasLength(1));
    expect(find.text('أُرسل للمراجعة'), findsOneWidget);
    expect(find.text('سيظهر إعلانك بعد اعتماد الإدارة.'), findsOneWidget);

    await tester.tap(find.text('إعلاناتي'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد إعلانات بعد'), findsOneWidget);
  });

  testWidgets('انقطاع أثناء الإرسال ثم إعادة المحاولة بمعرف الطلب نفسه', (
    tester,
  ) async {
    final server = FakeListingServer()
      ..submitFailures.add(const PostgrestException(message: 'INTERNAL_ERROR'));
    await _openPreview(tester, server: server);
    await _tapText(tester, 'أقر بصحة البيانات وأحقيتي في العرض');

    await _tapText(tester, 'إرسال للمراجعة');
    expect(find.textContaining('حدث خطأ غير متوقع'), findsOneWidget);
    expect(find.text('أُرسل للمراجعة'), findsNothing);

    await _tapText(tester, 'إرسال للمراجعة');
    expect(find.text('أُرسل للمراجعة'), findsOneWidget);
    expect(server.submitRequestIds, hasLength(2));
    expect(server.submitRequestIds.toSet(), hasLength(1));
  });

  testWidgets('رفض الخادم لحقول يعرض أزرار الانتقال إلى خطواتها', (
    tester,
  ) async {
    final server = FakeListingServer()
      ..submitFailures.add(
        const PostgrestException(
          message: 'VALIDATION_FAILED',
          code: 'P0001',
          details: '{"fields": ["title", "contact_phone", "images"]}',
        ),
      );
    await _openPreview(tester, server: server);
    await _tapText(tester, 'أقر بصحة البيانات وأحقيتي في العرض');
    await _tapText(tester, 'إرسال للمراجعة');

    expect(find.textContaining('تحقق من البيانات'), findsOneWidget);
    expect(find.text('عدّل: بيانات الإبل'), findsOneWidget);
    expect(find.text('عدّل: رقم التواصل'), findsOneWidget);
    expect(find.text('عدّل: الصور'), findsOneWidget);

    await _tapText(tester, 'عدّل: رقم التواصل');
    expect(find.text('إعلان جديد 6 / 7'), findsOneWidget);
  });

  testWidgets('MEDIA_NOT_READY يوجه إلى خطوة الصور', (tester) async {
    final server = FakeListingServer()
      ..submitFailures.add(
        const PostgrestException(message: 'MEDIA_NOT_READY', code: 'P0001'),
      );
    await _openPreview(tester, server: server);
    await _tapText(tester, 'أقر بصحة البيانات وأحقيتي في العرض');
    await _tapText(tester, 'إرسال للمراجعة');
    expect(find.text('عدّل: الصور'), findsOneWidget);
  });

  testWidgets('تحديد حد الإرسال RATE_LIMITED يعرض رسالته', (tester) async {
    final server = FakeListingServer()
      ..submitFailures.add(
        const PostgrestException(
          message: 'RATE_LIMITED',
          code: 'P0001',
          details: '{"limit": 5, "window_hours": 24}',
        ),
      );
    await _openPreview(tester, server: server);
    await _tapText(tester, 'أقر بصحة البيانات وأحقيتي في العرض');
    await _tapText(tester, 'إرسال للمراجعة');
    expect(find.textContaining('تجاوزت الحد المسموح'), findsOneWidget);
  });

  testWidgets('حساب غير مكتمل: تفتح شاشة الإكمال ثم يتابع الإرسال', (
    tester,
  ) async {
    final account = Map<String, dynamic>.from(fixture('account-new') as Map);
    final server = FakeListingServer();
    await _openPreview(tester, account: account, server: server);
    await _tapText(tester, 'أقر بصحة البيانات وأحقيتي في العرض');
    await _tapText(tester, 'إرسال للمراجعة');

    // A04 مفتوحة فوق المعالج، ولم يرسل شيء بعد.
    expect(find.text('إكمال الحساب'), findsWidgets);
    expect(server.submitRequestIds, isEmpty);

    await tester.enterText(find.byType(TextField), 'سالم');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الرياض').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('أوافق على شروط الاستخدام'));
    await tester.tap(find.text('أوافق على سياسة الخصوصية'));
    await tester.pump();
    await tester.tap(find.text('حفظ ومتابعة'));
    await tester.pumpAndSettle();

    // عاد إلى المعاينة وأكمل الإرسال تلقائيًا.
    expect(server.submitRequestIds, hasLength(1));
    expect(find.text('أُرسل للمراجعة'), findsOneWidget);
  });

  testWidgets('الحساب الموقوف: تنبيه H08 ولا إرسال', (tester) async {
    final account = Map<String, dynamic>.from(fixture('account-ready') as Map)
      ..['status'] = 'SUSPENDED';
    final server = await _openPreview(tester, account: account);
    expect(find.textContaining('الحساب موقوف'), findsOneWidget);

    await _tapText(tester, 'أقر بصحة البيانات وأحقيتي في العرض');
    await _tapText(tester, 'إرسال للمراجعة');
    expect(server.submitRequestIds, isEmpty);
  });

  testWidgets('خطأ AppError من الحفظ لا يمر كإرسال', (tester) async {
    final server = FakeListingServer();
    await _openPreview(tester, server: server);
    // بعد الوصول إلى المعاينة: حفظ الإقرار هو الذي يفشل.
    server.failNextSave = const PostgrestException(
      message: 'ACCOUNT_SUSPENDED',
    );
    await _tapText(tester, 'أقر بصحة البيانات وأحقيتي في العرض');
    await _tapText(tester, 'إرسال للمراجعة');
    expect(find.textContaining('حسابك معلّق'), findsOneWidget);
    expect(server.submitRequestIds, isEmpty);
    expect(
      _container(tester).read(postControllerProvider).error?.code,
      AppErrorCode.accountSuspended,
    );
  });
}
