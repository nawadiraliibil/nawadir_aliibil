import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/app/theme/app_theme.dart';
import 'package:nawadir_aliibil/core/settings/published_settings.dart';
import 'package:nawadir_aliibil/core/settings/settings_repository.dart';
import 'package:nawadir_aliibil/core/supabase/rest.dart';
import 'package:nawadir_aliibil/core/supabase/rpc.dart';
import 'package:nawadir_aliibil/features/listing/application/media_controller.dart';
import 'package:nawadir_aliibil/features/listing/application/post_controller.dart';
import 'package:nawadir_aliibil/features/listing/data/draft_form.dart';
import 'package:nawadir_aliibil/features/listing/data/media_backend.dart';
import 'package:nawadir_aliibil/features/listing/data/media_models.dart';
import 'package:nawadir_aliibil/features/listing/data/video_playback.dart';
import 'package:nawadir_aliibil/features/listing/domain/image_sniff.dart';
import 'package:nawadir_aliibil/features/listing/presentation/video_player_view.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/fake_media.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/fake_tables.dart';
import '../../helpers/fake_video.dart';
import '../../helpers/pump_app.dart';

PickedImage _img(int seed) => PickedImage(
  name: 'p$seed.jpg',
  bytes: jpegBytes(seed: seed),
);

PickedVideo _video({int size = 1024, int? seconds = 30, bool mp4 = true}) =>
    PickedVideo(
      name: 'v.mp4',
      sizeBytes: size,
      bytes: mp4 ? mp4Bytes() : htmlBytes(),
      durationSeconds: seconds,
    );

