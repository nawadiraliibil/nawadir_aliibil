/// تقييم ظاهر للعامة: صف `public_ratings` (`contracts/fixtures/public-ratings.json`).
class PublicRating {
  const PublicRating({
    required this.id,
    required this.sellerId,
    required this.raterId,
    required this.raterName,
    required this.score,
    required this.body,
    required this.replyBody,
    required this.edited,
    required this.createdAt,
  });

  factory PublicRating.fromJson(Map<String, dynamic> j) => PublicRating(
    id: j['rating_id'] as String,
    sellerId: j['seller_id'] as String,
    raterId: j['rater_id'] as String,
    raterName: j['rater_display_name'] as String?,
    score: j['score'] as int,
    body: j['body'] as String?,
    replyBody: j['reply_body'] as String?,
    edited: j['edited_at'] != null,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  final String id;
  final String sellerId;
  final String raterId;
  final String? raterName;
  final int score;
  final String? body;
  final String? replyBody;
  final bool edited;
  final DateTime createdAt;

  String get displayName =>
      (raterName == null || raterName!.isEmpty) ? 'مستخدم' : raterName!;
}

/// تقييم لصاحب الجلسة كمعلن: صف `my_received_ratings`.
class ReceivedRating {
  const ReceivedRating({
    required this.id,
    required this.raterName,
    required this.score,
    required this.body,
    required this.hidden,
    required this.replyBody,
    required this.appealId,
    required this.appealStatus,
    required this.createdAt,
  });

  factory ReceivedRating.fromJson(Map<String, dynamic> j) => ReceivedRating(
    id: j['rating_id'] as String,
    raterName: j['rater_display_name'] as String?,
    score: j['score'] as int,
    body: j['body'] as String?,
    hidden: j['status'] == 'HIDDEN',
    replyBody: j['reply_body'] as String?,
    appealId: j['appeal_id'] as String?,
    appealStatus: j['appeal_status'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  final String id;
  final String? raterName;
  final int score;
  final String? body;

  /// أخفته الإدارة: يراه المعلن بحالته ولا يظهر للعامة.
  final bool hidden;
  final String? replyBody;
  final String? appealId;

  /// `OPEN` أو `ACCEPTED` أو `REJECTED`، أو `null` دون اعتراض.
  final String? appealStatus;
  final DateTime createdAt;

  String get displayName =>
      (raterName == null || raterName!.isEmpty) ? 'مستخدم' : raterName!;

  bool get canReply => !hidden;

  /// اعتراض واحد لكل تقييم ظاهر.
  bool get canAppeal => !hidden && appealId == null;
}

/// أهلية صاحب الجلسة لتقييم معلن (`get_rating_eligibility`).
class RatingEligibility {
  const RatingEligibility({required this.eligible, this.reason});

  factory RatingEligibility.fromJson(Map<String, dynamic> j) =>
      RatingEligibility(
        eligible: j['eligible'] as bool,
        reason: j['reason'] as String?,
      );

  final bool eligible;

  /// `SELF` أو `ALREADY_RATED` أو `BLOCKED` أو `NO_CONVERSATION` أو `NO_EXCHANGE`.
  final String? reason;

  /// شرح بسيط لسبب عدم الأهلية (F07).
  String get reasonText => switch (reason) {
    'SELF' => 'لا يمكنك تقييم نفسك.',
    'BLOCKED' => 'لا يمكن التقييم بسبب الحظر.',
    'NO_EXCHANGE' =>
      'يمكن التقييم بعد أن يرد المعلن على رسالتك وتتبادلا الحديث.',
    'NO_CONVERSATION' =>
      'يمكن التقييم بعد تبادل رسائل مع المعلن. افتح أحد إعلاناته وراسله.',
    _ => 'التقييم غير متاح الآن.',
  };
}

/// كلمات الدرجات 1 إلى 5.
const scoreWords = {1: 'سيئ', 2: 'مقبول', 3: 'جيد', 4: 'جيد جدًا', 5: 'ممتاز'};
