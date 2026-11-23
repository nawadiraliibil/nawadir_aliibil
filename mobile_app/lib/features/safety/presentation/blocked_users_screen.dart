import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/widgets/empty_state.dart';
import '../../chat/application/chat_providers.dart';
import '../application/safety_providers.dart';
import '../data/safety_repository.dart';

/// المحظورون (G08): قائمة بإلغاء الحظر.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  Future<void> _unblock(
    BuildContext context,
    WidgetRef ref,
    BlockedUser u,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(safetyRepositoryProvider).unblock(u.userId);
      ref.invalidate(blockedUsersProvider);
      ref.invalidate(conversationsProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('أُلغي حظر ${u.displayName}.')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessage(AppError.from(e)))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider);
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_forward),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.account),
        ),
        title: const Text('المحظورون'),
      ),
      body: SafeArea(
        child: blocked.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'تعذّر تحميل القائمة',
            message: errorMessage(AppError.from(e)),
            actionLabel: 'إعادة المحاولة',
            onAction: () => ref.invalidate(blockedUsersProvider),
          ),
          data: (items) => items.isEmpty
              ? const EmptyState(
                  icon: Icons.block,
                  title: 'لا محظورون',
                  message: 'من تحظره لن يستطيع مراسلتك ولن تصلك رسائله.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final u = items[i];
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.soft,
                        borderRadius: BorderRadius.circular(AppShapes.card),
                      ),
                      child: ListTile(
                        title: Text(u.displayName),
                        trailing: TextButton(
                          key: ValueKey('unblock-${u.userId}'),
                          onPressed: () => _unblock(context, ref, u),
                          child: const Text('إلغاء الحظر'),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
