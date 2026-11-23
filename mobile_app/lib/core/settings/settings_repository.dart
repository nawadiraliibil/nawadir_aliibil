import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../errors/app_error.dart';
import '../supabase/rpc.dart';
import 'published_settings.dart';

/// يجلب الإعدادات والقوائم المنشورة ويحتفظ بآخر نسخة ناجحة على الجهاز، فتعمل
/// الشاشات التي تعتمد عليها (مثل نموذج الإعلان) دون اتصال.
class SettingsRepository {
  /// [rpc] ينفذ `get_published_settings` ويعيد الرد الخام.
  SettingsRepository(this._rpc, this._prefs);

  static const cacheKey = 'published_settings.v1';

  final Future<dynamic> Function() _rpc;
  final SharedPreferencesAsync _prefs;

  /// النسخة المخزنة، أو `null` إن لم توجد أو تعذّر تحليلها.
  Future<PublishedSettings?> cached() async {
    final raw = await _prefs.getString(cacheKey);
    if (raw == null) return null;
    try {
      return PublishedSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object {
      // نسخة تالفة أو من مخطط قديم: تتجاهل ويعاد الجلب.
      await _prefs.remove(cacheKey);
      return null;
    }
  }

  /// يجلب من الخادم ويخزن. يرمي [AppError] عند الفشل.
  Future<PublishedSettings> fetch() async {
    try {
      final res = await _rpc();
      final json = Map<String, dynamic>.from(res as Map);
      final settings = PublishedSettings.fromJson(json);
      await _prefs.setString(cacheKey, jsonEncode(json));
      return settings;
    } on TypeError catch (e) {
      // رد لا يطابق العقد: خطأ توافق لا خطأ شبكة.
      throw AppError(AppErrorCode.unknown, cause: e);
    } on Object catch (e) {
      throw AppError.from(e);
    }
  }

  /// الخادم أولًا، ثم النسخة المخزنة إن فشل الاتصال. يرمي الخطأ الأصلي إن لم
  /// توجد نسخة مخزنة.
  Future<PublishedSettings> load() async {
    try {
      return await fetch();
    } on AppError {
      final saved = await cached();
      if (saved != null) return saved;
      rethrow;
    }
  }
}

final sharedPreferencesProvider = Provider<SharedPreferencesAsync>(
  (ref) => SharedPreferencesAsync(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(
    () => ref.watch(rpcProvider)('get_published_settings'),
    ref.watch(sharedPreferencesProvider),
  ),
);

/// الإعدادات والقوائم المنشورة. تُحمّل مرة لكل تشغيل، ويعاد التحميل بإبطال
/// المزود (`ref.invalidate`).
final publishedSettingsProvider = FutureProvider<PublishedSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).load(),
);
