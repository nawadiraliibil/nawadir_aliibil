import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/app_notification.dart';
import '../data/notifications_repository.dart';

/// إشعارات صاحب الجلسة (فارغة للزائر).
class NotificationsNotifier extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    if (!(ref.watch(signedInProvider).value ?? false)) return const [];
    return ref.watch(notificationsRepositoryProvider).list();
  }

  /// يعلّم [ids] مقروءة: يظهر ذلك فورًا ويرتد عند فشل الخادم.
  Future<void> markRead(List<String> ids) async {
    final current = state.value;
    if (current == null || ids.isEmpty) return;
    final now = DateTime.now();
    state = AsyncData([
      for (final n in current)
        if (ids.contains(n.id) && n.isUnread)
          AppNotification(
            id: n.id,
            category: n.category,
            event: n.event,
            resourceType: n.resourceType,
            resourceId: n.resourceId,
            payload: n.payload,
            readAt: now,
            createdAt: n.createdAt,
          )
        else
          n,
    ]);
    try {
      await ref.read(notificationsRepositoryProvider).markRead(ids);
    } on Object {
      if (ref.mounted) state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> markAllRead() => markRead([
    for (final n in state.value ?? const <AppNotification>[])
      if (n.isUnread) n.id,
  ]);
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<AppNotification>>(
      NotificationsNotifier.new,
    );

/// عدد غير المقروء، لشارة الجرس.
final unreadNotificationsProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider).value ?? const [];
  return list.where((n) => n.isUnread).length;
});

/// تفضيلات الدفع بحسب الفئة (فارغة للزائر).
final notificationPreferencesProvider =
    FutureProvider.autoDispose<Map<String, bool>>((ref) async {
      if (!(ref.watch(signedInProvider).value ?? false)) return const {};
      return ref.watch(notificationsRepositoryProvider).preferences();
    });
