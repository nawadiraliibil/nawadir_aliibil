import 'package:flutter/material.dart';
import '../../../core/widgets/app_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/format/money.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/empty_state.dart';
import '../../listing/data/listing_repository.dart';
import '../../listing/presentation/media_image.dart';
import '../../browse/presentation/listing_stats.dart';
import '../application/my_listings_providers.dart';
import '../data/my_listing.dart';

/// إعلاناتي: كل إعلانات صاحب الجلسة بحالاتها.
class MyListingsScreen extends ConsumerStatefulWidget {
  const MyListingsScreen({super.key});

  @override
  ConsumerState<MyListingsScreen> createState() => _MyListingsScreenState();
}

/// شرائح التصفية بالحالة (E01): الكل ثم الحالات الأكثر استعمالًا.
const _statusFilters = <(String, String?)>[
  ('الكل', null),
  ('منشور', 'PUBLISHED'),
  ('مخفي', 'HIDDEN'),
  ('مؤرشف', 'ARCHIVED'),
  ('مسودة', 'DRAFT'),
];

class _MyListingsScreenState extends ConsumerState<MyListingsScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final listings = ref.watch(myListingsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.account),
        ),
        title: const Text('إعلاناتي'),
      ),
      body: SafeArea(
        child: listings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'تعذّر تحميل إعلاناتك',
            message: errorMessage(AppError.from(e)),
            actionLabel: 'إعادة المحاولة',
            onAction: () => ref.invalidate(myListingsProvider),
          ),
          data: (items) => items.isEmpty
              ? EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'لا توجد إعلانات بعد',
                  message: 'أضف إعلانك الأول وسيظهر هنا مع حالته.',
                  actionLabel: 'إعلان جديد',
                  onAction: () => context.push(Routes.postAd),
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        children: [
                          for (final (label, value) in _statusFilters)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(
                                key: ValueKey('status-${value ?? 'all'}'),
                                label: Text(label),
                                selected: _status == value,
                                onSelected: (_) =>
                                    setState(() => _status = value),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final shown = [
                            for (final l in items)
                              if (_status == null || l.status == _status) l,
                          ];
                          return RefreshIndicator(
                            onRefresh: () =>
                                ref.refresh(myListingsProvider.future),
                            child: shown.isEmpty
                                ? ListView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: const [
                                      SizedBox(height: 48),
                                      Center(
                                        child: Text('لا إعلانات بهذه الحالة.'),
                                      ),
                                    ],
                                  )
                                : ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      24,
                                    ),
                                    itemCount: shown.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 14),
                                    itemBuilder: (context, i) =>
                                        MyListingTile(listing: shown[i]),
                                  ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// اسم الحالة وشارتها.
(String, AppBadgeKind) statusBadge(MyListing l) => switch (l.status) {
  'DRAFT' => ('مسودة', AppBadgeKind.neutral),
  'UNDER_REVIEW' => ('قيد المراجعة', AppBadgeKind.pending),
  'REJECTED' => ('مرفوض', AppBadgeKind.error),
  'PUBLISHED' => ('منشور', AppBadgeKind.success),
  'HIDDEN' => ('مخفي', AppBadgeKind.error),
  'ARCHIVED' => ('مؤرشف', AppBadgeKind.neutral),
  _ => (l.status, AppBadgeKind.neutral),
};

class MyListingTile extends ConsumerWidget {
  const MyListingTile({super.key, required this.listing});

  final MyListing listing;

