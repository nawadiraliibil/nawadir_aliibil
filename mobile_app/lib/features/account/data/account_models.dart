/// نص سارٍ ينتظر موافقة المستخدم (ملخص في `get_my_account.pending_policies`).
class PendingPolicy {
  const PendingPolicy({
    required this.id,
    required this.kind,
    required this.version,
    required this.title,
  });

  factory PendingPolicy.fromJson(Map<String, dynamic> j) => PendingPolicy(
    id: j['id'] as int,
    kind: j['kind'] as String,
    version: j['version'] as int,
    title: j['title'] as String,
  );

  final int id;

  /// `TERMS` أو `PRIVACY`.
  final String kind;
  final int version;
  final String title;
}

/// نص كامل من `get_current_policies`.
class PolicyDocument {
  const PolicyDocument({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.isPlaceholder,
  });

  factory PolicyDocument.fromJson(Map<String, dynamic> j) => PolicyDocument(
    id: j['id'] as int,
    kind: j['kind'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    isPlaceholder: j['is_placeholder'] as bool? ?? false,
  );

  final int id;
  final String kind;
  final String title;
  final String body;

  /// نص مؤقت للتطوير وليس الشروط المعتمدة.
  final bool isPlaceholder;
}

/// حساب صاحب الجلسة (`get_my_account`، مخطط `account.schema.json`).
class MyAccount {
  const MyAccount({
    required this.id,
    required this.status,
    required this.displayName,
    required this.regionId,
    required this.createdAt,
    this.avatarPath,
    required this.profileComplete,
    required this.canPublish,
    required this.pendingPolicies,
  });

  factory MyAccount.fromJson(Map<String, dynamic> j) => MyAccount(
    id: j['id'] as String,
    status: j['status'] as String,
    displayName: j['display_name'] as String?,
    regionId: j['region_id'] as int?,
    avatarPath: j['avatar_path'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String),
    profileComplete: j['profile_complete'] as bool,
    canPublish: j['can_publish'] as bool,
    pendingPolicies: List.unmodifiable(
      (j['pending_policies'] as List).map(
        (e) => PendingPolicy.fromJson(e as Map<String, dynamic>),
      ),
    ),
  );

  final String id;

  /// `ACTIVE` أو `SUSPENDED`.
  final String status;
  final String? displayName;
  final int? regionId;

  /// مسار الصورة الشخصية في bucket `avatars`، أو `null` إن لم تُضبط.
  final String? avatarPath;
  final DateTime createdAt;
  final bool profileComplete;
  final bool canPublish;
  final List<PendingPolicy> pendingPolicies;

  bool get isSuspended => status == 'SUSPENDED';

  /// يحتاج المستخدم إلى شاشة إكمال الحساب (ملف ناقص أو موافقات معلقة).
  bool get needsCompletion => !profileComplete || pendingPolicies.isNotEmpty;
}
