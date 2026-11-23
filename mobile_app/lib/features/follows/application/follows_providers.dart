import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/follows_repository.dart';

/// عمليات البحث المحفوظة لصاحب الجلسة (فارغة للزائر).
final savedSearchesProvider = FutureProvider.autoDispose<List<SavedSearch>>((
  ref,
) async {
  if (!(ref.watch(signedInProvider).value ?? false)) return const [];
  return ref.watch(followsRepositoryProvider).savedSearches();
});

/// المعلنون المتابَعون (فارغة للزائر).
final followedSellersProvider =
    FutureProvider.autoDispose<List<FollowedSeller>>((ref) async {
      if (!(ref.watch(signedInProvider).value ?? false)) return const [];
      return ref.watch(followsRepositoryProvider).sellers();
    });

/// هل يتابع صاحب الجلسة هذا المعلن؟ `null` ما دامت القائمة لم تُحمَّل.
final isFollowingProvider = Provider.autoDispose.family<bool?, String>((
  ref,
  id,
) {
  final list = ref.watch(followedSellersProvider).value;
  return list?.any((s) => s.userId == id);
});
