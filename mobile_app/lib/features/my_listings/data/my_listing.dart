/// صف من `my_listings` (`contracts/fixtures/my-listing.json`).
class MyListing {
  const MyListing({
    required this.listingId,
    required this.status,
    required this.hasDraft,
    required this.title,
    required this.offerType,
    required this.price,
    required this.auctionStartsAt,
    required this.auctionPassed,
    required this.coverBucket,
    required this.coverPath,
    required this.reasonLabel,
    required this.reasonText,
    required this.nextBumpAt,
    required this.updatedAt,
  });

  factory MyListing.fromJson(Map<String, dynamic> j) => MyListing(
    listingId: j['listing_id'] as String,
    status: j['status'] as String,
    hasDraft: j['has_draft'] as bool,
    title: j['title'] as String?,
    offerType: j['offer_type'] as String?,
    price: j['price'] as num?,
    auctionStartsAt: j['auction_starts_at'] == null
        ? null
        : DateTime.parse(j['auction_starts_at'] as String),
    auctionPassed: j['auction_passed'] as bool? ?? false,
    coverBucket: j['cover_bucket'] as String?,
    coverPath: j['cover_path'] as String?,
    reasonLabel: j['reason_label_ar'] as String?,
    reasonText: j['reason_text'] as String?,
    nextBumpAt: j['next_bump_at'] == null
        ? null
        : DateTime.parse(j['next_bump_at'] as String),
    updatedAt: DateTime.parse(j['updated_at'] as String),
  );

  final String listingId;

  /// `DRAFT` أو `UNDER_REVIEW` أو `REJECTED` أو `PUBLISHED` أو `HIDDEN` أو `ARCHIVED`.
  final String status;

  /// للمنشور: توجد نسخة تعديل خاصة قيد التحرير.
  final bool hasDraft;
  final String? title;
  final String? offerType;
  final num? price;
  final DateTime? auctionStartsAt;
  final bool auctionPassed;
  final String? coverBucket;
  final String? coverPath;

  /// سبب الرفض أو الإخفاء: تسمية السبب ونصه الحر.
  final String? reasonLabel;
  final String? reasonText;
  final DateTime? nextBumpAt;
  final DateTime updatedAt;

  bool get isAuction => offerType == 'IN_PERSON_AUCTION';
  bool get isDraft => status == 'DRAFT';
  bool get isRejected => status == 'REJECTED';

  /// يسمح بحذف المسودة والمرفوض فقط (`delete_listing`).
  bool get canDelete => status == 'DRAFT' || status == 'REJECTED';

  /// يسمح بمتابعة تحرير مسودة (قراءة مباشرة).
  bool get canResume => isDraft;

  /// تعديل إعلان منشور أو مرفوض أو مؤرشف بمسودة جديدة (`start_listing_edit`).
  bool get canEdit =>
      status == 'PUBLISHED' || status == 'REJECTED' || status == 'ARCHIVED';
}
