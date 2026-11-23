import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/rest.dart';
import '../../../core/supabase/rpc.dart';

/// هدف البلاغ.
enum ReportTarget {
  listing('LISTING'),
  account('ACCOUNT'),
  message('MESSAGE'),
  comment('COMMENT'),
  rating('RATING');

  const ReportTarget(this.wire);
  final String wire;
}

/// أسباب البلاغ المعتمدة؛ «أخرى» تشترط وصفًا.
enum ReportReason {
  spam('SPAM', 'محتوى مزعج أو دعائي'),
  fraud('FRAUD', 'اشتباه احتيال'),
  abuse('ABUSE', 'إساءة أو ألفاظ غير لائقة'),
  misleading('MISLEADING', 'معلومات مضللة'),
  prohibited('PROHIBITED_CONTENT', 'محتوى مخالف'),
  other('OTHER', 'أخرى');

  const ReportReason(this.wire, this.label);
  final String wire;
  final String label;
}

/// نتيجة إرسال بلاغ.
class ReportReceipt {
  const ReportReceipt({required this.ref, required this.duplicate});

  /// الرقم المرجعي، مثل `R-1001`.
  final String ref;

  /// بلاغ مفتوح سابق للهدف نفسه أُعيد بدل إنشاء ثانٍ.
  final bool duplicate;
}

/// محظور من صاحب الجلسة: صف `my_blocks`.
class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.name,
    required this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> j) => BlockedUser(
    userId: j['user_id'] as String,
    name: j['display_name'] as String?,
    blockedAt: DateTime.parse(j['blocked_at'] as String),
  );

  final String userId;
  final String? name;
  final DateTime blockedAt;

  String get displayName => (name == null || name!.isEmpty) ? 'مستخدم' : name!;
}

/// البلاغات والحظر.
class SafetyRepository {
  SafetyRepository(this._rpc, this._read);

  final RpcCaller _rpc;
  final TableReader _read;

  /// يرسل بلاغًا. إعادة [requestId] لا تنشئ بلاغًا ثانيًا.
  Future<ReportReceipt> report({
    required ReportTarget target,
    required String targetId,
    required ReportReason reason,
    required String? description,
    required String requestId,
  }) => guardRpc(() async {
    final res = await _rpc(
      'submit_report',
      params: {
        'p_target_type': target.wire,
        'p_target_id': targetId,
        'p_reason': reason.wire,
        'p_description': description,
        'p_request_id': requestId,
      },
    );
    final m = Map<String, dynamic>.from(res as Map);
    return ReceiptParser.parse(m);
  });

  Future<void> block(String userId) =>
      guardRpc(() => _rpc('block_user', params: {'p_user_id': userId}));

  Future<void> unblock(String userId) =>
      guardRpc(() => _rpc('unblock_user', params: {'p_user_id': userId}));

  Future<List<BlockedUser>> blocked() async {
    final rows = await _read(
      'my_blocks',
      orderBy: 'blocked_at',
      ascending: false,
      limit: 200,
    );
    try {
      return [for (final r in rows) BlockedUser.fromJson(r)];
    } on TypeError catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  }
}

/// تحليل رد `submit_report`.
abstract final class ReceiptParser {
  static ReportReceipt parse(Map<String, dynamic> m) => ReportReceipt(
    ref: m['ref'] as String,
    duplicate: m['duplicate'] as bool? ?? false,
  );
}

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) =>
      SafetyRepository(ref.watch(rpcProvider), ref.watch(tableReaderProvider)),
);
