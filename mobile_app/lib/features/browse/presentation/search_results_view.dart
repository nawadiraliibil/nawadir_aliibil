import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_title.dart';
import '../application/browse_providers.dart';
import '../data/listing_card.dart';
import 'auction_widgets.dart';
import 'listing_card_tile.dart';

/// قائمة نتائج بحث على دفعات: تحميل أول، حالة فراغ وخطأ، وجلب الدفعة التالية
/// قرب نهاية القائمة. تُستعمل في الرئيسية وملف المعلن.
class SearchResultsView extends ConsumerStatefulWidget {
  const SearchResultsView({
    super.key,
    required this.filters,
    this.header,
    this.emptyTitle = 'لا توجد إعلانات مطابقة',
    this.emptyMessage = 'جرّب تغيير البحث أو إزالة بعض المرشحات.',
    this.onClearFilters,
    this.showUpcomingAuctions = false,
    this.listTitle,
    this.listTitleBuilder,
    this.compact = false,
  });

  final SearchFilters filters;

  /// يظهر أعلى القائمة ويتحرك معها.
  final Widget? header;
  final String emptyTitle;
  final String emptyMessage;

  /// يظهر زر «مسح المرشحات» في حالة الفراغ حين يُمرر.
  final VoidCallback? onClearFilters;

  /// شريط «مزادات قريبة» من المزادات التي لم يمض موعدها في النتائج المعروضة.
  final bool showUpcomingAuctions;

  /// عنوان القسم فوق القائمة (مع إجراءاته)، ويظهر حين توجد نتائج.
  final Widget? listTitle;

  /// بديل لـ[listTitle] يعرف عدد ما حُمِّل وهل بقي المزيد (عدد النتائج B02).
  final Widget Function(int loaded, bool hasMore)? listTitleBuilder;

  /// عرض عمودين بدل البطاقة الكبيرة.
  final bool compact;

  @override
  ConsumerState<SearchResultsView> createState() => _SearchResultsViewState();
}

class _SearchResultsViewState extends ConsumerState<SearchResultsView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 400) {
      ref.read(searchResultsProvider(widget.filters).notifier).loadMore();
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(searchResultsProvider(widget.filters));
    await ref.read(searchResultsProvider(widget.filters).future);
  }

  Widget _resultsSliver(BuildContext context, SearchResults data) {
    final provider = searchResultsProvider(widget.filters);
    final footer = _Footer(
      results: data,
      onRetry: () => ref.read(provider.notifier).loadMore(retry: true),
    );
    void open(ListingCard card) => context.push(Routes.listing(card.listingId));

    if (widget.compact) {
      final rows = (data.items.length + 1) ~/ 2;
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        sliver: SliverList.separated(
          itemCount: rows + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, r) {
            if (r == rows) return footer;
            Widget cell(int i) => Expanded(
              child: i < data.items.length
                  ? ListingCardTile(
                      compact: true,
                      card: data.items[i],
                      onTap: () => open(data.items[i]),
                    )
                  : const SizedBox.shrink(),
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cell(r * 2),
                const SizedBox(width: 12),
                cell(r * 2 + 1),
              ],
            );
          },
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      sliver: SliverList.separated(
        itemCount: data.items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == data.items.length) return footer;
          final card = data.items[i];
          return ListingCardTile(card: card, onTap: () => open(card));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = searchResultsProvider(widget.filters);
    final results = ref.watch(provider);

    return results.when(
      loading: () => CustomScrollView(
        slivers: [
          if (widget.header != null) SliverToBoxAdapter(child: widget.header),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (e, _) => CustomScrollView(
        slivers: [
          if (widget.header != null) SliverToBoxAdapter(child: widget.header),
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'تعذّر تحميل الإعلانات',
              message: errorMessage(AppError.from(e)),
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(provider),
            ),
          ),
        ],
      ),
      data: (data) {
        // قد تكون الدفعة الأولى أقصر من الشاشة فلا يحدث تمرير يجلب التالية.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _scroll.hasClients &&
              _scroll.position.maxScrollExtent <= 0) {
            _maybeLoadMore();
          }
        });
        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (widget.header != null)
                SliverToBoxAdapter(child: widget.header),
              if (data.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.search_off_outlined,
                    title: widget.emptyTitle,
                    message: widget.emptyMessage,
                    actionLabel: widget.onClearFilters == null
                        ? null
                        : 'مسح المرشحات',
                    onAction: widget.onClearFilters,
                  ),
                )
              else ...[
                if (widget.showUpcomingAuctions)
                  SliverToBoxAdapter(
                    child: _UpcomingAuctions(items: data.items),
                  ),
                if (widget.listTitleBuilder != null || widget.listTitle != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child:
                          widget.listTitleBuilder?.call(
                            data.items.length,
                            data.hasMore,
                          ) ??
                          widget.listTitle,
                    ),
                  ),
                _resultsSliver(context, data),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.results, required this.onRetry});

  final SearchResults results;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (results.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = results.loadMoreError;
    if (error != null) {
      return Column(
        children: [
          Text(errorMessage(error), textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

/// شريط «مزادات قريبة»: أقرب المزادات موعدًا بين النتائج المعروضة.
class _UpcomingAuctions extends StatelessWidget {
  const _UpcomingAuctions({required this.items});

  final List<ListingCard> items;

  @override
  Widget build(BuildContext context) {
    final upcoming =
        items
            .where(
              (c) =>
                  c.isAuction && !c.auctionPassed && c.auctionStartsAt != null,
            )
            .toList()
          ..sort((a, b) => a.auctionStartsAt!.compareTo(b.auctionStartsAt!));
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SectionTitle('مزادات قريبة'),
          ),
          const SizedBox(height: 12),
          if (upcoming.length == 1)
            Padding(
              key: const ValueKey('upcoming-auctions'),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AuctionTicket(
                width: null,
                title: upcoming.first.title,
                startsAt: upcoming.first.auctionStartsAt!,
                place: upcoming.first.cityName,
                onTap: () =>
                    context.push(Routes.listing(upcoming.first.listingId)),
              ),
            )
          else
            SingleChildScrollView(
              key: const ValueKey('upcoming-auctions'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    for (final c in upcoming.take(6)) ...[
                      AuctionTicket(
                        title: c.title,
                        startsAt: c.auctionStartsAt!,
                        place: c.cityName,
                        onTap: () => context.push(Routes.listing(c.listingId)),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
