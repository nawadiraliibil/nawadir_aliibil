import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/realtime.dart';
import '../../auth/application/auth_providers.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';

/// محادثات صاحب الجلسة (فارغة للزائر). تتجدد عند وصول رسالة جديدة.
class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    final signedIn = ref.watch(signedInProvider).value ?? false;
    if (!signedIn) return const [];
    // أي رسالة جديدة (لي أو لي) تعيد قراءة القائمة: آخر رسالة وغير المقروء.
    final sub = ref.watch(messageInsertsProvider).listen((_) {
      ref.invalidateSelf();
    });
    ref.onDispose(sub.cancel);
    return ref.watch(chatRepositoryProvider).conversations();
  }

  /// بعد قراءة محادثة: يصفّر غير المقروء محليًا دون انتظار إعادة القراءة.
  void markReadLocally(String conversationId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final c in current)
        if (c.id == conversationId) c.copyWith(unreadCount: 0) else c,
    ]);
  }

  void setMutedLocally(String conversationId, bool muted) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final c in current)
        if (c.id == conversationId) c.copyWith(muted: muted) else c,
    ]);
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
      ConversationsNotifier.new,
    );

/// مجموع غير المقروء، لشارة تبويب الرسائل.
final unreadMessagesProvider = Provider<int>((ref) {
  final list = ref.watch(conversationsProvider).value ?? const [];
  return list.fold(0, (sum, c) => sum + c.unreadCount);
});

/// رسائل محادثة مع ما أُرسل ولم يصل بعد.
class ChatState {
  const ChatState({required this.messages});

  final List<ChatMessage> messages;
}

/// دمج رسالة واصلة: تُتجاوز إن كانت موجودة، وتحل محل نسختها المحلية بمعرف الطلب.
List<ChatMessage> mergeMessage(List<ChatMessage> list, ChatMessage incoming) {
  if (list.any((m) => m.id == incoming.id)) return list;
  final i = incoming.requestId == null
      ? -1
      : list.indexWhere(
          (m) => m.requestId == incoming.requestId && m.state != SendState.sent,
        );
  if (i >= 0) return [...list]..[i] = incoming;
  return [...list, incoming];
}

class ChatNotifier extends AsyncNotifier<ChatState> {
  ChatNotifier(this.conversationId);

  final String conversationId;

  @override
  Future<ChatState> build() async {
    final repo = ref.watch(chatRepositoryProvider);
    final sub = ref.watch(messageInsertsProvider).listen(_onInsert);
    ref.onDispose(sub.cancel);
    final messages = await repo.messages(conversationId);
    _markRead();
    return ChatState(messages: messages);
  }

  void _onInsert(Map<String, dynamic> row) {
    if (row['conversation_id'] != conversationId) return;
    final current = state.value;
    if (current == null) return;
    try {
      final msg = ChatMessage.fromJson(row);
      state = AsyncData(
        ChatState(messages: mergeMessage(current.messages, msg)),
      );
      _markRead();
    } on TypeError {
      // صف لا يطابق العقد: يُعاد تحميل الرسائل بدل إسقاط الحالة.
      ref.invalidateSelf();
    }
  }

  void _markRead() {
    // لا يحجب العرض؛ فشله يعاد عند الفتح التالي.
    ref.read(chatRepositoryProvider).markRead(conversationId).then((_) {
      if (ref.mounted) {
        ref
            .read(conversationsProvider.notifier)
            .markReadLocally(conversationId);
      }
    }, onError: (_) {});
  }

  /// يرسل [body] (مقصوصًا). تظهر الرسالة فورًا «قيد الإرسال».
  Future<void> send(String body) async {
    final text = body.trim();
    final current = state.value;
    if (text.isEmpty || current == null) return;
    final requestId = const Uuid().v4();
    state = AsyncData(
      ChatState(
        messages: [
          ...current.messages,
          ChatMessage(
            id: 'local-$requestId',
            senderId: 'me',
            body: text,
            createdAt: DateTime.now(),
            requestId: requestId,
            state: SendState.sending,
          ),
        ],
      ),
    );
    await _deliver(requestId, text);
  }

  /// إعادة محاولة رسالة فاشلة بمعرف طلبها نفسه فلا تتكرر إن وصلت أصلًا.
  Future<void> retry(String requestId) async {
    final msg = state.value?.messages
        .where((m) => m.requestId == requestId)
        .firstOrNull;
    if (msg == null || msg.state != SendState.failed) return;
    _replaceLocal(requestId, (m) => _copy(m, SendState.sending, null));
    await _deliver(requestId, msg.body);
  }

  /// يزيل رسالة فاشلة من العرض (لم تصل إلى الخادم).
  void discard(String requestId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      ChatState(
        messages: [
          for (final m in current.messages)
            if (!(m.requestId == requestId && m.state == SendState.failed)) m,
        ],
      ),
    );
  }

  Future<void> _deliver(String requestId, String text) async {
    try {
      final sent = await ref
          .read(chatRepositoryProvider)
          .send(conversationId, text, requestId);
      if (!ref.mounted) return;
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          ChatState(messages: mergeMessage(current.messages, sent)),
        );
      }
      ref.invalidate(conversationsProvider);
    } on Object catch (e) {
      if (!ref.mounted) return;
      _replaceLocal(
        requestId,
        (m) => _copy(m, SendState.failed, AppError.from(e)),
      );
    }
  }

  void _replaceLocal(String requestId, ChatMessage Function(ChatMessage) f) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      ChatState(
        messages: [
          for (final m in current.messages)
            if (m.requestId == requestId && m.state != SendState.sent)
              f(m)
            else
              m,
        ],
      ),
    );
  }

  ChatMessage _copy(ChatMessage m, SendState s, Object? error) => ChatMessage(
    id: m.id,
    senderId: m.senderId,
    body: m.body,
    createdAt: m.createdAt,
    requestId: m.requestId,
    state: s,
    error: error,
  );
}

final chatProvider = AsyncNotifierProvider.autoDispose
    .family<ChatNotifier, ChatState, String>(ChatNotifier.new);
