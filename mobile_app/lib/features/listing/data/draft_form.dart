/// حقول مسودة الإعلان القابلة للتحرير، بمفاتيح `save_listing_draft` نفسها
/// (`contracts/schemas/listing-draft-patch.schema.json`).
///
/// القيم في خريطة واحدة ليُحسب الفرق بين ما على الجهاز وما في الخادم فيُرسل
/// ما تغير فقط. المفتاح الغائب والقيمة `null` سواء.
class DraftForm {
  const DraftForm([this.values = const {}]);

  /// يبني النموذج من `version` في رد دوال المعلن.
  factory DraftForm.fromVersion(Map<String, dynamic>? v) {
    if (v == null) return const DraftForm();
    return DraftForm({
      for (final k in _scalarKeys) k: v[k],
      'owner_declaration': v['owner_declaration_at'] != null,
      'auction_starts_at': v['auction_starts_at'] == null
          ? null
          : DateTime.parse(v['auction_starts_at'] as String).toUtc(),
    });
  }

  static const offerFixed = 'FIXED_PRICE';
  static const offerAuction = 'IN_PERSON_AUCTION';

  static const _scalarKeys = [
    'title',
    'description',
    'breed_id',
    'breed_note',
    'sex',
    'age_months',
    'color',
    'region_id',
    'city_id',
    'health_notes',
    'offer_type',
    'price',
    'auction_region_id',
    'auction_city_id',
    'auction_venue',
    'auction_lat',
    'auction_lng',
    'contact_phone',
    'contact_whatsapp_phone',
  ];

  final Map<String, Object?> values;

  String? get title => values['title'] as String?;
  String? get description => values['description'] as String?;
  int? get breedId => values['breed_id'] as int?;
  String? get breedNote => values['breed_note'] as String?;
  String? get sex => values['sex'] as String?;
  int? get ageMonths => values['age_months'] as int?;
  String? get color => values['color'] as String?;
  int? get regionId => values['region_id'] as int?;
  int? get cityId => values['city_id'] as int?;
  String? get healthNotes => values['health_notes'] as String?;
  bool get ownerDeclaration => values['owner_declaration'] == true;
  String? get offerType => values['offer_type'] as String?;
  num? get price => values['price'] as num?;
  int? get auctionRegionId => values['auction_region_id'] as int?;
  int? get auctionCityId => values['auction_city_id'] as int?;
  String? get auctionVenue => values['auction_venue'] as String?;
  double? get auctionLat => (values['auction_lat'] as num?)?.toDouble();
  double? get auctionLng => (values['auction_lng'] as num?)?.toDouble();
  bool get hasAuctionLocation => auctionLat != null && auctionLng != null;
  DateTime? get auctionStartsAt => values['auction_starts_at'] as DateTime?;
  String? get contactPhone => values['contact_phone'] as String?;
  String? get whatsappPhone => values['contact_whatsapp_phone'] as String?;

  bool get isAuction => offerType == offerAuction;

  DraftForm set(String key, Object? value) =>
      DraftForm({...values, key: value});

  /// يضبط عدة مفاتيح معًا.
  DraftForm setAll(Map<String, Object?> changes) =>
      DraftForm({...values, ...changes});

  /// رقعة `save_listing_draft` بالمفاتيح [keys] التي اختلفت عن [saved].
  Map<String, Object?> diff(DraftForm saved, Iterable<String> keys) {
    final patch = <String, Object?>{};
    for (final k in keys) {
      final mine = values[k];
      if (mine != saved.values[k]) patch[k] = _wire(mine);
    }
    return patch;
  }

  /// نسخة تأخذ [keys] من [server] وتبقي الباقي كما هو محليًا.
  DraftForm adopt(DraftForm server, Iterable<String> keys) =>
      DraftForm({...values, for (final k in keys) k: server.values[k]});

  static Object? _wire(Object? v) =>
      v is DateTime ? v.toUtc().toIso8601String() : v;
}

/// مفاتيح كل خطوة، لحفظها وحدها.
abstract final class DraftKeys {
  static const offer = {'offer_type'};
  static const data = {
    'title',
    'breed_id',
    'breed_note',
    'sex',
    'age_months',
    'color',
  };
  static const description = {'description', 'health_notes'};
  static const location = {'region_id', 'city_id'};
  static const price = {'price'};
  static const auction = {
    'auction_region_id',
    'auction_city_id',
    'auction_venue',
    'auction_starts_at',
    'auction_lat',
    'auction_lng',
  };
  static const contact = {'contact_phone', 'contact_whatsapp_phone'};
  static const declaration = {'owner_declaration'};

  static const all = {
    ...offer,
    ...data,
    ...description,
    ...location,
    ...price,
    ...auction,
    ...contact,
  };
}

/// وسيط في مسودة كما يعيده الخادم.
class OwnerMedia {
  const OwnerMedia({
    required this.id,
    required this.status,
    required this.isCover,
    required this.sortOrder,
    required this.bucket,
    required this.objectPath,
    this.failureReason,
    this.kind = 'IMAGE',
  });

  factory OwnerMedia.fromJson(Map<String, dynamic> j) => OwnerMedia(
    kind: j['kind'] as String? ?? 'IMAGE',
    id: j['id'] as String,
    status: j['status'] as String,
    isCover: j['is_cover'] as bool,
    sortOrder: j['sort_order'] as int,
    bucket: j['bucket'] as String,
    objectPath: j['object_path'] as String,
    failureReason: j['failure_reason'] as String?,
  );

  final String id;

  /// `IMAGE` أو `VIDEO`.
  final String kind;

  /// `PENDING` أو `READY` أو `FAILED`.
  final String status;
  final bool isCover;
  final int sortOrder;
  final String bucket;
  final String objectPath;
  final String? failureReason;
}

/// الإعلان كما يعيده الخادم لصاحبه (`listing-owner.schema.json`): ما يلزم
/// المعالج منه.
class OwnerListing {
  const OwnerListing({
    required this.id,
    required this.status,
    required this.form,
    required this.media,
  });

  factory OwnerListing.fromJson(Map<String, dynamic> j) {
    final listing = j['listing'] as Map<String, dynamic>;
    return OwnerListing(
      id: listing['id'] as String,
      status: listing['status'] as String,
      form: DraftForm.fromVersion(j['version'] as Map<String, dynamic>?),
      media: List.unmodifiable(
        (j['media'] as List)
            .map((e) => OwnerMedia.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      ),
    );
  }

  final String id;
  final String status;
  final DraftForm form;
  final List<OwnerMedia> media;

  int get mediaCount => media.length;
}
