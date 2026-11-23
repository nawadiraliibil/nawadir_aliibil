import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/supabase/rest.dart';

/// رابط موقع قصير الأجل لملف خاص. يُطلب مرة لكل ملف ويُعاد عند انتهاء عمر المزود.
final signedImageUrlProvider = FutureProvider.autoDispose
    .family<String, ({String bucket, String path})>(
      (ref, f) => ref.watch(signedUrlProvider)(f.bucket, f.path),
    );

/// صورة وسيط: من بايتات محلية إن وُجدت، وإلا من رابط موقع لملف في التخزين.
class MediaImage extends ConsumerWidget {
  const MediaImage({
    super.key,
    this.bytes,
    this.bucket,
    this.path,
    this.fit = BoxFit.cover,
  });

  final Uint8List? bytes;
  final String? bucket;
  final String? path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    Widget placeholder([IconData icon = Icons.image_outlined]) => ColoredBox(
      color: c.soft,
      child: Icon(icon, color: c.muted),
    );

    final local = bytes;
    if (local != null) {
      return Image.memory(
        local,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => placeholder(),
      );
    }
    if (bucket == null || path == null) return placeholder();
    final url = ref.watch(
      signedImageUrlProvider((bucket: bucket!, path: path!)),
    );
    return url.when(
      data: (u) => Image.network(
        u,
        fit: fit,
        errorBuilder: (_, _, _) => placeholder(Icons.broken_image_outlined),
      ),
      loading: placeholder,
      error: (_, _) => placeholder(Icons.broken_image_outlined),
    );
  }
}
