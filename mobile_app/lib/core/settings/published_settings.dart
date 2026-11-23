/// نماذج رد `get_published_settings` (العقد 0.1.0، `schemas/published-settings.schema.json`).
///
/// تُكتب يدويًا وفق قرار المطابقة في `contracts/README.md`؛ يتحقق منها
/// اختبار يحلل مثال العقد.
library;

class Region {
  const Region({required this.id, required this.nameAr});

  factory Region.fromJson(Map<String, dynamic> j) =>
      Region(id: j['id'] as int, nameAr: j['name_ar'] as String);

  final int id;
  final String nameAr;
}

class City {
  const City({required this.id, required this.nameAr, required this.regionId});

  factory City.fromJson(Map<String, dynamic> j) => City(
    id: j['id'] as int,
    nameAr: j['name_ar'] as String,
    regionId: j['region_id'] as int,
  );

  final int id;
  final String nameAr;
  final int regionId;
}

class Breed {
  const Breed({
    required this.id,
    required this.nameAr,
    required this.requiresNote,
  });

  factory Breed.fromJson(Map<String, dynamic> j) => Breed(
    id: j['id'] as int,
    nameAr: j['name_ar'] as String,
    requiresNote: j['requires_note'] as bool,
  );

  final int id;
  final String nameAr;

  /// «أخرى»: يلزم نص حر يصف السلالة.
  final bool requiresNote;
}

/// القوائم الفعالة: المناطق والمدن والسلالات.
class Lookups {
  const Lookups({
    required this.regions,
    required this.cities,
    required this.breeds,
  });

  factory Lookups.fromJson(Map<String, dynamic> j) => Lookups(
    regions: _list(j['regions'], Region.fromJson),
    cities: _list(j['cities'], City.fromJson),
    breeds: _list(j['breeds'], Breed.fromJson),
  );

  final List<Region> regions;
  final List<City> cities;
  final List<Breed> breeds;

  List<City> citiesOf(int regionId) =>
      cities.where((c) => c.regionId == regionId).toList(growable: false);

  Region? region(int? id) => _find(regions, (r) => r.id == id);
  City? city(int? id) => _find(cities, (c) => c.id == id);
  Breed? breed(int? id) => _find(breeds, (b) => b.id == id);
}

class ListingLimits {
  const ListingLimits({
    required this.titleMin,
    required this.titleMax,
    required this.descriptionMin,
    required this.descriptionMax,
    required this.dailyNewLimit,
    required this.openDraftsMax,
  });

  factory ListingLimits.fromJson(Map<String, dynamic> j) => ListingLimits(
    titleMin: j['title_min'] as int,
    titleMax: j['title_max'] as int,
    descriptionMin: j['description_min'] as int,
    descriptionMax: j['description_max'] as int,
    dailyNewLimit: j['daily_new_limit'] as int,
    openDraftsMax: j['open_drafts_max'] as int,
  );

  final int titleMin;
  final int titleMax;
  final int descriptionMin;
  final int descriptionMax;
  final int dailyNewLimit;
  final int openDraftsMax;
}

class MediaLimits {
  const MediaLimits({
    required this.imagesMin,
    required this.imagesMax,
    required this.imageMaxBytes,
    required this.imageMimeTypes,
    required this.videoEnabled,
    required this.videoMaxSeconds,
    required this.videoMaxBytes,
  });

  factory MediaLimits.fromJson(Map<String, dynamic> j) => MediaLimits(
    imagesMin: j['images_min'] as int,
    imagesMax: j['images_max'] as int,
    imageMaxBytes: j['image_max_bytes'] as int,
    imageMimeTypes: List<String>.unmodifiable(
      (j['image_mime_types'] as List).cast<String>(),
    ),
    videoEnabled: j['video_enabled'] as bool,
    videoMaxSeconds: j['video_max_seconds'] as int,
    videoMaxBytes: j['video_max_bytes'] as int,
  );

  final int imagesMin;
  final int imagesMax;
  final int imageMaxBytes;
  final List<String> imageMimeTypes;
  final bool videoEnabled;
  final int videoMaxSeconds;
  final int videoMaxBytes;
}

class InteractionLimits {
  const InteractionLimits({
    required this.messageMax,
    required this.commentMax,
    required this.ratingMax,
  });

  factory InteractionLimits.fromJson(Map<String, dynamic> j) =>
      InteractionLimits(
        messageMax: j['message_max'] as int,
        commentMax: j['comment_max'] as int,
        ratingMax: j['rating_max'] as int,
      );

  final int messageMax;
  final int commentMax;
  final int ratingMax;
}

class RateLimits {
  const RateLimits({
    required this.messagesPerMinute,
    required this.newConversationsPerHour,
    required this.commentsPerMinute,
    required this.reportsPerDay,
  });

  factory RateLimits.fromJson(Map<String, dynamic> j) => RateLimits(
    messagesPerMinute: j['messages_per_minute'] as int,
    newConversationsPerHour: j['new_conversations_per_hour'] as int,
    commentsPerMinute: j['comments_per_minute'] as int,
    reportsPerDay: j['reports_per_day'] as int,
  );

  final int messagesPerMinute;
  final int newConversationsPerHour;
  final int commentsPerMinute;
  final int reportsPerDay;
}

class FollowLimits {
  const FollowLimits({
    required this.savedSearchesMax,
    required this.followedSellersMax,
  });

  factory FollowLimits.fromJson(Map<String, dynamic> j) => FollowLimits(
    savedSearchesMax: j['saved_searches_max'] as int,
    followedSellersMax: j['followed_sellers_max'] as int,
  );

  final int savedSearchesMax;
  final int followedSellersMax;
}

class PublishedSettings {
  const PublishedSettings({
    required this.version,
    required this.publishedAt,
    required this.listing,
    required this.media,
    required this.interaction,
    required this.rateLimits,
    required this.follows,
    required this.bumpIntervalHours,
    required this.lookups,
  });

  factory PublishedSettings.fromJson(Map<String, dynamic> j) {
    final s = j['settings'] as Map<String, dynamic>;
    return PublishedSettings(
      version: j['version'] as int,
      publishedAt: DateTime.parse(j['published_at'] as String),
      listing: ListingLimits.fromJson(s['listing'] as Map<String, dynamic>),
      media: MediaLimits.fromJson(s['media'] as Map<String, dynamic>),
      interaction: InteractionLimits.fromJson(
        s['interaction'] as Map<String, dynamic>,
      ),
      rateLimits: RateLimits.fromJson(s['rate_limits'] as Map<String, dynamic>),
      follows: FollowLimits.fromJson(s['follows'] as Map<String, dynamic>),
      bumpIntervalHours:
          (s['bump'] as Map<String, dynamic>)['interval_hours'] as int,
      lookups: Lookups.fromJson(j['lookups'] as Map<String, dynamic>),
    );
  }

  final int version;
  final DateTime publishedAt;
  final ListingLimits listing;
  final MediaLimits media;
  final InteractionLimits interaction;
  final RateLimits rateLimits;
  final FollowLimits follows;
  final int bumpIntervalHours;
  final Lookups lookups;
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) =>
    List<T>.unmodifiable(
      (raw as List).map((e) => parse(e as Map<String, dynamic>)),
    );

T? _find<T>(List<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}
