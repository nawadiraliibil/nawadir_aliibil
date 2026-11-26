import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../browse/presentation/listing_detail_screen.dart'
    show externalLauncherProvider;
import '../application/promotions_providers.dart';
import '../data/promotion.dart';
import '../data/promotions_repository.dart';

/// المدة التي تبقى فيها البطاقة معروضة قبل احتساب ظهورها.
const promotionImpressionDelay = Duration(seconds: 1);

/// بطاقة دعاية تجارية بين إعلانات المستخدمين (TEAM-DEC-017): صورة 16:10 كالبطاقة
/// الكبيرة وشارة «إعلان ممول» ظاهرة دائمًا، واسم المعلن والعنوان والنص، وزر
/// الإجراء. بلا سعر ولا مفضلة ولا مشاركة ولا صفحة تفاصيل.
class PromotionCard extends ConsumerStatefulWidget {
  const PromotionCard({
    super.key,
    required this.promotion,
    this.compact = false,
  });

  final Promotion promotion;

  /// في العرض المدمج تمتد البطاقة بعرض الصف بنص أقصر.
  final bool compact;

  @override
  ConsumerState<PromotionCard> createState() => _PromotionCardState();
}

class _PromotionCardState extends ConsumerState<PromotionCard> {
  Timer? _impression;

  @override
  void initState() {
    super.initState();
    // القوائم تبني العناصر قرب الشاشة فقط؛ بقاء البطاقة مبنية ثانية يقارب
    // «ظهرت للمستخدم» دون مراقب رؤية إضافي.
    _impression = Timer(promotionImpressionDelay, () {
      if (!mounted) return;
      ref.read(promotionEventRecorderProvider)(
        widget.promotion.id,
        PromotionEvent.impression,
      );
    });
  }

  @override
  void dispose() {
    _impression?.cancel();
    super.dispose();
  }

  Future<void> _act() async {
    final uri = widget.promotion.actionUri;
    if (uri == null) return;
    ref.read(promotionEventRecorderProvider)(
      widget.promotion.id,
      PromotionEvent.click,
    );
    await ref.read(externalLauncherProvider)(uri);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.promotion;
    final c = context.colors;
    final theme = Theme.of(context);
    final imageUrl = ref.watch(promotionImageUrlProvider)(p.imagePath);
    final label = p.actionLabel;
    final hasAction = label != null && p.actionUri != null;

    Widget placeholder(IconData icon) => ColoredBox(
      color: c.soft,
      child: Center(child: Icon(icon, color: c.muted)),
    );

    final image = Stack(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipRRect(
              borderRadius: AppShapes.imageRadius,
              child: SizedBox.expand(
                child: ExcludeSemantics(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : placeholder(Icons.image_outlined),
                    errorBuilder: (_, _, _) =>
                        placeholder(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
        ),
        const PositionedDirectional(
          top: 10,
          start: 10,
          child: SponsoredBadge(),
        ),
      ],
    );

    return Semantics(
      container: true,
      label: 'إعلان ممول: ${p.title} من ${p.advertiserName}',
      child: InkWell(
        key: ValueKey('promotion-${p.id}'),
        borderRadius: AppShapes.imageRadius,
        onTap: hasAction ? _act : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            image,
            const SizedBox(height: 8),
            // النصوص يغطيها وصف البطاقة لقارئ الشاشة؛ زر الإجراء يبقى قابلًا للوصول.
            ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    style: widget.compact
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (p.body != null && p.body!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      p.body!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                      ),
                      maxLines: widget.compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.storefront_outlined, size: 15, color: c.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      p.advertiserName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (hasAction) ...[
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    key: ValueKey('promotion-action-${p.id}'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, AppShapes.minTouchTarget),
                      backgroundColor: c.tintGold,
                      foregroundColor: c.gold,
                    ),
                    onPressed: _act,
                    child: Text(label),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// شارة الإفصاح «إعلان ممول»: داكنة على الصورة لتبقى مقروءة فوق أي صورة.
class SponsoredBadge extends StatelessWidget {
  const SponsoredBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD12D241B),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          'إعلان ممول',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
