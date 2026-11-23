import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/core/errors/app_error.dart';
import 'package:nawadir_aliibil/features/listing/application/post_controller.dart';
import 'package:nawadir_aliibil/features/listing/data/media_models.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/fake_media.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/pump_app.dart';

PickedImage _img(int seed) => PickedImage(
  name: 'p$seed.jpg',
  bytes: jpegBytes(seed: seed),
);

Future<void> _openMediaStep(
  WidgetTester tester, {
  required FakeMediaBackend backend,
  required FakePhotoSource photos,
}) async {
  final server = FakeListingServer();
  await pumpApp(
    tester,
    auth: FakeAuthBackend(signedIn: true),
    rpc: FakeRpc(server.handlers),
    media: backend,
    photos: photos,
  );
  await tester.tap(find.bySemanticsLabel('أضف إعلان'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('سعر محدد'));
  await tester.pumpAndSettle();
  ProviderScope.containerOf(
    tester.element(find.byType(Scaffold).last),
  ).read(postControllerProvider.notifier).goTo(PostStep.media);
  await tester.pumpAndSettle();
}

Future<void> _addFromGallery(WidgetTester tester) async {
  await tester.tap(find.text('إضافة صور'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('من المعرض'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('الخطوة تعرض الحدود وتمنع المتابعة دون الحد الأدنى', (
    tester,
  ) async {
    await _openMediaStep(
      tester,
      backend: FakeMediaBackend(),
      photos: FakePhotoSource(gallery: [_img(1)]),
    );
    expect(find.text('إعلان جديد 5 / 7'), findsOneWidget);
    expect(find.textContaining('3–10 صور'), findsOneWidget);

    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(find.text('أضف 3 صور على الأقل.'), findsOneWidget);

    await _addFromGallery(tester);
    expect(find.bySemanticsLabel(RegExp('صورة 1 من 1')), findsOneWidget);
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(find.text('أضف 3 صور على الأقل.'), findsOneWidget);
  });

  testWidgets('ثلاث صور جاهزة: الغلاف الأولى، والمتابعة ترتب ثم تنتقل', (
    tester,
  ) async {
    final backend = FakeMediaBackend();
    final photos = FakePhotoSource(gallery: [_img(1), _img(2), _img(3)]);
    await _openMediaStep(tester, backend: backend, photos: photos);

    await _addFromGallery(tester);
    expect(photos.limits, [10]);
    expect(find.bySemanticsLabel(RegExp('جاهزة')), findsNWidgets(3));
    expect(find.text('غلاف'), findsOneWidget);

    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();

    expect(backend.lastArrangedIds, ['media-1', 'media-2', 'media-3']);
    expect(backend.lastCoverId, 'media-1');
    expect(find.text('رقم التواصل'), findsOneWidget);
  });

  testWidgets('ملف غير مدعوم يظهر تنبيهه ولا يرسل', (tester) async {
    final backend = FakeMediaBackend();
    await _openMediaStep(
      tester,
      backend: backend,
      photos: FakePhotoSource(
        gallery: [PickedImage(name: 'x.jpg', bytes: htmlBytes())],
      ),
    );
    await _addFromGallery(tester);
    expect(find.textContaining('النوع غير مدعوم'), findsOneWidget);
    expect(backend.calls, isEmpty);
  });

  testWidgets('صورة مرفوضة من الخادم تمنع المتابعة حتى تحذف', (tester) async {
    final backend = FakeMediaBackend()
      ..rejectedWith['media-2'] = 'CORRUPT_FILE';
    await _openMediaStep(
      tester,
      backend: backend,
      photos: FakePhotoSource(gallery: [_img(1), _img(2), _img(3)]),
    );
    await _addFromGallery(tester);
    expect(find.text('الملف تالف.'), findsOneWidget);

    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('احذف الصور التي تعذّر قبولها'), findsOneWidget);
    expect(backend.lastArrangedIds, isNull);

    // حذف الفاشلة (الثانية) من قائمتها.
    await tester.tap(find.byTooltip('خيارات الصورة 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف الصورة'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('remove:media-2'));
    expect(find.text('الملف تالف.'), findsNothing);
    // بقيت صورتان: أقل من الحد الأدنى.
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(find.text('أضف 3 صور على الأقل.'), findsOneWidget);
  });

  testWidgets('تعثر الرفع يعرض إعادة المحاولة ثم يكتمل', (tester) async {
    final backend = FakeMediaBackend();
    backend.uploadFailures.add(const AppError(AppErrorCode.network));
    await _openMediaStep(
      tester,
      backend: backend,
      photos: FakePhotoSource(gallery: [_img(1), _img(2), _img(3)]),
    );
    await _addFromGallery(tester);

    expect(find.text('أعد المحاولة'), findsOneWidget);
    await tester.tap(find.text('أعد المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('أعد المحاولة'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('جاهزة')), findsNWidgets(3));
  });

  testWidgets('التصوير بالكاميرا يضيف صورة واحدة', (tester) async {
    final backend = FakeMediaBackend();
    await _openMediaStep(
      tester,
      backend: backend,
      photos: FakePhotoSource(camera: _img(9)),
    );
    await tester.tap(find.text('إضافة صور'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التقاط صورة'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('صورة 1 من 1')), findsOneWidget);
  });

  testWidgets('الغلاف يتغير من قائمة الصورة ويرسل إلى الخادم', (tester) async {
    final backend = FakeMediaBackend();
    await _openMediaStep(
      tester,
      backend: backend,
      photos: FakePhotoSource(gallery: [_img(1), _img(2), _img(3)]),
    );
    await _addFromGallery(tester);

    await tester.tap(find.byTooltip('خيارات الصورة 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعيين كغلاف'));
    await tester.pumpAndSettle();
    expect(find.text('غلاف'), findsOneWidget);

    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(backend.lastCoverId, 'media-3');
  });
}
