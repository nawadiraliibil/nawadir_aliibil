import 'package:flutter/material.dart';
import '../../../core/widgets/app_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/push/push_service.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/notifications_providers.dart';
import '../data/notifications_repository.dart';

/// حالة إذن الدفع على الجهاز لعرضها في الإعدادات.
final pushPermissionProvider = FutureProvider.autoDispose<PushPermission>(
  (ref) => ref.watch(pushServiceProvider).permission(),
);

/// إعدادات الإشعارات (G05): الدفع لكل فئة، وحالة إذن الدفع. إيقاف فئة يوقف
/// الدفع وحده ولا يخفي إشعاراتها من المركز (AD-FR-027).
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    String category,
    bool enabled,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .setPreference(category, enabled);
      ref.invalidate(notificationPreferencesProvider);
    } on Object catch (e) {
      messenger.showApp(
        errorMessage(AppError.from(e)),
        kind: AppNoteKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final push = ref.watch(pushServiceProvider);
    final permission = ref.watch(pushPermissionProvider).value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(Routes.notifications),
        ),
        title: const Text('إعدادات الإشعارات'),
      ),
      body: SafeArea(
        child: prefs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'تعذّر تحميل الإعدادات',
            message: errorMessage(AppError.from(e)),
            actionLabel: 'إعادة المحاولة',
            onAction: () => ref.invalidate(notificationPreferencesProvider),
          ),
          data: (map) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (!push.available)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: AppNote(
                    'الإشعارات الفورية غير مفعلة على هذا الجهاز. تصلك إشعاراتك داخل '
                    'التطبيق في «الإشعارات».',
                  ),
                )
              else if (permission == PushPermission.denied)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: AppNote(
                    'إذن الإشعارات مرفوض على هذا الجهاز. فعّله من إعدادات النظام لتصلك '
                    'الإشعارات الفورية؛ مركز الإشعارات يعمل دونه.',
                  ),
                )
              else if (permission == PushPermission.notDetermined)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton.tonal(
                    key: const ValueKey('enable-push'),
                    onPressed: () async {
                      await ref.read(pushRegistrarProvider).enable();
                      ref.invalidate(pushPermissionProvider);
                    },
                    child: const Text('السماح بالإشعارات الفورية'),
                  ),
                ),
              for (final (key, label) in notificationCategories) ...[
                SwitchListTile(
                  key: ValueKey('pref-$key'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(label),
                  value: map[key] ?? true,
                  onChanged: (v) => _toggle(context, ref, key, v),
                ),
                Divider(height: 1, thickness: 1, color: context.colors.hair),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
