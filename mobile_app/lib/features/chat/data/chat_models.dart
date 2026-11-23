/// صف من `my_conversations` (`contracts/fixtures/my-conversation.json`).
class Conversation {
  const Conversation({
    required this.id,
    required this.listingId,
    required this.isBuyer,
    required this.otherUserId,
    required this.otherName,
    required this.listingAvailable,
    required this.listingTitle,
    required this.coverBucket,
    required this.coverPath,
    required this.writable,
    required this.muted,
    required this.lastMessageAt,
    required this.lastMessageBody,
    required this.lastMessageSenderId,
    required this.unreadCount,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    id: j['conversation_id'] as String,
    listingId: j['listing_id'] as String,
    isBuyer: j['my_role'] == 'BUYER',
    otherUserId: j['other_user_id'] as String,
    otherName: j['other_display_name'] as String?,
    listingAvailable: j['listing_available'] as bool,
    listingTitle: j['listing_title'] as String?,
    coverBucket: j['cover_bucket'] as String?,
    coverPath: j['cover_path'] as String?,
    writable: j['writable'] as bool,
    muted: j['muted'] as bool,
    lastMessageAt: j['last_message_at'] == null
        ? null
        : DateTime.parse(j['last_message_at'] as String),
    lastMessageBody: j['last_message_body'] as String?,
    lastMessageSenderId: j['last_message_sender_id'] as String?,
    unreadCount: j['unread_count'] as int,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  final String id;
  final String listingId;
  final bool isBuyer;
  final String otherUserId;
  final String? otherName;

  /// `false`: الإعلان لم يعد منشورًا؛ لا عنوان ولا غلاف (لا يكشف السبب).
  final bool listingAvailable;
  final String? listingTitle;
  final String? coverBucket;
  final String? coverPath;

  /// `false`: للقراءة فقط (إعلان غير منشور أو طرف موقوف أو حظر).
  final bool writable;
  final bool muted;
  final DateTime? lastMessageAt;
  final String? lastMessageBody;
  final String? lastMessageSenderId;
  final int unreadCount;
  final DateTime createdAt;

  /// ترتيب القائمة: آخر نشاط، وإلا وقت الإنشاء.
  DateTime get activityAt => lastMessageAt ?? createdAt;

  String get displayName =>
      (otherName == null || otherName!.isEmpty) ? 'مستخدم' : otherName!;

  Conversation copyWith({int? unreadCount, bool? muted}) => Conversation(
    id: id,
    listingId: listingId,
    isBuyer: isBuyer,
    otherUserId: otherUserId,
    otherName: otherName,
    listingAvailable: listingAvailable,
    listingTitle: listingTitle,
    coverBucket: coverBucket,
    coverPath: coverPath,
    writable: writable,
    muted: muted ?? this.muted,
    lastMessageAt: lastMessageAt,
    lastMessageBody: lastMessageBody,
    lastMessageSenderId: lastMessageSenderId,
    unreadCount: unreadCount ?? this.unreadCount,
    createdAt: createdAt,
  );
}

/// حالة إرسال رسالة في الواجهة.
enum SendState { sent, sending, failed }

/// رسالة في محادثة: صف `messages` أو رسالة محلية قيد الإرسال أو فاشلة.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.requestId,
    this.state = SendState.sent,
    this.error,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: j['id'] as String,
    senderId: j['sender_id'] as String,
    body: j['body'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
    requestId: j['request_id'] as String?,
  );

  /// معرف الخادم، أو معرف محلي مؤقت لرسالة لم تصل بعد.
  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;

  /// معرف طلب الإرسال: إعادة المحاولة به لا تكرر الرسالة في الخادم.
  final String? requestId;
  final SendState state;
  final Object? error;
}
