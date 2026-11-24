/// بطاقة إعلان منشور: صف `public_listing_cards` وعنصر نتيجة `search_listings`
/// (`contracts/fixtures/search-result.json`).
class ListingCard {
  const ListingCard({
    required this.listingId,
    required this.ownerId,
    required this.ownerName,
    required this.title,
    required this.offerType,
    required this.price,
    required this.auctionStartsAt,
    required this.auctionPassed,
    required this.breedName,
    required this.breedNote,
    required this.sex,
    required this.ageMonths,
    required this.regionName,
    required this.cityName,
    required this.coverBucket,
    required this.coverPath,
    required this.publicRef,
    this.auctionLat,
    this.auctionLng,
    this.viewCount = 0,
    this.favoriteCount = 0,
  });

  factory ListingCard.fromJson(Map<String, dynamic> j) => ListingCard(
    listingId: j['listing_id'] as String,
    ownerId: j['owner_id'] as String,
    ownerName: j['owner_display_name'] as String,
    title: j['title'] as String,
    offerType: j['offer_type'] as String,
    price: j['price'] as num?,
    auctionStartsAt: j['auction_starts_at'] == null
        ? null
        : DateTime.parse(j['auction_starts_at'] as String),
    auctionPassed: j['auction_passed'] as bool? ?? false,
    breedName: j['breed_name_ar'] as String,
    breedNote: j['breed_note'] as String?,
    sex: j['sex'] as String,
    ageMonths: j['age_months'] as int,
    regionName: j['region_name_ar'] as String,
    cityName: j['city_name_ar'] as String,
    coverBucket: j['cover_bucket'] as String?,
    coverPath: j['cover_path'] as String?,
    publicRef: j['public_ref'] as String?,
    auctionLat: (j['auction_lat'] as num?)?.toDouble(),
    auctionLng: (j['auction_lng'] as num?)?.toDouble(),
    viewCount: j['view_count'] as int? ?? 0,
    favoriteCount: j['favorite_count'] as int? ?? 0,
  );

  final String listingId;
  final String ownerId;
  final String ownerName;
  final String title;

  /// `FIXED_PRICE` أو `IN_PERSON_AUCTION`.
  final String offerType;
  final num? price;
  final DateTime? auctionStartsAt;
  final bool auctionPassed;
  final String breedName;
  final String? breedNote;

  /// `MALE` أو `FEMALE`.
  final String sex;
  final int ageMonths;
  final String regionName;
  final String cityName;
  final String? coverBucket;
  final String? coverPath;
  final String? publicRef;

  /// موقع المزاد الحضوري على الخريطة؛ فارغ لغير المزاد وللمزادات القديمة.
  final double? auctionLat;
  final double? auctionLng;
  final int viewCount;
  final int favoriteCount;

  bool get hasAuctionLocation => auctionLat != null && auctionLng != null;

  bool get isAuction => offerType == 'IN_PERSON_AUCTION';

  /// السلالة كما يعرضها المعلن: عند «أخرى» يظهر توضيحه.
  String get breedLabel =>
      (breedNote == null || breedNote!.isEmpty) ? breedName : breedNote!;
}

/// صفحة من نتائج البحث: العناصر ومؤشر الصفحة التالية (`null` عند الانتهاء).
class SearchPage {
  const SearchPage({required this.items, required this.nextCursor});

  factory SearchPage.fromJson(Map<String, dynamic> j) => SearchPage(
    items: [
      for (final e in j['items'] as List<dynamic>)
        ListingCard.fromJson(Map<String, dynamic>.from(e as Map)),
    ],
    nextCursor: j['next_cursor'] == null
        ? null
        : Map<String, dynamic>.from(j['next_cursor'] as Map),
  );

  final List<ListingCard> items;

  /// يمرر كما هو في `p_cursor`.
  final Map<String, dynamic>? nextCursor;
}

/// الفرز المدعوم من الخادم.
enum SearchSort {
  newestVisible('NEWEST_VISIBLE', 'الأحدث'),
  priceAsc('PRICE_ASC', 'السعر: من الأقل'),
  priceDesc('PRICE_DESC', 'السعر: من الأعلى'),
  mostViewed('MOST_VIEWED', 'الأكثر مشاهدة');

