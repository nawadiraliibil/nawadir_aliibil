import 'package:flutter/material.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/app_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_title.dart';
import '../../auth/application/auth_providers.dart';
import '../../browse/data/listing_card.dart';
import '../../browse/presentation/search_results_view.dart';
import '../../ratings/presentation/seller_ratings_screen.dart';
import '../../safety/data/safety_repository.dart';
import '../../safety/presentation/safety_actions.dart';
import '../../follows/application/follows_providers.dart';
import '../../follows/data/follows_repository.dart';
import '../data/seller_profile.dart';

/// الملف العام للمعلن (C06): الاسم والمنطقة وتاريخ الانضمام وإعلاناته المنشورة.
class SellerScreen extends ConsumerWidget {
  const SellerScreen({super.key, required this.sellerId});

  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sellerProfileProvider(sellerId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        title: const Text('ملف المعلن'),
        actions: [
          if (profile.value case final p?
              when ref.watch(authBackendProvider).userId != p.id)
            PopupMenuButton<String>(
              key: const ValueKey('seller-menu'),
              tooltip: 'المزيد',
              onSelected: (v) => v == 'block'
                  ? confirmAndBlock(
                      context,
                      ref,
                      userId: p.id,
                      name: p.displayName,
                    )
                  : showReportSheet(
                      context,
                      ref,
                      target: ReportTarget.account,
                      targetId: p.id,
                      targetLabel: p.displayName,
                    ),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'report',
                  child: Text('الإبلاغ عن المعلن'),
                ),
                PopupMenuItem(value: 'block', child: Text('حظر المعلن')),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            final err = AppError.from(e);
            if (err.code == AppErrorCode.notFound) {
              return EmptyState(
                icon: Icons.person_off_outlined,
                title: 'الملف غير متاح',
                actionLabel: 'العودة للرئيسية',
                onAction: () => context.go(Routes.home),
              );
            }
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'تعذّر تحميل الملف',
              message: errorMessage(err),
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(sellerProfileProvider(sellerId)),
            );
          },
          data: (p) => SearchResultsView(
            filters: SearchFilters(ownerId: p.id),
            header: _Header(profile: p),
            emptyTitle: 'لا إعلانات منشورة حاليًا',
            emptyMessage: 'ستظهر هنا إعلانات هذا المعلن حين تُنشر.',
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.profile});

  final SellerProfile profile;

  Future<void> _toggleFollow(
    BuildContext context,
    WidgetRef ref,
    bool following,
  ) async {
    if (!requireSignIn(context, ref)) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(followsRepositoryProvider);
      if (following) {
        await repo.unfollow(profile.id);
      } else {
        await repo.follow(profile.id);
      }
      ref.invalidate(followedSellersProvider);
    } on Object catch (e) {
      messenger.showApp(
        errorMessage(AppError.from(e)),
        kind: AppNoteKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authBackendProvider).userId;
    final following = ref.watch(isFollowingProvider(profile.id)) ?? false;
    final theme = Theme.of(context);
    final c = context.colors;
    final ratingLabel = profile.ratingCount == 0
        ? 'لا تقييمات بعد'
        : '${profile.ratingAvg!.toStringAsFixed(1)} · '
              '${profile.ratingCount} تقييمًا';
    final region = profile.regionName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: c.soft,
            child: Text(
              profile.displayName.characters.first,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.displayName,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${region == null ? '' : '$region · '}'
            'عضو منذ ${profile.joinedAt.toUtc().year} · '
            '${profile.publishedCount} إعلانًا منشورًا',
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (myId != profile.id)
                following
                    ? OutlinedButton(
                        key: const ValueKey('follow-seller'),
                        onPressed: () => _toggleFollow(context, ref, true),
                        child: const Text('إلغاء المتابعة'),
                      )
                    : FilledButton(
                        key: const ValueKey('follow-seller'),
                        onPressed: () => _toggleFollow(context, ref, false),
                        child: const Text('متابعة'),
                      ),
              Material(
                color: c.soft,
                shape: const StadiumBorder(),
                child: InkWell(
                  key: const ValueKey('seller-rating-summary'),
                  customBorder: const StadiumBorder(),
                  onTap: () => context.push(
                    Uri(
                      path: Routes.sellerRatings(profile.id),
                      queryParameters: {'name': profile.displayName},
                    ).toString(),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (profile.ratingAvg != null) ...[
                            StarsRow(score: profile.ratingAvg!, size: 16),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              ratingLabel,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const Icon(Icons.chevron_left, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: SectionTitle('إعلانات المعلن'),
          ),
        ],
      ),
    );
  }
}
