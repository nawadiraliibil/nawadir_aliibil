import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/core/errors/app_error.dart';
import 'package:nawadir_aliibil/core/settings/published_settings.dart';
import 'package:nawadir_aliibil/core/settings/settings_repository.dart';
import 'package:nawadir_aliibil/core/supabase/rest.dart';
import 'package:nawadir_aliibil/core/supabase/rpc.dart';
import 'package:nawadir_aliibil/features/listing/application/media_controller.dart';
import 'package:nawadir_aliibil/features/listing/application/post_controller.dart';
import 'package:nawadir_aliibil/features/listing/data/draft_form.dart';
import 'package:nawadir_aliibil/features/listing/data/media_backend.dart';
import 'package:nawadir_aliibil/features/listing/data/media_models.dart';
import 'package:nawadir_aliibil/features/listing/domain/image_sniff.dart';

import '../../helpers/fake_media.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/fake_tables.dart';

PickedImage _img(int seed) => PickedImage(
  name: 'p$seed.jpg',
  bytes: jpegBytes(seed: seed),
);

/// يهيئ حاوية فيها مسودة منشأة ومتحكم وسائط بخلفية مزيفة.
Future<(ProviderContainer, FakeMediaBackend)> _setup({
  PublishedSettings? settings,
}) async {
  final backend = FakeMediaBackend();
  final s =
      settings ??
      PublishedSettings.fromJson(
        Map<String, dynamic>.from(fixture('published-settings') as Map),
      );
  final container = ProviderContainer(
    overrides: [
      mediaBackendProvider.overrideWithValue(backend),
      publishedSettingsProvider.overrideWith((ref) => s),
      tableReaderProvider.overrideWithValue(FakeTables().reader),
      storageRemoverProvider.overrideWithValue(FakeStorage().remover),
      rpcProvider.overrideWithValue(
        FakeRpc(FakeListingServer().handlers).caller,
      ),
    ],
  );
  addTearDown(container.dispose);
  // نبقي المتحكمين حيين طوال الاختبار.
  container.listen(postControllerProvider, (_, _) {});
  container.listen(mediaControllerProvider, (_, _) {});
  await container.read(publishedSettingsProvider.future);
  final post = container.read(postControllerProvider.notifier);
  post.setOfferType(DraftForm.offerFixed);
  expect(await post.save(DraftKeys.offer), isTrue);
  return (container, backend);
}

