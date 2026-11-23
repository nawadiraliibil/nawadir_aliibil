import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../splash/splash_handoff.dart';
import '../splash/splash_overlay.dart';
import '../theme/app_typography.dart';

/// ترويسة الرئيسية: شعار التطبيق واسمه في البداية، وإجراءات في النهاية.
///
/// شعارها هو هدف هبوط شاشة البداية، ويبقى مخفيًا إلى أن يصل شعار البداية.
class BrandHeader extends ConsumerWidget implements PreferredSizeWidget {
  const BrandHeader({super.key, this.actions = const []});

  /// عناصر نهاية الترويسة، مثل كبسولة المنطقة وجرس التنبيهات.
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handoff = ref.watch(splashHandoffProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 12,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: handoff.logoVisible,
            builder: (context, visible, child) => Visibility(
              visible: visible,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: child!,
            ),
            child: SizedBox.square(
              key: handoff.targetKey,
              dimension: 32,
              child: Image.asset(
                logoEmblemAsset,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
          ),
          const SizedBox(width: 9),
          // مرن كي لا يتجاوز الترويسة مع تكبير النص في الشاشات الضيقة.
          Flexible(
            child: Text(
              'نوادر الإبل',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.displayStyle(
                size: 18,
                color: scheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
      actions: [...actions, const SizedBox(width: 8)],
    );
  }
}
