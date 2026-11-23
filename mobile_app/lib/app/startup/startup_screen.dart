import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/supabase/supabase_providers.dart';
import '../../core/widgets/empty_state.dart';

/// شاشة للمطور تظهر حين يكون إعداد البيئة ناقصًا أو خاطئًا، بدل تشغيل تطبيق
/// لا يستطيع الاتصال بالخلفية. ليست جزءًا من التصميم المعتمد.
class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final problem = ref.watch(envProvider).problem ?? EnvProblem.missing;

    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.settings_outlined,
          title: _title(problem),
          message: _help(problem),
        ),
      ),
    );
  }

  static String _title(EnvProblem problem) => switch (problem) {
    EnvProblem.missing => 'إعداد البيئة ناقص',
    EnvProblem.invalidUrl => 'عنوان مشروع Supabase غير صالح',
    EnvProblem.privilegedKey => 'مفتاح غير مسموح في التطبيق',
  };

  static String _help(EnvProblem problem) => switch (problem) {
    EnvProblem.missing =>
      'انسخ env/dev.example.json إلى env/dev.json واملأ القيم، ثم شغّل '
          'التطبيق مع الخيار --dart-define-from-file=env/dev.json',
    EnvProblem.invalidUrl => 'راجع قيمة SUPABASE_URL في ملف البيئة.',
    EnvProblem.privilegedKey =>
      'القيمة في SUPABASE_PUBLISHABLE_KEY مفتاح خدمة أو مفتاح سري. استخدم '
          'المفتاح العام للعميل فقط.',
  };
}
