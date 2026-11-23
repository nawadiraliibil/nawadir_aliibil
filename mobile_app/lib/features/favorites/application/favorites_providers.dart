import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/favorite.dart';
import '../data/favorites_repository.dart';

/// مفضلة صاحب الجلسة (فارغة للزائر). تتبع الجلسة: الخروج يفرغها.
class FavoritesNotifier extends AsyncNotifier<List<Favorite>> {
  @override
  Future<List<Favorite>> build() async {
    final signedIn = ref.watch(signedInProvider).value ?? false;
    if (!signedIn) return const [];
    return ref.watch(favoritesRepositoryProvider).list();
  }

  /// يحفظ الإعلان ثم يعيد قراءة القائمة ليظهر بتاريخ الخادم. يرمي عند الفشل،
  /// والقائمة تبقى كما كانت.
  Future<void> add(String listingId) async {
    final repo = ref.read(favoritesRepositoryProvider);
    await repo.add(listingId);
    final fresh = await repo.list();
    if (ref.mounted) state = AsyncData(fresh);
  }

  /// يزيل الإعلان من القائمة فورًا بعد نجاح الخادم.
  Future<void> remove(String listingId) async {
    await ref.read(favoritesRepositoryProvider).remove(listingId);
    final current = state.value;
    if (current != null && ref.mounted) {
      state = AsyncData([
        for (final f in current)
          if (f.listingId != listingId) f,
      ]);
    }
  }
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<Favorite>>(
      FavoritesNotifier.new,
    );

/// هل الإعلان في المفضلة؟ `null` ما دامت القائمة لم تُحمَّل.
final isFavoriteProvider = Provider.family<bool?, String>((ref, id) {
  final list = ref.watch(favoritesProvider).value;
  if (list == null) return null;
  return list.any((f) => f.listingId == id);
});
