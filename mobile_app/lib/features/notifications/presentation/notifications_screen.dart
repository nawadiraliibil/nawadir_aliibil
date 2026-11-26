import 'package:flutter/material.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/app_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/format/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/application/auth_providers.dart';
import '../application/notifications_providers.dart';
import '../data/app_notification.dart';

/// الوجهة التي يفتحها الإشعار، أو `null` إن لم يكن له مورد يفتح.
String? notificationRoute(AppNotification n) => switch (n.event) {
  'message.received' => Routes.chat(n.resourceId),
  'follow.new_listing' ||
  'comment.created' ||
  'comment.replied' => Routes.listing(n.resourceId),
  'listing.approved' ||
  'listing.rejected' ||
  'listing.hidden' ||
  'listing.unhidden' => Routes.myListings,
  _ => null,
};

IconData _icon(String category) => switch (category) {
  'LISTING_STATUS' => Icons.campaign_outlined,
  'MESSAGES' => Icons.chat_bubble_outline,
  'COMMENTS' => Icons.forum_outlined,
  'FOLLOWS' => Icons.bookmark_border,
  'REPORTS' => Icons.flag_outlined,
  'ACCOUNT' => Icons.person_outline,
  _ => Icons.notifications_none,
};

/// جرس الإشعارات في الترويسة بعدد غير المقروء.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider);
    return IconButton(
      key: const ValueKey('notification-bell'),
      tooltip: unread > 0 ? 'الإشعارات، $unread غير مقروءة' : 'الإشعارات',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_none),
      ),
      onPressed: () => context.push(Routes.notifications),
    );
  }
}

/// مركز الإشعارات (G04): يعمل دون إذن الدفع.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppNotification n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final route = notificationRoute(n);
    if (route != null) context.push(route);
    if (n.isUnread) {
      try {
        await ref.read(notificationsProvider.notifier).markRead([n.id]);
      } on Object catch (e) {
        messenger.showApp(
          errorMessage(AppError.from(e)),
          kind: AppNoteKind.error,
        );
      }
    }
  }

  Future<void> _markAll(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(notificationsProvider.notifier).markAllRead();
    } on Object catch (e) {
      messenger.showApp(
        errorMessage(AppError.from(e)),
        kind: AppNoteKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider).value ?? false;
    final items = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final theme = Theme.of(context);
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        title: const Text('الإشعارات'),
        actions: [
          if (unread > 0)
            TextButton(
              key: const ValueKey('mark-all-read'),
              onPressed: () => _markAll(context, ref),
              child: const Text('تعليم الكل مقروءًا'),
            ),
          if (signedIn)
            IconButton(
              tooltip: 'إعدادات الإشعارات',
              icon: const Icon(Icons.tune),
              onPressed: () => context.push(Routes.notificationSettings),
            ),
        ],
      ),
      body: SafeArea(
        child: !signedIn
            ? EmptyState(
                icon: Icons.notifications_none,
                title: 'سجّل الدخول لمتابعة إشعاراتك',
                actionLabel: 'تسجيل الدخول',
                onAction: () => context.push(
                  Uri(
                    path: Routes.login,
                    queryParameters: {'from': Routes.notifications},
                  ).toString(),
                ),
              )
            : items.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'تعذّر تحميل الإشعارات',
                  message: errorMessage(AppError.from(e)),
                  actionLabel: 'إعادة المحاولة',
                  onAction: () => ref.invalidate(notificationsProvider),
                ),
                data: (list) => list.isEmpty
                    ? const EmptyState(
                        icon: Icons.notifications_none,
                        title: 'لا إشعارات',
                        message:
                            'ستظهر هنا قرارات إعلاناتك والرسائل والمتابعات.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(notificationsProvider);
                          await ref.read(notificationsProvider.future);
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: list.length,
                          separatorBuilder: (_, _) =>
                              Divider(height: 1, thickness: 1, color: c.hair),
                          itemBuilder: (context, i) {
                            final n = list[i];
                            return Semantics(
                              container: true,
                              button: true,
                              label:
                                  '${n.isUnread ? 'غير مقروء. ' : ''}${n.title}',
                              child: InkWell(
                                key: ValueKey('notification-${n.id}'),
                                onTap: () => _open(context, ref, n),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: AppShapes.minTouchTarget,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: c.tintGold,
                                            shape: BoxShape.circle,
                                          ),
                                          child: SizedBox.square(
                                            dimension: 40,
                                            child: Icon(
                                              _icon(n.category),
                                              size: 20,
                                              color: c.gold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ExcludeSemantics(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  n.title,
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight: n.isUnread
                                                            ? FontWeight.w700
                                                            : null,
                                                      ),
                                                ),
                                                if (n.detail != null)
                                                  Text(
                                                    n.detail!,
                                                    style: theme
                                                        .textTheme
                                                        .bodyMedium,
                                                  ),
                                                Text(
                                                  formatShortTime(n.createdAt),
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: c.muted,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (n.isUnread) ...[
                                          const SizedBox(width: 8),
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: c.gold,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const SizedBox.square(
                                              dimension: 8,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right,
                                          size: 20,
                                          color: c.muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
      ),
    );
  }
}
