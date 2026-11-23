import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/settings/published_settings.dart';
import '../../../core/settings/settings_repository.dart';
import '../data/draft_form.dart';
import '../data/media_backend.dart';
import '../data/media_models.dart';
import '../domain/image_sniff.dart';
import 'post_controller.dart';

enum MediaStage {
  /// بانتظار دوره في الطابور.
  queued,
  registering,
  uploading,
  finalizing,
  ready,

  /// رفضه الخادم بعد الفحص (`failureReason`)؛ يحذف ولا يعاد.
  failed,

  /// تعذرت مرحلة (انقطاع مثلًا)؛ يمكن استئنافها بـ[MediaController.retry].
  stalled,
}

class MediaItem {
  const MediaItem({
    required this.key,
    this.bytes,
    required this.mimeType,
    this.slot,
    this.uploaded = false,
    this.stage = MediaStage.queued,
    this.error,
    this.failureReason,
  });

  /// معرف محلي ثابت قبل أن يعطيه الخادم معرفًا.
  final String key;

  /// بايتات الصورة المحلية. `null` لصورة محفوظة في الخادم من جلسة سابقة؛ تعرض
  /// برابط موقع من [slot].
  final Uint8List? bytes;
  final String mimeType;

  /// موضع الملف بعد `add_listing_media`.
  final MediaSlot? slot;
  final bool uploaded;
  final MediaStage stage;
  final AppError? error;
  final String? failureReason;

  String? get mediaId => slot?.mediaId;
  bool get isBusy =>
      stage == MediaStage.queued ||
      stage == MediaStage.registering ||
      stage == MediaStage.uploading ||
      stage == MediaStage.finalizing;

  MediaItem copyWith({
    MediaSlot? slot,
    bool? uploaded,
    MediaStage? stage,
    AppError? error,
    bool clearError = false,
    String? failureReason,
  }) => MediaItem(
    key: key,
    bytes: bytes,
    mimeType: mimeType,
    slot: slot ?? this.slot,
    uploaded: uploaded ?? this.uploaded,
    stage: stage ?? this.stage,
    error: clearError ? null : (error ?? this.error),
    failureReason: failureReason ?? this.failureReason,
  );
}

class MediaState {
  const MediaState({
    this.items = const [],
    this.coverKey,
    this.notices = const [],
    this.arranged = false,
    this.error,
  });

  final List<MediaItem> items;

  /// الغلاف الذي اختاره المستخدم؛ وإلا فأول صورة جاهزة.
  final String? coverKey;

  /// ملاحظات عن ملفات تجوهلت محليًا (نوع أو حجم أو عدد).
  final List<String> notices;

  /// هل رتب الخادم الوسائط بآخر ترتيب وغلاف.
  final bool arranged;

  /// خطأ عملية عامة (حذف أو ترتيب).
  final AppError? error;

  int get readyCount => items.where((i) => i.stage == MediaStage.ready).length;
  bool get anyBusy => items.any((i) => i.isBusy);

  /// جاهزة كلها وبلا فاشلة أو متعثرة.
  bool get allReady =>
      items.isNotEmpty && items.every((i) => i.stage == MediaStage.ready);

  String? get effectiveCoverKey {
    final chosen = items.where((i) => i.key == coverKey).firstOrNull;
    if (chosen != null && chosen.stage != MediaStage.failed) return chosen.key;
    return items.where((i) => i.stage == MediaStage.ready).firstOrNull?.key;
  }

  MediaState copyWith({
    List<MediaItem>? items,
    String? coverKey,
    bool clearCover = false,
    List<String>? notices,
    bool? arranged,
    AppError? error,
    bool clearError = false,
  }) => MediaState(
    items: items ?? this.items,
    coverKey: clearCover ? null : (coverKey ?? this.coverKey),
    notices: notices ?? this.notices,
    arranged: arranged ?? this.arranged,
    error: clearError ? null : (error ?? this.error),
  );
}

/// صور المسودة: يفحصها محليًا ثم يسجلها ويرفعها ويثبتها واحدة بعد أخرى.
class MediaController extends Notifier<MediaState> {
  static const _finalizeAttempts = 3;

