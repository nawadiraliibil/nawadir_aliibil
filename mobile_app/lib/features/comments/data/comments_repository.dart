import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/rest.dart';
import '../../../core/supabase/rpc.dart';
import 'comment.dart';

/// الردود العامة على إعلان منشور. القراءة من `public_comments`، والكتابة بدوال.
class CommentsRepository {
  CommentsRepository(this._rpc, this._read);

  final RpcCaller _rpc;
  final TableReader _read;

  /// ردود الإعلان بالأقدم أولًا، حتى 300.
  Future<List<Comment>> list(String listingId) async {
    final rows = await _read(
      'public_comments',
      eq: {'listing_id': listingId},
      orderBy: 'created_at',
      limit: 300,
    );
    try {
      return [for (final r in rows) Comment.fromJson(r)];
    } on TypeError catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  }

  /// ينشر ردًا (أو رد المعلن عند [parentId]). إعادة [requestId] لا تكرر.
  Future<void> post(
    String listingId,
    String body,
    String requestId, {
    String? parentId,
  }) => guardRpc(
    () => _rpc(
      'post_comment',
      params: {
        'p_listing_id': listingId,
        'p_body': body,
        'p_request_id': requestId,
        'p_parent_id': ?parentId,
      },
    ),
  );

  Future<void> edit(String commentId, String body) => guardRpc(
    () => _rpc(
      'edit_comment',
      params: {'p_comment_id': commentId, 'p_body': body},
    ),
  );

  Future<void> delete(String commentId) => guardRpc(
    () => _rpc('delete_comment', params: {'p_comment_id': commentId}),
  );

  /// المعلن يغلق الردود الجديدة على إعلانه أو يعيد فتحها.
  Future<void> setClosed(String listingId, bool closed) => guardRpc(
    () => _rpc(
      'set_comments_closed',
      params: {'p_listing_id': listingId, 'p_closed': closed},
    ),
  );
}

final commentsRepositoryProvider = Provider<CommentsRepository>(
  (ref) => CommentsRepository(
    ref.watch(rpcProvider),
    ref.watch(tableReaderProvider),
  ),
);
