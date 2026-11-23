/// وسيط في معرض الإعلان (`get_listing` ← `media`).
class DetailMedia {
  const DetailMedia({
    required this.mediaId,
    required this.kind,
    required this.bucket,
    required this.path,
    required this.isCover,
  });

  factory DetailMedia.fromJson(Map<String, dynamic> j) => DetailMedia(
    mediaId: j['media_id'] as String,
    kind: j['kind'] as String,
    bucket: j['bucket'] as String,
    path: j['object_path'] as String,
    isCover: j['is_cover'] as bool? ?? false,
  );

  final String mediaId;

  /// `IMAGE` أو `VIDEO`.
  final String kind;
  final String bucket;
  final String path;
  final bool isCover;

  bool get isImage => kind == 'IMAGE';
}

/// تفاصيل إعلان منشور ووسائطه وحالة مفضلته لصاحب الجلسة
/// (`contracts/fixtures/listing-detail.json`).
class ListingDetail {
  const ListingDetail({
    required this.listingId,
    required this.ownerId,
    required this.ownerName,
    required this.ownerJoinedAt,
    required this.title,
    required this.description,
    required this.offerType,
    required this.price,
    required this.auctionRegionName,
    required this.auctionCityName,
    required this.auctionVenue,
    required this.auctionStartsAt,
    required this.auctionPassed,
    required this.breedName,
    required this.breedNote,
    required this.sex,
    required this.ageMonths,
    required this.color,
    required this.healthNotes,
    required this.regionName,
    required this.cityName,
    required this.contactPhone,
    required this.callEnabled,
    required this.whatsappEnabled,
    required this.publishedAt,
    required this.publicRef,
    required this.commentsClosed,
    required this.media,
    required this.isFavorite,
  });

  factory ListingDetail.fromJson(Map<String, dynamic> json) {
    final l = Map<String, dynamic>.from(json['listing'] as Map);
    return ListingDetail(
      listingId: l['listing_id'] as String,
      ownerId: l['owner_id'] as String,
      ownerName: l['owner_display_name'] as String,
      ownerJoinedAt: DateTime.parse(l['owner_joined_at'] as String),
      title: l['title'] as String,
      description: l['description'] as String,
      offerType: l['offer_type'] as String,
      price: l['price'] as num?,
      auctionRegionName: l['auction_region_name_ar'] as String?,
      auctionCityName: l['auction_city_name_ar'] as String?,
      auctionVenue: l['auction_venue'] as String?,
      auctionStartsAt: l['auction_starts_at'] == null
          ? null
          : DateTime.parse(l['auction_starts_at'] as String),
      auctionPassed: l['auction_passed'] as bool? ?? false,
      breedName: l['breed_name_ar'] as String,
      breedNote: l['breed_note'] as String?,
      sex: l['sex'] as String,
      ageMonths: l['age_months'] as int,
      color: l['color'] as String?,
      healthNotes: l['health_notes'] as String,
      regionName: l['region_name_ar'] as String,
      cityName: l['city_name_ar'] as String,
      contactPhone: l['contact_phone'] as String,
      callEnabled: l['contact_call_enabled'] as bool,
      whatsappEnabled: l['contact_whatsapp_enabled'] as bool,
      publishedAt: DateTime.parse(l['first_published_at'] as String),
      publicRef: l['public_ref'] as String?,
      commentsClosed: l['comments_closed'] as bool? ?? false,
      media: [
        for (final m in json['media'] as List<dynamic>)
          DetailMedia.fromJson(Map<String, dynamic>.from(m as Map)),
      ],
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }

  final String listingId;
  final String ownerId;
  final String ownerName;
  final DateTime ownerJoinedAt;
  final String title;
  final String description;
  final String offerType;
  final num? price;
  final String? auctionRegionName;
  final String? auctionCityName;
  final String? auctionVenue;
  final DateTime? auctionStartsAt;
  final bool auctionPassed;
  final String breedName;
  final String? breedNote;
  final String sex;
  final int ageMonths;
  final String? color;
  final String healthNotes;
  final String regionName;
  final String cityName;

  /// بصيغة E.164 (`+9665xxxxxxxx`).
  final String contactPhone;
  final bool callEnabled;
  final bool whatsappEnabled;
  final DateTime publishedAt;
  final String? publicRef;

  /// أغلق المعلن الردود الجديدة.
  final bool commentsClosed;
  final List<DetailMedia> media;
  final bool isFavorite;

  bool get isAuction => offerType == 'IN_PERSON_AUCTION';

  String get breedLabel =>
      (breedNote == null || breedNote!.isEmpty) ? breedName : breedNote!;

  ListingDetail withFavorite(bool value) => ListingDetail(
    listingId: listingId,
    ownerId: ownerId,
    ownerName: ownerName,
    ownerJoinedAt: ownerJoinedAt,
    title: title,
    description: description,
    offerType: offerType,
    price: price,
    auctionRegionName: auctionRegionName,
    auctionCityName: auctionCityName,
    auctionVenue: auctionVenue,
    auctionStartsAt: auctionStartsAt,
    auctionPassed: auctionPassed,
    breedName: breedName,
    breedNote: breedNote,
    sex: sex,
    ageMonths: ageMonths,
    color: color,
    healthNotes: healthNotes,
    regionName: regionName,
    cityName: cityName,
    contactPhone: contactPhone,
    callEnabled: callEnabled,
    whatsappEnabled: whatsappEnabled,
    publishedAt: publishedAt,
    publicRef: publicRef,
    commentsClosed: commentsClosed,
    media: media,
    isFavorite: value,
  );
}
