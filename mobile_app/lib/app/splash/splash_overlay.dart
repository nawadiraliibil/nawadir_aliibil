import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import 'splash_handoff.dart';

/// صورة شعار التطبيق (الرمز دون الاسم).
const logoEmblemAsset = 'assets/images/logo_emblem.webp';

/// شاشة البداية A00: تغطي التطبيق عند فتحه، تعرض الشعار، ثم ينكمش ويهبط
/// على شعار ترويسة الرئيسية بينما يتلاشى الغطاء (MOBILE-SPLASH-20261121).
///
/// مع «تقليل الحركة»، أو إذا لم تكن الرئيسية معروضة، يتلاشى المشهد دون
/// انتقال مكاني.
class SplashOverlay extends ConsumerStatefulWidget {
  const SplashOverlay({super.key, required this.child});

  /// مدة عرض الشعار قبل الانتقال.
  static const hold = Duration(milliseconds: 1000);

  /// مدة هبوط الشعار على الترويسة.
  static const fly = Duration(milliseconds: 720);

  /// تلاشي الشعار بعد الهبوط، حين يحل محله شعار الترويسة.
  static const settle = Duration(milliseconds: 140);

  /// مدة التلاشي في وضع «تقليل الحركة».
  static const reducedFade = Duration(milliseconds: 200);

  final Widget child;

  @override
  ConsumerState<SplashOverlay> createState() => _SplashOverlayState();
}

enum _Phase { holding, flying, fading, done }

class _SplashOverlayState extends ConsumerState<SplashOverlay>
    with SingleTickerProviderStateMixin {
  // `preserve`: مع «تقليل الحركة» يقصّر Flutter مدد الحركة تلقائيًا إلى 5%.
  // المدد هنا محددة صراحة لكل وضع (تلاشٍ 200ms)، فتُحفظ كما هي.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  final GlobalKey _emblemKey = GlobalKey(debugLabel: 'splash-emblem');
  Timer? _holdTimer;
  _Phase _phase = _Phase.holding;
  Rect? _from;
  Rect? _to;

  SplashHandoff get _handoff => ref.read(splashHandoffProvider);

  @override
  void initState() {
    super.initState();
    _holdTimer = Timer(SplashOverlay.hold, _leave);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (!mounted) return;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final target = _handoff.targetRect();
    final emblemBox = _emblemKey.currentContext?.findRenderObject();

    if (reduced || target == null || emblemBox is! RenderBox) {
      // شعار الترويسة يظهر مباشرة ويتلاشى المشهد فوقه.
      _handoff.logoVisible.value = true;
      setState(() => _phase = _Phase.fading);
      _controller.duration = SplashOverlay.reducedFade;
      await _controller.forward(from: 0);
    } else {
      setState(() {
        _from = emblemBox.localToGlobal(Offset.zero) & emblemBox.size;
        _to = target;
        _phase = _Phase.flying;
      });
      _controller.duration = SplashOverlay.fly;
      await _controller.forward(from: 0);
      if (!mounted) return;
      // الشعار وصل: يظهر شعار الترويسة تحته ثم يتلاشى شعار البداية.
      _handoff.logoVisible.value = true;
      setState(() => _phase = _Phase.fading);
      _controller.duration = SplashOverlay.settle;
      await _controller.forward(from: 0);
    }

    if (mounted) setState(() => _phase = _Phase.done);
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.done) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // الغطاء يمنع التفاعل مع ما تحته إلى أن يبدأ الانتقال.
        AbsorbPointer(
          absorbing: _phase == _Phase.holding,
          child: ExcludeSemantics(
            excluding: _phase != _Phase.holding,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => switch (_phase) {
                _Phase.holding => _SplashScene(
                  veilOpacity: 1,
                  emblemKey: _emblemKey,
                ),
                _Phase.flying => _flying(),
                _Phase.fading => _fading(),
                _Phase.done => const SizedBox.shrink(),
              },
            ),
          ),
        ),
      ],
    );
  }

  /// الشعار يتحرك من موضعه في الوسط إلى مستطيل شعار الترويسة.
  Widget _flying() {
    final t = _controller.value;
    // الغطاء: يتلاشى في 60% من المدة بعد تأخير 10%.
    final veil = 1 - Curves.ease.transform(((t - 0.1) / 0.6).clamp(0, 1));
    // سطر الحالة: يتلاشى في 220ms.
    final status =
        1 - (t * SplashOverlay.fly.inMilliseconds / 220).clamp(0.0, 1.0);
    final rect = Rect.lerp(
      _from,
      _to,
      const Cubic(0.55, 0, 0.15, 1).transform(t),
    )!;

    return Stack(
      fit: StackFit.expand,
      children: [
        _SplashScene(
          veilOpacity: veil,
          statusOpacity: status,
          showEmblem: false,
        ),
        Positioned.fromRect(rect: rect, child: const _Emblem()),
      ],
    );
  }

  Widget _fading() {
    final opacity = 1 - _controller.value;
    final landed = _to;
    if (landed != null) {
      // بعد الهبوط: يتلاشى الشعار وحده فوق شعار الترويسة.
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fromRect(
            rect: landed,
            child: Opacity(opacity: opacity, child: const _Emblem()),
          ),
        ],
      );
    }
    return Opacity(opacity: opacity, child: const _SplashScene(veilOpacity: 1));
  }
}

