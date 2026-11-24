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
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/application/auth_providers.dart';
import '../../safety/data/safety_repository.dart';
import '../../safety/presentation/safety_actions.dart';
import '../application/ratings_providers.dart';
import '../data/rating_models.dart';
import 'rating_sheet.dart';

/// نجوم درجة (قراءة فقط).
class StarsRow extends StatelessWidget {
  const StarsRow({super.key, required this.score, this.size = 18});

  final num score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.gold;
    return Semantics(
      label: '$score من 5',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                i <= score.round() ? Icons.star : Icons.star_border,
                size: size,
                color: color,
              ),
          ],
        ),
      ),
    );
  }
}

/// تقييمات المعلن (F05/F07): المتوسط وعدد الظاهر، وأهلية التقييم بشرح بسيط،
/// وقائمة التقييمات بردود المعلن، والبلاغ عن تقييم.
class SellerRatingsScreen extends ConsumerWidget {
  const SellerRatingsScreen({
    super.key,
    required this.sellerId,
    required this.sellerName,
  });

  final String sellerId;
  final String sellerName;

  Future<void> _rate(
    BuildContext context,
    WidgetRef ref, {
    PublicRating? existing,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showRatingSheet(
      context,
      sellerId: sellerId,
      sellerName: sellerName,
      existing: existing,
    );
    if (ok == true) {
      ref.invalidate(sellerRatingsProvider(sellerId));
      ref.invalidate(ratingEligibilityProvider(sellerId));
      messenger.showApp(
        existing == null ? 'تم نشر تقييمك.' : 'تم حفظ تعديل تقييمك.',
        kind: AppNoteKind.success,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratings = ref.watch(sellerRatingsProvider(sellerId));
    final eligibility = ref.watch(ratingEligibilityProvider(sellerId));
    final myId = ref.watch(authBackendProvider).userId;
    final signedIn = ref.watch(signedInProvider).value ?? false;
    final theme = Theme.of(context);
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        title: const Text('تقييمات المعلن'),
      ),
      body: SafeArea(
        child: ratings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'تعذّر تحميل التقييمات',
            message: errorMessage(AppError.from(e)),
            actionLabel: 'إعادة المحاولة',
            onAction: () => ref.invalidate(sellerRatingsProvider(sellerId)),
          ),
          data: (list) {
            final avg = list.isEmpty
                ? null
                : list.fold<int>(0, (s, r) => s + r.score) / list.length;
            final mine = list.where((r) => r.raterId == myId).firstOrNull;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    Text(
                      avg == null ? '—' : avg.toStringAsFixed(1),
                      key: const ValueKey('rating-average'),
                      style: theme.textTheme.displaySmall,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (avg != null) StarsRow(score: avg, size: 22),
                          Text(
                            list.isEmpty
                                ? 'لا تقييمات بعد'
                                : '${list.length} تقييمًا',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const AppNote(
                  'التقييم يعبّر عن تجربة المقيّم في التعامل ولا يثبت عملية شراء.',
                ),
                const SizedBox(height: 12),
                if (!signedIn)
                  OutlinedButton(
                    key: const ValueKey('rating-login'),
                    onPressed: () => context.push(
                      Uri(
                        path: Routes.login,
                        queryParameters: {
                          'from': Routes.sellerRatings(sellerId),
                        },
                      ).toString(),
                    ),
                    child: const Text('سجّل الدخول لتقييم المعلن'),
                  )
                else
                  eligibility.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (e) {
                      if (e == null) return const SizedBox.shrink();
                      if (e.eligible) {
                        return FilledButton.icon(
                          key: const ValueKey('rate-seller'),
                          icon: const Icon(Icons.star_outline),
                          label: const Text('قيّم هذا المعلن'),
                          onPressed: () => _rate(context, ref),
                        );
                      }
                      if (e.reason == 'ALREADY_RATED') {
                        return mine != null
                            ? OutlinedButton.icon(
                                key: const ValueKey('edit-my-rating'),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('تعديل تقييمي'),
                                onPressed: () =>
                                    _rate(context, ref, existing: mine),
                              )
                            : const AppNote(
                                'تقييمك لهذا المعلن غير معروض حاليًا.',
                              );
                      }
                      // F07: التقييم غير متاح الآن، بسبب بسيط.
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: c.tintGold,
                                child: Icon(
                                  Icons.star_outline,
                                  size: 20,
                                  color: c.gold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'التقييم غير متاح الآن',
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          AppNote(e.reasonText),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 16),
                for (final r in list)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.hair)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.displayName,
                                  style: theme.textTheme.titleSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                formatShortTime(r.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: c.muted,
                                ),
                              ),
                              if (r.raterId != myId)
                                PopupMenuButton<String>(
                                  key: ValueKey('rating-menu-${r.id}'),
                                  tooltip: 'خيارات التقييم',
                                  onSelected: (_) => showReportSheet(
                                    context,
                                    ref,
                                    target: ReportTarget.rating,
                                    targetId: r.id,
                                    targetLabel: 'التقييم',
                                  ),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'report',
                                      child: Text('إبلاغ'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          StarsRow(score: r.score, size: 16),
                          if (r.body != null) ...[
                            const SizedBox(height: 6),
                            Text(r.body!, style: theme.textTheme.bodyLarge),
                          ],
                          if (r.edited)
                            Text(
                              'معدّل',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: c.muted,
                              ),
                            ),
                          if (r.replyBody != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: c.soft,
                                borderRadius: BorderRadius.circular(
                                  AppShapes.image,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'رد المعلن',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(color: c.gold),
                                  ),
                                  Text(
                                    r.replyBody!,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
