import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/settings/settings_repository.dart';
import '../data/rating_models.dart';
import '../data/ratings_repository.dart';

/// ورقة إضافة تقييم أو تعديله (F06). تعيد `true` عند نجاح الحفظ في الخادم.
/// الجديد يشترط إقرار «تعاملت مع هذا المعلن» غير مفعل مسبقًا؛ ولا ادعاء شراء.
Future<bool?> showRatingSheet(
  BuildContext context, {
  required String sellerId,
  required String sellerName,
  PublicRating? existing,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _RatingSheet(
    sellerId: sellerId,
    sellerName: sellerName,
    existing: existing,
  ),
);

class _RatingSheet extends ConsumerStatefulWidget {
  const _RatingSheet({
    required this.sellerId,
    required this.sellerName,
    this.existing,
  });

  final String sellerId;
  final String sellerName;
  final PublicRating? existing;

  @override
  ConsumerState<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends ConsumerState<_RatingSheet> {
  late int _score = widget.existing?.score ?? 0;
  late final _body = TextEditingController(text: widget.existing?.body ?? '');

  /// ثابت لعمر الورقة: إعادة الإرسال بعد انقطاع لا تنشئ تقييمًا ثانيًا.
  final _requestId = const Uuid().v4();
  var _declared = false;
  var _busy = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  int get _max =>
      ref.read(publishedSettingsProvider).value?.interaction.ratingMax ?? 1000;

  bool get _valid =>
      _score >= 1 &&
      (_editing || _declared) &&
      _body.text.trim().length <= _max;

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final text = _body.text.trim();
    final body = text.isEmpty ? null : text;
    try {
      final repo = ref.read(ratingsRepositoryProvider);
      if (_editing) {
        await repo.edit(widget.existing!.id, _score, body);
      } else {
        await repo.submit(
          sellerId: widget.sellerId,
          score: _score,
          body: body,
          requestId: _requestId,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorMessage(AppError.from(e));
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
              _editing ? 'تعديل تقييمك' : 'قيّم ${widget.sellerName}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    key: ValueKey('score-$i'),
                    tooltip: '$i من 5 — ${scoreWords[i]}',
                    icon: Icon(
                      i <= _score ? Icons.star : Icons.star_border,
                      color: context.colors.gold,
                      size: 32,
                    ),
                    onPressed: () => setState(() => _score = i),
                  ),
                const SizedBox(width: 8),
                Text(
                  _score == 0 ? 'اختر درجة' : scoreWords[_score]!,
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            TextField(
              key: const ValueKey('rating-body'),
              controller: _body,
              minLines: 2,
              maxLines: 5,
              maxLength: _max,
              decoration: const InputDecoration(labelText: 'تعليقك (اختياري)'),
              onChanged: (_) => setState(() {}),
            ),
            if (!_editing)
              CheckboxListTile(
                key: const ValueKey('rating-declaration'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _declared,
                onChanged: (v) => setState(() => _declared = v ?? false),
                title: const Text('تعاملت مع هذا المعلن'),
                subtitle: const Text(
                  'التقييم يعبّر عن تجربتك في التعامل ولا يثبت عملية شراء.',
                ),
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
                key: const ValueKey('rating-submit'),
                onPressed: _valid && !_busy ? _submit : null,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_editing ? 'حفظ التعديل' : 'نشر التقييم'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