  bool _draining = false;

  MediaBackend get _backend => ref.read(mediaBackendProvider);
  PublishedSettings get _settings =>
      ref.read(publishedSettingsProvider).requireValue;

  @override
  MediaState build() => const MediaState();

  /// كم صورة بقي مكانها.
  int get remainingSlots =>
      (_settings.media.imagesMax - state.items.length).clamp(0, 999);

  /// يحمّل صور مسودة محفوظة في الخادم (استئناف مسودة). يستبدل ما في الحالة.
  void preload(List<OwnerMedia> media) {
    final items = [
      for (final m in media)
        MediaItem(
          key: m.id,
          mimeType: 'image/jpeg',
          slot: MediaSlot(
            mediaId: m.id,
            bucket: m.bucket,
            objectPath: m.objectPath,
          ),
          uploaded: true,
          // وسيط ما زال بانتظار الرفع لا بايتات له هنا ليكمل: يحذف ويضاف غيره.
          stage: m.status == 'READY' ? MediaStage.ready : MediaStage.failed,
          failureReason: m.failureReason,
        ),
    ];
    state = MediaState(
      items: items,
      coverKey: media.where((m) => m.isCover).firstOrNull?.id,
      arranged: true,
    );
  }

  /// يضيف الصور المختارة بعد فحصها محليًا ثم يبدأ رفعها.
  void addPicked(List<PickedImage> picked) {
    final media = _settings.media;
    var room = remainingSlots;
    var unsupported = 0, tooLarge = 0, overLimit = 0, empty = 0;
    final accepted = <MediaItem>[];
    for (final p in picked) {
      if (p.bytes.isEmpty) {
        empty++;
        continue;
      }
      final mime = ImageSniff.mimeOf(p.bytes);
      if (mime == null || !media.imageMimeTypes.contains(mime)) {
        unsupported++;
      } else if (p.bytes.length > media.imageMaxBytes) {
        tooLarge++;
      } else if (room <= 0) {
        overLimit++;
      } else {
        room--;
        accepted.add(
          MediaItem(key: const Uuid().v4(), bytes: p.bytes, mimeType: mime),
        );
      }
    }
    final mb = (media.imageMaxBytes / (1024 * 1024)).round();
    state = state.copyWith(
      items: [...state.items, ...accepted],
      arranged: accepted.isEmpty ? state.arranged : false,
      clearError: true,
      notices: [
        if (unsupported > 0)
          'تجوهل $unsupported ملف: النوع غير مدعوم. المسموح JPEG وPNG.',
        if (tooLarge > 0) 'تجوهل $tooLarge ملف: أكبر من $mb ميغابايت.',
        if (empty > 0) 'تجوهل $empty ملف فارغ.',
        if (overLimit > 0)
          'تجوهل $overLimit ملف: الحد الأقصى ${media.imagesMax} صور.',
      ],
    );
    _drain();
  }

  /// يستأنف عنصرًا متعثرًا من المرحلة التي توقف عندها.
  void retry(String key) {
    _update(key, (i) => i.copyWith(stage: MediaStage.queued, clearError: true));
    _drain();
  }

  /// يحذف عنصرًا: محليًا إن لم يسجل بعد، وإلا من الخادم والتخزين.
  Future<void> remove(String key) async {
    final item = state.items.where((i) => i.key == key).firstOrNull;
    if (item == null || item.isBusy && item.slot == null) {
      // لم يبدأ تسجيله: يُسحب من القائمة فقط.
      if (item != null) _drop(key);
      return;
    }
    try {
      if (item.slot != null) await _backend.remove(item.slot!.mediaId);
      _drop(key);
    } on AppError catch (e) {
      state = state.copyWith(error: e);
    }
  }

  void _drop(String key) => state = state.copyWith(
    items: [
      for (final i in state.items)
        if (i.key != key) i,
    ],
    clearCover: state.coverKey == key,
    arranged: false,
    clearError: true,
  );

  void setCover(String key) =>
      state = state.copyWith(coverKey: key, arranged: false);

