import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/theme_mode.dart';
import 'router/app_router.dart';
import 'splash/splash_overlay.dart';
import 'theme/app_theme.dart';

/// جذر التطبيق: عربي باتجاه RTL (AD-NFR-001).
class NawadirApp extends ConsumerWidget {
  const NawadirApp({super.key});

  static const _locale = Locale('ar', 'SA');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'نوادر الإبل',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [_locale],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // اختيار المستخدم في الإعدادات (G06)؛ الافتراضي يتبع النظام.
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(appRouterProvider),
      // شاشة البداية تغطي التطبيق عند فتحه ثم تهبط على شعار الترويسة.
      builder: (context, child) => SplashOverlay(child: child!),
    );
  }
}
