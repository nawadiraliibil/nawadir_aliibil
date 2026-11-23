/// رد عام: صف `public_comments` (`contracts/fixtures/public-comments.json`).
/// المخفي إداريًا والمحذوف يظهران بحالتهما دون نص.
class Comment {
  const Comment({
    required this.id,
    required this.listingId,
    required this.parentId,
    required this.authorId,
    required this.authorName,
    required this.isOwner,
    required this.state,
    required this.body,
    required this.editedAt,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
    id: j['comment_id'] as String,
    listingId: j['listing_id'] as String,
    parentId: j['parent_id'] as String?,
    authorId: j['author_id'] as String,
    authorName: j['author_display_name'] as String?,
    isOwner: j['is_owner'] as bool,
    state: j['state'] as String,
    body: j['body'] as String?,
    editedAt: j['edited_at'] == null
        ? null
        : DateTime.parse(j['edited_at'] as String),
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  final String id;
  final String listingId;

  /// رد المعلن على رد: مستوى واحد.
  final String? parentId;
  final String authorId;
  final String? authorName;
  final bool isOwner;

  /// `VISIBLE` أو `HIDDEN` أو `DELETED`.
  final String state;
  final String? body;
  final DateTime? editedAt;
  final DateTime createdAt;

  bool get isVisible => state == 'VISIBLE';
  String get displayName =>
      (authorName == null || authorName!.isEmpty) ? 'مستخدم' : authorName!;
}

/// خيط: رد رئيسي وردود المعلن عليه بترتيب الإنشاء.
class CommentThread {
  const CommentThread(this.root, this.replies);

  final Comment root;
  final List<Comment> replies;
}

/// يبني الخيوط من قائمة مسطحة. الرد اليتيم (رئيسه غير موجود) يُتجاهل.
List<CommentThread> buildThreads(List<Comment> all) {
  final roots = all.where((c) => c.parentId == null).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return [
    for (final r in roots)
      CommentThread(
        r,
        all.where((c) => c.parentId == r.id).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      ),
  ];
}
