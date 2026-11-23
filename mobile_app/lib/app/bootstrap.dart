import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../core/push/firebase_push_service.dart';
import '../core/push/push_service.dart';
import '../core/supabase/secure_session_storage.dart';
import '../core/supabase/supabase_providers.dart';
import 'app.dart';

/// نقطة تهيئة التطبيق: يقرأ البيئة، يهيئ Supabase إن كان الإعداد صالحًا،
/// ثم يشغّل الواجهة.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  const env = Env.fromEnvironment();
  SupabaseClient? client;

  if (env.isConfigured) {
    final supabase = await Supabase.initialize(
      url: env.supabaseUrl,
      publishableKey: env.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(),
      ),
    );
    client = supabase.client;
  }

  // الدفع (FCM): يبقى معطلًا إن غاب ملف إعداد Firebase (INT-006).
  final push = await FirebasePushService.tryCreate();

  runApp(
    ProviderScope(
      // لا إعادة محاولة تلقائية صامتة: كل شاشة تعرض خطأها وزر «إعادة المحاولة».
      retry: (_, _) => null,
      overrides: [
        envProvider.overrideWithValue(env),
        if (push != null) pushServiceProvider.overrideWithValue(push),
        if (client != null) supabaseClientProvider.overrideWithValue(client),
      ],
      child: const NawadirApp(),
    ),
  );
}
