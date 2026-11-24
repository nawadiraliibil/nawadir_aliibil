import 'package:flutter/material.dart';
import '../../../core/widgets/app_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/push/push_service.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/saudi_phone.dart';
import '../application/account_providers.dart';
import '../data/account_models.dart';
import 'menu_group.dart';

/// G01 — حسابي. للزائر دعوة إلى الدخول، وللمسجل ملخص الحساب والإجراءات.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider).value ?? false;
    final account = ref.watch(myAccountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: SafeArea(
        child: !signedIn
            ? EmptyState(
                icon: Icons.person_outline,
                title: 'سجّل الدخول',
                message: 'ادخل برقم جوالك لإدارة إعلاناتك وحسابك.',
                actionLabel: 'تسجيل الدخول',
                onAction: () => context.go(
                  Uri(
                    path: Routes.login,
                    queryParameters: {'from': Routes.account},
                  ).toString(),
                ),
              )
            : account.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'تعذّر تحميل حسابك',
                  message: errorMessage(AppError.from(e)),
                  actionLabel: 'إعادة المحاولة',
                  onAction: () => ref.invalidate(myAccountProvider),
                ),
                data: (a) => a == null
                    ? const Center(child: CircularProgressIndicator())
                    : _SignedIn(account: a),
              ),
      ),
    );
  }
}

class _SignedIn extends ConsumerWidget {
  const _SignedIn({required this.account});

  final MyAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.colors;
    final phone = SaudiPhone.tryParse(
      ref.watch(authBackendProvider).phone ?? '',
    );
    final regionName = ref
        .watch(publishedSettingsProvider)
        .value
        ?.lookups
        .region(account.regionId)
        ?.nameAr;
    final name = account.displayName;
    final subtitle = [?regionName, ?phone?.masked].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (account.isSuspended) ...[
          // H08
          const AppNote(
            'الحساب موقوف: النشر والتعديل غير متاحين حاليًا.',
            kind: AppNoteKind.error,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: c.tintGold,
              child: Text(
                name == null || name.isEmpty ? '؟' : name.characters.first,
                style: theme.textTheme.titleLarge?.copyWith(color: c.gold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name ?? 'مستخدم جديد',
                    style: theme.textTheme.titleMedium,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            IconButton(
              tooltip: 'تعديل الملف',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(Routes.accountEdit),
            ),
          ],
        ),
        if (account.needsCompletion && !account.isSuspended) ...[
          const SizedBox(height: 16),
          const AppNote(
            'أكمل بيانات حسابك والموافقة على الشروط لتتمكن من نشر إعلاناتك.',
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => context.push(Routes.accountComplete),
            child: const Text('إكمال الحساب'),
          ),
        ],
        const SizedBox(height: 16),
        MenuGroup(
          children: [
            MenuRow(
              icon: Icons.campaign_outlined,
              title: 'إعلاناتي',
              onTap: () => context.push(Routes.myListings),
            ),
            MenuRow(
              icon: Icons.star_border,
              title: 'تقييماتي كمعلن',
              onTap: () => context.push(Routes.receivedRatings),
            ),
            MenuRow(
              icon: Icons.notifications_none,
              title: 'الإشعارات',
              onTap: () => context.push(Routes.notificationSettings),
            ),
            MenuRow(
              icon: Icons.bookmark_border,
              title: 'المتابعات',
              onTap: () => context.push(Routes.follows),
            ),
            MenuRow(
              icon: Icons.block,
              title: 'المحظورون',
              onTap: () => context.push(Routes.blockedUsers),
            ),
            MenuRow(
              icon: Icons.info_outline,
              title: 'الشروط والمساعدة',
              onTap: () => context.push(Routes.legal),
            ),
            MenuRow(
              icon: Icons.settings_outlined,
              title: 'الإعدادات',
              onTap: () => context.push(Routes.settings),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: c.error),
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج'),
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ),
      ],
    );
  }

  /// G10: ورقة سفلية بزر خروج رئيسي وإلغاء ثانوي.
  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تسجيل الخروج؟',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                'ستنتهي جلسة هذا الجهاز، ويمكنك الدخول مجددًا برقم الجوال.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('تسجيل الخروج'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    // يوقف الدفع إلى هذا الجهاز قبل إبطال الجلسة؛ فشله لا يمنع الخروج.
    await ref.read(pushRegistrarProvider).unregister();
    try {
      await ref.read(authBackendProvider).signOut();
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showApp(
          'تعذّر تسجيل الخروج. حاول مرة أخرى.',
          kind: AppNoteKind.error,
        );
      }
    }
  }
}
