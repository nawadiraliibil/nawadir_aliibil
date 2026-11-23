import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';

/// حقل رمز من [length] خانات. حقل نص واحد شفاف فوق خانات مرسومة، فيعمل
/// اللصق والتعبئة التلقائية من الرسالة وقارئ الشاشة كما في أي حقل.
class OtpField extends StatelessWidget {
  const OtpField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onChanged,
    this.onCompleted,
    this.enabled = true,
    this.hasError = false,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      // الأرقام تُدخل وتُعرض من اليسار إلى اليمين.
      textDirection: TextDirection.ltr,
      child: Semantics(
        textField: true,
        label: 'رمز التحقق المكوّن من $length أرقام',
        child: SizedBox(
          height: 56,
          child: Stack(
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final text = value.text;
                  return ExcludeSemantics(
                    child: Row(
                      children: [
                        for (var i = 0; i < length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _Box(
                              digit: i < text.length ? text[i] : '',
                              active:
                                  enabled &&
                                  i == text.length.clamp(0, length - 1),
                              hasError: hasError,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              Positioned.fill(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: length,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  style: const TextStyle(color: Colors.transparent),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    onChanged?.call(v);
                    if (v.length == length) onCompleted?.call(v);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.digit,
    required this.active,
    required this.hasError,
  });

  final String digit;
  final bool active;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final border = hasError
        ? c.error
        : active
        ? c.gold
        : c.line;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(AppShapes.field),
        border: Border.all(color: border, width: active || hasError ? 2 : 1),
      ),
      child: Center(
        child: Text(
          digit,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: c.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
