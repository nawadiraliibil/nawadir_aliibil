import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/application/auth_providers.dart';
import '../../browse/presentation/listing_card_tile.dart';
import '../application/favorites_providers.dart';
import '../data/favorite.dart';

/// المفضلة (B09): الإعلانات المحفوظة بالأحدث حفظًا. الإعلان الذي لم يعد منشورًا
/// يظهر «غير متاح» دون محتواه ولا سببه، ويمكن إزالته.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: SafeArea(
        child: !signedIn
            ? EmptyState(
                icon: Icons.favorite_border,
                title: 'سجّل الدخول لحفظ إعلاناتك',
                message: 'مفضلتك تتزامن مع حسابك على كل أجهزتك.',
                actionLabel: 'تسجيل الدخول',
                onAction: () => context.push(
                  Uri(
                    path: Routes.login,
                    queryParameters: {'from': Routes.favorites},
                  ).toString(),
                ),
              )
            : ref
                  .watch(favoritesProvider)
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'تعذّر تحميل المفضلة',
                      message: errorMessage(AppError.from(e)),
                      actionLabel: 'إعادة المحاولة',
                      onAction: () => ref.invalidate(favoritesProvider),
                    ),
                    data: (items) => items.isEmpty
                        ? EmptyState(
                            icon: Icons.favorite_border,
                            title: 'لا توجد إعلانات محفوظة',
                            message: 'اضغط القلب على أي إعلان لتجده هنا.',
                            actionLabel: 'تصفح الإعلانات',
                            onAction: () => context.go(Routes.home),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(favoritesProvider);
                              await ref.read(favoritesProvider.future);
                            },
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) =>
                                  _FavoriteRow(favorite: items[i]),
                            ),
                          ),
                  ),
      ),
    );
  }
}

class _FavoriteRow extends ConsumerWidget {
  const _FavoriteRow({required this.favorite});

  final Favorite favorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = favorite.card;
    if (card != null) {
      return ListingCardTile(
        card: card,
        onTap: () => context.push(Routes.listing(card.listingId)),
      );
    }
    final c = context.colors;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(AppShapes.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.visibility_off_outlined, color: c.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'الإعلان غير متاح',
                style: theme.textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref
                      .read(favoritesProvider.notifier)
                      .remove(favorite.listingId);
                } on Object catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(errorMessage(AppError.from(e)))),
                  );
                }
              },
              child: const Text('إزالة'),
            ),
          ],
        ),
      ),
    );
  }
}
