import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/rpc.dart';
import '../../../core/supabase/supabase_providers.dart';
import 'media_models.dart';

/// عمليات وسائط الإعلان في الخلفية والتخزين. كل خطأ يخرج [AppError].
/// تُستبدل في الاختبارات.
abstract class MediaBackend {
  /// يسجل ملفًا بانتظار الرفع ويعيد موضعه.
  Future<MediaSlot> add(
    String listingId, {
    required String mimeType,
    required int sizeBytes,
  });

  /// يرفع البايتات إلى `bucket/objectPath` بجلسة المستخدم.
  Future<void> upload(
    MediaSlot slot,
    Uint8List bytes, {
    required String mimeType,
  });

  /// يستدعي `media-finalize`: فحص النوع الفعلي وتنظيف البيانات الوصفية.
  Future<FinalizeResult> finalize(String mediaId);

  /// يحذف الوسيط من المسودة، ثم ملفه من التخزين إن لم يعد مشارًا إليه.
  Future<void> remove(String mediaId);

  /// يرتب كل وسائط المسودة ويعين الغلاف. [orderedIds] يجب أن تضم كل الوسائط.
  Future<void> arrange(
    String listingId,
    List<String> orderedIds, {
    required String? coverId,
  });
}

class SupabaseMediaBackend implements MediaBackend {
  SupabaseMediaBackend(this._rpc, this._client);

  final RpcCaller _rpc;
  final SupabaseClient _client;

  @override
  Future<MediaSlot> add(
    String listingId, {
    required String mimeType,
    required int sizeBytes,
  }) => guardRpc(() async {
    final res = await _rpc(
      'add_listing_media',
      params: {
        'p_listing_id': listingId,
        'p_kind': 'IMAGE',
        'p_mime_type': mimeType,
        'p_size_bytes': sizeBytes,
      },
    );
    return _parse(res, MediaSlot.fromJson);
  });

  @override
  Future<void> upload(
    MediaSlot slot,
    Uint8List bytes, {
    required String mimeType,
  }) => guardRpc(
    () => _client.storage
        .from(slot.bucket)
        .uploadBinary(
          slot.objectPath,
          bytes,
          // لا استبدال: ملف مرفوع لا يعدله العميل (storage.md).
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        ),
  );

  @override
  Future<FinalizeResult> finalize(String mediaId) => guardRpc(() async {
    final res = await _client.functions.invoke(
      'media-finalize',
      body: {'media_id': mediaId},
    );
    return _parse(res.data, FinalizeResult.fromJson);
  });

  @override
  Future<void> remove(String mediaId) => guardRpc(() async {
    final res = await _rpc(
      'remove_listing_media',
      params: {'p_media_id': mediaId},
    );
    final removed = _parse(res, RemovedMedia.fromJson);
    if (removed.deleteObject) {
      try {
        await _client.storage.from(removed.bucket).remove([removed.objectPath]);
      } on StorageException {
        // الصف حُذف؛ بقاء ملف يتيم في مجلد المالك لا يظهر لأحد ولا يمنع شيئًا.
      }
    }
  });

  @override
  Future<void> arrange(
    String listingId,
    List<String> orderedIds, {
    required String? coverId,
  }) => guardRpc(
    () => _rpc(
      'arrange_listing_media',
      params: {
        'p_listing_id': listingId,
        'p_media_ids': orderedIds,
        'p_cover_id': coverId,
      },
    ),
  );

  /// رد لا يطابق العقد خطأ توافق لا خطأ شبكة.
  static T _parse<T>(Object? raw, T Function(Map<String, dynamic>) from) {
    try {
      return from(Map<String, dynamic>.from(raw! as Map));
    } on TypeError catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  }
}

final mediaBackendProvider = Provider<MediaBackend>(
  (ref) => SupabaseMediaBackend(
    ref.watch(rpcProvider),
    ref.watch(supabaseClientProvider),
  ),
);

/// مصدر الصور: المعرض أو الكاميرا. يُستبدل في الاختبارات.
abstract class PhotoSource {
  /// حتى [limit] صورة من المعرض. قائمة فارغة عند الإلغاء.
  Future<List<PickedImage>> pickFromGallery({required int limit});

  /// صورة واحدة من الكاميرا، أو `null` عند الإلغاء.
  Future<PickedImage?> pickFromCamera();
}

class PlatformPhotoSource implements PhotoSource {
  PlatformPhotoSource([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  // إعادة ترميز بجودة 90 وحد للعرض: تقلل الحجم، وتحول HEIC إلى JPEG على الجهاز
  // (TEAM-DEC-011 البند 5) قبل أن يصل إلى فحص الخادم.
  static const _quality = 90;
  static const _maxSide = 2560.0;

  @override
  Future<List<PickedImage>> pickFromGallery({required int limit}) async {
    final files = await _picker.pickMultiImage(
      limit: limit,
      imageQuality: _quality,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
    );
    return [for (final f in files) await _read(f)];
  }

  @override
  Future<PickedImage?> pickFromCamera() async {
    final f = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: _quality,
      maxWidth: _maxSide,
      maxHeight: _maxSide,
    );
    return f == null ? null : _read(f);
  }

  static Future<PickedImage> _read(XFile f) async =>
      PickedImage(name: f.name, bytes: await f.readAsBytes());
}

final photoSourceProvider = Provider<PhotoSource>(
  (ref) => PlatformPhotoSource(),
);
