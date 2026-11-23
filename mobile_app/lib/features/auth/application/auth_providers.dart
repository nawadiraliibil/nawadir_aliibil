import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/auth_backend.dart';

final authBackendProvider = Provider<AuthBackend>(
  (ref) => SupabaseAuthBackend(ref.watch(supabaseClientProvider).auth),
);

/// حالة الدخول الحالية، تتحدث مع كل تغير في الجلسة.
final signedInProvider = StreamProvider<bool>((ref) async* {
  final backend = ref.watch(authBackendProvider);
  yield backend.isSignedIn;
  yield* backend.signedInChanges;
});

/// يوقظ موجّه go_router عند تغير حالة الدخول ليعيد تقييم الحراس.
class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier(AuthBackend backend) : _signedIn = backend.isSignedIn {
    _sub = backend.signedInChanges.listen((signedIn) {
      if (signedIn == _signedIn) return;
      _signedIn = signedIn;
      notifyListeners();
    });
  }

  late final StreamSubscription<bool> _sub;
  bool _signedIn;

  bool get signedIn => _signedIn;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}

/// هل يظهر الدخول البديل بالبريد؟ في بيئة `dev` وبناءات غير الإنتاج فقط. يتيح
/// تجربة التطبيق دون مزود رسائل نصية؛ لا يوجد في بناء الإنتاج ولا بيئة غير dev.
final devLoginEnabledProvider = Provider<bool>(
  (ref) => !kReleaseMode && ref.watch(envProvider).appEnv == 'dev',
);
