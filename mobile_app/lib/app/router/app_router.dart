import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_providers.dart';
import '../../features/account/presentation/account_screen.dart';
import '../../features/account/presentation/profile_screens.dart';
import '../../features/browse/presentation/home_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/conversations_screen.dart';
import '../../features/browse/presentation/listing_detail_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/listing/presentation/post_wizard.dart';
import '../../features/follows/presentation/follows_screen.dart';
import '../../features/notifications/presentation/notification_settings_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/ratings/presentation/received_ratings_screen.dart';
import '../../features/settings/presentation/legal_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/ratings/presentation/seller_ratings_screen.dart';
import '../../features/safety/presentation/blocked_users_screen.dart';
import '../../features/seller/presentation/seller_screen.dart';
import '../../features/my_listings/presentation/my_listing_detail_screen.dart';
import '../../features/my_listings/presentation/my_listings_screen.dart';
import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/phone_screen.dart';
import '../shell/app_shell.dart';
import '../startup/startup_screen.dart';
import 'routes.dart';

/// مسارات التطبيق: أربعة تبويبات داخل الهيكل، وشاشات كاملة خارجه.
///
/// حارس الدخول هنا؛ اكتمال الحساب يفرض عند نشر الإعلان (MOBILE-APP-107).
final appRouterProvider = Provider<GoRouter>((ref) {
  final env = ref.watch(envProvider);

  // دون إعداد صالح لا يوجد عميل Supabase ولا حالة دخول.
  final auth = env.isConfigured
      ? AuthRefreshNotifier(ref.watch(authBackendProvider))
      : null;
  if (auth != null) ref.onDispose(auth.dispose);

  final router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: auth,
    redirect: (context, state) {
      // دون إعداد بيئة صالح لا تتوفر الخلفية؛ تُعرض تعليمات الإعداد.
      final atSetup = state.matchedLocation == Routes.setup;
      if (!env.isConfigured) return atSetup ? null : Routes.setup;
      if (atSetup) return Routes.home;

      final path = state.matchedLocation;
      final atLogin = path == Routes.login || path == Routes.loginOtp;
      if (auth!.signedIn) {
        // دخل للتو: تفتح شاشة إكمال الحساب تلقائيًا، وتمضي بنفسها إلى الوجهة
        // الأصلية أو الرئيسية إن كان الحساب مكتملًا (A04).
        return atLogin
            ? Uri(
                path: Routes.accountComplete,
                queryParameters: {
                  'from': Routes.safeFrom(state.uri.queryParameters['from']),
                  'auto': '1',
                },
              ).toString()
            : null;
      }
      if (Routes.needsSignIn(path)) {
        return Uri(
          path: Routes.login,
          queryParameters: {'from': state.uri.toString()},
        ).toString();
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.setup,
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) =>
            PhoneScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: Routes.loginOtp,
        redirect: (context, state) =>
            state.extra is String ? null : Routes.login,
        builder: (context, state) => OtpScreen(
          phoneE164: state.extra! as String,
          from: state.uri.queryParameters['from'],
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.favorites,
                builder: (context, state) => const FavoritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.messages,
                builder: (context, state) => const ConversationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.account,
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.listingPattern,
        builder: (context, state) =>
            ListingDetailScreen(listingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.chatPattern,
        builder: (context, state) =>
            ChatScreen(conversationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.sellerRatingsPattern,
        builder: (context, state) => SellerRatingsScreen(
          sellerId: state.pathParameters['id']!,
          sellerName: state.uri.queryParameters['name'] ?? 'المعلن',
        ),
      ),
      GoRoute(
        path: Routes.receivedRatings,
        builder: (context, state) => const ReceivedRatingsScreen(),
      ),
      GoRoute(
        path: Routes.sellerPattern,
        builder: (context, state) =>
            SellerScreen(sellerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.accountComplete,
        builder: (context, state) => CompleteAccountScreen(
          from: state.uri.queryParameters['from'],
          auto: state.uri.queryParameters['auto'] == '1',
        ),
      ),
      GoRoute(
        path: Routes.accountEdit,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: Routes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: Routes.notificationSettings,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.legal,
        builder: (context, state) => const LegalScreen(),
      ),
      GoRoute(
        path: Routes.follows,
        builder: (context, state) => const FollowsScreen(),
      ),
      GoRoute(
        path: Routes.blockedUsers,
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: Routes.myListings,
        builder: (context, state) => const MyListingsScreen(),
      ),
      GoRoute(
        path: Routes.myListingPattern,
        builder: (context, state) =>
            MyListingDetailScreen(listingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.postAd,
        builder: (context, state) => PostWizardScreen(
          draftId: state.uri.queryParameters['draft'],
          editId: state.uri.queryParameters['edit'],
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
