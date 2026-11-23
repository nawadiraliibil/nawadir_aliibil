import 'package:flutter/material.dart';
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
                secondaryLabel: 'الإعدادات',
                onSecondary: () => context.push(Routes.settings),
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
        const Divider(),
        ListTile(
          leading: const Icon(Icons.campaign_outlined),
          title: const Text('إعلاناتي'),
          onTap: () => context.push(Routes.myListings),
        ),
        ListTile(
          leading: const Icon(Icons.star_border),
          title: const Text('تقييماتي كمعلن'),
          onTap: () => context.push(Routes.receivedRatings),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_none),
          title: const Text('الإشعارات'),
          onTap: () => context.push(Routes.notificationSettings),
        ),
        ListTile(
          leading: const Icon(Icons.bookmark_border),
          title: const Text('المتابعات'),
          onTap: () => context.push(Routes.follows),
        ),
        ListTile(
          leading: const Icon(Icons.block),
          title: const Text('المحظورون'),
          onTap: () => context.push(Routes.blockedUsers),
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('الإعدادات والمساعدة'),
          onTap: () => context.push(Routes.settings),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('تسجيل الخروج'),
          onTap: () => _confirmSignOut(context, ref),
        ),
      ],
    );
  }

  /// G10.
  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج؟'),
        content: const Text(
          'ستنتهي جلسة هذا الجهاز، ويمكنك الدخول مجددًا برقم الجوال.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // يوقف الدفع إلى هذا الجهاز قبل إبطال الجلسة؛ فشله لا يمنع الخروج.
    await ref.read(pushRegistrarProvider).unregister();
    try {
      await ref.read(authBackendProvider).signOut();
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر تسجيل الخروج. حاول مرة أخرى.')),
        );
      }
    }
  }
}
