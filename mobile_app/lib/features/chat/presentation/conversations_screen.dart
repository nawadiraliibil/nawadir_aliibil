import 'package:flutter/material.dart';
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
import '../../listing/presentation/media_image.dart';
import '../application/chat_providers.dart';
import '../data/chat_models.dart';

/// الرسائل (F01): محادثات صاحب الجلسة، الأحدث نشاطًا أولًا. الزائر يُدعى للدخول.
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('الرسائل')),
      body: SafeArea(
        child: !signedIn
            ? EmptyState(
                icon: Icons.chat_bubble_outline,
                title: 'سجّل الدخول لمراسلة المعلنين',
                message: 'محادثاتك خاصة بينك وبين المعلن حول إعلانه.',
                actionLabel: 'تسجيل الدخول',
                onAction: () => context.push(
                  Uri(
                    path: Routes.login,
                    queryParameters: {'from': Routes.messages},
                  ).toString(),
                ),
              )
            : ref
                  .watch(conversationsProvider)
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'تعذّر تحميل المحادثات',
                      message: errorMessage(AppError.from(e)),
                      actionLabel: 'إعادة المحاولة',
                      onAction: () => ref.invalidate(conversationsProvider),
                    ),
                    data: (items) => items.isEmpty
                        ? EmptyState(
                            icon: Icons.chat_bubble_outline,
                            title: 'لا توجد محادثات بعد',
                            message:
                                'افتح أي إعلان واضغط «راسل المعلن» لبدء محادثة.',
                            actionLabel: 'تصفح الإعلانات',
                            onAction: () => context.go(Routes.home),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(conversationsProvider);
                              await ref.read(conversationsProvider.future);
                            },
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) =>
                                  _ConversationTile(conversation: items[i]),
                            ),
                          ),
                  ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final conv = conversation;
    final title = conv.listingAvailable
        ? (conv.listingTitle ?? '')
        : 'الإعلان غير متاح';
    final last = conv.lastMessageBody == null
        ? 'لا رسائل بعد'
        : (conv.lastMessageSenderId == conv.otherUserId
              ? conv.lastMessageBody!
              : 'أنت: ${conv.lastMessageBody!}');
    final unread = conv.unreadCount > 0;

    return Semantics(
      container: true,
      button: true,
      label:
          '${conv.displayName}، $title، $last'
          '${unread ? '، ${conv.unreadCount} غير مقروءة' : ''}',
      child: Material(
        color: c.soft,
        borderRadius: BorderRadius.circular(AppShapes.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppShapes.card),
          onTap: () => context.push(Routes.chat(conv.id)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppShapes.image),
                  child: SizedBox.square(
                    dimension: 56,
                    child: ExcludeSemantics(
                      child: MediaImage(
                        bucket: conv.listingAvailable ? conv.coverBucket : null,
                        path: conv.listingAvailable ? conv.coverPath : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conv.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: unread ? FontWeight.w700 : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: c.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          last,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: unread ? FontWeight.w600 : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatShortTime(conv.activityAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (unread)
                      Badge(
                        key: const ValueKey('unread-badge'),
                        label: Text('${conv.unreadCount}'),
                      )
                    else if (conv.muted)
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 16,
                        color: c.muted,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
