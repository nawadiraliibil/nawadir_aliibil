import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';

/// تسمية حقل فوق الحقل المملوء، كما في التصميم المعتمد.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: context.colors.muted),
      ),
    );
  }
}

/// مجموعة قوائم مملوءة بزوايا واسعة وفواصل رفيعة بين الصفوف.
class MenuGroup extends StatelessWidget {
  const MenuGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.soft,
      borderRadius: AppShapes.cardRadius,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: c.line,
                indent: 14,
                endIndent: 14,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// صف قائمة: أيقونة داخل دائرة، عنوان، ووصف اختياري، وسهم أو أيقونة نهاية.
class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing = Icons.chevron_left,
    this.circleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final IconData? trailing;

  /// لون دائرة الأيقونة؛ الافتراضي لون السطح.
  final Color? circleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: circleColor ?? c.surface,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 38,
                  child: Icon(icon, size: 20, color: c.gold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.muted,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) Icon(trailing, size: 20, color: c.muted),
            ],
          ),
        ),
      ),
    );
  }
}
