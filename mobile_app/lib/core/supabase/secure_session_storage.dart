import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// يحفظ جلسة Supabase في التخزين الآمن للنظام (Keystore / Keychain) بدل
/// التفضيلات العادية (AD-NFR-002).
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const _sessionKey = 'supabase.session';

  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _sessionKey);

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _sessionKey, value: persistSessionString);
}
