import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/rest.dart';
import '../../../core/supabase/rpc.dart';
import '../../browse/data/listing_card.dart';

/// بحث محفوظ: صف `my_saved_searches` (`contracts/fixtures/my-saved-search.json`).
class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.name,
    required this.filters,
    required this.createdAt,
  });

  factory SavedSearch.fromJson(Map<String, dynamic> j) => SavedSearch(
    id: j['id'] as String,
    name: j['name'] as String?,
    filters: searchFiltersFromSaved(
      Map<String, dynamic>.from(j['filters'] as Map),
    ),
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  final String id;
  final String? name;
  final SearchFilters filters;
  final DateTime createdAt;
}

/// معلن متابَع: صف `my_follows` (`contracts/fixtures/my-follow.json`).
class FollowedSeller {
  const FollowedSeller({
    required this.userId,
    required this.name,
    required this.regionName,
    required this.publishedCount,
  });

  factory FollowedSeller.fromJson(Map<String, dynamic> j) => FollowedSeller(
    userId: j['user_id'] as String,
    name: j['display_name'] as String?,
    regionName: j['region_name_ar'] as String?,
    publishedCount: j['published_listings_count'] as int,
  );

  final String userId;
  final String? name;
  final String? regionName;
  final int publishedCount;

  String get displayName => (name == null || name!.isEmpty) ? 'معلن' : name!;
}

/// مرشحات بحث محفوظ ← [SearchFilters] (دون فرز).
SearchFilters searchFiltersFromSaved(Map<String, dynamic> j) => SearchFilters(
  query: j['query'] as String?,
  regionId: (j['region_id'] as num?)?.toInt(),
  cityId: (j['city_id'] as num?)?.toInt(),
  breedId: (j['breed_id'] as num?)?.toInt(),
  sex: j['sex'] as String?,
  offerType: j['offer_type'] as String?,
  ageMin: (j['age_min'] as num?)?.toInt(),
  ageMax: (j['age_max'] as num?)?.toInt(),
  priceMin: j['price_min'] as num?,
  priceMax: j['price_max'] as num?,
);

/// مرشحات للحفظ: مفاتيح `save_search` (الفارغ والفرز لا يحفظان).
Map<String, dynamic> savedFiltersOf(SearchFilters f) {
  final q = f.query?.trim();
  return {
    if (q != null && q.isNotEmpty) 'query': q,
    'region_id': ?f.regionId,
    'city_id': ?f.cityId,
    'breed_id': ?f.breedId,
    'sex': ?f.sex,
    'offer_type': ?f.offerType,
    'age_min': ?f.ageMin,
    'age_max': ?f.ageMax,
    'price_min': ?f.priceMin,
    'price_max': ?f.priceMax,
  };
}

/// المتابعات: عمليات البحث المحفوظة والمعلنون.
class FollowsRepository {
  FollowsRepository(this._rpc, this._read);

  final RpcCaller _rpc;
  final TableReader _read;

  Future<List<SavedSearch>> savedSearches() async {
    final rows = await _read(
      'my_saved_searches',
      orderBy: 'created_at',
      ascending: false,
      limit: 100,
    );
    try {
      return [for (final r in rows) SavedSearch.fromJson(r)];
    } on TypeError catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  }

  Future<List<FollowedSeller>> sellers() async {
    final rows = await _read(
      'my_follows',
      orderBy: 'followed_at',
      ascending: false,
      limit: 200,
    );
    try {
      return [for (final r in rows) FollowedSeller.fromJson(r)];
    } on TypeError catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  }

  /// يحفظ بحثًا للمتابعة. المكرر يعيد `created=false`.
  Future<bool> saveSearch(SearchFilters filters, {String? name}) =>
      guardRpc(() async {
        final res = await _rpc(
          'save_search',
          params: {'p_filters': savedFiltersOf(filters), 'p_name': name},
        );
        return (res as Map)['created'] as bool;
      });

  Future<void> deleteSearch(String id) =>
      guardRpc(() => _rpc('delete_saved_search', params: {'p_id': id}));

  Future<void> follow(String userId) =>
      guardRpc(() => _rpc('follow_seller', params: {'p_user_id': userId}));

  Future<void> unfollow(String userId) =>
      guardRpc(() => _rpc('unfollow_seller', params: {'p_user_id': userId}));
}

final followsRepositoryProvider = Provider<FollowsRepository>(
  (ref) =>
      FollowsRepository(ref.watch(rpcProvider), ref.watch(tableReaderProvider)),
);
