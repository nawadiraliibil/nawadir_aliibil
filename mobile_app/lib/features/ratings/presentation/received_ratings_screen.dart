import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/format/money.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/ratings_providers.dart';
import '../data/ratings_repository.dart';
import 'seller_ratings_screen.dart';

/// تقييماتي كمعلن (F08): رد مستقل على كل تقييم واعتراض بسبب منفصل. الاعتراض
/// لا يخفي التقييم تلقائيًا؛ تقرر الإدارة.
class ReceivedRatingsScreen extends ConsumerWidget {
  const ReceivedRatingsScreen({super.key});

  Future<String?> _ask(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String hint,
    required String ok,
    String initial = '',
  }) {
    final max =
        ref.read(publishedSettingsProvider).value?.interaction.ratingMax ??
        1000;
    return showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(
        title: title,
        hint: hint,
        ok: ok,
        initial: initial,
        max: max,
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String success,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(receivedRatingsProvider);
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessage(AppError.from(e)))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final received = ref.watch(receivedRatingsProvider);
    final theme = Theme.of(context);
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_forward),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.account),
        ),
        title: const Text('تقييماتي كمعلن'),
      ),
      body: SafeArea(
        child: received.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'تعذّر تحميل التقييمات',
            message: errorMessage(AppError.from(e)),
            actionLabel: 'إعادة المحاولة',
            onAction: () => ref.invalidate(receivedRatingsProvider),
          ),
          data: (list) => list.isEmpty
              ? const EmptyState(
                  icon: Icons.star_border,
                  title: 'لا تقييمات بعد',
                  message: 'ستظهر هنا تقييمات من تعاملوا معك لترد عليها.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    const AppNote(
                      'ردك لا يغير الدرجة، والاعتراض لا يخفي التقييم حتى تقرر الإدارة.',
                    ),
                    const SizedBox(height: 12),
                    for (final r in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.soft,
                            borderRadius: BorderRadius.circular(AppShapes.card),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    StarsRow(score: r.score),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        r.displayName,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    ),
                                    if (r.hidden)
                                      const AppBadge(
                                        label: 'مخفي',
                                        kind: AppBadgeKind.error,
                                      ),
                                    const SizedBox(width: 6),
                                    Text(
                                      formatShortTime(r.createdAt),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: c.muted),
                                    ),
                                  ],
                                ),
                                if (r.body != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      r.body!,
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  ),
                                if (r.replyBody != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'ردك: ${r.replyBody}',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                if (r.appealStatus != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: AppNote(switch (r.appealStatus) {
                                      'OPEN' => 'اعتراضك قيد المراجعة.',
                                      'ACCEPTED' =>
                                        'قُبل اعتراضك وأُخفي التقييم.',
                                      _ => 'رُفض اعتراضك وبقي التقييم ظاهرًا.',
                                    }),
                                  ),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (r.canReply)
                                      TextButton(
                                        key: ValueKey('reply-rating-${r.id}'),
                                        onPressed: () async {
                                          final text = await _ask(
                                            context,
                                            ref,
                                            title: 'الرد على التقييم',
                                            hint: 'اكتب ردك',
                                            ok: 'نشر',
                                            initial: r.replyBody ?? '',
                                          );
                                          if (text == null ||
                                              text.isEmpty ||
                                              !context.mounted) {
                                            return;
                                          }
                                          await _run(
                                            context,
                                            ref,
                                            () => ref
                                                .read(ratingsRepositoryProvider)
                                                .reply(r.id, text),
                                            'تم نشر ردك.',
                                          );
                                        },
                                        child: Text(
                                          r.replyBody == null
                                              ? 'رد'
                                              : 'تعديل الرد',
                                        ),
                                      ),
                                    if (r.canAppeal)
                                      TextButton(
                                        key: ValueKey('appeal-rating-${r.id}'),
                                        onPressed: () async {
                                          final text = await _ask(
                                            context,
                                            ref,
                                            title: 'الاعتراض على التقييم',
                                            hint: 'اذكر سبب اعتراضك',
                                            ok: 'إرسال الاعتراض',
                                          );
                                          if (text == null ||
                                              text.isEmpty ||
                                              !context.mounted) {
                                            return;
                                          }
                                          await _run(
                                            context,
                                            ref,
                                            () => ref
                                                .read(ratingsRepositoryProvider)
                                                .appeal(r.id, text),
                                            'تم استلام اعتراضك وسيراجعه فريق الإشراف.',
                                          );
                                        },
                                        child: const Text('اعتراض'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.hint,
    required this.ok,
    required this.initial,
    required this.max,
  });

  final String title;
  final String hint;
  final String ok;
  final String initial;
  final int max;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('rating-dialog-input'),
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 6,
        maxLength: widget.max,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.ok),
        ),
      ],
    );
  }
}
