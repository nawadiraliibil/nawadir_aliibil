import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../data/video_playback.dart';
import 'media_image.dart';

/// فيديو إعلان بتشغيل يدوي فقط (C04): تظهر بلاطة بزر تشغيل، ولا يُطلب الرابط
/// ولا يُحمّل شيء إلا بعد الضغط. أزرار تشغيل/إيقاف وحالتا تحميل وخطأ.
class VideoPlayerView extends ConsumerStatefulWidget {
  const VideoPlayerView({
    super.key,
    required this.bucket,
    required this.path,
    this.onFullscreen,
  });

  final String bucket;
  final String path;

  /// إن وُجد يظهر زر «ملء الشاشة»؛ يوقف التشغيل قبل استدعائه.
  final VoidCallback? onFullscreen;

  @override
  ConsumerState<VideoPlayerView> createState() => _VideoPlayerViewState();
}

enum _Phase { idle, loading, ready, error }

class _VideoPlayerViewState extends ConsumerState<VideoPlayerView> {
  _Phase _phase = _Phase.idle;
  VideoPlayback? _playback;
  var _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _playback?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final old = _playback;
    _playback = null;
    old?.dispose();
    setState(() => _phase = _Phase.loading);
    VideoPlayback? pb;
    try {
      final url = await ref.read(
        signedImageUrlProvider((
          bucket: widget.bucket,
          path: widget.path,
        )).future,
      );
      if (_disposed) return;
      pb = ref.read(videoPlaybackFactoryProvider)(url);
      _playback = pb;
      await pb.initialize();
      if (_disposed) return;
      await pb.play();
      if (_disposed) return;
      setState(() => _phase = _Phase.ready);
    } on Object {
      if (_disposed) return;
      if (identical(_playback, pb)) _playback = null;
      pb?.dispose();
      setState(() => _phase = _Phase.error);
    }
  }

  Future<void> _toggle(VideoPlayback pb) async {
    if (pb.snapshot.value.playing) {
      await pb.pause();
    } else {
      await pb.play();
    }
  }

  Future<void> _fullscreen() async {
    await _playback?.pause();
    widget.onFullscreen?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final Widget body;
    switch (_phase) {
      case _Phase.idle:
        body = Semantics(
          button: true,
          label: 'فيديو الإعلان. اضغط للتشغيل',
          excludeSemantics: true,
          onTap: _start,
          child: InkWell(
            key: const ValueKey('video-play'),
            onTap: _start,
            child: const Center(child: _RoundIcon(Icons.play_arrow, 56)),
          ),
        );
      case _Phase.loading:
        body = Center(
          child: Semantics(
            label: 'جارٍ تحميل الفيديو',
            child: const CircularProgressIndicator(
              key: ValueKey('video-loading'),
            ),
          ),
        );
      case _Phase.error:
        body = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'تعذّر تشغيل الفيديو.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              TextButton(
                key: const ValueKey('video-retry'),
                onPressed: _start,
                child: const Text('أعد المحاولة'),
              ),
            ],
          ),
        );
      case _Phase.ready:
        final pb = _playback!;
        body = ValueListenableBuilder<VideoSnapshot>(
          valueListenable: pb.snapshot,
          builder: (context, snap, _) {
            if (snap.hasError) {
              return Center(
                child: TextButton(
                  key: const ValueKey('video-retry'),
                  onPressed: _start,
                  child: const Text('تعذّر التشغيل. أعد المحاولة'),
                ),
              );
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: snap.aspectRatio,
                    child: pb.buildView(),
                  ),
                ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _toggle(pb),
                  ),
                ),
                Center(
                  child: IconButton(
                    key: const ValueKey('video-toggle'),
                    tooltip: snap.playing ? 'إيقاف مؤقت' : 'تشغيل',
                    iconSize: 40,
                    onPressed: () => _toggle(pb),
                    icon: _RoundIcon(
                      snap.playing ? Icons.pause : Icons.play_arrow,
                      snap.playing ? 40 : 56,
                      faded: snap.playing,
                    ),
                  ),
                ),
              ],
            );
          },
        );
    }
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          body,
          if (widget.onFullscreen != null && _phase != _Phase.loading)
            PositionedDirectional(
              top: 8,
              end: 8,
              child: IconButton.filled(
                key: const ValueKey('video-fullscreen'),
                tooltip: 'ملء الشاشة',
                style: IconButton.styleFrom(backgroundColor: c.surface),
                color: c.text,
                onPressed: _fullscreen,
                icon: const Icon(Icons.fullscreen),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon, this.size, {this.faded = false});

  final IconData icon;
  final double size;
  final bool faded;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: faded ? 0.25 : 0.55),
      shape: BoxShape.circle,
    ),
    child: SizedBox.square(
      dimension: size,
      child: Icon(icon, color: Colors.white, size: size * 0.6),
    ),
  );
}
