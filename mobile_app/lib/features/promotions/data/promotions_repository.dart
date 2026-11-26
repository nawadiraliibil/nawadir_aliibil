import '../../../core/errors/app_error.dart';
import '../../../core/supabase/rpc.dart';
import 'promotion.dart';

/// نوع حدث الدعاية في `record_promotion_event`.
enum PromotionEvent {
  impression('IMPRESSION'),
  click('CLICK');

  const PromotionEvent(this.wire);
  final String wire;
}

/// قراءة الدعايات الجارية وتسجيل أحداثها. متاحة للزائر.
class PromotionsRepository {
  PromotionsRepository(this._rpc);

  final RpcCaller _rpc;

  Future<ActivePromotions> active(
    PromotionPlacement placement, {
    int? regionId,
  }) => guardRpc(() async {
    final res = await _rpc(
      'list_active_promotions',
      params: {'p_placement': placement.wire, 'p_region_id': ?regionId},
    );
    // رد لا يطابق العقد خطأ توافق لا خطأ شبكة (كما في BrowseRepository).
    try {
      return ActivePromotions.fromJson(Map<String, dynamic>.from(res as Map));
    } on TypeError catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    } on FormatException catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  });

  /// يعيد هل حسبه الخادم (الظهور مرة في الساعة والنقر مرة في الدقيقة لكل مشاهد).
  Future<bool> record(
    String promotionId,
    PromotionEvent event, {
    String? deviceId,
  }) => guardRpc(() async {
    final res = await _rpc(
      'record_promotion_event',
      params: {
        'p_promotion_id': promotionId,
        'p_kind': event.wire,
        'p_device_id': ?deviceId,
      },
    );
    return res == true;
  });
}
