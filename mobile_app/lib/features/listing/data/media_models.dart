import 'dart:typed_data';

/// صورة اختارها المستخدم من المعرض أو الكاميرا.
class PickedImage {
  const PickedImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// فيديو اختاره المستخدم. [bytes] فارغة إذا تجاوز [sizeBytes] الحد قبل القراءة
/// (لا يحمّل ملف ضخم في الذاكرة لمجرد رفضه). [durationSeconds] `null` إن تعذر
/// قياسها محليًا؛ يعيد الخادم الفحص.
class PickedVideo {
  const PickedVideo({
    required this.name,
    required this.sizeBytes,
    required this.bytes,
    this.durationSeconds,
  });

  final String name;
  final int sizeBytes;
  final Uint8List bytes;
  final int? durationSeconds;
}

/// رد `add_listing_media`: أين يُرفع الملف.
class MediaSlot {
  const MediaSlot({
    required this.mediaId,
    required this.bucket,
    required this.objectPath,
  });

  factory MediaSlot.fromJson(Map<String, dynamic> j) => MediaSlot(
    mediaId: j['media_id'] as String,
    bucket: j['bucket'] as String,
    objectPath: j['object_path'] as String,
  );

  final String mediaId;
  final String bucket;
  final String objectPath;
}

/// رد `media-finalize`.
class FinalizeResult {
  const FinalizeResult({required this.ready, this.failureReason});

  factory FinalizeResult.fromJson(Map<String, dynamic> j) => FinalizeResult(
    ready: j['status'] == 'READY',
    failureReason: j['failure_reason'] as String?,
  );

  final bool ready;

  /// عند الفشل: قيمة من `media_failure_reasons` في العقد.
  final String? failureReason;
}

/// رد `remove_listing_media`.
class RemovedMedia {
  const RemovedMedia({
    required this.bucket,
    required this.objectPath,
    required this.deleteObject,
  });

  factory RemovedMedia.fromJson(Map<String, dynamic> j) => RemovedMedia(
    bucket: j['bucket'] as String,
    objectPath: j['object_path'] as String,
    deleteObject: j['delete_object'] as bool,
  );

  final String bucket;
  final String objectPath;

  /// هل يحذف الملف من التخزين (لم يعد صف يشير إليه).
  final bool deleteObject;
}
