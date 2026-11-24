import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/widgets/app_note.dart';
import '../application/media_controller.dart';
import '../application/post_controller.dart';
import '../data/media_backend.dart';
import 'media_image.dart';
import 'step_widgets.dart';

/// D07 — صور الإعلان وفيديوه. الفيديو يظهر فقط عند `media.video_enabled` في
/// الإعدادات المنشورة (معطل افتراضيًا)؛ دونه تبقى الخطوة صورًا فقط.
class MediaStep extends ConsumerStatefulWidget {
  const MediaStep({super.key, required this.onSaveDraft});

  final Future<void> Function() onSaveDraft;

  @override
  ConsumerState<MediaStep> createState() => _MediaStepState();
}

class _MediaStepState extends ConsumerState<MediaStep> {
  String? _blocker;
  bool _arranging = false;

  Future<void> _continue() async {
    final media = ref.read(publishedSettingsProvider).requireValue.media;
    final state = ref.read(mediaControllerProvider);
    String? block;
    if (state.anyBusy) {
      block = 'انتظر اكتمال رفع الصور.';
    } else if (state.items.any((i) => i.stage != MediaStage.ready)) {
      block = 'احذف الصور التي تعذّر قبولها أو أعد محاولة رفعها.';
    } else if (state.readyImageCount < media.imagesMin) {
      block = 'أضف ${media.imagesMin} صور على الأقل.';
    }
    setState(() => _blocker = block);
    if (block != null) return;

    setState(() => _arranging = true);
    final ok = await ref.read(mediaControllerProvider.notifier).arrange();
    if (!mounted) return;
    setState(() => _arranging = false);
    if (ok) ref.read(postControllerProvider.notifier).goTo(PostStep.contact);
  }

  Future<void> _add({required bool canAddImages}) async {
    final media = ref.read(publishedSettingsProvider).requireValue.media;
    final videoAllowed =
        media.videoEnabled && !ref.read(mediaControllerProvider).hasVideo;
    final source = await showModalBottomSheet<_Source>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canAddImages) ...[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('من المعرض'),
                onTap: () => Navigator.pop(context, _Source.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('التقاط صورة'),
                onTap: () => Navigator.pop(context, _Source.camera),
              ),
            ],
            if (videoAllowed) ...[
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('اختيار فيديو من المعرض'),
                onTap: () => Navigator.pop(context, _Source.videoGallery),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('تسجيل فيديو'),
                onTap: () => Navigator.pop(context, _Source.videoCamera),
              ),
            ],
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final controller = ref.read(mediaControllerProvider.notifier);
    final photos = ref.read(photoSourceProvider);
    switch (source) {
      case _Source.gallery:
        final picked = await photos.pickFromGallery(
          limit: controller.remainingSlots,
        );
        if (picked.isNotEmpty) controller.addPicked(picked);
      case _Source.camera:
        if (!await _explainCamera() || !mounted) return;
        final one = await photos.pickFromCamera();
        if (one != null) controller.addPicked([one]);
      case _Source.videoGallery || _Source.videoCamera:
        final isCamera = source == _Source.videoCamera;
        if (isCamera && !await _explainCamera() || !mounted) return;
        final v = await photos.pickVideo(
          camera: isCamera,
          maxBytes: media.videoMaxBytes,
          maxSeconds: media.videoMaxSeconds,
        );
        if (v != null) controller.addVideo(v);
    }
  }

  /// H09 — شرح سبب إذن الكاميرا مرة واحدة قبل أن يطلبه النظام.
  Future<bool> _explainCamera() async {
    const key = 'camera_rationale_seen';
    final prefs = ref.read(sharedPreferencesProvider);
    if (await prefs.getBool(key) ?? false) return true;
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('السماح باستخدام الكاميرا'),
        content: const Text(
          'نستخدم الكاميرا لالتقاط صور إعلانك فقط، ولا نصل إلى الكاميرا في '
          'أي وقت آخر. سيطلب النظام إذنك بعد المتابعة، ويمكنك الرفض واختيار '
          'الصور من المعرض بدلًا من ذلك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ليس الآن'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    await prefs.setBool(key, true);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final media = ref.watch(publishedSettingsProvider).requireValue.media;
    final state = ref.watch(mediaControllerProvider);
    final controller = ref.read(mediaControllerProvider.notifier);
    final theme = Theme.of(context);
    final mb = (media.imageMaxBytes / (1024 * 1024)).round();
    final cover = state.effectiveCoverKey;
    final videoEnabled = media.videoEnabled;
    final canAddImages = controller.remainingSlots > 0;
    final canAddVideo = videoEnabled && !state.hasVideo;
    final canAdd = canAddImages || canAddVideo;
    final videoMb = (media.videoMaxBytes / (1024 * 1024)).round();

    return StepFrame(
      onContinue: _continue,
      onSaveDraft: widget.onSaveDraft,
      children: [
        Text(
          videoEnabled
              ? '${media.imagesMin}–${media.imagesMax} صور حتى $mb MB للصورة · '
                    'فيديو واحد حتى ${media.videoMaxSeconds} ثانية و$videoMb MB. '
                    'الصورة الأولى غلاف الإعلان.'
              : '${media.imagesMin}–${media.imagesMax} صور، حتى $mb MB للصورة. '
                    'الصورة الأولى غلاف الإعلان.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (state.items.isNotEmpty || canAdd)
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var i = 0; i < state.items.length; i++)
                _Tile(
                  item: state.items[i],
                  index: i,
                  total: state.items.length,
                  isCover: state.items[i].key == cover,
                ),
              if (canAdd)
                _AddTile(
                  label: videoEnabled ? 'إضافة صور أو فيديو' : 'إضافة صور',
                  onTap: () => _add(canAddImages: canAddImages),
                ),
            ],
          ),
        if (!canAddImages) ...[
          const SizedBox(height: 8),
          const AppNote('بلغت الحد الأقصى من الصور'),
        ],
        for (final n in state.notices) ...[
          const SizedBox(height: 8),
          AppNote(n),
        ],
        if (state.error != null) ...[
          const SizedBox(height: 8),
          AppNote(errorMessage(state.error!), kind: AppNoteKind.error),
        ],
        if (_blocker != null) ...[
          const SizedBox(height: 8),
          AppNote(_blocker!, kind: AppNoteKind.error),
        ],
        if (_arranging) const LinearProgressIndicator(),
      ],
    );
  }
}

