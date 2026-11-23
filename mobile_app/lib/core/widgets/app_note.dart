import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_shapes.dart';

enum AppNoteKind { info, success, error }

/// ملاحظة داخل الصفحة: تنبيه أو تأكيد أو خطأ، بأيقونة ونص.
class AppNote extends StatelessWidget {
  const AppNote(this.message, {super.key, this.kind = AppNoteKind.info});

  final String message;
  final AppNoteKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (background, accent, icon) = switch (kind) {
      AppNoteKind.info => (c.tintBlue, c.info, Icons.info_outline),
      AppNoteKind.success => (
        c.tintGreen,
        c.success,
        Icons.check_circle_outline,
      ),
      AppNoteKind.error => (c.tintRed, c.error, Icons.error_outline),
    };

    return Semantics(
      container: true,
      liveRegion: kind == AppNoteKind.error,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: const BorderRadius.all(Radius.circular(AppShapes.note)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: c.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