  String get _offerLine {
    if (listing.isAuction) {
      final at = listing.auctionStartsAt;
      if (listing.auctionPassed) return 'مزاد حضوري · انتهى موعده';
      return at == null
          ? 'مزاد حضوري'
          : 'مزاد حضوري · ${formatSaudiMoment(at)}';
    }
    final p = listing.price;
    return p == null ? '' : '${formatMoney(p)} ريال';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.colors;
    final (label, kind) = statusBadge(listing);
    final title = (listing.title == null || listing.title!.isEmpty)
        ? 'مسودة بلا عنوان'
        : listing.title!;
    final showReason =
        (listing.status == 'REJECTED' || listing.status == 'HIDDEN') &&
        (listing.reasonLabel != null || listing.reasonText != null);

    return Semantics(
      container: true,
      label: '$title، $label',
      child: Material(
        color: c.soft,
        borderRadius: BorderRadius.circular(AppShapes.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Routes.myListing(listing.listingId)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppShapes.image),
                      child: SizedBox.square(
                        dimension: 64,
                        child: ExcludeSemantics(
                          child: MediaImage(
                            bucket: listing.coverBucket,
                            path: listing.coverPath,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_offerLine.isNotEmpty)
                            Text(_offerLine, style: theme.textTheme.bodyMedium),
                          if (listing.status == 'PUBLISHED') ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                StatLabel(
                                  icon: Icons.favorite_border,
                                  count: listing.favoriteCount,
                                  noun: 'إعجاب',
                                ),
                                const SizedBox(width: 12),
                                StatLabel(
                                  icon: Icons.visibility_outlined,
                                  count: listing.viewCount,
                                  noun: 'مشاهدة',
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              AppBadge(label: label, kind: kind),
                              if (listing.status == 'PUBLISHED' &&
                                  listing.hasDraft)
                                const AppBadge(
                                  label: 'تعديل قيد التحرير',
                                  kind: AppBadgeKind.pending,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _Menu(listing: listing),
                  ],
                ),
                if (showReason) ...[
                  const SizedBox(height: 10),
                  AppNote(
                    [?listing.reasonLabel, ?listing.reasonText].join(' — '),
                    kind: AppNoteKind.error,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Action { resume, edit, delete }

class _Menu extends ConsumerWidget {
  const _Menu({required this.listing});

  final MyListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      if (listing.canResume)
        const PopupMenuItem(
          value: _Action.resume,
          child: Text('متابعة التحرير'),
        ),
      if (listing.canEdit)
        PopupMenuItem(
          value: _Action.edit,
          child: Text(listing.isRejected ? 'تعديل وإعادة الإرسال' : 'تعديل'),
        ),
      if (listing.canDelete)
        const PopupMenuItem(value: _Action.delete, child: Text('حذف')),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<_Action>(
      tooltip: 'خيارات الإعلان',
      icon: const Icon(Icons.more_vert),
      itemBuilder: (_) => items,
      onSelected: (a) async {
        switch (a) {
          case _Action.resume:
            await resumeListingDraft(context, ref, listing);
          case _Action.edit:
            await editListing(context, ref, listing);
          case _Action.delete:
            await confirmDeleteListing(context, ref, listing);
        }
      },
    );
  }
}

/// متابعة تحرير مسودة ثم إعادة تحميل القائمة.
Future<void> resumeListingDraft(
  BuildContext context,
  WidgetRef ref,
  MyListing listing,
) async {
  await context.push(
    Uri(
      path: Routes.postAd,
      queryParameters: {'draft': listing.listingId},
    ).toString(),
  );
  ref.invalidate(myListingsProvider);
}

/// تعديل إعلان (أو تصحيح مرفوض) ثم إعادة تحميل القائمة.
Future<void> editListing(
  BuildContext context,
  WidgetRef ref,
  MyListing listing,
) async {
  await context.push(
    Uri(
      path: Routes.postAd,
      queryParameters: {'edit': listing.listingId},
    ).toString(),
  );
  ref.invalidate(myListingsProvider);
}

/// حذف بتأكيد؛ يعيد true إذا حُذف الإعلان فعلًا.
Future<bool> confirmDeleteListing(
  BuildContext context,
  WidgetRef ref,
  MyListing listing,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('حذف الإعلان؟'),
      content: const Text('لن تتمكن من استرجاعه.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await ref.read(listingRepositoryProvider).delete(listing.listingId);
    ref.invalidate(myListingsProvider);
    return true;
  } on AppError catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showApp(errorMessage(e), kind: AppNoteKind.error);
    }
    return false;
  }
}
