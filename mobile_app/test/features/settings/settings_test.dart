import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/features/settings/application/theme_mode.dart';
import 'package:nawadir_aliibil/features/settings/presentation/legal_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/fake_auth_backend.dart';
import '../../helpers/fake_rpc.dart';
import '../../helpers/pump_app.dart';

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('home-settings')));
  await tester.pumpAndSettle();
}

void main() {
  group('المظهر', () {
    test('الاختيار يحفظ ويُقرأ في تشغيل لاحق', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final a = ProviderContainer();
      addTearDown(a.dispose);
      expect(a.read(themeModeProvider), ThemeMode.system);
      await a.read(themeModeProvider.notifier).set(ThemeMode.dark);
      expect(a.read(themeModeProvider), ThemeMode.dark);

      final b = ProviderContainer();
      addTearDown(b.dispose);
      expect(b.read(themeModeProvider), ThemeMode.system);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(b.read(themeModeProvider), ThemeMode.dark);
      // قيمة تالفة تُتجاهل.
      await SharedPreferencesAsync().setString(ThemeModeNotifier.key, 'bogus');
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(themeModeProvider);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(themeModeProvider), ThemeMode.system);
    });

    testWidgets('اختيار «داكن» يطبق فورًا على التطبيق ثم يعود الفاتح', (
      tester,
    ) async {
      await pumpApp(
        tester,
        rpc: FakeRpc({'get_my_account': (_) => fixture('account-ready')}),
      );
      await _openSettings(tester);
      Brightness current() =>
          Theme.of(tester.element(find.text('الإعدادات').first)).brightness;

      await tester.tap(find.byKey(const ValueKey('theme-dark')));
      await tester.pumpAndSettle();
      expect(current(), Brightness.dark);
      await tester.tap(find.byKey(const ValueKey('theme-light')));
      await tester.pumpAndSettle();
      expect(current(), Brightness.light);
    });

    testWidgets('مداخل الإشعارات والشروط بلا ملاحظة حجم الخط', (tester) async {
      await pumpApp(
        tester,
        rpc: FakeRpc({'get_my_account': (_) => fixture('account-ready')}),
      );
      await _openSettings(tester);
      expect(find.text('حجم الخط'), findsNothing);
      expect(
        find.textContaining('يتبع التطبيق حجم الخط المضبوط'),
        findsNothing,
      );
      expect(find.text('إعدادات الإشعارات'), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-legal')), findsOneWidget);
    });

    testWidgets('الزائر يصل إلى الإعدادات من الرئيسية لا من «حسابي»', (
      tester,
    ) async {
      await pumpApp(tester, auth: FakeAuthBackend(signedIn: false));
      await _openSettings(tester);
      expect(find.text('المظهر'), findsOneWidget);

      await tester.tap(find.byTooltip('رجوع'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حسابي').last);
      await tester.pumpAndSettle();
      expect(find.text('الإعدادات'), findsNothing);
    });
  });

  group('الشروط والخصوصية والمساعدة', () {
    Future<void> openLegal(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        rpc: FakeRpc({'get_my_account': (_) => fixture('account-ready')}),
      );
      await _openSettings(tester);
      await tester.tap(find.byKey(const ValueKey('settings-legal')));
      await tester.pumpAndSettle();
    }

    testWidgets('قائمة النصوص السارية، والنص المؤقت يُوسم صراحة', (
      tester,
    ) async {
      await openLegal(tester);
      expect(find.byKey(const ValueKey('policy-TERMS')), findsOneWidget);
      expect(find.byKey(const ValueKey('policy-PRIVACY')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('policy-TERMS')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ينتظر اعتماد النص القانوني'), findsOneWidget);
      expect(find.textContaining('نص مؤقت لأغراض التطوير'), findsOneWidget);
    });

    testWidgets('الأسئلة الشائعة تفتح، ولا رقم دعم مختلقًا', (tester) async {
      await openLegal(tester);
      await tester.tap(find.text('كيف أنشر إعلانًا؟'));
      await tester.pumpAndSettle();
      expect(find.textContaining('اضغط «إعلان»'), findsOneWidget);
      for (final (q, a) in faq) {
        expect('$q $a', isNot(matches(RegExp(r'\d{7,}'))));
        expect('$q $a', isNot(contains('@')));
      }
    });

    testWidgets('فشل تحميل النصوص: إعادة المحاولة', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var fail = true;
      final rpc = FakeRpc({
        'get_my_account': (_) => fixture('account-ready'),
        'get_current_policies': (_) {
          if (fail) throw StateError('x');
          return fixture('current-policies');
        },
      });
      await pumpApp(tester, rpc: rpc);
      await _openSettings(tester);
      await tester.tap(find.byKey(const ValueKey('settings-legal')));
      await tester.pumpAndSettle();
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('policy-TERMS')), findsOneWidget);
    });
  });
}
