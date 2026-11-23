import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/comment.dart';
import '../data/comments_repository.dart';

/// ردود إعلان. التعديل يعيد القراءة بعد نجاح الخادم؛ الأخطاء تُرمى للواجهة.
class CommentsNotifier extends AsyncNotifier<List<CommentThread>> {
  CommentsNotifier(this.listingId);

  final String listingId;

  @override
  Future<List<CommentThread>> build() async =>
      buildThreads(await ref.watch(commentsRepositoryProvider).list(listingId));

  Future<void> _reload() async {
    final fresh = buildThreads(
      await ref.read(commentsRepositoryProvider).list(listingId),
    );
    if (ref.mounted) state = AsyncData(fresh);
  }

  Future<void> post(String body, String requestId, {String? parentId}) async {
    await ref
        .read(commentsRepositoryProvider)
        .post(listingId, body, requestId, parentId: parentId);
    await _reload();
  }

  Future<void> edit(String commentId, String body) async {
    await ref.read(commentsRepositoryProvider).edit(commentId, body);
    await _reload();
  }

  Future<void> delete(String commentId) async {
    await ref.read(commentsRepositoryProvider).delete(commentId);
    await _reload();
  }
}

final commentsProvider = AsyncNotifierProvider.autoDispose
    .family<CommentsNotifier, List<CommentThread>, String>(
      CommentsNotifier.new,
    );
