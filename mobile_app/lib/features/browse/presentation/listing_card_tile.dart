import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/widgets/app_badge.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../listing/presentation/media_image.dart';
import '../data/listing_card.dart';
import '../domain/labels.dart';

/// بطاقة إعلان في القوائم: الغلاف والعنوان والسعر أو المزاد والمواصفات والموقع.
class ListingCardTile extends StatelessWidget {
  const ListingCardTile({
    super.key,
    required this.card,
    required this.onTap,
    this.showFavorite = true,
  });

  final ListingCard card;
  final VoidCallback onTap;
  final bool showFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final offer = offerLine(
      isAuction: card.isAuction,
      price: card.price,
      auctionStartsAt: card.auctionStartsAt,
      auctionPassed: card.auctionPassed,
    );
    final specs = [
      card.breedLabel,
      sexLabel(card.sex),
      ageLabel(card.ageMonths),
    ].join(' · ');

    return Material(
      color: c.soft,
      borderRadius: BorderRadius.circular(AppShapes.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppShapes.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppShapes.image),
                child: SizedBox.square(
                  dimension: 96,
                  child: ExcludeSemantics(
                    child: MediaImage(
                      bucket: card.coverBucket,
                      path: card.coverPath,
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
                      card.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppBadge(
                          label: card.isAuction ? 'مزاد' : 'سعر محدد',
                          kind: card.isAuction
                              ? AppBadgeKind.auction
                              : AppBadgeKind.fixedPrice,
                        ),
                        Text(offer, style: theme.textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      specs,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${card.regionName} · ${card.cityName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (showFavorite) FavoriteButton(listingId: card.listingId),
            ],
          ),
        ),
      ),
    );
  }
}