  /// يحرك عنصرًا موضعًا واحدًا: [delta] سالب للأمام، موجب للخلف.
  void move(String key, int delta) {
    final list = [...state.items];
    final from = list.indexWhere((i) => i.key == key);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= list.length) return;
    list.insert(to, list.removeAt(from));
    state = state.copyWith(items: list, arranged: false);
  }

  /// يثبت الترتيب والغلاف في الخادم قبل الانتقال. `true` عند النجاح.
  Future<bool> arrange() async {
    if (state.arranged) return true;
    final listingId = ref.read(postControllerProvider).listingId;
    final ids = [
      for (final i in state.items)
        if (i.mediaId != null) i.mediaId!,
    ];
    if (listingId == null || ids.isEmpty) return false;
    final coverKey = state.effectiveCoverKey;
    final cover = state.items.where((i) => i.key == coverKey).firstOrNull;
    try {
      await _backend.arrange(listingId, ids, coverId: cover?.mediaId);
      state = state.copyWith(arranged: true, clearError: true);
      return true;
    } on AppError catch (e) {
      state = state.copyWith(error: e);
      return false;
    }
  }

  void _update(String key, MediaItem Function(MediaItem) f) {
    state = state.copyWith(
      items: [for (final i in state.items) i.key == key ? f(i) : i],
    );
  }

  MediaItem? _byKey(String key) =>
      state.items.where((i) => i.key == key).firstOrNull;

  /// يعالج الطابور واحدًا بعد آخر؛ استدعاء ثانٍ أثناء العمل لا يبدأ عاملًا ثانيًا.
  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (true) {
        final next = state.items
            .where((i) => i.stage == MediaStage.queued)
            .firstOrNull;
        if (next == null) break;
        await _process(next.key);
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _process(String key) async {
    final listingId = ref.read(postControllerProvider).listingId;
    var item = _byKey(key)!;
    if (listingId == null) {
      _update(
        key,
        (i) => i.copyWith(
          stage: MediaStage.stalled,
          error: const AppError(AppErrorCode.invalidState),
        ),
      );
      return;
    }
    try {
      if (item.slot == null) {
        _update(key, (i) => i.copyWith(stage: MediaStage.registering));
        final slot = await _backend.add(
          listingId,
          mimeType: item.mimeType,
          sizeBytes: item.bytes!.length,
        );
        _update(key, (i) => i.copyWith(slot: slot));
        item = _byKey(key)!;
      }
      for (var attempt = 1; ; attempt++) {
        if (!item.uploaded) {
          _update(key, (i) => i.copyWith(stage: MediaStage.uploading));
          await _backend.upload(
            item.slot!,
            item.bytes!,
            mimeType: item.mimeType,
          );
          _update(key, (i) => i.copyWith(uploaded: true));
          item = _byKey(key)!;
        }
        _update(key, (i) => i.copyWith(stage: MediaStage.finalizing));
        try {
          final res = await _backend.finalize(item.slot!.mediaId);
          _update(
            key,
            (i) => res.ready
                ? i.copyWith(stage: MediaStage.ready, clearError: true)
                : i.copyWith(
                    stage: MediaStage.failed,
                    failureReason: res.failureReason,
                  ),
          );
          state = state.copyWith(arranged: false);
          return;
        } on AppError catch (e) {
          if (e.code == AppErrorCode.mediaNotUploaded && attempt == 1) {
            // الخادم لم يجد الملف: يعاد الرفع مرة ثم الاستدعاء.
            _update(key, (i) => i.copyWith(uploaded: false));
            item = _byKey(key)!;
            continue;
          }
          if (e.code == AppErrorCode.mediaProcessingFailed &&
              attempt < _finalizeAttempts) {
            continue;
          }
          rethrow;
        }
      }
    } on AppError catch (e) {
      _update(key, (i) => i.copyWith(stage: MediaStage.stalled, error: e));
    }
  }
}

final mediaControllerProvider =
    NotifierProvider.autoDispose<MediaController, MediaState>(
      MediaController.new,
    );
