import 'package:flutter/material.dart';
import '../../../core/widgets/app_snack.dart';
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
import '../../listing/presentation/media_image.dart';
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
      messenger.showApp(
        errorMessage(AppError.from(e)),
        kind: AppNoteKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.messages),
        ),
        title: Text(
          conv == null ? 'المحادثة' : conv.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
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
                if (conv != null) _ListingContext(conversation: conv),
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
                          itemBuilder: (context, i) => _withDay(
                            messages,
                            i,
                            _Bubble(
                              message: messages[i],
                              mine: messages[i].senderId != conv?.otherUserId,
                              onRetry: (id) => ref
                                  .read(
                                    chatProvider(
                                      widget.conversationId,
                                    ).notifier,
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
                                    chatProvider(
                                      widget.conversationId,
                                    ).notifier,
                                  )
                                  .discard(id),
                            ),
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
    final c = context.colors;
    final canSend = text.isNotEmpty && !tooLong;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(
              color: c.soft,
              shape: const StadiumBorder(),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(6, 5, 18, 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('chat-input'),
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالة',
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const ValueKey('chat-send'),
                    tooltip: 'إرسال',
                    style: IconButton.styleFrom(
                      backgroundColor: c.button,
                      foregroundColor: c.buttonText,
                      disabledBackgroundColor: c.surface,
                      disabledForegroundColor: c.muted,
                      fixedSize: const Size.square(44),
                    ),
                    icon: const Icon(Icons.send_outlined, size: 20),
                    onPressed: canSend ? onSend : null,
                  ),
                ],
              ),
            ),
          ),
          if (tooLong)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 18, top: 4),
              child: Text(
                'الحد $max حرفًا.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.error),
              ),
            ),
        ],
      ),
    );
  }
}

/// شريط سياق الإعلان أعلى المحادثة: غلاف وعنوان وسهم، ويفتح الإعلان.
class _ListingContext extends StatelessWidget {
  const _ListingContext({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final conv = conversation;
    final available = conv.listingAvailable;
    final title = available ? (conv.listingTitle ?? '') : 'الإعلان غير متاح';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Semantics(
        button: available,
        label: available ? 'فتح الإعلان: $title' : title,
        excludeSemantics: true,
        child: Material(
          color: c.soft,
          borderRadius: BorderRadius.circular(AppShapes.image),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppShapes.image),
            onTap: available
                ? () => context.push(Routes.listing(conv.listingId))
                : null,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox.square(
                      dimension: 44,
                      child: MediaImage(
                        bucket: available ? conv.coverBucket : null,
                        path: available ? conv.coverPath : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: available ? null : c.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (available)
                    Icon(Icons.chevron_right, size: 20, color: c.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// يضيف فاصل اليوم فوق أول رسالة في كل يوم (القائمة معكوسة: الأقدم لاحقًا).
Widget _withDay(List<ChatMessage> messages, int i, Widget bubble) {
  final day = _dayOf(messages[i].createdAt);
  final olderIsSameDay =
      i + 1 < messages.length && _dayOf(messages[i + 1].createdAt) == day;
  if (olderIsSameDay) return bubble;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _DateDivider(day: day),
      bubble,
    ],
  );
}

DateTime _dayOf(DateTime utc) {
  final ksa = utc.toUtc().add(const Duration(hours: 3));
  return DateTime.utc(ksa.year, ksa.month, ksa.day);
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = _dayOf(DateTime.now());
    final label = day == today
        ? 'اليوم'
        : '${day.day.toString().padLeft(2, '0')}/'
              '${day.month.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: c.soft,
          shape: const StadiumBorder(),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: c.muted),
          ),
        ),
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
    final bubbleColor = mine ? c.tintGold : c.soft;
    final radius = BorderRadiusDirectional.only(
      topStart: const Radius.circular(18),
      topEnd: const Radius.circular(18),
      bottomStart: Radius.circular(mine ? 4 : 18),
      bottomEnd: Radius.circular(mine ? 18 : 4),
    );
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: GestureDetector(
            // الضغط المطول على رسالة الطرف الآخر الواصلة يتيح الإبلاغ عنها.
            onLongPress: !mine && message.state == SendState.sent
                ? () => onReport(message)
                : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: radius,
                border: failed ? Border.all(color: c.error) : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // الوقت بجانب النص القصير، وينزل سطرًا حين يطول النص.
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Text(message.body, style: theme.textTheme.bodyLarge),
                        Text(
                          status,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: failed ? c.error : c.muted,
                          ),
                        ),
                      ],
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
          ),
        ),
      ),
    );
  }
}
