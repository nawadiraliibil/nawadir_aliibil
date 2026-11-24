import 'package:flutter/material.dart';
import '../../../core/widgets/app_snack.dart';
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
import '../data/rating_models.dart';
import '../data/ratings_repository.dart';
import 'seller_ratings_screen.dart';

/// تقييماتي كمعلن (F08): رد مستقل على كل تقييم واعتراض بسبب منفصل. الاعتراض
/// لا يخفي التقييم تلقائيًا؛ تقرر الإدارة.
class ReceivedRatingsScreen extends ConsumerWidget {
  const ReceivedRatingsScreen({super.key});

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    ReceivedRating r,
    bool appeal,
  ) async {
    final max =
        ref.read(publishedSettingsProvider).value?.interaction.ratingMax ??
        1000;
    final res = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ReplyAppealSheet(
        canReply: r.canReply,
        canAppeal: r.canAppeal,
        startOnAppeal: appeal,
        initialReply: r.replyBody ?? '',
        max: max,
      ),
    );
    if (res == null || res.text.isEmpty || !context.mounted) return;
    final repo = ref.read(ratingsRepositoryProvider);
    await _run(
      context,
      ref,
      () =>
          res.appeal ? repo.appeal(r.id, res.text) : repo.reply(r.id, res.text),
      res.appeal ? 'تم استلام اعتراضك وسيراجعه فريق الإشراف.' : 'تم نشر ردك.',
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
      messenger.showApp(success, kind: AppNoteKind.success);
    } on Object catch (e) {
      messenger.showApp(
        errorMessage(AppError.from(e)),
        kind: AppNoteKind.error,
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
          icon: const Icon(Icons.arrow_back),
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
                        padding: EdgeInsets.zero,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: c.hair)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: c.soft,
                                        borderRadius: BorderRadius.circular(
                                          AppShapes.image,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          'ردك: ${r.replyBody}',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
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
                                          await _submit(context, ref, r, false);
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
                                          await _submit(context, ref, r, true);
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

class _SheetResult {
  const _SheetResult(this.appeal, this.text);
  final bool appeal;
  final String text;
}

/// ورقة سفلية واحدة بتبويبين كبسوليين: «رد المعلن» و«اعتراض» (F08).
class _ReplyAppealSheet extends StatefulWidget {
  const _ReplyAppealSheet({
    required this.canReply,
    required this.canAppeal,
    required this.startOnAppeal,
    required this.initialReply,
    required this.max,
  });

  final bool canReply;
  final bool canAppeal;
  final bool startOnAppeal;
  final String initialReply;
  final int max;

  @override
  State<_ReplyAppealSheet> createState() => _ReplyAppealSheetState();
}

class _ReplyAppealSheetState extends State<_ReplyAppealSheet> {
  late var _appeal = widget.startOnAppeal;
  late final _controller = TextEditingController(
    text: _appeal ? '' : widget.initialReply,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(bool appeal) {
    if (appeal == _appeal) return;
    setState(() {
      _appeal = appeal;
      _controller.text = appeal ? '' : widget.initialReply;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    Widget tab(Key key, String label, bool appeal, bool enabled) {
      final selected = _appeal == appeal;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected ? c.tintGold : Colors.transparent,
            shape: const StadiumBorder(),
            child: InkWell(
              key: key,
              customBorder: const StadiumBorder(),
              onTap: enabled ? () => _select(appeal) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: !enabled
                          ? c.muted.withValues(alpha: 0.5)
                          : selected
                          ? c.gold
                          : c.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        20,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('الرد والاعتراض', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: ShapeDecoration(
                color: c.soft,
                shape: const StadiumBorder(),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    tab(
                      const ValueKey('rating-tab-reply'),
                      'رد المعلن',
                      false,
                      widget.canReply,
                    ),
                    tab(
                      const ValueKey('rating-tab-appeal'),
                      'اعتراض',
                      true,
                      widget.canAppeal,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _appeal ? 'سبب الاعتراض' : 'نص الرد',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('rating-dialog-input'),
              controller: _controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: widget.max,
              decoration: InputDecoration(
                hintText: _appeal ? 'اذكر سبب اعتراضك' : 'اكتب ردك',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('rating-sheet-submit'),
              onPressed: () => Navigator.pop(
                context,
                _SheetResult(_appeal, _controller.text.trim()),
              ),
              child: Text(_appeal ? 'إرسال الاعتراض' : 'إرسال الرد'),
            ),
          ],
        ),
      ),
    );
  }
}
