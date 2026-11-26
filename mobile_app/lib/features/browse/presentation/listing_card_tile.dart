import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/format/money.dart';
import '../../../core/widgets/app_badge.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../listing/presentation/media_image.dart';
import '../data/listing_card.dart';
import '../domain/labels.dart';
import 'auction_widgets.dart';
import 'listing_detail_screen.dart' show listingShareLink, shareTextProvider;
import 'listing_stats.dart';

/// السعر بخط العناوين الذهبي، و«ريال» أصغر بعده. نص واحد لقارئ الشاشة.
class PriceText extends StatelessWidget {
  const PriceText(this.price, {super.key, this.size = 20});

  final num price;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formatMoney(price),
            style: AppTypography.displayStyle(
              size: size,
              color: c.gold,
              height: 1.3,
            ),
          ),
          TextSpan(
            text: ' ريال',
            style: TextStyle(
              fontSize: size * 0.6,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// بطاقة إعلان في القوائم. الافتراضي بطاقة كبيرة: صورة 4:3 ثم سطر واحد
/// (العنوان والسعر) ثم المدينة. [compact] نسخة أصغر لعرض عمودين.
/// المزاد بلاطة تاريخ على الصورة بدل السعر.
class ListingCardTile extends ConsumerWidget {
  const ListingCardTile({
    super.key,
    required this.card,
    required this.onTap,
    this.showFavorite = true,
    this.compact = false,
  });

  final ListingCard card;
  final VoidCallback onTap;
  final bool showFavorite;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.colors;
    final startsAt = card.auctionStartsAt;

    final image = Stack(
      children: [
        // سقف للارتفاع كي لا تتضخم الصورة على الشاشات العريضة.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: AspectRatio(
            aspectRatio: compact ? 4 / 3 : 16 / 10,
            child: ClipRRect(
              borderRadius: AppShapes.imageRadius,
              child: SizedBox.expand(
                child: ExcludeSemantics(
                  child: MediaImage(
                    bucket: card.coverBucket,
                    path: card.coverPath,
                  ),
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: 10,
          start: 10,
          child: AppBadge(
            label: card.isAuction ? 'مزاد حضوري' : 'سعر محدد',
            kind: card.isAuction
                ? AppBadgeKind.auction
                : AppBadgeKind.fixedPrice,
          ),
        ),
        if (showFavorite)
          PositionedDirectional(
            top: 4,
            end: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
              ),
              child: FavoriteButton(listingId: card.listingId, dense: compact),
            ),
          ),
        if (!compact)
          PositionedDirectional(
            top: showFavorite ? 58 : 4,
            end: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                color: c.muted,
                key: ValueKey('card-share-${card.listingId}'),
                tooltip: 'مشاركة',
                iconSize: 20,
                icon: const Icon(Icons.ios_share),
                onPressed: () {
                  final link = listingShareLink(
                    ref.read(envProvider).shareBaseUrl,
                    card.publicRef,
                  );
                  ref.read(shareTextProvider)(
                    link == null ? card.title : '${card.title}\n$link',
                    card.title,
                  );
                },
              ),
            ),
          ),
        if (card.isAuction && startsAt != null && !card.auctionPassed)
          PositionedDirectional(
            bottom: 10,
            start: 10,
            child: AuctionDateTile(startsAt: startsAt),
          ),
      ],
    );

    final Widget offer;
    if (card.isAuction) {
      // بنفس حجم وخط السعر في بطاقة السعر المحدد كي تتناسق البطاقتان.
      final size = compact ? 16.0 : 20.0;
      final timeText = Text(
        card.auctionPassed
            ? 'مضى موعده'
            : startsAt == null
            ? ''
            : saudiTime12(startsAt),
        style: card.auctionPassed
            ? AppTypography.displayStyle(
                size: size,
                color: c.muted,
                height: 1.3,
              )
            : AppTypography.displayStyle(
                size: size,
                color: c.info,
                height: 1.3,
              ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      // أيقونة ساعة تفسّر الوقت المنفرد بجانب العنوان.
      offer = card.auctionPassed || startsAt == null
          ? timeText
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: size - 2, color: c.info),
                const SizedBox(width: 4),
                Flexible(child: timeText),
              ],
            );
    } else {
      offer = card.price == null
          ? const SizedBox.shrink()
          : PriceText(card.price!, size: compact ? 16 : 20);
    }

    final title = Text(
      card.title,
      style: compact ? theme.textTheme.titleSmall : theme.textTheme.titleMedium,
      maxLines: compact ? 1 : 2,
      overflow: TextOverflow.ellipsis,
    );

    final place = Row(
      children: [
        Icon(Icons.location_on_outlined, size: 15, color: c.muted),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            compact ? card.cityName : '${card.regionName} · ${card.cityName}',
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    // البعد عن المتصفح للمزاد الحضوري المحدد موقعه.
    final showDistance =
        card.isAuction && card.hasAuctionLocation && !card.auctionPassed;
    final statSize = compact ? 14.0 : 15.0;
    final stats = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatLabel(
          icon: Icons.favorite_border,
          count: card.favoriteCount,
          noun: 'إعجاب',
          size: statSize,
        ),
        SizedBox(width: compact ? 8 : 12),
        StatLabel(
          icon: Icons.visibility_outlined,
          count: card.viewCount,
          noun: 'مشاهدة',
          size: statSize,
        ),
      ],
    );

    return Semantics(
      container: true,
      child: InkWell(
        borderRadius: AppShapes.imageRadius,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            image,
            const SizedBox(height: 8),
            if (compact) ...[
              title,
              const SizedBox(height: 2),
              Align(alignment: AlignmentDirectional.centerStart, child: offer),
              const SizedBox(height: 4),
              place,
              if (showDistance)
                DistanceLabel(lat: card.auctionLat!, lng: card.auctionLng!),
              const SizedBox(height: 4),
              stats,
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 12),
                  // عرض المحتوى فقط (flex 0) كي يلتصق بالطرف لا بمنتصف نصف الصف.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: offer,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: place),
                  const SizedBox(width: 12),
                  stats,
                ],
              ),
              if (showDistance)
                DistanceLabel(lat: card.auctionLat!, lng: card.auctionLng!),
            ],
          ],
        ),
      ),
    );
  }
}
