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
/// الموضع k يأخذ الدعاية `k mod promotionCount`. لا دعاية قبل أول N ولا في قائمة
/// أقصر من N، ولا دعايات إن كان [promotionCount] صفرًا.
List<FeedEntry> buildFeed({
  required int listingCount,
  required int promotionCount,
  required int interval,
}) {
  final out = <FeedEntry>[];
  var slot = 0;
  for (var i = 0; i < listingCount; i++) {
    out.add(ListingEntry(i));
    if (promotionCount > 0 && interval > 0 && (i + 1) % interval == 0) {
      out.add(PromotionEntry(slot % promotionCount));
      slot++;
    }
  }
  return out;
}
