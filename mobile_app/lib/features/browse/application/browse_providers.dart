import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:uuid/uuid.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/settings/settings_repository.dart';
import '../../auth/application/auth_providers.dart';
import '../data/browse_repository.dart';
import '../data/listing_card.dart';
import '../data/listing_detail.dart';

/// مرشحات الرئيسية (B01 إلى B04). تحفظ ما دام التطبيق يعمل.
class HomeFiltersNotifier extends Notifier<SearchFilters> {
  @override
  SearchFilters build() => const SearchFilters();

  void set(SearchFilters next) => state = next;

  /// يمسح المرشحات والنص معًا.
  void reset() => state = const SearchFilters();

  void setQuery(String? query) {
    final q = query?.trim();
    state = state.copyWith(query: (q == null || q.isEmpty) ? null : q);
  }
}

final homeFiltersProvider =
    NotifierProvider<HomeFiltersNotifier, SearchFilters>(
      HomeFiltersNotifier.new,
    );

/// ما عُرض من النتائج حتى الآن.
class SearchResults {
  const SearchResults({
    required this.items,
    this.nextCursor,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<ListingCard> items;

  /// مؤشر الدفعة التالية، و`null` عند انتهاء النتائج.
  final Map<String, dynamic>? nextCursor;
  final bool loadingMore;

  /// فشل جلب دفعة تالية؛ ما عُرض يبقى ظاهرًا.
  final AppError? loadMoreError;

  bool get hasMore => nextCursor != null;

  SearchResults copyWith({
    List<ListingCard>? items,
    Object? nextCursor = _keep,
    bool? loadingMore,
    Object? loadMoreError = _keep,
  }) => SearchResults(
    items: items ?? this.items,
    nextCursor: identical(nextCursor, _keep)
        ? this.nextCursor
        : nextCursor as Map<String, dynamic>?,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreError: identical(loadMoreError, _keep)
        ? this.loadMoreError
        : loadMoreError as AppError?,
  );
}

const _keep = Object();

/// نتائج بحث بمرشحات معينة، على دفعات. تغيّر المرشحات يعني مزودًا جديدًا
/// (family) فتبدأ النتائج من أولها.
class SearchResultsNotifier extends AsyncNotifier<SearchResults> {
  SearchResultsNotifier(this.filters);

  final SearchFilters filters;

  @override
  Future<SearchResults> build() async {
    final page = await ref.watch(browseRepositoryProvider).search(filters);
    return SearchResults(items: page.items, nextCursor: page.nextCursor);
  }

  /// يجلب الدفعة التالية. لا يفعل شيئًا أثناء جلب أو عند انتهاء النتائج، ولا
  /// يعيد المحاولة تلقائيًا بعد فشل (يتكرر الفشل مع كل تمرير)؛ زر «إعادة
  /// المحاولة» يمرر [retry].
  Future<void> loadMore({bool retry = false}) async {
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;
    if (current.loadMoreError != null && !retry) return;
    state = AsyncData(current.copyWith(loadingMore: true, loadMoreError: null));
    try {
      final page = await ref
          .read(browseRepositoryProvider)
          .search(filters, cursor: current.nextCursor);
      if (!ref.mounted) return;
      // لا تكرار: المعرفات المعروضة تُتخطى (إعلان جُدّد بين الدفعتين).
      final seen = {for (final c in current.items) c.listingId};
      state = AsyncData(
        SearchResults(
          items: [
            ...current.items,
            for (final c in page.items)
              if (!seen.contains(c.listingId)) c,
          ],
          nextCursor: page.nextCursor,
        ),
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreError: AppError.from(e)),
      );
    }
  }
}

final searchResultsProvider = AsyncNotifierProvider.autoDispose
    .family<SearchResultsNotifier, SearchResults, SearchFilters>(
      SearchResultsNotifier.new,
    );

/// معرف عشوائي لهذا الجهاز، يولد مرة ويحفظ، ليحسب الخادم الزائر غير الداخل
/// مشاهدة واحدة. لا يحمل بيانات شخصية.
final deviceViewIdProvider = FutureProvider<String>((ref) async {
  const key = 'device_view_id.v1';
  final prefs = ref.read(sharedPreferencesProvider);
  final saved = await prefs.getString(key);
  if (saved != null) return saved;
  final id = const Uuid().v4();
  await prefs.setString(key, id);
  return id;
});

/// يسجل مشاهدة الإعلان عند فتح التفاصيل؛ الخادم يحسبها مرة لكل شخص. الفشل
/// صامت: العدّاد لا يعطل القراءة.
final recordListingViewProvider = FutureProvider.autoDispose
    .family<void, String>((ref, id) async {
      try {
        final device = await ref.read(deviceViewIdProvider.future);
        await ref
            .read(browseRepositoryProvider)
            .recordView(id, deviceId: device);
      } on Object {
        // لا أثر على المستخدم.
      }
    });

/// تفاصيل إعلان منشور. حالة المفضلة تتبع الجلسة، فيعاد الجلب عند الدخول أو الخروج.
final listingDetailProvider = FutureProvider.autoDispose
    .family<ListingDetail, String>((ref, id) {
      ref.watch(signedInProvider);
      return ref.watch(browseRepositoryProvider).get(id);
    });
