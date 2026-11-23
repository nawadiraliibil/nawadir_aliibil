import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// إعدادات البيئة. تُحقن في `bootstrap` وتُستبدل في الاختبارات.
final envProvider = Provider<Env>(
  (ref) => throw StateError('envProvider لم يُحقن؛ استخدم bootstrap().'),
);

/// عميل Supabase الوحيد في التطبيق. يُحقن بعد التهيئة، ولا يتوفر إذا كان
/// إعداد البيئة ناقصًا.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => throw StateError(
    'supabaseClientProvider غير متوفر: إعداد البيئة ناقص أو لم تكتمل التهيئة.',
  ),
);
