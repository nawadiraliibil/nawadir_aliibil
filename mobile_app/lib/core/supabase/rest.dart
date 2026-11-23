import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_error.dart';
import 'rpc.dart';
import 'supabase_providers.dart';

/// قراءة صفوف علاقة من PostgREST (`/rest/v1/<relation>`). لا كتابة مباشرة:
/// الكتابة عبر دوال `rpc.yaml` فقط (`contracts/api/read-surface.md`).
typedef TableReader =
    Future<List<Map<String, dynamic>>> Function(
      String relation, {
      Map<String, Object>? eq,
      String? orderBy,
      bool ascending,
      int? limit,
    });

final tableReaderProvider = Provider<TableReader>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return (relation, {eq, orderBy, ascending = true, limit}) =>
      guardRpc(() async {
        var filter = client.from(relation).select();
        for (final e in (eq ?? const <String, Object>{}).entries) {
          filter = filter.eq(e.key, e.value);
        }
        if (orderBy == null && limit == null) {
          return List<Map<String, dynamic>>.from(await filter);
        }
        var query = filter.order(orderBy ?? 'id', ascending: ascending);
        if (limit != null) query = query.limit(limit);
        return List<Map<String, dynamic>>.from(await query);
      });
});

/// رابط موقع قصير الأجل لملف في bucket خاص (يقرأه صاحبه). لا تخزن الروابط.
typedef SignedUrlFetcher = Future<String> Function(String bucket, String path);

final signedUrlProvider = Provider<SignedUrlFetcher>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return (bucket, path) => guardRpc(
    () => client.storage.from(bucket).createSignedUrl(path, 60 * 30),
  );
});

/// يحذف ملفات من التخزين. فشل الحذف لا يعيد المحاولة: الصف حُذف ولا أثر ظاهر
/// لملف يتيم في مجلد المالك.
typedef StorageRemover =
    Future<void> Function(String bucket, List<String> paths);

final storageRemoverProvider = Provider<StorageRemover>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return (bucket, paths) async {
    if (paths.isEmpty) return;
    try {
      await client.storage.from(bucket).remove(paths);
    } on Object catch (e) {
      // لا يحجب نجاح العملية الأساسية.
      AppError.from(e);
    }
  };
});
