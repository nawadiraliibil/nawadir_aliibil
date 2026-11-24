import 'package:flutter/material.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/app_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_title.dart';
import '../../auth/application/auth_providers.dart';
import '../../browse/presentation/listing_card_tile.dart';
import '../application/favorites_providers.dart';
import '../data/favorite.dart';

/// المفضلة (B09): الإعلانات المحفوظة بالأحدث حفظًا. الإعلان الذي لم يعد منشورًا
/// يظهر «غير متاح» دون محتواه ولا سببه، ويمكن إزالته. مبدّل عرض كبير/مدمج.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  /// عرض عمودين بدل البطاقة الكبيرة.
  var _compact = false;

  /// عناصر القائمة: العنوان، ثم الصفوف. في المدمج يُجمع كل إعلانين متتاليين
  /// متاحين في صف، و«غير متاح» يأخذ صفًا كاملًا.
  List<Widget> _rows(BuildContext context, List<Favorite> items) {
    Widget card(Favorite f) => ListingCardTile(
      card: f.card!,
      compact: true,
      onTap: () => context.push(Routes.listing(f.card!.listingId)),
    );
    if (!_compact) return [for (final f in items) _FavoriteRow(favorite: f)];
    final out = <Widget>[];
    var i = 0;
    while (i < items.length) {
      final f = items[i];
      if (f.card == null) {
        out.add(_FavoriteRow(favorite: f));
        i++;
        continue;
      }
      final next = i + 1 < items.length && items[i + 1].card != null
          ? items[i + 1]
          : null;
      out.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: card(f)),
            const SizedBox(width: 12),
            Expanded(child: next == null ? const SizedBox() : card(next)),
          ],
        ),
      );
      i += next == null ? 1 : 2;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
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
                            child: Builder(
                              builder: (context) {
                                final rows = _rows(context, items);
                                return ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    24,
                                  ),
                                  itemCount: rows.length + 1,
                                  separatorBuilder: (_, i) =>
                                      SizedBox(height: i == 0 ? 12 : 20),
                                  itemBuilder: (context, i) => i == 0
                                      ? _FavoritesTitle(
                                          compact: _compact,
                                          onChanged: (v) =>
                                              setState(() => _compact = v),
                                        )
                                      : rows[i - 1],
                                );
                              },
                            ),
                          ),
                  ),
      ),
    );
  }
}

/// عنوان القسم ومبدّل العرض الكبير والمدمج (نمط الرئيسية).
class _FavoritesTitle extends StatelessWidget {
  const _FavoritesTitle({required this.compact, required this.onChanged});

  final bool compact;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget option(Key key, IconData icon, String tip, bool value) {
      final selected = compact == value;
      return Semantics(
        selected: selected,
        child: IconButton(
          key: key,
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
        const Expanded(child: SectionTitle('إعلاناتي المحفوظة')),
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
                option(
                  const ValueKey('favorites-view-large'),
                  Icons.view_agenda_outlined,
                  'عرض كبير',
                  false,
                ),
                option(
                  const ValueKey('favorites-view-compact'),
                  Icons.grid_view_outlined,
                  'عرض مدمج',
                  true,
                ),
              ],
            ),
          ),
        ),
      ],
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
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 40,
                child: Icon(
                  Icons.visibility_off_outlined,
                  size: 20,
                  color: c.muted,
                ),
              ),
            ),
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
                  messenger.showApp(
                    errorMessage(AppError.from(e)),
                    kind: AppNoteKind.error,
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