Future<void> _openMediaStep(
  WidgetTester tester, {
  required FakeMediaBackend backend,
  required FakePhotoSource photos,
  required bool videoEnabled,
}) async {
  final server = FakeListingServer();
  await pumpApp(
    tester,
    auth: FakeAuthBackend(signedIn: true),
    rpc: FakeRpc({
      ...server.handlers,
      'get_published_settings': (_) => settingsWithVideo(enabled: videoEnabled),
    }),
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

Future<void> _pickVideo(WidgetTester tester, String addLabel) async {
  await tester.tap(find.text(addLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.text('اختيار فيديو من المعرض'));
  await tester.pumpAndSettle();
}

void main() {
  group('خطوة الصور والفيديو', () {
    testWidgets('الفيديو معطل: تبقى الواجهة الحالية دون أي أثر للفيديو', (
      tester,
    ) async {
      await _openMediaStep(
        tester,
        backend: FakeMediaBackend(),
        photos: FakePhotoSource(),
        videoEnabled: false,
      );
      expect(find.text('إضافة صور'), findsOneWidget);
      expect(find.text('إضافة صور أو فيديو'), findsNothing);
      expect(find.textContaining('فيديو واحد'), findsNothing);
      expect(find.textContaining('تسجيل فيديو'), findsNothing);
      expect(find.textContaining('3–10 صور، حتى 10 MB للصورة'), findsOneWidget);

      await tester.tap(find.text('إضافة صور'));
      await tester.pumpAndSettle();
      expect(find.text('من المعرض'), findsOneWidget);
      expect(find.text('اختيار فيديو من المعرض'), findsNothing);
    });

    testWidgets('الفيديو مفعل: الخانة والتلميح وخيارا الفيديو', (tester) async {
      await _openMediaStep(
        tester,
        backend: FakeMediaBackend(),
        photos: FakePhotoSource(),
        videoEnabled: true,
      );
      expect(find.text('إضافة صور أو فيديو'), findsOneWidget);
      expect(
        find.textContaining('فيديو واحد حتى 60 ثانية و100 MB'),
        findsOneWidget,
      );
      await tester.tap(find.text('إضافة صور أو فيديو'));
      await tester.pumpAndSettle();
      expect(find.text('اختيار فيديو من المعرض'), findsOneWidget);
      expect(find.text('تسجيل فيديو'), findsOneWidget);
    });

    testWidgets('رفع فيديو بالمسار نفسه، بلاطة بزر حذف، وحد فيديو واحد', (
      tester,
    ) async {
      final backend = FakeMediaBackend();
      final photos = FakePhotoSource(video: _video());
      await _openMediaStep(
        tester,
        backend: backend,
        photos: photos,
        videoEnabled: true,
      );
      await _pickVideo(tester, 'إضافة صور أو فيديو');

      expect(photos.videoRequests.single.maxBytes, 104857600);
      expect(photos.videoRequests.single.maxSeconds, 60);
      expect(backend.kinds, ['VIDEO']);
      expect(backend.calls, ['add', 'upload:media-1', 'finalize:media-1']);
      expect(find.bySemanticsLabel(RegExp('فيديو الإعلان، جاهزة')), findsOne);
      expect(find.byKey(const ValueKey('video-delete')), findsOneWidget);

      // بعد فيديو واحد لا خيار فيديو آخر.
      await tester.tap(find.text('إضافة صور أو فيديو'));
      await tester.pumpAndSettle();
      expect(find.text('اختيار فيديو من المعرض'), findsNothing);
      expect(find.text('من المعرض'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // الحذف يزيل البلاطة ويعيد خيار الفيديو.
      await tester.tap(find.byKey(const ValueKey('video-delete')));
      await tester.pumpAndSettle();
      expect(backend.calls, contains('remove:media-1'));
      expect(find.byKey(const ValueKey('video-delete')), findsNothing);
    });

    testWidgets('الفيديو لا يحسب من حد الصور الأدنى ولا يصير غلافًا', (
      tester,
    ) async {
      final backend = FakeMediaBackend();
      final photos = FakePhotoSource(
        gallery: [_img(1), _img(2)],
        video: _video(),
      );
      await _openMediaStep(
        tester,
        backend: backend,
        photos: photos,
        videoEnabled: true,
      );
      await _pickVideo(tester, 'إضافة صور أو فيديو');
      await tester.tap(find.text('إضافة صور أو فيديو'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('من المعرض'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('متابعة'));
      await tester.pumpAndSettle();
      expect(find.text('أضف 3 صور على الأقل.'), findsOneWidget);
      expect(backend.lastArrangedIds, isNull);
    });
  });

  group('تحقق محلي', () {
    Future<(ProviderContainer, FakeMediaBackend)> setup({
      bool enabled = true,
    }) async {
      final backend = FakeMediaBackend();
      final settings = PublishedSettings.fromJson(
        settingsWithVideo(enabled: enabled),
      );
      final container = ProviderContainer(
        overrides: [
          mediaBackendProvider.overrideWithValue(backend),
          publishedSettingsProvider.overrideWith((ref) => settings),
          tableReaderProvider.overrideWithValue(FakeTables().reader),
          storageRemoverProvider.overrideWithValue(FakeStorage().remover),
          rpcProvider.overrideWithValue(
            FakeRpc(FakeListingServer().handlers).caller,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(postControllerProvider, (_, _) {});
      container.listen(mediaControllerProvider, (_, _) {});
      await container.read(publishedSettingsProvider.future);
      final post = container.read(postControllerProvider.notifier);
      post.setOfferType(DraftForm.offerFixed);
      expect(await post.save(DraftKeys.offer), isTrue);
      return (container, backend);
    }

    Future<void> settle(ProviderContainer c) async {
      for (var i = 0; i < 50 && c.read(mediaControllerProvider).anyBusy; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('كشف mp4 من البايتات', () {
      expect(VideoSniff.mimeOf(mp4Bytes()), VideoSniff.mp4);
      expect(VideoSniff.mimeOf(htmlBytes()), isNull);
      expect(VideoSniff.mimeOf(jpegBytes()), isNull);
    });

    test('فيديو صالح يرفع بنوع VIDEO ولا يغير حد الصور', () async {
      final (c, backend) = await setup();
      final ctl = c.read(mediaControllerProvider.notifier);
      ctl.addVideo(_video());
      await settle(c);
      final s = c.read(mediaControllerProvider);
      expect(s.items.single.isVideo, isTrue);
      expect(s.items.single.stage, MediaStage.ready);
      expect(backend.kinds, ['VIDEO']);
      expect(ctl.remainingSlots, 10);
      expect(s.readyImageCount, 0);
      expect(s.effectiveCoverKey, isNull);
    });

    test('الحجم الأكبر من الحد يرفض دون استدعاء الخادم', () async {
      final (c, backend) = await setup();
      c
          .read(mediaControllerProvider.notifier)
          .addVideo(
            PickedVideo(
              name: 'big.mp4',
              sizeBytes: 104857600 + 1,
              bytes: Uint8List(0),
              durationSeconds: 10,
            ),
          );
      final s = c.read(mediaControllerProvider);
      expect(s.items, isEmpty);
      expect(s.notices.single, contains('أكبر من 100 ميغابايت'));
      expect(backend.calls, isEmpty);
    });

    test('المدة الأطول من الحد ترفض، والحد نفسه يقبل', () async {
      final (c, backend) = await setup();
      final ctl = c.read(mediaControllerProvider.notifier);
      ctl.addVideo(_video(seconds: 61));
      expect(c.read(mediaControllerProvider).items, isEmpty);
      expect(
        c.read(mediaControllerProvider).notices.single,
        contains('أطول من 60 ثانية'),
      );
      expect(backend.calls, isEmpty);

      ctl.addVideo(_video(seconds: 60));
      await settle(c);
      expect(c.read(mediaControllerProvider).items, hasLength(1));
    });

    test('مدة غير معروفة محليًا لا تمنع (الخادم يفحص)', () async {
      final (c, _) = await setup();
      c.read(mediaControllerProvider.notifier).addVideo(_video(seconds: null));
      await settle(c);
      expect(c.read(mediaControllerProvider).items, hasLength(1));
    });

    test('صيغة غير mp4 ترفض', () async {
      final (c, backend) = await setup();
      c.read(mediaControllerProvider.notifier).addVideo(_video(mp4: false));
      expect(c.read(mediaControllerProvider).items, isEmpty);
      expect(
        c.read(mediaControllerProvider).notices.single,
        contains('المسموح MP4'),
      );
      expect(backend.calls, isEmpty);
    });

    test('فيديو ثانٍ يرفض: واحد فقط لكل إعلان', () async {
      final (c, backend) = await setup();
      final ctl = c.read(mediaControllerProvider.notifier);
      ctl.addVideo(_video());
      await settle(c);
      ctl.addVideo(_video());
      expect(c.read(mediaControllerProvider).items, hasLength(1));
      expect(
        c.read(mediaControllerProvider).notices.single,
        contains('فيديو واحد فقط'),
      );
      expect(backend.kinds, ['VIDEO']);
    });

    test('معطل في الإعدادات: يتجاهل دون أثر', () async {
      final (c, backend) = await setup(enabled: false);
      c.read(mediaControllerProvider.notifier).addVideo(_video());
      expect(c.read(mediaControllerProvider).items, isEmpty);
      expect(backend.calls, isEmpty);
    });

    test('الغلاف لا يكون فيديو حتى لو أول الوسائط', () async {
      final (c, _) = await setup();
      final ctl = c.read(mediaControllerProvider.notifier);
      ctl.addVideo(_video());
      await settle(c);
      ctl.addPicked([_img(1)]);
      await settle(c);
      final s = c.read(mediaControllerProvider);
      expect(s.items.first.isVideo, isTrue);
      expect(s.effectiveCoverKey, s.items.last.key);
      ctl.setCover(s.items.first.key);
      expect(
        c.read(mediaControllerProvider).effectiveCoverKey,
        s.items.last.key,
      );
    });
  });

  group('العرض اليدوي', () {
    final fakes = <FakeVideoPlayback>[];
    var failInit = false;

    setUp(() {
      fakes.clear();
      failInit = false;
    });

    Future<void> pumpPlayer(WidgetTester tester, {VoidCallback? full}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            signedUrlProvider.overrideWithValue(
              (bucket, path) async => 'https://signed/$bucket/$path',
            ),
            videoPlaybackFactoryProvider.overrideWithValue((url) {
              final f = FakeVideoPlayback(url, failInit: failInit);
              fakes.add(f);
              return f;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 300,
                child: VideoPlayerView(
                  bucket: 'listing-videos',
                  path: 'o/v.mp4',
                  onFullscreen: full,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('لا تشغيل تلقائي: لا مشغل ولا رابط قبل الضغط', (tester) async {
      await pumpPlayer(tester);
      await tester.pumpAndSettle();
      expect(fakes, isEmpty);
      expect(find.byKey(const ValueKey('video-play')), findsOneWidget);
    });

    testWidgets('الضغط يحمّل بالرابط الموقع ثم يشغل، والزر يوقف ويستأنف', (
      tester,
    ) async {
      await pumpPlayer(tester);
      await tester.tap(find.byKey(const ValueKey('video-play')));
      await tester.pumpAndSettle();

      expect(fakes.single.url, 'https://signed/listing-videos/o/v.mp4');
      expect(fakes.single.events, ['initialize', 'play']);
      expect(find.byTooltip('إيقاف مؤقت'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('video-toggle')));
      await tester.pumpAndSettle();
      expect(fakes.single.events.last, 'pause');
      expect(find.byTooltip('تشغيل'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('video-toggle')));
      await tester.pumpAndSettle();
      expect(fakes.single.events.last, 'play');
    });

    testWidgets('فشل التحميل يعرض خطأ وإعادة محاولة تنجح', (tester) async {
      failInit = true;
      await pumpPlayer(tester);
      await tester.tap(find.byKey(const ValueKey('video-play')));
      await tester.pumpAndSettle();
      expect(find.text('تعذّر تشغيل الفيديو.'), findsOneWidget);
      expect(fakes.single.disposed, isTrue);

      failInit = false;
      await tester.tap(find.byKey(const ValueKey('video-retry')));
      await tester.pumpAndSettle();
      expect(fakes, hasLength(2));
      expect(fakes.last.events, ['initialize', 'play']);
      expect(find.text('تعذّر تشغيل الفيديو.'), findsNothing);
    });

    testWidgets('ملء الشاشة يوقف التشغيل ثم يستدعي الرد', (tester) async {
      var opened = 0;
      await pumpPlayer(tester, full: () => opened++);
      await tester.tap(find.byKey(const ValueKey('video-play')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('video-fullscreen')));
      await tester.pumpAndSettle();
      expect(fakes.single.events.last, 'pause');
      expect(opened, 1);
    });

    testWidgets('التخلص من العنصر يحرر المشغل', (tester) async {
      await pumpPlayer(tester);
      await tester.tap(find.byKey(const ValueKey('video-play')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(fakes.single.disposed, isTrue);
    });
  });
}
