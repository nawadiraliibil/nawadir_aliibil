/// إشعار في المركز: صف `notifications` (`contracts/fixtures/notifications.json`).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.event,
    required this.resourceType,
    required this.resourceId,
    required this.payload,
    required this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    category: j['category'] as String,
    event: j['event'] as String,
    resourceType: j['resource_type'] as String,
    resourceId: j['resource_id'] as String,
    payload: Map<String, dynamic>.from(j['payload'] as Map),
    readAt: j['read_at'] == null
        ? null
        : DateTime.parse(j['read_at'] as String),
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  final String id;
  final String category;
  final String event;
  final String resourceType;
  final String resourceId;
  final Map<String, dynamic> payload;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  /// نص الإشعار من نوع الحدث وحمولته. لا نص رسائل خاصة في أي إشعار.
  String get title {
    final t = payload['title'] as String?;
    final quoted = (t == null || t.isEmpty) ? '' : ' «$t»';
    return switch (event) {
      'listing.approved' => 'تم نشر إعلانك$quoted',
      'listing.rejected' => 'رُفض إعلانك$quoted',
      'listing.hidden' => 'أُخفي إعلانك$quoted',
      'listing.unhidden' => 'أُعيد إظهار إعلانك$quoted',
      'account.suspended' => 'تم تعليق حسابك',
      'account.reactivated' => 'أُعيد تفعيل حسابك',
      'message.received' => 'رسالة جديدة',
      'comment.created' => 'رد جديد على إعلانك',
      'comment.replied' => 'رد المعلن على سؤالك',
      'follow.new_listing' => 'إعلان جديد يطابق متابعتك$quoted',
      'report.closed' => 'تم إغلاق بلاغك ${payload['ref'] ?? ''}'.trim(),
      _ => 'إشعار جديد',
    };
  }

  /// سطر تفصيل اختياري: سبب القرار أو رد الإدارة.
  String? get detail {
    final parts = switch (event) {
      'listing.rejected' || 'listing.hidden' || 'account.suspended' => [
        payload['reason_label_ar'],
        payload['reason_text'],
      ],
      'report.closed' => [payload['response_text']],
      _ => const [],
    };
    final text = parts
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' — ');
    return text.isEmpty ? null : text;
  }
}
