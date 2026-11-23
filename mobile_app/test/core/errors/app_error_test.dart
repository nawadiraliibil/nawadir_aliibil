import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nawadir_aliibil/core/errors/app_error.dart';
import 'package:nawadir_aliibil/core/errors/error_messages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  test('PostgrestException يُحوَّل برمزه وتفاصيله المفكوكة', () {
    final e = AppError.from(
      const PostgrestException(
        message: 'MEDIA_LIMIT_REACHED',
        code: 'P0001',
        details: '{"kind": "VIDEO", "limit": 1}',
      ),
    );
    expect(e.code, AppErrorCode.mediaLimitReached);
    expect(e.details['limit'], 1);
    expect(errorMessage(e), contains('الفيديو'));
  });

  test('تفاصيل غير JSON لا تكسر التحويل', () {
    final e = AppError.from(
      const PostgrestException(message: 'FORBIDDEN', details: 'not json'),
    );
    expect(e.code, AppErrorCode.forbidden);
    expect(e.details, isEmpty);
  });

  test('رسالة غير معروفة وJWT منتهٍ', () {
    expect(
      AppError.from(const PostgrestException(message: 'boom')).code,
      AppErrorCode.unknown,
    );
    expect(
      AppError.from(
        const PostgrestException(message: 'JWT expired', code: 'PGRST301'),
      ).code,
      AppErrorCode.authRequired,
    );
  });

  test('أخطاء الشبكة تقبل إعادة المحاولة', () {
    for (final ex in [const SocketException('x'), TimeoutException('x')]) {
      final e = AppError.from(ex);
      expect(e.code, AppErrorCode.network);
      expect(e.isRetryable, isTrue);
    }
    expect(AppError.from(StateError('x')).isRetryable, isFalse);
  });

  test('FunctionException برمز في الجسم', () {
    final e = AppError.from(
      FunctionException(
        status: 409,
        details: {
          'code': 'MEDIA_NOT_UPLOADED',
          'details': {'media_id': 'a'},
        },
      ),
    );
    expect(e.code, AppErrorCode.mediaNotUploaded);
    expect(e.details['media_id'], 'a');
    expect(
      AppError.from(FunctionException(status: 401)).code,
      AppErrorCode.authRequired,
    );
  });

  test('AppError يمرر كما هو', () {
    const original = AppError(AppErrorCode.lastAdmin);
    expect(identical(AppError.from(original), original), isTrue);
  });

  test('رسالة تجديد الظهور تحمل الموعد', () {
    final msg = errorMessage(
      const AppError(
        AppErrorCode.bumpTooEarly,
        details: {'eligible_at': '2026-11-23T17:32:11+00:00'},
      ),
    );
    expect(msg, startsWith('يمكنك تجديد الظهور بعد'));
  });
}
