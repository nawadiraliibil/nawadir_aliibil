import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/shell/brand_header.dart';
import '../application/browse_providers.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../follows/application/follows_providers.dart';
import '../../follows/data/follows_repository.dart';
import '../../safety/presentation/safety_actions.dart';
import '../data/listing_card.dart';
import '../../notifications/presentation/notifications_screen.dart';
import 'filter_sheet.dart';
import 'search_results_view.dart';

/// الرئيسية (B01): بحث في العناوين، ومرشحات وفرز، وقائمة الإعلانات المنشورة.
/// متاحة للزائر.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// يحفظ البحث الحالي للمتابعة. الزائر يُوجَّه إلى الدخول.
  Future<void> _followSearch(SearchFilters filters) async {
    if (!requireSignIn(context, ref)) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await ref
          .read(followsRepositoryProvider)
          .saveSearch(filters);
      ref.invalidate(savedSearchesProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            created
                ? 'تمت متابعة البحث. سيصلك تنبيه عند نشر إعلان مطابق.'
                : 'هذا البحث محفوظ لديك بالفعل.',
          ),
        ),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessage(AppError.from(e)))),
      );
    }
  }

  Future<void> _openFilters() async {
    final current = ref.read(homeFiltersProvider);
    final next = await showFilterSheet(context, current);
    if (next != null) ref.read(homeFiltersProvider.notifier).set(next);
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(homeFiltersProvider);
    // التفريغ من الخارج (مسح المرشحات) يتبعه حقل البحث.
    ref.listen(homeFiltersProvider, (_, next) {
      if ((next.query ?? '') != _search.text.trim()) {
        _search.text = next.query ?? '';
      }
    });

    final searchRow = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('home-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث في عناوين الإعلانات',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: filters.query == null
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          ref.read(homeFiltersProvider.notifier).setQuery(null);
                        },
                      ),
              ),
              onSubmitted: ref.read(homeFiltersProvider.notifier).setQuery,
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: filters.activeCount > 0,
            label: Text('${filters.activeCount}'),
            child: IconButton.filledTonal(
              key: const ValueKey('home-filters'),
              tooltip: 'المرشحات والفرز',
              icon: const Icon(Icons.tune),
              onPressed: _openFilters,
            ),
          ),
        ],
      ),
    );

    final hasCriteria = filters.activeCount > 0 || filters.query != null;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        searchRow,
        if (hasCriteria)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12),
            child: TextButton.icon(
              key: const ValueKey('follow-search'),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('متابعة هذا البحث'),
              onPressed: () => _followSearch(filters),
            ),
          ),
      ],
    );
    return Scaffold(
      appBar: const BrandHeader(actions: [NotificationBell()]),
      body: SafeArea(
        child: SearchResultsView(
          filters: filters,
          header: header,
          onClearFilters: hasCriteria
              ? ref.read(homeFiltersProvider.notifier).reset
              : null,
        ),
      ),
    );
  }
}
