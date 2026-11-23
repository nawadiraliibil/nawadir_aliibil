import 'dart:convert';

/// إعدادات البيئة المقروءة وقت البناء من `--dart-define-from-file=env/<name>.json`.
///
/// لا يحمل التطبيق إلا عنوان المشروع والمفتاح العام للعميل. مفاتيح الخدمة
/// والأسرار تبقى في الخادم (SRS 12.3-3).
class Env {
  const Env({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.appEnv = 'dev',
    this.shareBaseUrl = '',
  });

  /// القيم المضمّنة وقت البناء. تكون فارغة إذا شُغّل التطبيق دون ملف بيئة.
  const Env.fromEnvironment()
    : supabaseUrl = const String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey = const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
      appEnv = const String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
      shareBaseUrl = const String.fromEnvironment('SHARE_BASE_URL');

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String appEnv;

  /// أساس روابط المشاركة العامة. فارغ إلى أن يُحدد النطاق (INT-005).
  final String shareBaseUrl;

  /// سبب عدم صلاحية الإعداد، أو `null` إذا كان صالحًا للاتصال بالخلفية.
  EnvProblem? get problem {
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      return EnvProblem.missing;
    }
    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return EnvProblem.invalidUrl;
    }
    if (_isPrivilegedKey(supabasePublishableKey)) {
      return EnvProblem.privilegedKey;
    }
    return null;
  }

  bool get isConfigured => problem == null;

  /// يكشف وضع مفتاح سري أو مفتاح `service_role` مكان المفتاح العام بالخطأ.
  static bool _isPrivilegedKey(String key) {
    if (key.startsWith('sb_secret_')) return true;
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload);
      return claims is Map && claims['role'] == 'service_role';
    } on FormatException {
      return false;
    }
  }
}

enum EnvProblem {
  /// لم يُمرر عنوان المشروع أو المفتاح العام.
  missing,

  /// عنوان المشروع ليس رابطًا صالحًا.
  invalidUrl,

  /// المفتاح الممرر مفتاح خدمة أو مفتاح سري، ولا يجوز وضعه في التطبيق.
  privilegedKey,
}
