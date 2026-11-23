import 'package:flutter/widgets.dart';

/// أشكال وأبعاد التصميم المعتمد (الأسلوب المتمايز: كبسولات وزوايا واسعة).
abstract final class AppShapes {
  /// الصور وبلاطة التاريخ (`--r-img`).
  static const double image = 12;

  /// الشرائح.
  static const double chip = 10;

  /// حقول الإدخال.
  static const double field = 14;

  /// الملاحظات.
  static const double note = 16;

  /// البطاقات المملوءة والقوائم المجمعة.
  static const double card = 20;

  /// الحوارات.
  static const double dialog = 26;

  /// ورقة التفاصيل والأوراق السفلية.
  static const double sheet = 28;

  /// كبسولة التنقل وزر «إعلان».
  static const double nav = 30;

  /// هامش الشاشة الأفقي.
  static const double screenPadding = 16;

  /// أصغر هدف لمس. المعرض يستخدم 44 و48 وأحيانًا أقل؛ يوحَّد هنا للوفاء
  /// بـAD-NFR-001.
  static const double minTouchTarget = 48;

  static const BorderRadius imageRadius = BorderRadius.all(
    Radius.circular(image),
  );
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}
