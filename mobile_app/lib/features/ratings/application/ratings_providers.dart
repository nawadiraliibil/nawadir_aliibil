import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/rating_models.dart';
import '../data/ratings_repository.dart';

/// التقييمات الظاهرة لمعلن (متاحة للزائر).
final sellerRatingsProvider = FutureProvider.autoDispose
    .family<List<PublicRating>, String>(
      (ref, sellerId) =>
          ref.watch(ratingsRepositoryProvider).forSeller(sellerId),
    );

/// أهلية صاحب الجلسة لتقييم معلن؛ `null` للزائر.
final ratingEligibilityProvider = FutureProvider.autoDispose
    .family<RatingEligibility?, String>((ref, sellerId) async {
      if (!(ref.watch(signedInProvider).value ?? false)) return null;
      return ref.watch(ratingsRepositoryProvider).eligibility(sellerId);
    });

/// تقييمات صاحب الجلسة كمعلن (فارغة للزائر).
final receivedRatingsProvider =
    FutureProvider.autoDispose<List<ReceivedRating>>((ref) async {
      if (!(ref.watch(signedInProvider).value ?? false)) return const [];
      return ref.watch(ratingsRepositoryProvider).received();
    });
