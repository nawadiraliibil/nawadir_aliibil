import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/rpc.dart';
import 'listing_card.dart';
import 'listing_detail.dart';

/// عدد البطاقات في الدفعة (AD-FR-011).
const browsePageSize = 20;

/// قراءة الإعلانات المنشورة: البحث والتفاصيل. متاحة للزائر.
class BrowseRepository {
  BrowseRepository(this._rpc);

  final RpcCaller _rpc;

  /// دفعة من النتائج. [cursor] من الدفعة السابقة، بالمرشحات والفرز نفسها.
  Future<SearchPage> search(
    SearchFilters filters, {
    Map<String, dynamic>? cursor,
    int limit = browsePageSize,
  }) => guardRpc(() async {
    final res = await _rpc(
      'search_listings',
      params: filters.toParams(limit: limit, cursor: cursor),
    );
    return _parse(
      () => SearchPage.fromJson(Map<String, dynamic>.from(res as Map)),
    );
  });

  /// تفاصيل إعلان منشور. غير المنشور يرمي [AppErrorCode.notFound] لكل الأسباب.
  Future<ListingDetail> get(String listingId) => guardRpc(() async {
    final res = await _rpc('get_listing', params: {'p_listing_id': listingId});
    return _parse(
      () => ListingDetail.fromJson(Map<String, dynamic>.from(res as Map)),
    );
  });

  /// يسجل مشاهدة إعلان منشور (مرة لكل فتح لشاشة التفاصيل). يعيد العدد الجديد.
  /// المشاهدة تحسب مرة لكل شخص: [deviceId] يميز الزائر غير الداخل.
  Future<int> recordView(String listingId, {String? deviceId}) =>
      guardRpc(() async {
        final res = await _rpc(
          'record_listing_view',
          params: {'p_listing_id': listingId, 'p_device_id': ?deviceId},
        );
        return res as int;
      });

  /// يترجم المعرّف العام في رابط المشاركة إلى معرف الإعلان.
  Future<String> resolveRef(String ref) => guardRpc(() async {
    final res = await _rpc('resolve_listing_ref', params: {'p_ref': ref});
    return res as String;
  });

  /// رد لا يطابق العقد خطأ توافق لا خطأ شبكة.
  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on TypeError catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  }
}

final browseRepositoryProvider = Provider<BrowseRepository>(
  (ref) => BrowseRepository(ref.watch(rpcProvider)),
);
