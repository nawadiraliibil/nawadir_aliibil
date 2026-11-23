import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/core/errors/app_error.dart';
import 'package:nawadir_aliibil/core/errors/error_messages.dart';
import 'package:nawadir_aliibil/core/settings/published_settings.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File('../contracts/$path').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('رموز الأخطاء في التطبيق = رموز العقد تمامًا', () {
    final contract =
        (_json('api/errors.json')['errors'] as Map<String, dynamic>).keys
            .toSet();
    final app = AppErrorCode.contractCodes.map((c) => c.wire).toSet();
    expect(app, contract);
  });

  test('لكل رمز رسالة عربية غير فارغة', () {
    for (final code in AppErrorCode.values) {
      final msg = errorMessage(AppError(code));
      expect(RegExp(r'[؀-ۿ]').hasMatch(msg), isTrue, reason: code.wire);
    }
  });

  test('أسباب فشل الوسائط في العقد لها رسائل خاصة', () {
    final reasons =
        (_json('api/errors.json')['media_failure_reasons']
                as Map<String, dynamic>)['values']
            as List;
    final generic = mediaFailureMessage(null);
    for (final r in reasons) {
      expect(mediaFailureMessage(r as String), isNot(generic), reason: r);
    }
  });

  test('مثال published-settings.json يُحلّل', () {
    final s = PublishedSettings.fromJson(
      _json('fixtures/published-settings.json'),
    );
    expect(s.version, greaterThanOrEqualTo(1));
    expect(s.lookups.regions, isNotEmpty);
    expect(s.lookups.breeds.where((b) => b.requiresNote), isNotEmpty);
    expect(s.media.imageMimeTypes, contains('image/jpeg'));
    for (final c in s.lookups.cities) {
      expect(s.lookups.region(c.regionId), isNotNull, reason: '${c.id}');
    }
  });

  test('أمثلة الأخطاء تحمل رموزًا يعرفها التطبيق', () {
    for (final f in [
      'error-bump-too-early',
      'error-forbidden',
      'error-mfa-required',
      'error-validation-failed',
      'error-version-changed',
    ]) {
      final j = _json('fixtures/$f.json');
      expect(
        AppErrorCode.tryParse(j['message'] as String),
        isNotNull,
        reason: f,
      );
    }
  });
}
