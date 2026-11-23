import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/saudi_phone.dart';
import '../application/account_providers.dart';
import '../data/account_repository.dart';
import 'profile_form.dart';

Widget _backButton(BuildContext context, String fallback) => IconButton(
  tooltip: 'رجوع',
  icon: const Icon(Icons.arrow_forward),
  onPressed: () => context.canPop() ? context.pop() : context.go(fallback),
);

Widget _accountLoading() => const Center(child: CircularProgressIndicator());

Widget _accountError(WidgetRef ref, Object e) => EmptyState(
  icon: Icons.cloud_off_outlined,
  title: 'تعذّر تحميل حسابك',
  message: errorMessage(AppError.from(e)),
  actionLabel: 'إعادة المحاولة',
  onAction: () => ref.invalidate(myAccountProvider),
);

/// A04 — إكمال الحساب: الاسم والمنطقة والموافقة على النصوص المعلقة.
class CompleteAccountScreen extends ConsumerWidget {
  const CompleteAccountScreen({super.key, this.from});

  /// الوجهة بعد الحفظ.
  final String? from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(myAccountProvider);
    return Scaffold(
      appBar: AppBar(
        leading: _backButton(context, Routes.account),
        title: const Text('إكمال الحساب'),
      ),
      body: SafeArea(
        child: account.when(
          loading: _accountLoading,
          error: (e, _) => _accountError(ref, e),
          data: (a) {
            if (a == null) return _accountLoading();
            return ProfileForm(
              submitLabel: 'حفظ ومتابعة',
              initialName: a.displayName,
              initialRegionId: a.regionId,
              pendingPolicies: a.pendingPolicies,
              onSubmit: (name, region, policyIds) async {
                final repo = ref.read(accountRepositoryProvider);
                await repo.updateProfile(displayName: name, regionId: region);
                if (policyIds.isNotEmpty) await repo.acceptPolicies(policyIds);
                ref.invalidate(myAccountProvider);
                if (!context.mounted) return;
                if (from != null) {
                  context.go(from!);
                } else if (context.canPop()) {
                  // فُتحت بـpush من شاشة تنتظر النتيجة (مثل إرسال إعلان).
                  context.pop(true);
                } else {
                  context.go(Routes.account);
                }
              },
            );
          },
        ),
      ),
    );
  }
}

/// G02 — تعديل الملف الشخصي. رقم الدخول يُعرض مخفيًا ولا يُعدَّل.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(myAccountProvider);
    final phone = SaudiPhone.tryParse(
      ref.watch(authBackendProvider).phone ?? '',
    );
    return Scaffold(
      appBar: AppBar(
        leading: _backButton(context, Routes.account),
        title: const Text('تعديل الملف الشخصي'),
      ),
      body: SafeArea(
        child: account.when(
          loading: _accountLoading,
          error: (e, _) => _accountError(ref, e),
          data: (a) {
            if (a == null) return _accountLoading();
            return Column(
              children: [
                Expanded(
                  child: ProfileForm(
                    submitLabel: 'حفظ التغييرات',
                    initialName: a.displayName,
                    initialRegionId: a.regionId,
                    pendingPolicies: a.pendingPolicies,
                    onSubmit: (name, region, policyIds) async {
                      final repo = ref.read(accountRepositoryProvider);
                      await repo.updateProfile(
                        displayName: name,
                        regionId: region,
                      );
                      if (policyIds.isNotEmpty) {
                        await repo.acceptPolicies(policyIds);
                      }
                      ref.invalidate(myAccountProvider);
                      if (context.mounted) context.go(Routes.account);
                    },
                  ),
                ),
                if (phone != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Text(
                      'رقم الدخول ${phone.masked}\nالجوال مؤكد · خاص',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
