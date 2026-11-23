import 'package:flutter/widgets.dart';

import '../../app/theme/app_colors.dart';

/// علامة «الوسم»: حلقة ذهبية صغيرة، وهي العلامة المميزة للتصميم المعتمد.
///
/// تظهر قبل عناوين الأقسام، وبحجم أكبر متقطعة في حالات الفراغ.
class WasmRing extends StatelessWidget {
  const WasmRing({
    super.key,
    this.size = 9,
    this.strokeWidth = 2.5,
    this.dashed = false,
    this.color,
    this.child,
  });

  final double size;
  final double strokeWidth;

  /// حلقة متقطعة، كما في حالات الفراغ.
  final bool dashed;

  /// لون الحلقة؛ الافتراضي ذهبي السمة.
  final Color? color;

  /// محتوى داخل الحلقة، مثل أيقونة حالة الفراغ.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(
          color: color ?? context.colors.gold,
          strokeWidth: strokeWidth,
          dashed: dashed,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashed,
  });

  final Color color;
  final double strokeWidth;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);

    if (!dashed) {
      canvas.drawOval(rect, paint);
      return;
    }

    // شرطات متساوية حول المحيط.
    const dashCount = 18;
    const sweep = 6.283185307179586 / dashCount;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashed != dashed;
}
