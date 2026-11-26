import 'package:flutter/material.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/section_title.dart';
import '../../../app/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import '../../../app/router/routes.dart';
import '../../../app/shell/brand_header.dart';
import '../../../core/settings/published_settings.dart';
import '../../../core/settings/settings_repository.dart';
import '../application/browse_providers.dart';
import '../data/listing_card.dart';
import 'region_picker.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../follows/application/follows_providers.dart';
import '../../follows/data/follows_repository.dart';
import '../../safety/presentation/safety_actions.dart';
import '../../notifications/presentation/notifications_screen.dart';
import 'filter_sheet.dart';
import 'sort_sheet.dart';
import 'search_results_view.dart';
import '../../promotions/data/promotion.dart';

/// الرئيسية (B01): بحث في العناوين، ومرشحات وفرز، وقائمة الإعلانات المنشورة.
/// متاحة للزائر.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();

  /// عرض عمودين بدل البطاقة الكبيرة.
  var _compact = false;

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
      messenger.showApp(
        created
            ? 'تمت متابعة البحث. سيصلك تنبيه عند نشر إعلان مطابق.'
            : 'هذا البحث محفوظ لديك بالفعل.',
        kind: AppNoteKind.success,
      );
    } on Object catch (e) {
      messenger.showApp(
        errorMessage(AppError.from(e)),
        kind: AppNoteKind.error,
      );
    }
  }

  Future<void> _openFilters() async {
    final current = ref.read(homeFiltersProvider);
    final next = await showFilterSheet(context, current);
    if (next != null) ref.read(homeFiltersProvider.notifier).set(next);
  }

  Future<void> _openSort() async {
    final current = ref.read(homeFiltersProvider);
    final next = await showSortSheet(context, current.sort);
    if (next != null) {
      ref.read(homeFiltersProvider.notifier).set(current.copyWith(sort: next));
    }
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

    final c = context.colors;
    OutlineInputBorder capsule() => const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(30)),
      borderSide: BorderSide.none,
    );

    // حقل بحث كبسولي يحوي زر التصفية في نهايته.
    final searchRow = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        key: const ValueKey('home-search'),
        controller: _search,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'ابحث في عناوين الإعلانات',
          prefixIcon: const Icon(Icons.search),
          border: capsule(),
          enabledBorder: capsule(),
          focusedBorder: capsule(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (filters.query != null)
                IconButton(
                  tooltip: 'مسح البحث',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _search.clear();
                    ref.read(homeFiltersProvider.notifier).setQuery(null);
                  },
                ),
              IconButton(
                key: const ValueKey('results-sort'),
                tooltip: 'ترتيب: ${filters.sort.label}',
                icon: const Icon(Icons.swap_vert),
                onPressed: _openSort,
              ),
              Badge(
                isLabelVisible: filters.activeCount > 0,
                label: Text('${filters.activeCount}'),
                child: IconButton(
                  key: const ValueKey('home-filters'),
                  tooltip: 'المرشحات',
                  style: IconButton.styleFrom(
                    backgroundColor: c.surface,
                    shape: const CircleBorder(),
                  ),
                  icon: const Icon(Icons.tune),
                  onPressed: _openFilters,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        onSubmitted: ref.read(homeFiltersProvider.notifier).setQuery,
      ),
    );

    // شرائح نوع العرض السريعة، وهي نفس مرشح «نوع العرض» في ورقة التصفية.
    final typeChips = SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final (label, value) in const [
            ('الكل', null),
            ('سعر محدد', 'FIXED_PRICE'),
            ('مزاد حضوري', 'IN_PERSON_AUCTION'),
          ])
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                key: ValueKey('home-type-${value ?? 'all'}'),
                label: Text(label),
                selected: filters.offerType == value,
                onSelected: (_) => ref
                    .read(homeFiltersProvider.notifier)
                    .set(filters.copyWith(offerType: value)),
              ),
            ),
        ],
      ),
    );

    // كبسولة المنطقة في الترويسة، وتنزل فوق الشرائح في العرض الضيق أو مع
    // تكبير النص كي لا تزاحم الشعار.
    final roomy =
        MediaQuery.sizeOf(context).width >= 400 &&
        MediaQuery.textScalerOf(context).scale(10) <= 13;
    final regionPill = _RegionPill(
      filters: filters,
      lookups: ref.watch(publishedSettingsProvider).value?.lookups,
      onChanged: ref.read(homeFiltersProvider.notifier).set,
    );
    final hasCriteria = filters.activeCount > 0 || filters.query != null;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!roomy)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16),
            child: regionPill,
          ),
        searchRow,
        typeChips,
        if (hasCriteria) ...[
          const SizedBox(height: 12),
          _ResultControls(
            filters: filters,
            lookups: ref.watch(publishedSettingsProvider).value?.lookups,
            onChanged: ref.read(homeFiltersProvider.notifier).set,
          ),
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
      ],
    );
    return Scaffold(
      appBar: BrandHeader(
        actions: [
          if (roomy) regionPill,
          const NotificationBell(),
          IconButton(
            key: const ValueKey('home-settings'),
            tooltip: 'الإعدادات',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: SearchResultsView(
          filters: filters,
          header: header,
          // التصفح (والمنطقة وحدها تصفح) يعرض دعايات الرئيسية، والبحث أو أي مرشح آخر
          // يعرض دعايات نتائج البحث. المنطقة تمرر للاستهداف في الحالتين.
          promotionPlacement:
              filters.query == null &&
                  filters.activeCount - (filters.regionId == null ? 0 : 1) == 0
              ? PromotionPlacement.homeFeed
              : PromotionPlacement.searchResults,
          onClearFilters: hasCriteria
              ? ref.read(homeFiltersProvider.notifier).reset
              : null,
          showUpcomingAuctions: !hasCriteria,
          compact: _compact,
          listTitleBuilder: (loaded, hasMore) => _ListTitle(
            title: hasCriteria ? 'نتائج البحث' : 'أحدث العروض',
            countLabel: hasCriteria ? resultCountLabel(loaded, hasMore) : null,
            compact: _compact,
            onChanged: (v) => setState(() => _compact = v),
          ),
        ),
      ),
    );
  }
}

