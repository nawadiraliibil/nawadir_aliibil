import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../application/theme_mode.dart';

/// الإعدادات والمظهر (G06): اختيار فاتح أو داكن أو تبع النظام يطبق فعليًا،
/// وإرشاد حجم الخط، ومداخل الإشعارات والشروط والمساعدة.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_forward),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.account),
        ),
        title: const Text('الإعدادات'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text('المظهر', style: theme.textTheme.titleMedium),
            RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (m) {
                if (m != null) ref.read(themeModeProvider.notifier).set(m);
              },
              child: const Column(
                children: [
                  RadioListTile<ThemeMode>(
                    key: ValueKey('theme-system'),
                    value: ThemeMode.system,
                    title: Text('مثل النظام'),
                  ),
                  RadioListTile<ThemeMode>(
                    key: ValueKey('theme-light'),
                    value: ThemeMode.light,
                    title: Text('فاتح'),
                  ),
                  RadioListTile<ThemeMode>(
                    key: ValueKey('theme-dark'),
                    value: ThemeMode.dark,
                    title: Text('داكن'),
                  ),
                ],
              ),
            ),
            const Divider(),
            Text('حجم الخط', style: theme.textTheme.titleMedium),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'يتبع التطبيق حجم الخط المضبوط في إعدادات جهازك. غيّره من '
                'إعدادات النظام ليكبر النص أو يصغر في كل التطبيق.',
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: const Text('إعدادات الإشعارات'),
              onTap: () => context.push(Routes.notificationSettings),
            ),
            ListTile(
              key: const ValueKey('settings-legal'),
              leading: const Icon(Icons.description_outlined),
              title: const Text('الشروط والخصوصية والمساعدة'),
              onTap: () => context.push(Routes.legal),
            ),
          ],
        ),
      ),
    );
  }
}
