import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/format/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/application/auth_providers.dart';
import '../../listing/presentation/media_image.dart';
import '../application/chat_providers.dart';
import '../data/chat_models.dart';

/// الرسائل (F01): محادثات صاحب الجلسة، الأحدث نشاطًا أولًا. الزائر يُدعى للدخول.
class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// تصفية محلية بالاسم أو عنوان الإعلان، بلا استدعاء خادم.
  List<Conversation> _filter(List<Conversation> items) {
    final q = _query.trim();
    if (q.isEmpty) return items;
    return [
      for (final c in items)
        if (c.displayName.contains(q) ||
            (c.listingAvailable && (c.listingTitle ?? '').contains(q)))
          c,
    ];
  }

  Widget _list(BuildContext context, List<Conversation> shown) {
    if (shown.isEmpty) {
      return const EmptyState(
        key: ValueKey('conversations-no-match'),
        icon: Icons.search_off,
        title: 'لا نتائج مطابقة',
        message: 'جرّب اسمًا أو عنوان إعلان آخر.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(conversationsProvider);
        await ref.read(conversationsProvider.future);
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: shown.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, thickness: 1, color: context.colors.hair),
        itemBuilder: (context, i) => _ConversationTile(conversation: shown[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        : Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  4,
                                ),
                                child: TextField(
                                  key: const ValueKey('conversations-search'),
                                  controller: _search,
                                  textInputAction: TextInputAction.search,
                                  onChanged: (v) => setState(() => _query = v),
                                  decoration: InputDecoration(
                                    hintText: 'ابحث في الرسائل',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: _query.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: 'مسح البحث',
                                            icon: const Icon(Icons.close),
                                            onPressed: () {
                                              _search.clear();
                                              setState(() => _query = '');
                                            },
                                          ),
                                    border: _capsule(),
                                    enabledBorder: _capsule(),
                                    focusedBorder: _capsule(),
                                  ),
                                ),
                              ),
                              Expanded(child: _list(context, _filter(items))),
                            ],
                          ),
                  ),
      ),
    );
  }
}

OutlineInputBorder _capsule() => const OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(30)),
  borderSide: BorderSide.none,
);

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
      child: InkWell(
        onTap: () => context.push(Routes.chat(conv.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: 48,
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
                      const SizedBox(height: 2),
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
                          color: unread ? c.text : c.muted,
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
                    style: theme.textTheme.labelSmall?.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: 6),
                  if (unread)
                    Badge(
                      key: const ValueKey('unread-badge'),
                      backgroundColor: c.tintGold,
                      textColor: c.gold,
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
    );
  }
}
