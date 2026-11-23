import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/rest.dart';

/// الملف العام للمعلن: صف `public_profiles` (`contracts/fixtures/public-profile.json`).
/// لا هاتف ولا مستندات؛ الملف لا يظهر لحساب بلا اسم عرض.
class SellerProfile {
  const SellerProfile({
    required this.id,
    required this.displayName,
    required this.regionName,
    required this.joinedAt,
    required this.publishedCount,
    required this.ratingAvg,
    required this.ratingCount,
  });

  factory SellerProfile.fromJson(Map<String, dynamic> j) => SellerProfile(
    id: j['id'] as String,
    displayName: j['display_name'] as String,
    regionName: j['region_name_ar'] as String?,
    joinedAt: DateTime.parse(j['joined_at'] as String),
    publishedCount: j['published_listings_count'] as int,
    ratingAvg: j['rating_avg'] as num?,
    ratingCount: j['rating_count'] as int? ?? 0,
  );

  final String id;
  final String displayName;
  final String? regionName;
  final DateTime joinedAt;
  final int publishedCount;

  /// متوسط التقييمات الظاهرة وعددها (`null` ما دام لا تقييم).
  final num? ratingAvg;
  final int ratingCount;
}

/// ملف معلن بمعرفه. غير الموجود يرمي [AppErrorCode.notFound].
final sellerProfileProvider = FutureProvider.autoDispose
    .family<SellerProfile, String>((ref, id) async {
      final rows = await ref.watch(tableReaderProvider)(
        'public_profiles',
        eq: {'id': id},
        limit: 1,
        orderBy: 'id',
      );
      if (rows.isEmpty) throw const AppError(AppErrorCode.notFound);
      try {
        return SellerProfile.fromJson(rows.first);
      } on TypeError catch (e) {
        throw AppError(AppErrorCode.unknown, cause: e);
      }
    });