/// ينتظر انتهاء الطابور.
Future<void> _settle(ProviderContainer c) async {
  for (var i = 0; i < 50 && c.read(mediaControllerProvider).anyBusy; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('كشف النوع من البايتات لا من الاسم', () {
    expect(ImageSniff.mimeOf(jpegBytes()), ImageSniff.jpeg);
    expect(ImageSniff.mimeOf(pngBytes()), ImageSniff.png);
    expect(ImageSniff.mimeOf(htmlBytes()), isNull);
    expect(ImageSniff.mimeOf(jpegBytes().sublist(0, 2)), isNull);
  });

  test('الصورة الصالحة تمر: تسجيل ثم رفع ثم تثبيت', () async {
    final (c, backend) = await _setup();
    final ctl = c.read(mediaControllerProvider.notifier);

    ctl.addPicked([_img(1)]);
    await _settle(c);

    final item = c.read(mediaControllerProvider).items.single;
    expect(item.stage, MediaStage.ready);
    expect(backend.calls, ['add', 'upload:media-1', 'finalize:media-1']);
  });

  test('الملفات غير الصالحة تُرفض محليًا ولا تصل إلى الخادم', () async {
    final (c, backend) = await _setup();
    final ctl = c.read(mediaControllerProvider.notifier);

    ctl.addPicked([
      PickedImage(name: 'a.jpg', bytes: htmlBytes()), // HTML بامتداد صورة
      PickedImage(name: 'b.heic', bytes: htmlBytes()),
      PickedImage(
        name: 'c.jpg',
        bytes: jpegBytes(length: 10 * 1024 * 1024 + 1),
      ),
      PickedImage(name: 'd.jpg', bytes: jpegBytes().sublist(0, 0)),
    ]);
    await _settle(c);

    final state = c.read(mediaControllerProvider);
    expect(state.items, isEmpty);
    expect(backend.calls, isEmpty);
    expect(state.notices.join(' '), contains('النوع غير مدعوم'));
    expect(state.notices.join(' '), contains('أكبر من 10 ميغابايت'));
    expect(state.notices.join(' '), contains('فارغ'));
  });

  test('حد عدد الصور من الإعدادات', () async {
    final (c, backend) = await _setup();
    final ctl = c.read(mediaControllerProvider.notifier);
    expect(ctl.remainingSlots, 10);

    ctl.addPicked([for (var i = 0; i < 12; i++) _img(i)]);
    await _settle(c);

    final state = c.read(mediaControllerProvider);
    expect(state.items, hasLength(10));
    expect(ctl.remainingSlots, 0);
    expect(state.notices.single, contains('الحد الأقصى 10'));
    expect(backend.calls.where((e) => e == 'add'), hasLength(10));
  });

  test('الرفض بعد الفحص يظهر سببه ويحذف من الخادم', () async {
    final (c, backend) = await _setup();
    backend.rejectedWith['media-1'] = 'CORRUPT_FILE';
    final ctl = c.read(mediaControllerProvider.notifier);

    ctl.addPicked([_img(1)]);
    await _settle(c);
    final item = c.read(mediaControllerProvider).items.single;
    expect(item.stage, MediaStage.failed);
    expect(item.failureReason, 'CORRUPT_FILE');

    await ctl.remove(item.key);
    expect(c.read(mediaControllerProvider).items, isEmpty);
    expect(backend.calls.last, 'remove:media-1');
  });

  test('انقطاع الرفع يتعثر ثم يستأنف من الرفع دون تسجيل ثانٍ', () async {
    final (c, backend) = await _setup();
    backend.uploadFailures.add(const AppError(AppErrorCode.network));
    final ctl = c.read(mediaControllerProvider.notifier);

    ctl.addPicked([_img(1)]);
    await _settle(c);
    var item = c.read(mediaControllerProvider).items.single;
    expect(item.stage, MediaStage.stalled);
    expect(item.error?.code, AppErrorCode.network);

    ctl.retry(item.key);
    await _settle(c);
    item = c.read(mediaControllerProvider).items.single;
    expect(item.stage, MediaStage.ready);
    expect(backend.calls.where((e) => e == 'add'), hasLength(1));
    expect(backend.calls.where((e) => e.startsWith('upload')), hasLength(2));
  });

  test('MEDIA_NOT_UPLOADED يعيد الرفع مرة ثم ينجح', () async {
    final (c, backend) = await _setup();
    backend.finalizeScript.add(const AppError(AppErrorCode.mediaNotUploaded));

    c.read(mediaControllerProvider.notifier).addPicked([_img(1)]);
    await _settle(c);

    expect(
      c.read(mediaControllerProvider).items.single.stage,
      MediaStage.ready,
    );
    expect(backend.calls, [
      'add',
      'upload:media-1',
      'finalize:media-1',
      'upload:media-1',
      'finalize:media-1',
    ]);
  });

  test('MEDIA_PROCESSING_FAILED يعاد التثبيت حتى ثلاث مرات ثم يتعثر', () async {
    final (c, backend) = await _setup();
    backend.finalizeScript.addAll([
      const AppError(AppErrorCode.mediaProcessingFailed),
      const AppError(AppErrorCode.mediaProcessingFailed),
    ]);
    final ctl = c.read(mediaControllerProvider.notifier);
    ctl.addPicked([_img(1)]);
    await _settle(c);
    expect(
      c.read(mediaControllerProvider).items.single.stage,
      MediaStage.ready,
    );
    expect(backend.calls.where((e) => e.startsWith('finalize')), hasLength(3));

    backend.finalizeScript.addAll([
      const AppError(AppErrorCode.mediaProcessingFailed),
      const AppError(AppErrorCode.mediaProcessingFailed),
      const AppError(AppErrorCode.mediaProcessingFailed),
    ]);
    ctl.addPicked([_img(2)]);
    await _settle(c);
    expect(
      c.read(mediaControllerProvider).items.last.stage,
      MediaStage.stalled,
    );
  });

  test('الترتيب والغلاف: arrange يستلم كل المعرفات بالترتيب المختار', () async {
    final (c, backend) = await _setup();
    final ctl = c.read(mediaControllerProvider.notifier);
    ctl.addPicked([_img(1), _img(2), _img(3)]);
    await _settle(c);

    var s = c.read(mediaControllerProvider);
    expect(s.effectiveCoverKey, s.items.first.key); // الأولى غلاف افتراضيًا

    ctl.setCover(s.items[2].key);
    ctl.move(s.items[2].key, -2); // الثالثة تصير أولى
    expect(await ctl.arrange(), isTrue);

    s = c.read(mediaControllerProvider);
    expect(backend.lastArrangedIds, ['media-3', 'media-1', 'media-2']);
    expect(backend.lastCoverId, 'media-3');
    expect(s.arranged, isTrue);

    // لا استدعاء ثانٍ دون تغيير.
    await ctl.arrange();
    expect(backend.calls.where((e) => e == 'arrange'), hasLength(1));
  });

  test('الحذف يلغي الغلاف المختار ويعود الافتراضي', () async {
    final (c, _) = await _setup();
    final ctl = c.read(mediaControllerProvider.notifier);
    ctl.addPicked([_img(1), _img(2)]);
    await _settle(c);
    final second = c.read(mediaControllerProvider).items[1];
    ctl.setCover(second.key);
    expect(c.read(mediaControllerProvider).effectiveCoverKey, second.key);

    await ctl.remove(second.key);
    final s = c.read(mediaControllerProvider);
    expect(s.items, hasLength(1));
    expect(s.effectiveCoverKey, s.items.single.key);
  });

  test('فشل الترتيب في الخادم يبقى خطأً ولا يعد مرتبًا', () async {
    final (c, backend) = await _setup();
    backend.arrangeFailure = const AppError(AppErrorCode.validationFailed);
    final ctl = c.read(mediaControllerProvider.notifier);
    ctl.addPicked([_img(1)]);
    await _settle(c);

    expect(await ctl.arrange(), isFalse);
    final s = c.read(mediaControllerProvider);
    expect(s.arranged, isFalse);
    expect(s.error?.code, AppErrorCode.validationFailed);
  });
}
