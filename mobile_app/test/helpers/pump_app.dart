import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/app/app.dart';
import 'package:nawadir_aliibil/app/splash/splash_overlay.dart';
import 'package:nawadir_aliibil/core/config/env.dart';
import 'package:nawadir_aliibil/core/supabase/realtime.dart';
import 'package:nawadir_aliibil/core/supabase/rest.dart';
import 'package:nawadir_aliibil/core/supabase/rpc.dart';
import 'package:nawadir_aliibil/core/supabase/supabase_providers.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:nawadir_aliibil/features/auth/application/auth_providers.dart';

import 'package:nawadir_aliibil/features/listing/data/media_backend.dart';

import 'fake_auth_backend.dart';
import 'fake_rpc.dart';
import 'fake_tables.dart';

const configuredEnv = Env(
  supabaseUrl: 'https://example.supabase.co',
  supabasePublishableKey: 'sb_publishable_x',
);

/// يشغّل التطبيق كاملًا ويتوقف عند أول إطار، وشاشة البداية ما زالت معروضة.
Future<void> pumpAppAtSplash(
  WidgetTester tester, {
  Env env = configuredEnv,
  FakeAuthBackend? auth,
  FakeRpc? rpc,
  MediaBackend? media,
  PhotoSource? photos,
  FakeTables? tables,
  FakeStorage? storage,
  List<Override> extraOverrides = const [],
  Stream<Map<String, dynamic>>? messageInserts,
}) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  await tester.pumpWidget(
    ProviderScope(
      // دون إعادة محاولة تلقائية: الأخطاء تظهر بأزرار «إعادة المحاولة» الصريحة.
      retry: (_, _) => null,
      overrides: [
        envProvider.overrideWithValue(env),
        rpcProvider.overrideWithValue((rpc ?? FakeRpc()).caller),
        tableReaderProvider.overrideWithValue((tables ?? FakeTables()).reader),
        storageRemoverProvider.overrideWithValue(
          (storage ?? FakeStorage()).remover,
        ),
        // الصور المحفوظة في الخادم لا تُحمَّل في الاختبارات: تظهر بديلًا.
        signedUrlProvider.overrideWithValue(
          (bucket, path) async => throw StateError('لا رابط في الاختبار'),
        ),
        if (media != null) mediaBackendProvider.overrideWithValue(media),
        if (photos != null) photoSourceProvider.overrideWithValue(photos),
        authBackendProvider.overrideWithValue(
          auth ?? FakeAuthBackend(signedIn: true),
        ),
        // دون Realtime في الاختبارات؛ تحقن اختبارات المحادثة بثها الخاص.
        messageInsertsProvider.overrideWithValue(
          messageInserts ?? const Stream.empty(),
        ),
        ...extraOverrides,
      ],
      child: const NawadirApp(),
    ),
  );
  // إطار ثانٍ لتحميل صورة الشعار ورسم المشهد.
  await tester.pump();
}

/// يشغّل التطبيق ويتجاوز شاشة البداية كاملة.
Future<void> pumpApp(
  WidgetTester tester, {
  Env env = configuredEnv,
  FakeAuthBackend? auth,
  FakeRpc? rpc,
  MediaBackend? media,
  PhotoSource? photos,
  FakeTables? tables,
  FakeStorage? storage,
  List<Override> extraOverrides = const [],
  Stream<Map<String, dynamic>>? messageInserts,
}) async {
  await pumpAppAtSplash(
    tester,
    env: env,
    auth: auth,
    rpc: rpc,
    media: media,
    photos: photos,
    tables: tables,
    storage: storage,
    extraOverrides: extraOverrides,
    messageInserts: messageInserts,
  );
  await tester.pump(SplashOverlay.hold);
  await tester.pumpAndSettle();
}
