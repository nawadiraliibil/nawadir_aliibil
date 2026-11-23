import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/rest.dart';
import '../../../core/supabase/rpc.dart';
import 'favorite.dart';

/// مفضلة صاحب الجلسة. القراءة من `my_favorites`، والكتابة بدالتين.
class FavoritesRepository {
  FavoritesRepository(this._rpc, this._read);

  final RpcCaller _rpc;
  final TableReader _read;

  /// حتى 200 إعلان، الأحدث حفظًا أولًا.
  Future<List<Favorite>> list() async {
    final rows = await _read(
      'my_favorites',
      orderBy: 'saved_at',
      ascending: false,
      limit: 200,
    );
    try {
      return [for (final r in rows) Favorite.fromJson(r)];
    } on TypeError catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  }

  /// التكرار آمن. غير المنشور يرمي [AppErrorCode.notFound].
  Future<void> add(String listingId) =>
      guardRpc(() => _rpc('add_favorite', params: {'p_listing_id': listingId}));

  /// الإزالة المتكررة آمنة.
  Future<void> remove(String listingId) => guardRpc(
    () => _rpc('remove_favorite', params: {'p_listing_id': listingId}),
  );
}

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(
    ref.watch(rpcProvider),
    ref.watch(tableReaderProvider),
  ),
);