  const SearchSort(this.wire, this.label);
  final String wire;
  final String label;
}

const _keep = Object();

/// مرشحات البحث. الفارغ منها لا يرسل.
class SearchFilters {
  const SearchFilters({
    this.query,
    this.regionId,
    this.cityId,
    this.breedId,
    this.sex,
    this.offerType,
    this.ageMin,
    this.ageMax,
    this.priceMin,
    this.priceMax,
    this.ownerId,
    this.sort = SearchSort.newestVisible,
  });

  final String? query;
  final int? regionId;
  final int? cityId;
  final int? breedId;
  final String? sex;
  final String? offerType;
  final int? ageMin;
  final int? ageMax;
  final num? priceMin;
  final num? priceMax;
  final String? ownerId;
  final SearchSort sort;

  /// عدد المرشحات المطبقة (دون النص والفرز)، لعلامة زر المرشحات.
  int get activeCount => [
    regionId,
    cityId,
    breedId,
    sex,
    offerType,
    ageMin ?? ageMax,
    priceMin ?? priceMax,
  ].where((e) => e != null).length;

  bool get hasPriceRange => priceMin != null || priceMax != null;

  /// يحل الحقول بترتيب: الممرر يغيّر ولو كان `null`، وغير الممرر يبقى.
  SearchFilters copyWith({
    Object? query = _keep,
    Object? regionId = _keep,
    Object? cityId = _keep,
    Object? breedId = _keep,
    Object? sex = _keep,
    Object? offerType = _keep,
    Object? ageMin = _keep,
    Object? ageMax = _keep,
    Object? priceMin = _keep,
    Object? priceMax = _keep,
    Object? ownerId = _keep,
    SearchSort? sort,
  }) => SearchFilters(
    query: identical(query, _keep) ? this.query : query as String?,
    regionId: identical(regionId, _keep) ? this.regionId : regionId as int?,
    cityId: identical(cityId, _keep) ? this.cityId : cityId as int?,
    breedId: identical(breedId, _keep) ? this.breedId : breedId as int?,
    sex: identical(sex, _keep) ? this.sex : sex as String?,
    offerType: identical(offerType, _keep)
        ? this.offerType
        : offerType as String?,
    ageMin: identical(ageMin, _keep) ? this.ageMin : ageMin as int?,
    ageMax: identical(ageMax, _keep) ? this.ageMax : ageMax as int?,
    priceMin: identical(priceMin, _keep) ? this.priceMin : priceMin as num?,
    priceMax: identical(priceMax, _keep) ? this.priceMax : priceMax as num?,
    ownerId: identical(ownerId, _keep) ? this.ownerId : ownerId as String?,
    sort: sort ?? this.sort,
  );

  /// معاملات `search_listings` (الفارغ يحذف).
  Map<String, dynamic> toParams({
    required int limit,
    Map<String, dynamic>? cursor,
  }) {
    final q = query?.trim();
    return {
      if (q != null && q.isNotEmpty) 'p_query': q,
      'p_region_id': ?regionId,
      'p_city_id': ?cityId,
      'p_breed_id': ?breedId,
      'p_sex': ?sex,
      'p_offer_type': ?offerType,
      'p_age_min': ?ageMin,
      'p_age_max': ?ageMax,
      'p_price_min': ?priceMin,
      'p_price_max': ?priceMax,
      'p_owner_id': ?ownerId,
      'p_sort': sort.wire,
      'p_limit': limit,
      'p_cursor': ?cursor,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      other.query == query &&
      other.regionId == regionId &&
      other.cityId == cityId &&
      other.breedId == breedId &&
      other.sex == sex &&
      other.offerType == offerType &&
      other.ageMin == ageMin &&
      other.ageMax == ageMax &&
      other.priceMin == priceMin &&
      other.priceMax == priceMax &&
      other.ownerId == ownerId &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(
    query,
    regionId,
    cityId,
    breedId,
    sex,
    offerType,
    ageMin,
    ageMax,
    priceMin,
    priceMax,
    ownerId,
    sort,
  );
}
