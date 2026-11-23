import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// نوع الشارة، ويحدد لونها وعلامتها.
enum AppBadgeKind {
  /// عرض بسعر محدد: ذهبي بعلامة شرطة.
  fixedPrice,

  /// مزاد حضوري: أزرق بعلامة حلقة.
  auction,

  /// حالة ناجحة، مثل «منشور».
  success,

  /// حالة مرفوضة أو مخفية.
  error,

  /// حالة انتظار، مثل «قيد المراجعة».
  pending,

  /// حالة محايدة، مثل «مؤرشف» أو «مسودة».
  neutral,
}

/// شارة كبسولية لنوع العرض أو حالة الإعلان.
class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, required this.kind});

  final String label;
  final AppBadgeKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (background, foreground) = switch (kind) {
      AppBadgeKind.fixedPrice => (c.tintGold, c.gold),
      AppBadgeKind.auction => (c.tintBlue, c.info),
      AppBadgeKind.success => (c.tintGreen, c.green),
      AppBadgeKind.error => (c.tintRed, c.error),
      AppBadgeKind.pending => (c.tintGold, c.gold),
      AppBadgeKind.neutral => (c.soft, c.text),
    };

    final marker = switch (kind) {
      AppBadgeKind.auction => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: foreground, width: 2),
        ),
      ),
      AppBadgeKind.fixedPrice => Container(
        width: 10,
        height: 3,
        decoration: BoxDecoration(
          color: foreground,
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
      ),
      _ => null,
    };

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (marker != null) ...[marker, const SizedBox(width: 6)],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
