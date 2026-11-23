import 'dart:typed_data';

import 'package:nawadir_aliibil/features/listing/data/media_backend.dart';
import 'package:nawadir_aliibil/features/listing/data/media_models.dart';

/// بايتات تبدأ بتوقيع JPEG. [seed] يميز الصور بعضها عن بعض.
Uint8List jpegBytes({int seed = 0, int length = 64}) => Uint8List.fromList([
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  ...List.filled(length - 4, seed),
]);

/// بايتات تبدأ بتوقيع PNG.
Uint8List pngBytes({int length = 64}) => Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  ...List.filled(length - 8, 1),
]);

/// بايتات ليست صورة مدعومة: HTML بامتداد صورة.
Uint8List htmlBytes() =>
    Uint8List.fromList('<html>x</html>'.codeUnits + List.filled(50, 0));

/// خلفية وسائط مزيفة تسجل الاستدعاءات وتنفذ سيناريوهات الفشل.
class FakeMediaBackend implements MediaBackend {
  /// سجل الاستدعاءات بالترتيب: `add`، `upload:<id>`، `finalize:<id>`،
  /// `remove:<id>`، `arrange`.
  final calls = <String>[];

  /// أخطاء تُرمى بالترتيب عند الرفع (واحد لكل استدعاء، ثم نجاح).
  final uploadFailures = <Object>[];

  /// أخطاء أو نتائج تُعاد بالترتيب عند التثبيت؛ الفارغة تعني نجاحًا.
  final finalizeScript = <Object>[];

  /// معرفات تُرفض بعد الفحص مع السبب.
  final rejectedWith = <String, String>{};

  Object? arrangeFailure;
  List<String>? lastArrangedIds;
  String? lastCoverId;

  var _n = 0;
  final _sizes = <String, int>{};

  @override
  Future<MediaSlot> add(
    String listingId, {
    required String mimeType,
    required int sizeBytes,
  }) async {
    calls.add('add');
    final id = 'media-${++_n}';
    _sizes[id] = sizeBytes;
    return MediaSlot(
      mediaId: id,
      bucket: 'listing-images',
      objectPath: 'owner/$listingId/$id.jpg',
    );
  }

  @override
  Future<void> upload(
    MediaSlot slot,
    Uint8List bytes, {
    required String mimeType,
  }) async {
    calls.add('upload:${slot.mediaId}');
    if (uploadFailures.isNotEmpty) throw uploadFailures.removeAt(0);
  }

  @override
  Future<FinalizeResult> finalize(String mediaId) async {
    calls.add('finalize:$mediaId');
    if (finalizeScript.isNotEmpty) {
      final next = finalizeScript.removeAt(0);
      if (next is FinalizeResult) return next;
      throw next;
    }
    final reason = rejectedWith[mediaId];
    return reason == null
        ? const FinalizeResult(ready: true)
        : FinalizeResult(ready: false, failureReason: reason);
  }

  @override
  Future<void> remove(String mediaId) async => calls.add('remove:$mediaId');

  @override
  Future<void> arrange(
    String listingId,
    List<String> orderedIds, {
    required String? coverId,
  }) async {
    calls.add('arrange');
    if (arrangeFailure != null) throw arrangeFailure!;
    lastArrangedIds = orderedIds;
    lastCoverId = coverId;
  }
}

/// مصدر صور مزيف: يعيد ما يُضبط عليه.
class FakePhotoSource implements PhotoSource {
  FakePhotoSource({this.gallery = const [], this.camera});

  List<PickedImage> gallery;
  PickedImage? camera;
  final limits = <int>[];

  @override
  Future<List<PickedImage>> pickFromGallery({required int limit}) async {
    limits.add(limit);
    return gallery;
  }

  @override
  Future<PickedImage?> pickFromCamera() async => camera;
}
