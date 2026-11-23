import '../../browse/data/listing_card.dart';

/// صف من `my_favorites` (`contracts/fixtures/my-favorite.json`).
///
/// الإعلان الذي لم يعد منشورًا يبقى صفًا بـ[available] خاطئ و[card] فارغ:
/// لا محتوى ولا وسائط ولا سبب (AD-FR-022).
class Favorite {
  const Favorite({
    required this.listingId,
    required this.savedAt,
    required this.card,
  });

  factory Favorite.fromJson(Map<String, dynamic> j) => Favorite(
    listingId: j['listing_id'] as String,
    savedAt: DateTime.parse(j['saved_at'] as String),
    card: (j['available'] as bool) ? ListingCard.fromJson(j) : null,
  );

  final String listingId;
  final DateTime savedAt;

  /// `null` حين يكون الإعلان غير متاح.
  final ListingCard? card;

  bool get available => card != null;
}
