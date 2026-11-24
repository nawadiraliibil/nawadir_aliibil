import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'wasm_ring.dart';

/// حالة فراغ أو خطأ أو انقطاع تملأ الصفحة: أيقونة داخل حلقة متقطعة، عنوان،
/// وصف، وإجراء واحد اختياري مثل «إعادة المحاولة».
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel و onAction يُمرران معًا',
       );

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// إجراء ثانوي نصي تحت الرئيسي (مثل «الإعدادات» للزائر).
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;

    // أعلى قليلًا من المنتصف الهندسي كي لا تبدو هابطة تحت الترويسة.
    return Align(
      alignment: const Alignment(0, -0.3),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WasmRing(
              size: 76,
              strokeWidth: 2,
              dashed: true,
              child: Icon(icon, size: 28, color: c.gold),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  message!,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 22),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
