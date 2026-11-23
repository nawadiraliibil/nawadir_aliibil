import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/format/money.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/chat_providers.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';
import '../../safety/data/safety_repository.dart';
import '../../safety/presentation/safety_actions.dart';

/// محادثة (F02): الرسائل بحالة الإرسال، وحقل الكتابة، وكتم التنبيهات.
/// المحادثة للقراءة فقط (إعلان غير منشور أو طرف موقوف أو حظر) تعطّل الكتابة
/// دون كشف السبب.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  var _refreshedList = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    setState(() {});
    await ref.read(chatProvider(widget.conversationId).notifier).send(text);
  }

  Future<void> _toggleMute(Conversation conv) async {
    final messenger = ScaffoldMessenger.of(context);
    final next = !conv.muted;
    try {
      await ref.read(chatRepositoryProvider).setMuted(conv.id, next);
      ref.read(conversationsProvider.notifier).setMutedLocally(conv.id, next);
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessage(AppError.from(e)))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final conversations = ref.watch(conversationsProvider);
    final conv = conversations.value
        ?.where((x) => x.id == widget.conversationId)
        .firstOrNull;
    // محادثة بدأت للتو لا تكون في القائمة المحملة: تعاد قراءتها مرة واحدة.
    if (conversations.hasValue && conv == null && !_refreshedList) {
      _refreshedList = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(conversationsProvider);
      });
    }
    final chat = ref.watch(chatProvider(widget.conversationId));
    final max =
        ref.watch(publishedSettingsProvider).value?.interaction.messageMax ??
        2000;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_forward),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.messages),
        ),
        title: conv == null
            ? const Text('المحادثة')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conv.displayName, style: theme.textTheme.titleMedium),
                  Text(
                    conv.listingAvailable
                        ? (conv.listingTitle ?? '')
                        : 'الإعلان غير متاح',
                    style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
        actions: [
          if (conv != null && conv.listingAvailable)
            IconButton(
              tooltip: 'فتح الإعلان',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => context.push(Routes.listing(conv.listingId)),
            ),
          if (conv != null)
            IconButton(
              key: const ValueKey('chat-mute'),
              tooltip: conv.muted ? 'إلغاء كتم التنبيهات' : 'كتم التنبيهات',
              icon: Icon(
                conv.muted
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_none,
              ),
              onPressed: () => _toggleMute(conv),
            ),
          if (conv != null)
            PopupMenuButton<String>(
              key: const ValueKey('chat-menu'),
              tooltip: 'المزيد',
              onSelected: (v) {
                if (v == 'block') {
                  confirmAndBlock(
                    context,
                    ref,
                    userId: conv.otherUserId,
                    name: conv.displayName,
                  );
                } else {
                  showReportSheet(
                    context,
                    ref,
                    target: ReportTarget.account,
                    targetId: conv.otherUserId,
                    targetLabel: conv.displayName,
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'report',
                  child: Text('الإبلاغ عن المستخدم'),
                ),
                PopupMenuItem(value: 'block', child: Text('حظر المستخدم')),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: chat.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            final err = AppError.from(e);
            return EmptyState(
              icon: err.code == AppErrorCode.notFound
                  ? Icons.chat_bubble_outline
                  : Icons.cloud_off_outlined,
              title: err.code == AppErrorCode.notFound
                  ? 'المحادثة غير متاحة'
                  : 'تعذّر تحميل الرسائل',
              message: errorMessage(err),
              actionLabel: 'إعادة المحاولة',
              onAction: () =>
                  ref.invalidate(chatProvider(widget.conversationId)),
            );
          },
          data: (state) {
            final messages = state.messages.reversed.toList();
            final writable = conv?.writable ?? true;
            return Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Text(
                            'ابدأ المحادثة بإرسال رسالة.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          key: const ValueKey('messages'),
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          itemCount: messages.length,
                          itemBuilder: (context, i) => _Bubble(
                            message: messages[i],
                            mine: messages[i].senderId != conv?.otherUserId,
                            onRetry: (id) => ref
                                .read(
                                  chatProvider(widget.conversationId).notifier,
                                )
                                .retry(id),
                            onReport: (m) => showReportSheet(
                              context,
                              ref,
                              target: ReportTarget.message,
                              targetId: m.id,
                              targetLabel: 'الرسالة',
                            ),
                            onDiscard: (id) => ref
                                .read(
                                  chatProvider(widget.conversationId).notifier,
                                )
                                .discard(id),
                          ),
                        ),
                ),
                if (!writable)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: AppNote(
                      'هذه المحادثة للقراءة فقط ولا تقبل رسائل جديدة.',
                    ),
                  )
                else
                  _Composer(
                    controller: _input,
                    max: max,
                    onChanged: () => setState(() {}),
                    onSend: _send,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.max,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final int max;
  final VoidCallback onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final text = controller.text.trim();
    final tooLong = text.length > max;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('chat-input'),
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'اكتب رسالة',
                errorText: tooLong ? 'الحد $max حرفًا.' : null,
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const ValueKey('chat-send'),
            tooltip: 'إرسال',
            icon: const Icon(Icons.send),
            onPressed: text.isEmpty || tooLong ? null : onSend,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.onRetry,
    required this.onDiscard,
    required this.onReport,
  });

  final ChatMessage message;
  final void Function(ChatMessage) onReport;
  final bool mine;
  final void Function(String requestId) onRetry;
  final void Function(String requestId) onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final failed = message.state == SendState.failed;
    final status = switch (message.state) {
      SendState.sending => 'جارٍ الإرسال…',
      SendState.failed => 'تعذّر الإرسال',
      SendState.sent => formatShortTime(message.createdAt),
    };
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              GestureDetector(
                // الضغط المطول على رسالة الطرف الآخر الواصلة يتيح الإبلاغ عنها.
                onLongPress: !mine && message.state == SendState.sent
                    ? () => onReport(message)
                    : null,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: failed ? c.tintRed : (mine ? c.tintGold : c.soft),
                    borderRadius: BorderRadius.circular(AppShapes.card),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(message.body, style: theme.textTheme.bodyLarge),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                status,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: failed ? c.error : c.muted,
                ),
              ),
              if (failed && message.requestId != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => onRetry(message.requestId!),
                      child: const Text('إعادة المحاولة'),
                    ),
                    TextButton(
                      onPressed: () => onDiscard(message.requestId!),
                      child: const Text('حذف'),
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
