/// عنصر في قائمة مختلطة: إعلان مستخدم برقمه، أو دعاية برقمها في قائمة الدعايات.
sealed class FeedEntry {
  const FeedEntry();
}

class ListingEntry extends FeedEntry {
  const ListingEntry(this.index);
  final int index;

  @override
  bool operator ==(Object other) =>
      other is ListingEntry && other.index == index;
  @override
  int get hashCode => index.hashCode;
  @override
  String toString() => 'L$index';
}

class PromotionEntry extends FeedEntry {
  const PromotionEntry(this.index);
  final int index;

  @override
  bool operator ==(Object other) =>
      other is PromotionEntry && other.index == index;
  @override
  int get hashCode => -index - 1;
  @override
  String toString() => 'P$index';
}

/// يدرج دعاية بعد كل [interval] إعلانًا (بعد الإعلان N ثم 2N...)، ويدوّر الدعايات:
/// الموضع k يأخذ الدعاية `k mod promotionCount`. لا دعاية قبل أول N. القائمة المكتملة
/// ([hasMore] خطأ) الأقصر من N وغير الفارغة تأخذ دعاية واحدة في آخرها، حتى لا تختفي
/// الدعايات حين تقل الإعلانات؛ ولا تضاف ما دامت صفحات أخرى ستحمّل كي لا تقفز الدعاية.
/// لا دعايات إن كان [promotionCount] صفرًا أو القائمة فارغة.
List<FeedEntry> buildFeed({
  required int listingCount,
  required int promotionCount,
  required int interval,
  bool hasMore = false,
}) {
  final out = <FeedEntry>[];
  if (promotionCount <= 0 || interval <= 0) {
    return [for (var i = 0; i < listingCount; i++) ListingEntry(i)];
  }
  var slot = 0;
  for (var i = 0; i < listingCount; i++) {
    out.add(ListingEntry(i));
    if ((i + 1) % interval == 0) {
      out.add(PromotionEntry(slot % promotionCount));
      slot++;
    }
  }
  if (!hasMore && listingCount > 0 && listingCount < interval) {
    out.add(const PromotionEntry(0));
  }
  return out;
}
