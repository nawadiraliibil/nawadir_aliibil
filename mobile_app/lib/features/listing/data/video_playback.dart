import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

/// حالة مشغل فيديو لحظة ما.
@immutable
class VideoSnapshot {
  const VideoSnapshot({
    this.initialized = false,
    this.playing = false,
    this.hasError = false,
    this.aspectRatio = 16 / 9,
  });

  final bool initialized;
  final bool playing;
  final bool hasError;
  final double aspectRatio;
}

/// مشغل فيديو لرابط واحد، خلف واجهة قابلة للاستبدال في الاختبارات؛
/// لا يبدأ التشغيل إلا بـ[play] (لا تشغيل تلقائي).
abstract class VideoPlayback {
  ValueListenable<VideoSnapshot> get snapshot;

  /// يحمّل الفيديو. يرمي عند التعذر.
  Future<void> initialize();
  Future<void> play();
  Future<void> pause();

  /// سطح العرض؛ يصلح بعد [initialize].
  Widget buildView();
  Future<void> dispose();
}

typedef VideoPlaybackFactory = VideoPlayback Function(String url);

/// المشغل الحقيقي فوق `video_player`.
class PlatformVideoPlayback implements VideoPlayback {
  PlatformVideoPlayback(String url)
    : _controller = VideoPlayerController.networkUrl(Uri.parse(url)) {
    _controller.addListener(_sync);
  }

  final VideoPlayerController _controller;
  final _snapshot = ValueNotifier(const VideoSnapshot());

  void _sync() {
    final v = _controller.value;
    _snapshot.value = VideoSnapshot(
      initialized: v.isInitialized,
      playing: v.isPlaying,
      hasError: v.hasError,
      aspectRatio: v.isInitialized && v.aspectRatio > 0
          ? v.aspectRatio
          : 16 / 9,
    );
  }

  @override
  ValueListenable<VideoSnapshot> get snapshot => _snapshot;

  @override
  Future<void> initialize() => _controller.initialize();

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Widget buildView() => VideoPlayer(_controller);

  @override
  Future<void> dispose() async {
    _controller.removeListener(_sync);
    await _controller.dispose();
    _snapshot.dispose();
  }
}

final videoPlaybackFactoryProvider = Provider<VideoPlaybackFactory>(
  (ref) => PlatformVideoPlayback.new,
);
