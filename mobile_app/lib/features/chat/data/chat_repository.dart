import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/rest.dart';
import '../../../core/supabase/rpc.dart';
import 'chat_models.dart';

/// المحادثات الخاصة: القراءة من `my_conversations` و`messages`، والكتابة بدوال.
class ChatRepository {
  ChatRepository(this._rpc, this._read);

  final RpcCaller _rpc;
  final TableReader _read;

  /// محادثات صاحب الجلسة، الأحدث نشاطًا أولًا. حتى 200.
  Future<List<Conversation>> conversations() async {
    final rows = await _read(
      'my_conversations',
      limit: 200,
      orderBy: 'created_at',
      ascending: false,
    );
    try {
      final list = [for (final r in rows) Conversation.fromJson(r)];
      list.sort((a, b) => b.activityAt.compareTo(a.activityAt));
      return list;
    } on TypeError catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  }

  /// رسائل محادثة من الأقدم إلى الأحدث، حتى آخر 200.
  Future<List<ChatMessage>> messages(String conversationId) async {
    final rows = await _read(
      'messages',
      eq: {'conversation_id': conversationId},
      orderBy: 'created_at',
      ascending: false,
      limit: 200,
    );
    try {
      return [for (final r in rows.reversed) ChatMessage.fromJson(r)];
    } on TypeError catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  }

  /// يبدأ محادثة حول إعلان أو يعيد الموجودة؛ يعيد معرف المحادثة.
  Future<String> start(String listingId) => guardRpc(() async {
    final res = await _rpc(
      'start_conversation',
      params: {'p_listing_id': listingId},
    );
    return (res as Map)['conversation_id'] as String;
  });

  /// يرسل رسالة. إعادة [requestId] نفسه تعيد الرسالة الأولى دون تكرار.
  Future<ChatMessage> send(
    String conversationId,
    String body,
    String requestId,
  ) => guardRpc(() async {
    final res = await _rpc(
      'send_message',
      params: {
        'p_conversation_id': conversationId,
        'p_body': body,
        'p_request_id': requestId,
      },
    );
    return ChatMessage.fromJson({
      ...Map<String, dynamic>.from(res as Map),
      'request_id': requestId,
    });
  });

  Future<void> markRead(String conversationId) => guardRpc(
    () => _rpc(
      'mark_conversation_read',
      params: {'p_conversation_id': conversationId},
    ),
  );

  Future<void> setMuted(String conversationId, bool muted) => guardRpc(
    () => _rpc(
      'set_conversation_muted',
      params: {'p_conversation_id': conversationId, 'p_muted': muted},
    ),
  );
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) =>
      ChatRepository(ref.watch(rpcProvider), ref.watch(tableReaderProvider)),
);
