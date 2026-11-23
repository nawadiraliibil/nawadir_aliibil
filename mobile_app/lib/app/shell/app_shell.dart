import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/push/push_service.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/chat/application/chat_providers.dart';
import '../router/routes.dart';
import '../theme/app_shapes.dart';
import 'app_nav_bar.dart';

/// هيكل التبويبات: محتوى التبويب الحالي وفوقه شريط التنقل العائم.
///
/// الشريط يُبنى هنا مرة واحدة ولا تبنيه الشاشات، وحالة كل تبويب محفوظة عبر
/// `StatefulNavigationShell`.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _select(int index) {
    // الضغط على التبويب الحالي يعيده إلى شاشته الأولى.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final unread = ref.watch(unreadMessagesProvider);
    // رمز الدفع يسجل عند الدخول؛ دون دفع مهيأ لا يحدث شيء.
    ref.listen(signedInProvider, (_, next) {
      if (next.value == true) ref.read(pushRegistrarProvider).register();
    });

    return Scaffold(
      body: Stack(
        children: [
          // يُزاد الهامش الآمن السفلي بارتفاع الشريط، فتترك القوائم
          // والـSafeArea داخل التبويبات مساحته تلقائيًا.
          MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(
                bottom: media.padding.bottom + AppNavBar.occupiedHeight,
              ),
            ),
            child: navigationShell,
          ),
          Positioned(
            left: AppShapes.screenPadding - 2,
            right: AppShapes.screenPadding - 2,
            bottom: media.padding.bottom + AppNavBar.bottomGap,
            child: Center(
              child: AppNavBar(
                currentIndex: navigationShell.currentIndex,
                onDestinationSelected: _select,
                onPostAd: () => context.push(Routes.postAd),
                badges: {2: unread},
              ),
            ),
          ),
        ],
      ),
    );
  }
}
