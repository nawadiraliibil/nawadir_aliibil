import 'package:flutter/material.dart';

/// خطوط التصميم المعتمد: Tajawal للنص، وReadex Pro للعناوين والأسعار
/// والأرقام الكبيرة. الخطان مضمّنان في `assets/fonts/`.
abstract final class AppTypography {
  static const String body = 'Tajawal';
  static const String display = 'ReadexPro';

  /// أصغر حجم نص في التطبيق. المعرض ينزل إلى 9–11 بكسل في مواضع؛ تُرفع
  /// هنا للوفاء بـAD-NFR-001.
  static const double minFontSize = 12;

  /// نمط بخط العناوين. Readex Pro خط متغير، فيُضبط محور الوزن صراحة.
  static TextStyle displayStyle({
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w600,
    double height = 1.4,
  }) {
    return TextStyle(
      fontFamily: display,
      fontFamilyFallback: const [body],
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      height: height,
      letterSpacing: 0,
      color: color,
    );
  }

  static TextStyle bodyStyle({
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w400,
    double height = 1.65,
  }) {
    return TextStyle(
      fontFamily: body,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: 0,
      color: color,
    );
  }

  static TextTheme textTheme({required Color text, required Color muted}) {
    return TextTheme(
      // السعر في التفاصيل والأرقام الكبيرة.
      displaySmall: displayStyle(size: 28, color: text),
      // عنوان الصفحة h1.
      headlineSmall: displayStyle(size: 22, color: text, height: 1.6),
      // عنوان الترويسة.
      titleLarge: displayStyle(size: 18, color: text, height: 1.5),
      // عنوان القسم h2.
      titleMedium: displayStyle(size: 17, color: text, height: 1.6),
      // عنوان البطاقة والعنصر.
      titleSmall: bodyStyle(size: 16, color: text, weight: FontWeight.w700),
      bodyLarge: bodyStyle(size: 16, color: text),
      // النص الأساسي: 15 بكسل وارتفاع سطر 1.65.
      bodyMedium: bodyStyle(size: 15, color: text),
      bodySmall: bodyStyle(size: 13, color: muted, height: 1.7),
      // نص الأزرار.
      labelLarge: bodyStyle(
        size: 15,
        color: text,
        weight: FontWeight.w700,
        height: 1.45,
      ),
      // الشرائح وتسميات الحقول.
      labelMedium: bodyStyle(
        size: 13,
        color: text,
        weight: FontWeight.w500,
        height: 1.5,
      ),
      // الشارات وتسميات التنقل.
      labelSmall: bodyStyle(
        size: minFontSize,
        color: muted,
        weight: FontWeight.w700,
        height: 1.6,
      ),
    );
  }
}
