import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/rest.dart';
import '../../../core/supabase/rpc.dart';
import 'draft_form.dart';

/// دوال المعلن في الخلفية. كل خطأ يخرج [AppError].
class ListingRepository {
  ListingRepository(this._rpc, this._read, this._removeFiles);

  final RpcCaller _rpc;
  final TableReader _read;
  final StorageRemover _removeFiles;

  /// ينشئ مسودة. المعرف نفسه يعيد المسودة نفسها، فإعادة المحاولة بعد انقطاع
  /// لا تنشئ مسودة ثانية.
  Future<OwnerListing> createDraft(String requestId) => guardRpc(
    () async => _owner(
      await _rpc('create_listing_draft', params: {'p_request_id': requestId}),
    ),
  );

  /// حفظ جزئي: المفتاح الغائب لا يتغير و`null` يمسح القيمة.
  Future<OwnerListing> saveDraft(
    String listingId,
    Map<String, Object?> patch,
  ) => guardRpc(
    () async => _owner(
      await _rpc(
        'save_listing_draft',
        params: {'p_listing_id': listingId, 'p_patch': patch},
      ),
    ),
  );

  /// يرسل المسودة للمراجعة. المعرف نفسه لا ينشئ إرسالًا ثانيًا ويعيد الحالة الحالية.
  Future<OwnerListing> submit(String listingId, String requestId) => guardRpc(
    () async => _owner(
      await _rpc(
        'submit_listing',
        params: {'p_listing_id': listingId, 'p_request_id': requestId},
      ),
    ),
  );

  /// يقرأ مسودة بمعرفها من جداولها (قراءة المالك). للمسودات فقط: نسخة الإعلان
  /// الحالية هي المسودة. لغيرها استعمل [startEdit].
  Future<OwnerListing> loadDraft(String listingId) => guardRpc(() async {
    final listings = await _read('listings', eq: {'id': listingId}, limit: 1);
    if (listings.isEmpty) throw const AppError(AppErrorCode.notFound);
    final listing = listings.single;
    final versionId = listing['current_version_id'] as String?;
    final versions = versionId == null
        ? const <Map<String, dynamic>>[]
        : await _read('listing_versions', eq: {'id': versionId}, limit: 1);
    final media = versionId == null
        ? const <Map<String, dynamic>>[]
        : await _read('media', eq: {'version_id': versionId});
    return _owner({
      'listing': listing,
      'version': versions.isEmpty ? null : versions.single,
      'media': media,
    });
  });

  /// يبدأ تعديل إعلان منشور أو مرفوض أو مؤرشف بمسودة جديدة (أو الموجودة).
  Future<OwnerListing> startEdit(String listingId) => guardRpc(
    () async => _owner(
      await _rpc('start_listing_edit', params: {'p_listing_id': listingId}),
    ),
  );

  /// يوقف إعلانًا منشورًا ويؤرشفه: يختفي عن العامة ويبقى لصاحبه.
  Future<void> archive(String listingId) => guardRpc(() async {
    await _rpc('archive_listing', params: {'p_listing_id': listingId});
  });

  /// يجدد ظهور إعلان منشور بعد مرور المهلة (BUMP_TOO_EARLY قبلها).
  Future<void> bump(String listingId) => guardRpc(() async {
    await _rpc('bump_listing', params: {'p_listing_id': listingId});
  });

  /// يحذف مسودة أو إعلانًا مرفوضًا، ثم ملفاته من التخزين.
  Future<void> delete(String listingId) => guardRpc(() async {
    final res = await _rpc(
      'delete_listing',
      params: {'p_listing_id': listingId},
    );
    final objects = (res is Map ? res['delete_objects'] : null) as List?;
    final byBucket = <String, List<String>>{};
    for (final o in objects ?? const []) {
      final m = o as Map;
      (byBucket[m['bucket'] as String] ??= []).add(m['object_path'] as String);
    }
    for (final e in byBucket.entries) {
      await _removeFiles(e.key, e.value);
    }
  });

  static OwnerListing _owner(Object? raw) {
    try {
      return OwnerListing.fromJson(Map<String, dynamic>.from(raw! as Map));
    } on TypeError catch (e) {
      // رد لا يطابق العقد خطأ توافق لا خطأ شبكة.
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  }
}

final listingRepositoryProvider = Provider<ListingRepository>(
  (ref) => ListingRepository(
    ref.watch(rpcProvider),
    ref.watch(tableReaderProvider),
    ref.watch(storageRemoverProvider),
  ),
);