/// الغطاء والكثبان والشعار وسطر الحالة.
class _SplashScene extends StatelessWidget {
  const _SplashScene({
    required this.veilOpacity,
    this.statusOpacity = 1,
    this.showEmblem = true,
    this.emblemKey,
  });

  final double veilOpacity;
  final double statusOpacity;

  /// يُخفى الشعار أثناء الانتقال لأن نسخة متحركة ترسم مكانه.
  final bool showEmblem;

  /// مفتاح مربع الشعار، ليُقرأ موضعه عند بدء الانتقال.
  final Key? emblemKey;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = MediaQuery.sizeOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // clamp(132px, min(32vw, 35vh), 224px)
    final emblemSize = math
        .min(size.width * 0.32, size.height * 0.35)
        .clamp(132.0, 224.0);
    // clamp(36px, 13vh, 125px)
    final dunesHeight = (size.height * 0.13).clamp(36.0, 125.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: veilOpacity,
          child: ColoredBox(
            color: c.bg,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: double.infinity,
                height: dunesHeight,
                child: CustomPaint(painter: _DunesPainter(dark: dark)),
              ),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  key: emblemKey,
                  dimension: emblemSize,
                  child: showEmblem ? const _Emblem() : null,
                ),
                const SizedBox(height: 9),
                Opacity(
                  opacity: statusOpacity * veilOpacity.clamp(0, 1),
                  child: const _Status(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      logoEmblemAsset,
      fit: BoxFit.contain,
      semanticLabel: 'نوادر الإبل',
    );
  }
}

/// سطر «جارٍ التحميل» بين خطين قصيرين.
class _Status extends StatelessWidget {
  const _Status();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget line() =>
        SizedBox(width: 22, height: 1, child: ColoredBox(color: c.line));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line(),
        const SizedBox(width: 11),
        // مرن كي لا يتجاوز السطر الشاشة مع تكبير النص.
        Flexible(
          child: Text(
            'جارٍ التحميل',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 14),
          ),
        ),
        const SizedBox(width: 11),
        line(),
      ],
    );
  }
}

/// كثبان أسفل شاشة البداية، منقولة من `splash-dunes.svg.html`
/// (viewBox 1440×140، ممدودة على عرض الشاشة).
class _DunesPainter extends CustomPainter {
  const _DunesPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1440, size.height / 140);

    final back = Path()
      ..moveTo(0, 58)
      ..cubicTo(163, 16, 355, 15, 576, 68)
      ..cubicTo(797, 121, 1060, 155, 1440, 47);
    final front = Path()
      ..moveTo(0, 95)
      ..cubicTo(282, 171, 580, 132, 813, 83)
      ..cubicTo(1046, 34, 1237, 26, 1440, 68);

    Path closed(Path ridge) => Path.from(ridge)
      ..lineTo(1440, 140)
      ..lineTo(0, 140)
      ..close();

    final fill1 = Color(dark ? 0xFF18282A : 0xFFF5F1EA);
    final fill2 = Color(dark ? 0xFF213432 : 0xFFEEE6D9);
    final line1 = Color(dark ? 0xFF2E443F : 0xFFE3D8C6);
    final line2 = Color(dark ? 0xFF385149 : 0xFFD9CCB6);

    Paint stroke(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    canvas
      ..drawPath(closed(back), Paint()..color = fill1)
      ..drawPath(back, stroke(line1))
      ..drawPath(closed(front), Paint()..color = fill2)
      ..drawPath(front, stroke(line2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DunesPainter oldDelegate) => oldDelegate.dark != dark;
}
