import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/app/shell/app_nav_bar.dart';
import 'package:nawadir_aliibil/app/shell/brand_header.dart';
import 'package:nawadir_aliibil/core/config/env.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('التطبيق عربي باتجاه RTL ويفتح على الرئيسية داخل الهيكل', (
    tester,
  ) async {
    await pumpApp(tester);

    final context = tester.element(find.byType(BrandHeader));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Localizations.localeOf(context), const Locale('ar', 'SA'));
    expect(find.byType(AppNavBar), findsOneWidget);
  });

  testWidgets('غياب ملف البيئة يعرض تعليمات الإعداد بدل الهيكل', (
    tester,
  ) async {
    await pumpApp(
      tester,
      env: const Env(supabaseUrl: '', supabasePublishableKey: ''),
    );

    expect(find.text('إعداد البيئة ناقص'), findsOneWidget);
    expect(find.textContaining('env/dev.example.json'), findsOneWidget);
    expect(find.byType(AppNavBar), findsNothing);
  });

  testWidgets('مفتاح سري في ملف البيئة يعرض تحذيرًا', (tester) async {
    await pumpApp(
      tester,
      env: const Env(
        supabaseUrl: 'https://example.supabase.co',
        supabasePublishableKey: 'sb_secret_x',
      ),
    );

    expect(find.text('مفتاح غير مسموح في التطبيق'), findsOneWidget);
    expect(find.byType(AppNavBar), findsNothing);
  });
}
