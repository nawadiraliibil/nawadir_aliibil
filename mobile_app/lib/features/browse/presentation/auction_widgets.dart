import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../domain/labels.dart';

/// بلاطة تاريخ المزاد (`.date-tile`): اليوم بخط كبير وتحته الشهر.
///
/// [large] هي النسخة الزرقاء الممتلئة في تفاصيل المزاد، وتضيف السنة.
class AuctionDateTile extends StatelessWidget {
  const AuctionDateTile({
    super.key,
    required this.startsAt,
    this.large = false,
  });

  final DateTime startsAt;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = saudiDateParts(startsAt);
    final fg = large ? c.bg : c.text;
    final sub = large ? c.bg : c.gold;
    return Semantics(
      label: 'موعد المزاد ${p.day} ${p.month} ${p.year}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: large ? c.info : c.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: large ? null : c.floatingShadow,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: large ? 68 : 50),
          child: Padding(
            padding: large
                ? const EdgeInsets.symmetric(horizontal: 10, vertical: 9)
                : const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${p.day}',
                  style: AppTypography.displayStyle(
                    size: large ? 32 : 21,
                    color: fg,
                    height: 1.15,
                  ),
                ),
                Text(
                  p.month,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: sub,
                    height: 1.3,
                  ),
                ),
                if (large)
                  Text(
                    '${p.year}',
                    style: TextStyle(fontSize: 11, color: sub, height: 1.3),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// تذكرة مزاد في شريط «مزادات قريبة»: بلاطة تاريخ زرقاء يفصلها خط متقطع
/// وثقبان، ثم العنوان والوقت والمدينة.
class AuctionTicket extends StatelessWidget {
  const AuctionTicket({
    super.key,
    required this.title,
    required this.startsAt,
    required this.place,
    required this.onTap,
    this.width = 272,
  });

  final String title;
  final DateTime startsAt;
  final String place;
  final VoidCallback onTap;

  /// عرض البطاقة؛ `null` يملأ العرض المتاح (حين يكون المزاد الوحيد).
  final double? width;

  static const double _dateWidth = 76;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final p = saudiDateParts(startsAt);

    return SizedBox(
      width: width,
      child: Material(
        color: c.tintBlue,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: _dateWidth,
                      color: c.info,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${p.day}',
                              style: AppTypography.displayStyle(
                                size: 30,
                                color: c.bg,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              p.month,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: c.bg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    CustomPaint(
                      painter: _DashedDivider(c.bg),
                      child: const SizedBox(width: 2),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'مزاد حضوري',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: c.info,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.displayStyle(
                                size: 16,
                                color: c.text,
                                height: 1.5,
                              ),
                            ),
                            Text(
                              '${saudiTime12(startsAt)} · $place',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ثقبا التذكرة عند حد البلاطة.
              for (final top in const [true, false])
                PositionedDirectional(
                  start: _dateWidth - 6,
                  top: top ? -7 : null,
                  bottom: top ? null : -7,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.bg,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedDivider extends CustomPainter {
  const _DashedDivider(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (double y = 0; y < size.height; y += 8) {
      canvas.drawLine(Offset(1, y), Offset(1, y + 4), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedDivider old) => old.color != color;
}
