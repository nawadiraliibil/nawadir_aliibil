import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/rest.dart';
import '../../../core/supabase/rpc.dart';
import 'rating_models.dart';

/// تقييم المعلنين: القراءة من `public_ratings` و`my_received_ratings`،
/// والكتابة بدوال. لا شراء موثق في أي نص.
class RatingsRepository {
  RatingsRepository(this._rpc, this._read);

  final RpcCaller _rpc;
  final TableReader _read;

  /// التقييمات الظاهرة لمعلن، الأحدث أولًا، حتى 200.
  Future<List<PublicRating>> forSeller(String sellerId) async {
    final rows = await _read(
      'public_ratings',
      eq: {'seller_id': sellerId},
      orderBy: 'created_at',
      ascending: false,
      limit: 200,
    );
    try {
      return [for (final r in rows) PublicRating.fromJson(r)];
    } on TypeError catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  }

  Future<List<ReceivedRating>> received() async {
    final rows = await _read(
      'my_received_ratings',
      orderBy: 'created_at',
      ascending: false,
      limit: 200,
    );
    try {
      return [for (final r in rows) ReceivedRating.fromJson(r)];
    } on TypeError catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  }

  Future<RatingEligibility> eligibility(String sellerId) => guardRpc(() async {
    final res = await _rpc(
      'get_rating_eligibility',
      params: {'p_seller_id': sellerId},
    );
    return RatingEligibility.fromJson(Map<String, dynamic>.from(res as Map));
  });

  /// تقييم جديد. إعادة [requestId] تعيد التقييم الأول دون تكرار.
  Future<void> submit({
    required String sellerId,
    required int score,
    required String? body,
    required String requestId,
  }) => guardRpc(
    () => _rpc(
      'submit_rating',
      params: {
        'p_seller_id': sellerId,
        'p_score': score,
        'p_body': body,
        'p_declaration': true,
        'p_request_id': requestId,
      },
    ),
  );

  Future<void> edit(String ratingId, int score, String? body) => guardRpc(
    () => _rpc(
      'edit_rating',
      params: {'p_rating_id': ratingId, 'p_score': score, 'p_body': body},
    ),
  );

  Future<void> reply(String ratingId, String body) => guardRpc(
    () => _rpc(
      'reply_to_rating',
      params: {'p_rating_id': ratingId, 'p_body': body},
    ),
  );

  Future<void> appeal(String ratingId, String reason) => guardRpc(
    () => _rpc(
      'appeal_rating',
      params: {'p_rating_id': ratingId, 'p_reason': reason},
    ),
  );
}

final ratingsRepositoryProvider = Provider<RatingsRepository>(
  (ref) =>
      RatingsRepository(ref.watch(rpcProvider), ref.watch(tableReaderProvider)),
);
