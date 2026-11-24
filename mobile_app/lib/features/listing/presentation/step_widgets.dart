import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
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

  /// يُستدعى عند «متابعة». يتولى التحقق والحفظ والانتقال. `null` يخفي الزر
  /// (D01: اختيار البطاقة هو المتابعة).
  final Future<void> Function()? onContinue;

  /// يُستدعى عند «حفظ مسودة». `null` يخفي الزر.
  final Future<void> Function()? onSaveDraft;
  final String continueLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(postControllerProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ...children,
        if (state.error != null) ...[
          const SizedBox(height: 16),
          AppNote(errorMessage(state.error!), kind: AppNoteKind.error),
        ],
        if (onContinue != null) ...[
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
        ],
        if (onSaveDraft != null) ...[
          SizedBox(height: onContinue == null ? 20 : 8),
          TextButton(
            onPressed: state.busy ? null : onSaveDraft,
            child: const Text('حفظ مسودة'),
          ),
        ],
      ],
    );
  }
}

/// تسمية الحقل فوقه (`.field label`): نص صغير غامق بلون ثانوي.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: context.colors.muted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// حقل بتسمية فوقه ومفتاح `field:<label>` تعتمد عليه الاختبارات.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.help,
  });

  final String label;
  final Widget child;

  /// سطر مساعد تحت الحقل.
  final String? help;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        key: ValueKey('field:$label'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          child,
          if (help != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(help!, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// شريط الخطوات: «إعلان جديد» و«n / 7» فوق سبع شرائح تمتلئ بالذهبي.
class PostStepper extends StatelessWidget {
  const PostStepper({super.key, required this.step});

  final PostStep step;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: stepSubtitle(step),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'إعلان جديد',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: c.gold),
                  ),
                ),
                const SizedBox(width: 8),
                // داخل واجهة RTL يُقلب ترتيب الأرقام فيظهر «7 / 1»؛ LTR يبقيه «1 / 7».
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${step.number} / ${PostStep.total}',
                    maxLines: 1,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 1; i <= PostStep.total; i++) ...[
                  if (i > 1) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= step.number ? c.gold : c.soft,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
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
    this.help,
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

  /// سطر مساعد يظهر ما دام لا خطأ.
  final String? help;
  final String? error;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final bool ltr;
  final String? prefix;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: label,
      help: error == null ? help : null,
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: maxLines > 3 ? 3 : maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        textDirection: ltr ? TextDirection.ltr : null,
        decoration: InputDecoration(
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
    return LabeledField(
      label: label,
      child: DropdownButtonFormField<T>(
        initialValue: items.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(errorText: error),
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
