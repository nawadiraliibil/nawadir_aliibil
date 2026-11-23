import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/format/money.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/widgets/app_note.dart';
import '../../auth/application/auth_providers.dart';
import '../../browse/application/browse_providers.dart';
import '../../browse/data/listing_detail.dart';
import '../application/comments_providers.dart';
import '../data/comment.dart';
import '../data/comments_repository.dart';
import '../../safety/data/safety_repository.dart';
import '../../safety/presentation/safety_actions.dart';

/// الأسئلة والردود العامة على الإعلان (C07/C08): خيوط بردود المعلن، وكتابة
/// لغير المعلن، وتحرير الكاتب وحذفه لردّه، وإغلاق المعلن للجديد.
class CommentsSection extends ConsumerStatefulWidget {
  const CommentsSection({super.key, required this.detail});

  final ListingDetail detail;

  @override
  ConsumerState<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<CommentsSection> {
  final _input = TextEditingController();

  /// معرف طلب النشر: يبقى بعد فشل فتعيد المحاولة نفسه ولا يتكرر الرد.
  String? _requestId;
  var _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  CommentsNotifier get _notifier =>
      ref.read(commentsProvider(widget.detail.listingId).notifier);

  void _toast(Object e) {
    final err = AppError.from(e);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err.code == AppErrorCode.notFound
              ? 'تعذّر تنفيذ الإجراء: العنصر لم يعد متاحًا.'
              : errorMessage(err),
        ),
      ),
    );
  }

  Future<void> _post() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    _requestId ??= const Uuid().v4();
    setState(() => _busy = true);
    try {
      await _notifier.post(text, _requestId!);
      _requestId = null;
      _input.clear();
    } on Object catch (e) {
      _toast(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _ask(String title, {String initial = '', String ok = 'حفظ'}) {
    final max =
        ref.read(publishedSettingsProvider).value?.interaction.commentMax ??
        1000;
    return showDialog<String>(
      context: context,
      builder: (context) =>
          _TextDialog(title: title, initial: initial, ok: ok, max: max),
    );
  }

  Future<void> _edit(Comment c) async {
    final text = await _ask('تعديل الرد', initial: c.body ?? '');
    if (text == null || text.isEmpty || text == c.body) return;
    try {
      await _notifier.edit(c.id, text);
    } on Object catch (e) {
      _toast(e);
    }
  }

  Future<void> _delete(Comment c) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الرد؟'),
        content: const Text('لن يظهر نص ردّك للآخرين.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await _notifier.delete(c.id);
    } on Object catch (e) {
      _toast(e);
    }
  }

  Future<void> _reply(Comment root) async {
    final text = await _ask('الرد على السؤال', ok: 'نشر');
    if (text == null || text.isEmpty) return;
    try {
      await _notifier.post(text, const Uuid().v4(), parentId: root.id);
    } on Object catch (e) {
      _toast(e);
    }
  }

  void _report(Comment c) => showReportSheet(
    context,
    ref,
    target: ReportTarget.comment,
    targetId: c.id,
    targetLabel: 'الرد',
  );

  Future<void> _toggleClosed() async {
    final d = widget.detail;
    try {
      await ref
          .read(commentsRepositoryProvider)
          .setClosed(d.listingId, !d.commentsClosed);
      ref.invalidate(listingDetailProvider(d.listingId));
    } on Object catch (e) {
      _toast(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final d = widget.detail;
    final signedIn = ref.watch(signedInProvider).value ?? false;
    final myId = ref.watch(authBackendProvider).userId;
    final isOwner = myId != null && myId == d.ownerId;
    final comments = ref.watch(commentsProvider(d.listingId));
    final max =
        ref.watch(publishedSettingsProvider).value?.interaction.commentMax ??
        1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'الأسئلة والردود',
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (isOwner)
              TextButton(
                key: const ValueKey('comments-toggle-closed'),
                onPressed: _toggleClosed,
                child: Text(
                  d.commentsClosed ? 'فتح الردود' : 'إغلاق الردود الجديدة',
                ),
              ),
          ],
        ),
        if (d.commentsClosed)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: AppNote('أغلق المعلن الردود الجديدة على هذا الإعلان.'),
          ),
        comments.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Column(
            children: [
              Text(errorMessage(AppError.from(e))),
              TextButton(
                onPressed: () => ref.invalidate(commentsProvider(d.listingId)),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
          data: (threads) => threads.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'لا ردود بعد. كن أول من يسأل.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                  ),
                )
              : Column(
                  children: [
                    for (final t in threads)
                      _ThreadTile(
                        thread: t,
                        myId: myId,
                        canReply: isOwner && t.root.isVisible,
                        onReply: () => _reply(t.root),
                        onEdit: _edit,
                        onDelete: _delete,
                        onReport: _report,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        if (!signedIn)
          OutlinedButton(
            key: const ValueKey('comments-login'),
            onPressed: () => context.push(
              Uri(
                path: Routes.login,
                queryParameters: {'from': Routes.listing(d.listingId)},
              ).toString(),
            ),
            child: const Text('سجّل الدخول لإضافة رد'),
          )
        else if (!isOwner && !d.commentsClosed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('comment-input'),
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: max,
                  decoration: const InputDecoration(
                    hintText: 'اكتب سؤالك أو ردّك',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                key: const ValueKey('comment-send'),
                tooltip: 'نشر',
                icon: const Icon(Icons.send),
                onPressed: _input.text.trim().isEmpty || _busy ? null : _post,
              ),
            ],
          ),
      ],
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.thread,
    required this.myId,
    required this.canReply,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
  });

  final CommentThread thread;
  final void Function(Comment) onReport;
  final String? myId;
  final bool canReply;
  final VoidCallback onReply;
  final void Function(Comment) onEdit;
  final void Function(Comment) onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
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
              _CommentBody(
                comment: thread.root,
                mine: myId == thread.root.authorId,
                onEdit: onEdit,
                onDelete: onDelete,
                onReport: onReport,
              ),
              for (final r in thread.replies)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16, top: 8),
                  child: _CommentBody(
                    comment: r,
                    mine: myId == r.authorId,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onReport: onReport,
                  ),
                ),
              if (canReply)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: ValueKey('reply-${thread.root.id}'),
                    onPressed: onReply,
                    child: const Text('رد'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentBody extends StatelessWidget {
  const _CommentBody({
    required this.comment,
    required this.mine,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
  });

  final Comment comment;
  final bool mine;
  final void Function(Comment) onReport;
  final void Function(Comment) onEdit;
  final void Function(Comment) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final text = switch (comment.state) {
      'HIDDEN' => 'أُخفي هذا الرد بقرار الإشراف.',
      'DELETED' => 'حذف كاتب الرد ردّه.',
      _ => comment.body ?? '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                comment.displayName,
                style: theme.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (comment.isOwner)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 6),
                child: Text(
                  'المعلن',
                  style: theme.textTheme.labelSmall?.copyWith(color: c.gold),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              formatShortTime(comment.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
            ),
            if (comment.editedAt != null && comment.isVisible)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 6),
                child: Text(
                  'معدّل',
                  style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                ),
              ),
            const Spacer(),
            if (!mine && comment.isVisible)
              PopupMenuButton<String>(
                key: ValueKey('comment-report-menu-${comment.id}'),
                tooltip: 'خيارات الرد',
                onSelected: (_) => onReport(comment),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'report', child: Text('إبلاغ')),
                ],
              ),
            if (mine && comment.isVisible)
              PopupMenuButton<String>(
                key: ValueKey('comment-menu-${comment.id}'),
                tooltip: 'خيارات الرد',
                onSelected: (v) =>
                    v == 'edit' ? onEdit(comment) : onDelete(comment),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
          ],
        ),
        Text(
          text,
          style: comment.isVisible
              ? theme.textTheme.bodyLarge
              : theme.textTheme.bodyMedium?.copyWith(
                  color: c.muted,
                  fontStyle: FontStyle.italic,
                ),
        ),
      ],
    );
  }
}

/// حوار نص: يملك متحكم الحقل ويتخلص منه مع حالته، فلا يُستعمل بعد إتلافه أثناء
/// حركة الإغلاق.
class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    required this.ok,
    required this.max,
  });

  final String title;
  final String initial;
  final String ok;
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
        key: const ValueKey('comment-dialog-input'),
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 6,
        maxLength: widget.max,
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
