import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/core/config/env.dart';

/// يبني رمزًا بصيغة JWT بدور محدد، دون توقيع حقيقي، لاختبار الكشف فقط.
String fakeJwt(String role) {
  String part(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'role': role})}.signature';
}

void main() {
  group('Env.problem', () {
    test('القيم الفارغة تعد إعدادًا ناقصًا', () {
      const env = Env(supabaseUrl: '', supabasePublishableKey: '');
      expect(env.problem, EnvProblem.missing);
      expect(env.isConfigured, isFalse);
    });

    test('غياب المفتاح وحده يعد إعدادًا ناقصًا', () {
      const env = Env(
        supabaseUrl: 'https://example.supabase.co',
        supabasePublishableKey: '',
      );
      expect(env.problem, EnvProblem.missing);
    });

    test('عنوان بلا مخطط أو نطاق غير صالح', () {
      const env = Env(
        supabaseUrl: 'example',
        supabasePublishableKey: 'sb_publishable_x',
      );
      expect(env.problem, EnvProblem.invalidUrl);
    });

    test('المفتاح العام بالصيغة الجديدة مقبول', () {
      const env = Env(
        supabaseUrl: 'https://example.supabase.co',
        supabasePublishableKey: 'sb_publishable_x',
      );
      expect(env.problem, isNull);
      expect(env.isConfigured, isTrue);
    });

    test('مفتاح anon بصيغة JWT مقبول', () {
      final env = Env(
        supabaseUrl: 'https://example.supabase.co',
        supabasePublishableKey: fakeJwt('anon'),
      );
      expect(env.problem, isNull);
    });

    test('المفتاح السري بالصيغة الجديدة مرفوض', () {
      const env = Env(
        supabaseUrl: 'https://example.supabase.co',
        supabasePublishableKey: 'sb_secret_x',
      );
      expect(env.problem, EnvProblem.privilegedKey);
    });

    test('مفتاح service_role بصيغة JWT مرفوض', () {
      final env = Env(
        supabaseUrl: 'https://example.supabase.co',
        supabasePublishableKey: fakeJwt('service_role'),
      );
      expect(env.problem, EnvProblem.privilegedKey);
    });

    test('نص من ثلاثة أجزاء ليس JWT لا يسبب خطأ', () {
      const env = Env(
        supabaseUrl: 'https://example.supabase.co',
        supabasePublishableKey: 'a.%%%.c',
      );
      expect(env.problem, isNull);
    });
  });
}
