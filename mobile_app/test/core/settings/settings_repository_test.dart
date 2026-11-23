import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/core/errors/app_error.dart';
import 'package:nawadir_aliibil/core/settings/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              '../contracts/fixtures/published-settings.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  late Future<dynamic> Function() rpc;
  late SettingsRepository repo;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    rpc = () async => fixture;
    repo = SettingsRepository(() => rpc(), SharedPreferencesAsync());
  });

  test('الجلب الناجح يخزن النسخة', () async {
    final s = await repo.load();
    expect(s.version, fixture['version']);
    expect((await repo.cached())?.version, s.version);
  });

  test('فشل الشبكة يرجع إلى النسخة المخزنة', () async {
    await repo.load();
    rpc = () async => throw const SocketException('offline');
    final s = await repo.load();
    expect(s.version, fixture['version']);
  });

  test('فشل الشبكة دون نسخة مخزنة يرمي خطأ الشبكة', () async {
    rpc = () async => throw const SocketException('offline');
    await expectLater(
      repo.load(),
      throwsA(
        isA<AppError>().having((e) => e.code, 'code', AppErrorCode.network),
      ),
    );
  });

  test('نسخة مخزنة تالفة تُتجاهل وتُحذف', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(SettingsRepository.cacheKey, '{bad');
    expect(await repo.cached(), isNull);
    expect(await prefs.getString(SettingsRepository.cacheKey), isNull);
  });

  test('رد لا يطابق العقد لا يخزن', () async {
    rpc = () async => {'version': 1};
    await expectLater(repo.load(), throwsA(isA<AppError>()));
    expect(await repo.cached(), isNull);
  });
}
