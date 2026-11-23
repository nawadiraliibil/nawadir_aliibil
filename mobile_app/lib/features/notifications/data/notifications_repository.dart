import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/rest.dart';
import '../../../core/supabase/rpc.dart';
import 'app_notification.dart';

/// فئات الإشعارات بأسمائها العربية وترتيب عرضها (G05).
const notificationCategories = <(String, String)>[
  ('LISTING_STATUS', 'حالة إعلاناتي'),
  ('MESSAGES', 'الرسائل'),
  ('COMMENTS', 'الردود على إعلاناتي'),
  ('FOLLOWS', 'المتابعات والإعلانات الجديدة'),
  ('REPORTS', 'البلاغات'),
  ('ACCOUNT', 'حسابي'),
  ('RATINGS', 'التقييمات'),
];

/// مركز الإشعارات وتفضيلات الدفع.
class NotificationsRepository {
  NotificationsRepository(this._rpc, this._read);

  final RpcCaller _rpc;
  final TableReader _read;

  /// آخر 100 إشعار، الأحدث أولًا.
  Future<List<AppNotification>> list() async {
    final rows = await _read(
      'notifications',
      orderBy: 'created_at',
      ascending: false,
      limit: 100,
    );
    try {
      return [for (final r in rows) AppNotification.fromJson(r)];
    } on TypeError catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  }

  /// يعلّم إشعارات مقروءة؛ يعيد عدد ما تغير.
  Future<void> markRead(List<String> ids) =>
      guardRpc(() => _rpc('mark_notifications_read', params: {'p_ids': ids}));

  /// تفضيل الدفع لكل فئة (الافتراضي مفعل).
  Future<Map<String, bool>> preferences() async {
    final rows = await _read(
      'my_notification_preferences',
      limit: 20,
      orderBy: 'category',
    );
    try {
      return {
        for (final r in rows)
          r['category'] as String: r['push_enabled'] as bool,
      };
    } on TypeError catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  }

  Future<void> setPreference(String category, bool enabled) => guardRpc(
    () => _rpc(
      'set_notification_preference',
      params: {'p_category': category, 'p_push_enabled': enabled},
    ),
  );
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(
    ref.watch(rpcProvider),
    ref.watch(tableReaderProvider),
  ),
);
