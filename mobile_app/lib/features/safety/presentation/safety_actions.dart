import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/router/routes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../auth/application/auth_providers.dart';
import '../../chat/application/chat_providers.dart';
import '../application/safety_providers.dart';
import '../data/safety_repository.dart';

/// يطلب الدخول للزائر ويعيد `false`؛ للمسجل يعيد `true`.
bool requireSignIn(BuildContext context, WidgetRef ref) {
  if (ref.read(signedInProvider).value ?? false) return true;
  final from = GoRouterState.of(context).uri.toString();
  context.push(
    Uri(path: Routes.login, queryParameters: {'from': from}).toString(),
  );
  return false;
}

/// ورقة الإبلاغ (F09): سبب ووصف، وإرسال بمعرف طلب ثابت. تعرض رقم البلاغ عند
/// النجاح. لا تكشف المبلّغ عنه ولا تعرض ملاحظات داخلية.
Future<void> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required ReportTarget target,
  required String targetId,
  required String targetLabel,
}) async {
  if (!requireSignIn(context, ref)) return;
  final messenger = ScaffoldMessenger.of(context);
  final receipt = await showModalBottomSheet<ReportReceipt>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(
      target: target,
      targetId: targetId,
      targetLabel: targetLabel,
    ),
  );
  if (receipt == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        receipt.duplicate
            ? 'لديك بلاغ مفتوح عن هذا الأمر (${receipt.ref}). سنراجعه قريبًا.'
            : 'تم استلام بلاغك. رقمه ${receipt.ref}.',
      ),
    ),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.target,
    required this.targetId,
    required this.targetLabel,
  });

  final ReportTarget target;
  final String targetId;
  final String targetLabel;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportReason? _reason;
  final _description = TextEditingController();

  /// ثابت طوال عمر الورقة: إعادة الإرسال بعد انقطاع لا تنشئ بلاغًا ثانيًا.
  final _requestId = const Uuid().v4();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  bool get _valid =>
      _reason != null &&
      (_reason != ReportReason.other || _description.text.trim().isNotEmpty);

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final text = _description.text.trim();
      final receipt = await ref
          .read(safetyRepositoryProvider)
          .report(
            target: widget.target,
            targetId: widget.targetId,
            reason: _reason!,
            description: text.isEmpty ? null : text,
            requestId: _requestId,
          );
      if (mounted) Navigator.of(context).pop(receipt);
    } on Object catch (e) {
      final err = AppError.from(e);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = err.code == AppErrorCode.notFound
              ? 'لم يعد بالإمكان الإبلاغ عن هذا العنصر.'
              : errorMessage(err);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإبلاغ عن ${widget.targetLabel}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'بلاغك خاص ولا يظهر لمن تبلّغ عنه.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final r in ReportReason.values)
                    RadioListTile<ReportReason>(
                      key: ValueKey('report-reason-${r.wire}'),
                      value: r,
                      title: Text(r.label),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            TextField(
              key: const ValueKey('report-description'),
              controller: _description,
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: _reason == ReportReason.other
                    ? 'اكتب التفاصيل (إلزامي)'
                    : 'تفاصيل إضافية (اختياري)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('report-submit'),
                onPressed: _valid && !_busy ? _submit : null,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('إرسال البلاغ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// حظر مستخدم بعد تأكيد. يعيد `true` عند النجاح.
Future<bool> confirmAndBlock(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
}) async {
  if (!requireSignIn(context, ref)) return false;
  final messenger = ScaffoldMessenger.of(context);
  final sure = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('حظر $name؟'),
      content: const Text(
        'لن يتمكن أي منكما من إرسال رسائل جديدة للآخر، ولن يرد على إعلاناتك '
        'ولن ترد على إعلاناته. تبقى المحادثات السابقة للقراءة، ويمكنك إلغاء '
        'الحظر في أي وقت.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('حظر'),
        ),
      ],
    ),
  );
  if (sure != true) return false;
  try {
    await ref.read(safetyRepositoryProvider).block(userId);
    ref.invalidate(blockedUsersProvider);
    ref.invalidate(conversationsProvider);
    messenger.showSnackBar(SnackBar(content: Text('تم حظر $name.')));
    return true;
  } on Object catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(errorMessage(AppError.from(e)))),
    );
    return false;
  }
}
