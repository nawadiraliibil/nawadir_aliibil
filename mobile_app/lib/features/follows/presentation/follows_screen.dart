import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
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
            icon: const Icon(Icons.arrow_forward),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(Routes.account),
          ),
          title: const Text('المتابعات'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'عمليات البحث'),
              Tab(text: 'المعلنون'),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(children: [_SearchesTab(), _SellersTab()]),
        ),
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
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final s = items[i];
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.soft,
                    borderRadius: BorderRadius.circular(AppShapes.card),
                  ),
                  child: ListTile(
                    key: ValueKey('saved-${s.id}'),
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
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(errorMessage(AppError.from(e))),
                            ),
                          );
                        }
                      },
                    ),
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
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final s = items[i];
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.soft,
                    borderRadius: BorderRadius.circular(AppShapes.card),
                  ),
                  child: ListTile(
                    key: ValueKey('followed-${s.userId}'),
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
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(errorMessage(AppError.from(e))),
                            ),
                          );
                        }
                      },
                      child: const Text('إلغاء المتابعة'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
