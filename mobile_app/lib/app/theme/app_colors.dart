import 'package:flutter/material.dart';

/// ألوان التصميم المعتمد، منقولة من متغيرات
/// `docs/shared/stitch-distinct-20261121/ui.css` بالوضعين الفاتح والداكن.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.text,
    required this.muted,
    required this.gold,
    required this.line,
    required this.button,
    required this.buttonText,
    required this.soft,
    required this.info,
    required this.green,
    required this.tintGold,
    required this.tintGreen,
    required this.tintBlue,
    required this.tintRed,
    required this.error,
    required this.success,
    required this.shadow,
  });

  static const light = AppColors(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF2D241B),
    muted: Color(0xFF76695C),
    gold: Color(0xFFA77434),
    line: Color(0xFFE8E2D8),
    button: Color(0xFF2D241B),
    buttonText: Color(0xFFFFFFFF),
    soft: Color(0xFFF5F1EA),
    info: Color(0xFF2F6F9F),
    green: Color(0xFF1F7A5C),
    tintGold: Color(0xFFFBEBD3),
    tintGreen: Color(0xFFDDF1E8),
    tintBlue: Color(0xFFE1EEF7),
    tintRed: Color(0xFFFBE4E2),
    error: Color(0xFFC95D59),
    success: Color(0xFF2F936A),
    shadow: Color(0x242D241B),
  );

  static const dark = AppColors(
    bg: Color(0xFF111B1C),
    surface: Color(0xFF202D2D),
    text: Color(0xFFF6EEE0),
    muted: Color(0xFFAABAB3),
    gold: Color(0xFFE4BC7B),
    line: Color(0xFF3B504B),
    button: Color(0xFFE4BC7B),
    buttonText: Color(0xFF111B1C),
    soft: Color(0xFF293A37),
    info: Color(0xFF83A9D8),
    green: Color(0xFF53BE90),
    tintGold: Color(0xFF3A3324),
    tintGreen: Color(0xFF1F3A33),
    tintBlue: Color(0xFF22343F),
    tintRed: Color(0xFF402826),
    error: Color(0xFFE17B75),
    success: Color(0xFF53BE90),
    shadow: Color(0x80000000),
  );

  /// خلفية الشاشة.
  final Color bg;

  /// خلفية العناصر المرتفعة: الكبسولة، الحوارات، الأوراق.
  final Color surface;
  final Color text;

  /// النص الثانوي.
  final Color muted;

  /// لون الهوية: الأسعار، التركيز، العلامات.
  final Color gold;

  /// حدود العناصر.
  final Color line;

  /// خلفية الزر الرئيسي ونصه.
  final Color button;
  final Color buttonText;

  /// تعبئة الحقول والشرائح والقوائم.
  final Color soft;

  /// لون المزاد والملاحظات.
  final Color info;
  final Color green;
  final Color tintGold;
  final Color tintGreen;
  final Color tintBlue;
  final Color tintRed;
  final Color error;
  final Color success;

  /// لون ظل العناصر العائمة.
  final Color shadow;

  /// فاصل رفيع داخل القوائم المملوءة (`--hair`: النص بشفافية 9%).
  Color get hair => text.withValues(alpha: 0.09);

  /// ظل العناصر العائمة (`--shadow`).
  List<BoxShadow> get floatingShadow => [
    BoxShadow(color: shadow, blurRadius: 28, offset: const Offset(0, 8)),
  ];

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? text,
    Color? muted,
    Color? gold,
    Color? line,
    Color? button,
    Color? buttonText,
    Color? soft,
    Color? info,
    Color? green,
    Color? tintGold,
    Color? tintGreen,
    Color? tintBlue,
    Color? tintRed,
    Color? error,
    Color? success,
    Color? shadow,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      gold: gold ?? this.gold,
      line: line ?? this.line,
      button: button ?? this.button,
      buttonText: buttonText ?? this.buttonText,
      soft: soft ?? this.soft,
      info: info ?? this.info,
      green: green ?? this.green,
      tintGold: tintGold ?? this.tintGold,
      tintGreen: tintGreen ?? this.tintGreen,
      tintBlue: tintBlue ?? this.tintBlue,
      tintRed: tintRed ?? this.tintRed,
      error: error ?? this.error,
      success: success ?? this.success,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      text: mix(text, other.text),
      muted: mix(muted, other.muted),
      gold: mix(gold, other.gold),
      line: mix(line, other.line),
      button: mix(button, other.button),
      buttonText: mix(buttonText, other.buttonText),
      soft: mix(soft, other.soft),
      info: mix(info, other.info),
      green: mix(green, other.green),
      tintGold: mix(tintGold, other.tintGold),
      tintGreen: mix(tintGreen, other.tintGreen),
      tintBlue: mix(tintBlue, other.tintBlue),
      tintRed: mix(tintRed, other.tintRed),
      error: mix(error, other.error),
      success: mix(success, other.success),
      shadow: mix(shadow, other.shadow),
    );
  }
}

extension AppColorsContext on BuildContext {
  /// ألوان التصميم للسمة الحالية.
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
