import 'package:flutter/material.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/app_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/format/money.dart';
import '../../../core/settings/published_settings.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/widgets/empty_state.dart';
import '../../browse/application/browse_providers.dart';
import '../../browse/data/listing_card.dart';
import '../../browse/domain/labels.dart';
import '../application/follows_providers.dart';
import '../data/follows_repository.dart';

/// وصف عربي مقروء لمرشحات بحث محفوظ.
String describeFilters(SearchFilters f, Lookups? lookups) {
  final parts = <String>[
    if (f.query != null && f.query!.isNotEmpty) '«${f.query}»',
    if (f.regionId != null) lookups?.region(f.regionId)?.nameAr ?? 'منطقة',
    if (f.cityId != null) lookups?.city(f.cityId)?.nameAr ?? 'مدينة',
    if (f.breedId != null) lookups?.breed(f.breedId)?.nameAr ?? 'سلالة',
    if (f.sex != null) sexLabel(f.sex!),
    if (f.offerType != null)
      f.offerType == 'IN_PERSON_AUCTION' ? 'مزاد حضوري' : 'سعر محدد',
    if (f.ageMin != null || f.ageMax != null)
      'العمر ${f.ageMin ?? 0}–${f.ageMax ?? '∞'} شهرًا',
    if (f.priceMin != null || f.priceMax != null)
      'السعر ${f.priceMin == null ? 0 : formatMoney(f.priceMin!)}'
          '–${f.priceMax == null ? '∞' : formatMoney(f.priceMax!)} ريال',
  ];
  return parts.isEmpty ? 'كل الإعلانات' : parts.join(' · ');
}

/// المتابعات (G03): عمليات البحث المحفوظة والمعلنون المتابَعون.
class FollowsScreen extends ConsumerWidget {
  const FollowsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'رجوع',
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(Routes.account),
          ),
          title: const Text('المتابعات'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(56),
            child: _FollowChips(),
          ),
        ),
        body: const SafeArea(
          child: TabBarView(children: [_SearchesTab(), _SellersTab()]),
        ),
      ),
    );
  }
}

/// شرائح التبويب (بحوث محفوظة / معلنون): المحددة بلون الزر والبقية مملوءة.
class _FollowChips extends StatelessWidget {
  const _FollowChips();

  static const _labels = ['بحوث محفوظة', 'المعلنون'];

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    final c = context.colors;
    return ListenableBuilder(
      listenable: controller.animation!,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            for (var i = 0; i < _labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Semantics(
                button: true,
                selected: controller.index == i,
                child: Material(
                  color: controller.index == i ? c.button : c.soft,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => controller.animateTo(i),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            _labels[i],
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: controller.index == i
                                      ? c.buttonText
                                      : c.text,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// أيقونة داخل دائرة ذهبية فاتحة (صف قائمة G03).
class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.tintGold, shape: BoxShape.circle),
      child: SizedBox.square(
        dimension: 40,
        child: Icon(icon, size: 20, color: c.gold),
      ),
    );
  }
}

class _SearchesTab extends ConsumerWidget {
  const _SearchesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searches = ref.watch(savedSearchesProvider);
    final lookups = ref.watch(publishedSettingsProvider).value?.lookups;
    final c = context.colors;
    return searches.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'تعذّر تحميل المتابعات',
        message: errorMessage(AppError.from(e)),
        actionLabel: 'إعادة المحاولة',
        onAction: () => ref.invalidate(savedSearchesProvider),
      ),
      data: (items) => items.isEmpty
          ? const EmptyState(
              icon: Icons.bookmark_border,
              title: 'لا عمليات بحث محفوظة',
              message:
                  'ابحث أو صفِّ الإعلانات ثم اضغط «متابعة هذا البحث» لتصلك تنبيهات عند نشر إعلان مطابق.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, thickness: 1, color: c.hair),
              itemBuilder: (context, i) {
                final s = items[i];
                return ListTile(
                  key: ValueKey('saved-${s.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const _RowIcon(Icons.search),
                  title: Text(s.name ?? 'بحث محفوظ'),
                  subtitle: Text(describeFilters(s.filters, lookups)),
                  onTap: () {
                    ref.read(homeFiltersProvider.notifier).set(s.filters);
                    context.go(Routes.home);
                  },
                  trailing: IconButton(
                    key: ValueKey('saved-delete-${s.id}'),
                    tooltip: 'إلغاء المتابعة',
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ref
                            .read(followsRepositoryProvider)
                            .deleteSearch(s.id);
                        ref.invalidate(savedSearchesProvider);
                      } on Object catch (e) {
                        messenger.showApp(
                          errorMessage(AppError.from(e)),
                          kind: AppNoteKind.error,
                        );
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _SellersTab extends ConsumerWidget {
  const _SellersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellers = ref.watch(followedSellersProvider);
    final c = context.colors;
    return sellers.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'تعذّر تحميل المتابعات',
        message: errorMessage(AppError.from(e)),
        actionLabel: 'إعادة المحاولة',
        onAction: () => ref.invalidate(followedSellersProvider),
      ),
      data: (items) => items.isEmpty
          ? const EmptyState(
              icon: Icons.person_add_alt,
              title: 'لا تتابع معلنين',
              message: 'افتح ملف معلن واضغط «متابعة» لتصلك إعلاناته الجديدة.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, thickness: 1, color: c.hair),
              itemBuilder: (context, i) {
                final s = items[i];
                return ListTile(
                  key: ValueKey('followed-${s.userId}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const _RowIcon(Icons.person_outline),
                  title: Text(s.displayName),
                  subtitle: Text(
                    [
                      ?s.regionName,
                      '${s.publishedCount} إعلانًا منشورًا',
                    ].join(' · '),
                  ),
                  onTap: () => context.push(Routes.seller(s.userId)),
                  trailing: TextButton(
                    key: ValueKey('unfollow-${s.userId}'),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ref
                            .read(followsRepositoryProvider)
                            .unfollow(s.userId);
                        ref.invalidate(followedSellersProvider);
                      } on Object catch (e) {
                        messenger.showApp(
                          errorMessage(AppError.from(e)),
                          kind: AppNoteKind.error,
                        );
                      }
                    },
                    child: const Text('إلغاء المتابعة'),
                  ),
                );
              },
            ),
    );
  }
}
