/// الدعايات التجارية (TEAM-DEC-017، العقد 1.6.0): رد `list_active_promotions`.
library;

/// موضع العرض في التطبيق.
enum PromotionPlacement {
  homeFeed('HOME_FEED'),
  searchResults('SEARCH_RESULTS');

  const PromotionPlacement(this.wire);

  /// القيمة في العقد.
  final String wire;
}

/// ما يحدث عند الضغط على الدعاية.
enum PromotionAction {
  url,
  whatsapp,
  call,
  none;

  static PromotionAction parse(String? v) => switch (v) {
    'URL' => url,
    'WHATSAPP' => whatsapp,
    'CALL' => call,
    'NONE' => none,
    _ => throw FormatException('action_type غير معروف: $v'),
  };
}

/// دعاية جارية كما يعرضها التطبيق (`schemas/promotion-public`).
class Promotion {
  const Promotion({
    required this.id,
    required this.title,
    required this.advertiserName,
    required this.imagePath,
    required this.action,
    this.body,
    this.actionValue,
  });

  factory Promotion.fromJson(Map<String, dynamic> j) => Promotion(
    id: j['id'] as String,
    title: j['title'] as String,
    body: j['body'] as String?,
    advertiserName: j['advertiser_name'] as String,
    imagePath: j['image_path'] as String,
    action: PromotionAction.parse(j['action_type'] as String?),
    actionValue: j['action_value'] as String?,
  );

  final String id;
  final String title;
  final String? body;
  final String advertiserName;

  /// مسار داخل bucket ‏promotions العام.
  final String imagePath;
  final PromotionAction action;

  /// رابط https، أو رقم +9665XXXXXXXX لواتساب والاتصال، أو null.
  final String? actionValue;

  /// الرابط الخارجي للإجراء، أو null إن لم يكن للدعاية إجراء صالح.
  Uri? get actionUri {
    final v = actionValue;
    if (v == null) return null;
    switch (action) {
      case PromotionAction.url:
        final u = Uri.tryParse(v);
        return u != null && u.scheme == 'https' && u.host.isNotEmpty ? u : null;
      case PromotionAction.whatsapp:
        final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
        return digits.isEmpty ? null : Uri.https('wa.me', '/$digits');
      case PromotionAction.call:
        return Uri(scheme: 'tel', path: v);
      case PromotionAction.none:
        return null;
    }
  }

  /// نص زر الإجراء، أو null بلا زر.
  String? get actionLabel => switch (action) {
    PromotionAction.url => 'زيارة الموقع',
    PromotionAction.whatsapp => 'تواصل واتساب',
    PromotionAction.call => 'اتصل الآن',
    PromotionAction.none => null,
  };
}

/// رد `list_active_promotions`: الدعايات الجارية وفاصل الإدراج.
class ActivePromotions {
  const ActivePromotions({
    required this.enabled,
    required this.feedInterval,
    required this.items,
  });

  factory ActivePromotions.fromJson(Map<String, dynamic> j) => ActivePromotions(
    enabled: j['enabled'] as bool,
    feedInterval: j['feed_interval'] as int,
    items: [
      for (final e in j['items'] as List)
        Promotion.fromJson(Map<String, dynamic>.from(e as Map)),
    ],
  );

  /// لا دعايات: الحالة عند الإطفاء أو فشل الجلب.
  static const none = ActivePromotions(
    enabled: false,
    feedInterval: 8,
    items: [],
  );

  final bool enabled;

  /// دعاية بعد كل [feedInterval] إعلانًا (4 إلى 30).
  final int feedInterval;
  final List<Promotion> items;

  bool get isEmpty => !enabled || items.isEmpty || feedInterval < 1;
}
