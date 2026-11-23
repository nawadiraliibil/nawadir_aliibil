import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/features/auth/data/auth_backend.dart';
import 'package:nawadir_aliibil/features/auth/domain/saudi_phone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SaudiPhone', () {
    test('الصيغ المقبولة تطبّع إلى الصيغة الدولية نفسها', () {
      for (final input in [
        '512345678',
        '0512345678',
        '966512345678',
        '+966512345678',
        '00966512345678',
        '+966 51 234 5678',
        '05 1234 5678',
        '٠٥١٢٣٤٥٦٧٨',
      ]) {
        expect(
          SaudiPhone.tryParse(input)?.e164,
          '+966512345678',
          reason: input,
        );
      }
    });

    test('الأرقام غير الصالحة ترفض', () {
      for (final input in [
        '',
        '51234567', // ناقص
        '5123456789', // زائد
        '412345678', // لا يبدأ بـ5
        '0112345678', // رقم أرضي
        '+971512345678', // ليس سعوديًا
        'abc',
      ]) {
        expect(SaudiPhone.tryParse(input), isNull, reason: input);
      }
    });

    test('العرض المحلي والمخفي', () {
      final p = SaudiPhone.tryParse('512345321')!;
      expect(p.local, '0512345321');
      expect(p.masked, '05*****321');
      expect(SaudiPhone.fromE164(p.e164), p);
    });
  });

  group('تصنيف أخطاء المصادقة', () {
    AuthFailureKind kind(AuthException e) =>
        SupabaseAuthBackend.classify(e).kind;

    test('الرمز الخاطئ أو المنتهي', () {
      expect(
        kind(
          const AuthApiException('x', statusCode: '403', code: 'otp_expired'),
        ),
        AuthFailureKind.invalidCode,
      );
    });

    test('حدود الإرسال والتحقق في الخادم', () {
      expect(
        kind(
          const AuthApiException(
            'x',
            statusCode: '429',
            code: 'over_sms_send_rate_limit',
          ),
        ),
        AuthFailureKind.rateLimited,
      );
      expect(
        kind(const AuthApiException('x', statusCode: '429')),
        AuthFailureKind.rateLimited,
      );
    });

    test('رقم مرفوض وانقطاع وغير معروف', () {
      expect(
        kind(
          const AuthApiException(
            'x',
            statusCode: '422',
            code: 'validation_failed',
          ),
        ),
        AuthFailureKind.invalidPhone,
      );
      expect(
        kind(AuthRetryableFetchException(message: 'x')),
        AuthFailureKind.network,
      );
      expect(
        kind(const AuthApiException('x', statusCode: '500')),
        AuthFailureKind.unavailable,
      );
    });
  });
}
