import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/app/theme/app_theme.dart';
import 'package:nawadir_aliibil/core/settings/published_settings.dart';
import 'package:nawadir_aliibil/core/settings/settings_repository.dart';
import 'package:nawadir_aliibil/core/supabase/rest.dart';
import 'package:nawadir_aliibil/features/browse/data/listing_detail.dart';
import 'package:nawadir_aliibil/features/browse/presentation/listing_detail_screen.dart';
import 'package:nawadir_aliibil/features/listing/data/video_playback.dart';

import '../../helpers/fake_video.dart';

DetailMedia _m(String id, String kind) => DetailMedia(
  mediaId: id,
  kind: kind,
  bucket: kind == 'VIDEO' ? 'listing-videos' : 'listing-images',
  path: 'o/$id',
  isCover: false,
);

void main() {
  final fakes = <FakeVideoPlayback>[];

  Future<void> pumpGallery(WidgetTester tester, {required bool enabled}) async {
    fakes.clear();
    final settings = PublishedSettings.fromJson(
      settingsWithVideo(enabled: enabled),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publishedSettingsProvider.overrideWith((ref) => settings),
          signedUrlProvider.overrideWithValue(
            (bucket, path) async => 'https://signed/$bucket/$path',
          ),
          videoPlaybackFactoryProvider.overrideWithValue((url) {
            final f = FakeVideoPlayback(url);
            fakes.add(f);
            return f;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListView(
              children: [
                ListingGallery(media: [_m('i1', 'IMAGE'), _m('v1', 'VIDEO')]),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('الفيديو معطل: المعرض صور فقط', (tester) async {
    await pumpGallery(tester, enabled: false);
    expect(find.byKey(const ValueKey('video-play')), findsNothing);
    await tester.drag(
      find.byKey(const ValueKey('gallery')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('video-play')), findsNothing);
    expect(find.byKey(const ValueKey('video-v1')), findsNothing);
  });

  testWidgets('الفيديو مفعل: صفحة فيديو بتشغيل يدوي ثم عارض كامل', (
    tester,
  ) async {
    await pumpGallery(tester, enabled: true);
    // الصفحة الأولى صورة؛ لا مشغل ولا تشغيل تلقائي.
    expect(find.byKey(const ValueKey('video-play')), findsNothing);
    expect(fakes, isEmpty);

    await tester.drag(
      find.byKey(const ValueKey('gallery')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('video-play')), findsOneWidget);
    expect(fakes, isEmpty);

    await tester.tap(find.byKey(const ValueKey('video-play')));
    await tester.pumpAndSettle();
    expect(fakes.single.url, 'https://signed/listing-videos/o/v1');
    expect(fakes.single.events, ['initialize', 'play']);

    // ملء الشاشة يوقف المشغل المضمن ويفتح العارض بفيديو غير مشغل.
    await tester.tap(find.byKey(const ValueKey('video-fullscreen')));
    await tester.pumpAndSettle();
    expect(fakes.single.events.last, 'pause');
    expect(find.byKey(const ValueKey('viewer')), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(fakes, hasLength(1));
    expect(find.byKey(const ValueKey('video-play')), findsOneWidget);
  });
}
