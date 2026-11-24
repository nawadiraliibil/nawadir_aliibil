import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/widgets/section_title.dart';
import '../../account/presentation/menu_group.dart';
import '../application/theme_mode.dart';

/// الإعدادات والمظهر (G06): اختيار فاتح أو داكن أو تبع النظام يطبق فعليًا،
/// ومداخل الإشعارات والشروط والمساعدة. تُفتح من ترويسة الرئيسية.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    void select(ThemeMode m) => ref.read(themeModeProvider.notifier).set(m);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.account),
        ),
        title: const Text('الإعدادات'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const SectionTitle('المظهر'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ThemeCard(
                    key: const ValueKey('theme-light'),
                    label: 'فاتح',
                    kind: _Preview.light,
                    selected: mode == ThemeMode.light,
                    onTap: () => select(ThemeMode.light),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ThemeCard(
                    key: const ValueKey('theme-dark'),
                    label: 'داكن',
                    kind: _Preview.dark,
                    selected: mode == ThemeMode.dark,
                    onTap: () => select(ThemeMode.dark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ThemeCard(
                    key: const ValueKey('theme-system'),
                    label: 'مثل النظام',
                    kind: _Preview.system,
                    selected: mode == ThemeMode.system,
                    onTap: () => select(ThemeMode.system),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionTitle('عام'),
            const SizedBox(height: 12),
            MenuGroup(
              children: [
                MenuRow(
                  icon: Icons.notifications_none,
                  title: 'إعدادات الإشعارات',
                  onTap: () => context.push(Routes.notificationSettings),
                ),
                MenuRow(
                  key: const ValueKey('settings-legal'),
                  icon: Icons.description_outlined,
                  title: 'الشروط والخصوصية والمساعدة',
                  onTap: () => context.push(Routes.legal),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _Preview { light, dark, system }

/// بطاقة اختيار مظهر بمعاينة مصغرة وتسمية تحتها.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    super.key,
    required this.label,
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final _Preview kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppShapes.card),
        child: Column(
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    // الحد فوق المعاينة، وإلا غطّته خلفيتها المعتمة فلا يظهر التحديد.
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppShapes.card),
                      border: Border.all(
                        color: selected ? c.gold : c.line,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppShapes.card - 1),
                      child: switch (kind) {
                        _Preview.light => _mini(AppColors.light),
                        _Preview.dark => _mini(AppColors.dark),
                        _Preview.system => Row(
                          textDirection: TextDirection.ltr,
                          children: [
                            Expanded(child: _mini(AppColors.dark)),
                            Expanded(child: _mini(AppColors.light)),
                          ],
                        ),
                      },
                    ),
                  ),
                ),
                // علامة واضحة على المظهر المختار.
                if (selected)
                  PositionedDirectional(
                    bottom: 8,
                    start: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.gold,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(Icons.check, size: 14, color: c.bg),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(AppColors p) => ColoredBox(
    color: kind == _Preview.light ? p.soft : p.bg,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.line),
        ),
        child: Align(
          alignment: AlignmentDirectional.topEnd,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 22,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
