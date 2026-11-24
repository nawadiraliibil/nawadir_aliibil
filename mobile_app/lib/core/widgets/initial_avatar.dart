import 'package:flutter/material.dart';

/// صورة رمزية بالحرف الأول من الاسم. الألف بأشكالها خط رفيع يُقرأ كشرطة،
/// فتُعرض بدله أيقونة شخص، وكذلك حين يغيب الاسم.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.name,
    required this.radius,
    required this.background,
    required this.foreground,
    this.textStyle,
  });

  final String? name;
  final double radius;
  final Color background;
  final Color foreground;
  final TextStyle? textStyle;

  static const _thin = {'ا', 'أ', 'إ', 'آ', 'ٱ'};

  @override
  Widget build(BuildContext context) {
    final trimmed = name?.trim() ?? '';
    final initial = trimmed.isEmpty ? null : trimmed.characters.first;
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: initial == null || _thin.contains(initial)
          ? Icon(Icons.person, size: radius, color: foreground)
          : Text(initial, style: textStyle?.copyWith(color: foreground)),
    );
  }
}
