import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'app_note.dart';

/// H10 — تأكيد النجاح أو فشل الحفظ بشكل موحد: أيقونة ونص ولون للحالة.
/// الأخطاء تعلن لقارئ الشاشة فورًا، ولا يعتمد المعنى على اللون وحده.
/// الألوان تقرأ داخل المحتوى فلا حاجة إلى سياق بعد العمليات غير المتزامنة.
SnackBar appSnack(String message, {AppNoteKind kind = AppNoteKind.success}) {
  return SnackBar(
    duration: Duration(seconds: kind == AppNoteKind.error ? 6 : 4),
    content: Builder(
      builder: (context) {
        final c = context.colors;
        final (accent, icon) = switch (kind) {
          AppNoteKind.info => (c.buttonText, Icons.info_outline),
          AppNoteKind.success => (c.success, Icons.check_circle_outline),
          AppNoteKind.error => (c.error, Icons.error_outline),
        };
        return Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        );
      },
    ),
  );
}

extension AppSnackMessenger on ScaffoldMessengerState {
  /// يعرض [message] بدل أي رسالة سابقة حتى لا تتراكم الرسائل.
  void showApp(String message, {AppNoteKind kind = AppNoteKind.success}) {
    hideCurrentSnackBar();
    showSnackBar(appSnack(message, kind: kind));
  }
}