/// عنوان قسم القائمة، ومبدّل العرض الكبير والمدمج.
class _ListTitle extends StatelessWidget {
  const _ListTitle({
    required this.title,
    required this.compact,
    required this.onChanged,
    this.countLabel,
  });

  final String title;

  /// عدد النتائج المعروضة (B02)، مثل «12 إعلانًا».
  final String? countLabel;
  final bool compact;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget option(IconData icon, String tip, bool value) {
      final selected = compact == value;
      return Semantics(
        selected: selected,
        child: IconButton(
          tooltip: tip,
          style: IconButton.styleFrom(
            backgroundColor: selected ? c.surface : Colors.transparent,
            foregroundColor: selected ? c.gold : c.muted,
            minimumSize: const Size(44, 40),
          ),
          icon: Icon(icon, size: 20),
          onPressed: () => onChanged(value),
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: SectionTitle(title)),
        if (countLabel != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: Text(
              countLabel!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        DecoratedBox(
          decoration: ShapeDecoration(
            color: c.soft,
            shape: const StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                option(Icons.view_agenda_outlined, 'عرض كبير', false),
                option(Icons.grid_view_outlined, 'عرض مدمج', true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// كبسولة المنطقة في الترويسة: تعرض المنطقة أو المدينة المختارة، وتفتح B05.
class _RegionPill extends StatelessWidget {
  const _RegionPill({
    required this.filters,
    required this.lookups,
    required this.onChanged,
  });

  final SearchFilters filters;
  final Lookups? lookups;
  final ValueChanged<SearchFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = lookups;
    if (l == null) return const SizedBox.shrink();
    final c = context.colors;
    final label =
        l.city(filters.cityId)?.nameAr ??
        l.region(filters.regionId)?.nameAr ??
        'كل المناطق';
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: ActionChip(
        key: const ValueKey('home-region'),
        tooltip: 'اختيار المنطقة والمدينة',
        avatar: Icon(Icons.location_on_outlined, size: 16, color: c.gold),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 96),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        onPressed: () async {
          final choice = await showRegionPicker(
            context,
            lookups: l,
            regionId: filters.regionId,
            cityId: filters.cityId,
          );
          if (choice != null) {
            onChanged(
              filters.copyWith(
                regionId: choice.regionId,
                cityId: choice.cityId,
              ),
            );
          }
        },
      ),
    );
  }
}

/// شرائح المرشحات النشطة (B02)، وكل منها يُزال بالنقر. التصفية والترتيب
/// أيقونتان في شريط البحث.
class _ResultControls extends StatelessWidget {
  const _ResultControls({
    required this.filters,
    required this.lookups,
    required this.onChanged,
  });

  final SearchFilters filters;
  final Lookups? lookups;
  final ValueChanged<SearchFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = lookups;
    final f = filters;
    final active = <(String, SearchFilters)>[
      if (l?.region(f.regionId)?.nameAr case final n?)
        (n, f.copyWith(regionId: null, cityId: null)),
      if (l?.city(f.cityId)?.nameAr case final n?)
        (n, f.copyWith(cityId: null)),
      if (l?.breed(f.breedId)?.nameAr case final n?)
        (n, f.copyWith(breedId: null)),
      if (f.sex != null)
        (f.sex == 'MALE' ? 'ذكر' : 'أنثى', f.copyWith(sex: null)),
      // نوع العرض لا يُكرَّر هنا: تعرضه شرائح النوع السريعة أعلاه محدّدًا.
      if (f.ageMin != null || f.ageMax != null)
        (
          'العمر: ${f.ageMin ?? 0}–${f.ageMax ?? '∞'} شهرًا',
          f.copyWith(ageMin: null, ageMax: null),
        ),
      if (f.hasPriceRange)
        (
          'السعر: ${f.priceMin ?? 0}–${f.priceMax ?? '∞'}',
          f.copyWith(priceMin: null, priceMax: null),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, next) in active)
                  InputChip(
                    label: Text(label),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    deleteButtonTooltipMessage: 'إزالة: $label',
                    onDeleted: () => onChanged(next),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// عدد النتائج بصياغة عربية. النتائج تُحمَّل على دفعات، فإن بقي المزيد يُكتب
/// ما حُمِّل مع «+» بدل رقم إجمالي لا يملكه العقد.
String resultCountLabel(int n, bool hasMore) {
  if (hasMore) return '$n+ إعلان';
  return switch (n) {
    0 => 'لا إعلانات',
    1 => 'إعلان واحد',
    2 => 'إعلانان',
    <= 10 => '$n إعلانات',
    _ => '$n إعلانًا',
  };
}
