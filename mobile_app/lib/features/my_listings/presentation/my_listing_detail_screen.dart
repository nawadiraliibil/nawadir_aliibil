import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/format/money.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/app_snack.dart';
import '../../listing/data/listing_repository.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/my_listings_providers.dart';
import '../data/my_listing.dart';
import 'my_listings_screen.dart';

/// إعلان واحد من إعلاناتي (E03–E09): الحالة والسبب والإجراءات المتاحة فعلًا.
///
/// «إيقاف وأرشفة» (E08) و«تجديد الظهور» (E06) يستدعيان `archive_listing` و
/// `bump_listing`؛ التجديد يُعطَّل بوصف الموعد حين لا تنتهي المهلة بعد.
class MyListingDetailScreen extends ConsumerWidget {
  const MyListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(Routes.myListings);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(myListingsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _back(context),
        ),
        title: Text(_screenTitle(listings.value, listingId)),
      ),
      body: SafeArea(
        child: listings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'تعذّر تحميل الإعلان',
            message: errorMessage(AppError.from(e)),
            actionLabel: 'إعادة المحاولة',
            onAction: () => ref.invalidate(myListingsProvider),
          ),
          data: (items) {
            final listing = items.where((l) => l.listingId == listingId);
            if (listing.isEmpty) {
              return EmptyState(
                icon: Icons.search_off_outlined,
                title: 'الإعلان غير موجود',
                message: 'ربما حُذف أو لم يعد متاحًا لك.',
                actionLabel: 'إعلاناتي',
                onAction: () => _back(context),
              );
            }
            return _Body(listing: listing.first, onBack: () => _back(context));
          },
        ),
      ),
    );
  }
}

String _screenTitle(List<MyListing>? items, String id) {
  final l = items?.where((l) => l.listingId == id).firstOrNull;
  if (l == null) return 'الإعلان';
  return switch (l.status) {
    'UNDER_REVIEW' => 'إعلان قيد المراجعة',
    'REJECTED' => 'إعلان مرفوض',
    'PUBLISHED' => 'إعلان منشور',
    'ARCHIVED' => 'إعلان مؤرشف',
    'HIDDEN' => 'إعلان مخفي',
    _ => 'مسودة',
  };
}

class _Body extends ConsumerWidget {
  const _Body({required this.listing, required this.onBack});

  final MyListing listing;
  final VoidCallback onBack;

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
    final reason = [?listing.reasonLabel, ?listing.reasonText].join(' — ');
    final status = listing.status;
    final bump = listing.nextBumpAt;
    final bumpLater = bump != null && bump.isAfter(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              AppBadge(label: label, kind: kind),
              if (status == 'PUBLISHED' && listing.hasDraft)
                const AppBadge(
                  label: 'تعديل قيد التحرير',
                  kind: AppBadgeKind.pending,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(title, style: theme.textTheme.headlineSmall),
        if (_offerLine.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _offerLine,
            style: theme.textTheme.titleLarge?.copyWith(color: c.gold),
          ),
        ],
        const SizedBox(height: 16),
        if (reason.isNotEmpty && (status == 'REJECTED' || status == 'HIDDEN'))
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AppNote(reason, kind: AppNoteKind.error),
          ),
        ..._info(status, bumpLater ? bump : null),
        ..._actions(context, ref, bumpLater ? bump : null),
      ],
    );
  }

  List<Widget> _info(String status, DateTime? bumpAt) {
    Widget note(String m) =>
        Padding(padding: const EdgeInsets.only(bottom: 16), child: AppNote(m));
    return switch (status) {
      'HIDDEN' => [
        note(
          'أخفته الإدارة عن الجمهور، ولا يمكنك تعديله أو إعادة نشره أو '
          'أرشفته حتى تعيد الإدارة إظهاره.',
        ),
      ],
      'ARCHIVED' => [
        note('الإعلان مؤرشف ولا يظهر للمشترين. يمكنك تعديله وإعادة نشره.'),
      ],
      'PUBLISHED' => [
        if (listing.hasDraft)
          note(
            'لديك تعديل قيد التحرير. النسخة المنشورة تبقى ظاهرة حتى تنشر '
            'التعديل، ويسري فور نشره.',
          ),
      ],
      _ => const [],
    };
  }

  Future<void> _bump(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(listingRepositoryProvider).bump(listing.listingId);
      ref.invalidate(myListingsProvider);
      messenger.showApp('جُدد ظهور إعلانك.', kind: AppNoteKind.success);
    } on AppError catch (e) {
      messenger.showApp(errorMessage(e), kind: AppNoteKind.error);
    }
  }

  /// E08: تأكيد في ورقة سفلية ثم أرشفة.
  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إيقاف الإعلان وأرشفته؟',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'يختفي الإعلان عن المشترين ويبقى في إعلاناتي. يمكنك تعديله '
                'وإعادة نشره لاحقًا.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('archive-confirm'),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('إيقاف وأرشفة'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(listingRepositoryProvider).archive(listing.listingId);
      ref.invalidate(myListingsProvider);
      messenger.showApp('أُرشف الإعلان.', kind: AppNoteKind.success);
    } on AppError catch (e) {
      messenger.showApp(errorMessage(e), kind: AppNoteKind.error);
    }
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref, DateTime? bumpAt) {
    final status = listing.status;
    return [
      if (status == 'PUBLISHED')
        _ActionRow(
          icon: Icons.visibility_outlined,
          label: 'عرض الإعلان',
          onTap: () => context.push(Routes.listing(listing.listingId)),
        ),
      if (listing.canResume)
        FilledButton(
          onPressed: () => resumeListingDraft(context, ref, listing),
          child: const Text('متابعة التحرير'),
        ),
      if (listing.canEdit && status == 'REJECTED')
        FilledButton(
          onPressed: () => editListing(context, ref, listing),
          child: const Text('تصحيح الإعلان'),
        ),
      if (listing.canEdit && status != 'REJECTED')
        _ActionRow(
          icon: Icons.edit_outlined,
          label: 'تعديل',
          onTap: () => editListing(context, ref, listing),
        ),
      if (status == 'PUBLISHED') ...[
        _ActionRow(
          icon: Icons.refresh,
          label: 'تجديد الظهور',
          subtitle: bumpAt == null
              ? 'يرفع إعلانك إلى أعلى القائمة'
              : 'غير متاح بعد · يتاح ${formatSaudiMoment(bumpAt)}',
          onTap: bumpAt == null ? () => _bump(context, ref) : null,
        ),
        _ActionRow(
          icon: Icons.pause_circle_outline,
          label: 'إيقاف الإعلان وأرشفته',
          subtitle: 'يختفي عن المشترين ويبقى لك',
          onTap: () => _archive(context, ref),
        ),
      ],
      if (listing.canDelete) ...[
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () async {
            final deleted = await confirmDeleteListing(context, ref, listing);
            if (deleted && context.mounted) onBack();
          },
          child: const Text('حذف'),
        ),
      ],
      if (status == 'REJECTED' || status == 'HIDDEN')
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextButton(onPressed: onBack, child: const Text('إعلاناتي')),
        ),
    ];
  }
}

/// صف إجراء بأيقونة؛ بلا onTap يكون معلوماتيًا فقط.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: onTap != null,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: c.tintGold,
        child: Icon(icon, color: c.gold),
      ),
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null ? null : const Icon(Icons.chevron_left),
    );
  }
}
