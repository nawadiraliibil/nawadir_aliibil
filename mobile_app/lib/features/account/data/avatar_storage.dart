import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/rpc.dart';
import '../../../core/supabase/supabase_providers.dart';

/// تخزين الصور الشخصية (bucket `avatars` العام). يُستبدل في الاختبارات.
abstract class AvatarStorage {
  /// يرفع الصورة إلى مجلد المستخدم باسم جديد ويعيد مسارها.
  Future<String> upload(Uint8List bytes, {required String mimeType});

  /// رابط العرض العام لمسار محفوظ.
  String urlFor(String path);

  /// يحذف ملفًا قديمًا. الفشل لا يحجب العملية: الملف اليتيم لا يظهر لأحد.
  Future<void> remove(String path);
}

class SupabaseAvatarStorage implements AvatarStorage {
  SupabaseAvatarStorage(this._client);

  final SupabaseClient _client;
  static const bucket = 'avatars';

  static String _ext(String mime) => switch (mime) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };

  @override
  Future<String> upload(Uint8List bytes, {required String mimeType}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AppError(AppErrorCode.authRequired);
    // اسم جديد في كل مرة: لا استبدال، ولا يبقى رابط قديم مخبأ.
    final path =
        '$uid/${DateTime.now().millisecondsSinceEpoch}.${_ext(mimeType)}';
    await guardRpc(
      () => _client.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          ),
    );
    return path;
  }

  @override
  String urlFor(String path) => _client.storage.from(bucket).getPublicUrl(path);

  @override
  Future<void> remove(String path) async {
    try {
      await _client.storage.from(bucket).remove([path]);
    } on Object catch (e) {
      AppError.from(e);
    }
  }
}

final avatarStorageProvider = Provider<AvatarStorage>(
  (ref) => SupabaseAvatarStorage(ref.watch(supabaseClientProvider)),
);
