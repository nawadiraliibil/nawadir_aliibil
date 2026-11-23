import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_messages.dart';
import '../../../core/widgets/app_note.dart';
import '../application/post_controller.dart';
import '../domain/draft_validation.dart';

/// هيكل شاشة خطوة: محتواها، وخطأ الخادم إن وُجد، وزرا «متابعة» و«حفظ مسودة».
class StepFrame extends ConsumerWidget {
  const StepFrame({
    super.key,
    required this.children,
    required this.onContinue,
    required this.onSaveDraft,
    this.continueLabel = 'متابعة',
  });

  final List<Widget> children;

  /// يُستدعى عند «متابعة». يتولى التحقق والحفظ والانتقال.
  final Future<void> Function() onContinue;

  /// يُستدعى عند «حفظ مسودة». `null` يخفي الزر.
  final Future<void> Function()? onSaveDraft;
  final String continueLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(postControllerProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        ...children,
        if (state.error != null) ...[
          const SizedBox(height: 16),
          AppNote(errorMessage(state.error!), kind: AppNoteKind.error),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: state.busy ? null : onContinue,
          child: state.busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(continueLabel),
        ),
        if (onSaveDraft != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: state.busy ? null : onSaveDraft,
            child: const Text('حفظ مسودة'),
          ),
        ],
      ],
    );
  }
}

/// حقل نصي مرتبط بمفتاح في المسودة.
class DraftTextField extends StatelessWidget {
  const DraftTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.hint,
    this.error,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.ltr = false,
    this.prefix,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? error;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final bool ltr;
  final String? prefix;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: maxLines > 3 ? 3 : maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        textDirection: ltr ? TextDirection.ltr : null,
        textAlign: ltr ? TextAlign.start : TextAlign.start,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: error,
          prefixText: prefix,
          counterText: maxLength == null ? null : '',
        ),
        onChanged: onChanged,
      ),
    );
  }
}

/// قائمة منسدلة لقيمة صحيحة أو نصية.
class DraftDropdown<T> extends StatelessWidget {
  const DraftDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.error,
  });

  final String label;
  final T? value;
  final Map<T, String> items;
  final String? error;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        initialValue: items.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, errorText: error),
        hint: const Text('اختر'),
        items: [
          for (final e in items.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// حالة الحقول: أخطاء الخطوة وهل تظهر.
mixin StepErrors<W extends StatefulWidget> on State<W> {
  bool showErrors = false;

  /// خطأ الحقل [key] إن كانت الأخطاء ظاهرة.
  String? errorOf(FieldErrors errors, String key) =>
      showErrors ? errors[key] : null;

  /// يُظهر الأخطاء ويعيد `true` إن كانت الخطوة صالحة.
  bool check(FieldErrors errors) {
    setState(() => showErrors = true);
    return errors.isEmpty;
  }
}

String stepSubtitle(PostStep step) =>
    'إعلان جديد ${step.number} / ${PostStep.total}';
