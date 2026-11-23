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

/// D07 — صور الإعلان. الفيديو غير متاح: معطل في الإعدادات ولا معالجة له في الخادم.
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
    } else if (state.readyCount < media.imagesMin) {
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

  Future<void> _add() async {
    final source = await showModalBottomSheet<_Source>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
        final one = await photos.pickFromCamera();
        if (one != null) controller.addPicked([one]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = ref.watch(publishedSettingsProvider).requireValue.media;
    final state = ref.watch(mediaControllerProvider);
    final controller = ref.read(mediaControllerProvider.notifier);
    final theme = Theme.of(context);
    final mb = (media.imageMaxBytes / (1024 * 1024)).round();
    final cover = state.effectiveCoverKey;
    final canAdd = controller.remainingSlots > 0;

    return StepFrame(
      onContinue: _continue,
      onSaveDraft: widget.onSaveDraft,
      children: [
        Text(
          '${media.imagesMin}–${media.imagesMax} صور، حتى $mb MB للصورة. '
          'الصورة الأولى غلاف الإعلان.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (state.items.isNotEmpty)
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
            ],
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: canAdd ? _add : null,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(canAdd ? 'إضافة صور' : 'بلغت الحد الأقصى من الصور'),
        ),
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

enum _Source { gallery, camera }

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
              Positioned(
                top: 4,
                right: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.gold,
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
                        color: c.buttonText,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              child: PopupMenuButton<String>(
                tooltip: 'خيارات الصورة ${index + 1}',
                iconColor: Colors.white,
                icon: const Icon(Icons.more_vert),
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