enum _Source { gallery, camera, videoGallery, videoCamera }

/// خانة الإضافة: إطار ذهبي متقطع بعلامة «+» (D07).
class _AddTile extends StatelessWidget {
  const _AddTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppShapes.image),
        child: CustomPaint(
          painter: _DashedBorder(c.gold, AppShapes.image),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 28, color: c.text),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}

class _Tile extends ConsumerWidget {
  const _Tile({
    required this.item,
    required this.index,
    required this.total,
    required this.isCover,
  });

  final MediaItem item;
  final int index;
  final int total;
  final bool isCover;

  String get _status => switch (item.stage) {
    MediaStage.queued => 'في الانتظار',
    MediaStage.registering || MediaStage.uploading => 'جارٍ الرفع',
    MediaStage.finalizing => 'جارٍ الفحص',
    MediaStage.ready => 'جاهزة',
    MediaStage.failed => 'مرفوضة',
    MediaStage.stalled => 'تعذّر الرفع',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final controller = ref.read(mediaControllerProvider.notifier);
    final theme = Theme.of(context);

    if (item.isVideo) {
      // بلاطة الفيديو (D07): إطار داكن بزر تشغيل وزر حذف مباشر.
      return Semantics(
        label: 'فيديو الإعلان، $_status',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppShapes.image),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF2B2118)),
              const ExcludeSemantics(
                child: Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),
              if (item.stage != MediaStage.ready)
                ColoredBox(
                  color: Colors.black54,
                  child: Center(child: _overlay(context, controller, theme)),
                ),
              PositionedDirectional(
                top: 4,
                end: 4,
                child: IconButton.filled(
                  key: const ValueKey('video-delete'),
                  tooltip: 'حذف الفيديو',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  style: IconButton.styleFrom(backgroundColor: c.surface),
                  color: c.text,
                  onPressed: () => controller.remove(item.key),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      label:
          'صورة ${index + 1} من $total، $_status${isCover ? '، الغلاف' : ''}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppShapes.image),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: MediaImage(
                bytes: item.bytes,
                bucket: item.slot?.bucket,
                path: item.slot?.objectPath,
              ),
            ),
            if (item.stage != MediaStage.ready)
              ColoredBox(
                color: Colors.black54,
                child: Center(child: _overlay(context, controller, theme)),
              ),
            if (isCover)
              PositionedDirectional(
                bottom: 6,
                start: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppShapes.chip),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Text(
                      'غلاف',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: c.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            PositionedDirectional(
              top: 4,
              end: 4,
              child: PopupMenuButton<String>(
                tooltip: 'خيارات الصورة ${index + 1}',
                padding: EdgeInsets.zero,
                icon: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.more_vert, size: 18, color: c.text),
                  ),
                ),
                onSelected: (v) {
                  switch (v) {
                    case 'cover':
                      controller.setCover(item.key);
                    case 'earlier':
                      controller.move(item.key, -1);
                    case 'later':
                      controller.move(item.key, 1);
                    case 'delete':
                      controller.remove(item.key);
                  }
                },
                itemBuilder: (context) => [
                  if (item.stage == MediaStage.ready && !isCover)
                    const PopupMenuItem(
                      value: 'cover',
                      child: Text('تعيين كغلاف'),
                    ),
                  if (index > 0)
                    const PopupMenuItem(value: 'earlier', child: Text('تقديم')),
                  if (index < total - 1)
                    const PopupMenuItem(value: 'later', child: Text('تأخير')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('حذف الصورة'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overlay(
    BuildContext context,
    MediaController controller,
    ThemeData theme,
  ) {
    final style = theme.textTheme.labelSmall?.copyWith(color: Colors.white);
    switch (item.stage) {
      case MediaStage.failed:
        return Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            mediaFailureMessage(item.failureReason),
            style: style,
            textAlign: TextAlign.center,
          ),
        );
      case MediaStage.stalled:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.error == null ? _status : errorMessage(item.error!),
              style: style,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            TextButton(
              onPressed: () => controller.retry(item.key),
              child: const Text('أعد المحاولة'),
            ),
          ],
        );
      case _:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 4),
            Text(_status, style: style),
          ],
        );
    }
  }
}
