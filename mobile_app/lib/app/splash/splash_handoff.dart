import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// حلقة الوصل بين شاشة البداية وشعار ترويسة الرئيسية.
///
/// الترويسة تضع [targetKey] على شعارها وتخفيه ما دام [logoVisible] خطأ.
/// شاشة البداية تقرأ موضع الشعار من المفتاح لتهبط عليه، ثم تظهره.
class SplashHandoff {
  SplashHandoff({bool logoVisible = false})
    : logoVisible = ValueNotifier(logoVisible);

  final GlobalKey targetKey = GlobalKey(debugLabel: 'splash-target');
  final ValueNotifier<bool> logoVisible;

  /// مستطيل شعار الترويسة على الشاشة، أو `null` إذا لم تكن الرئيسية معروضة.
  Rect? targetRect() {
    final box = targetKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void dispose() => logoVisible.dispose();
}

final splashHandoffProvider = Provider<SplashHandoff>((ref) {
  final handoff = SplashHandoff();
  ref.onDispose(handoff.dispose);
  return handoff;
});
