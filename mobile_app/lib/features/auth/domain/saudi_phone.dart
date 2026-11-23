import '../../../core/format/digits.dart';

/// رقم جوال سعودي مطبّع. الصيغة المخزنة هي الأرقام التسعة المحلية (5XXXXXXXX).
class SaudiPhone {
  const SaudiPhone._(this.national);

  /// تسعة أرقام تبدأ بـ5.
  final String national;

  /// الصيغة الدولية التي يستقبلها الخادم.
  String get e164 => '+966$national';

  /// الصيغة المحلية المعروضة: 05XXXXXXXX.
  String get local => '0$national';

  /// رقم مخفي للعرض: 05*****321.
  String get masked =>
      '${local.substring(0, 2)}*****${local.substring(local.length - 3)}';

  static final _nationalPattern = RegExp(r'^5\d{8}$');

  /// يقبل `5XXXXXXXX` و`05XXXXXXXX` و`9665XXXXXXXX` و`+9665XXXXXXXX` وأرقامًا
  /// عربية-هندية، مع مسافات وفواصل. يعيد `null` إن لم يكن رقمًا سعوديًا صالحًا.
  static SaudiPhone? tryParse(String input) {
    var digits = toWesternDigits(input).replaceAll(RegExp(r'[\s\-().]'), '');
    if (digits.startsWith('+')) digits = digits.substring(1);
    if (digits.startsWith('00966')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('966')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return _nationalPattern.hasMatch(digits) ? SaudiPhone._(digits) : null;
  }

  /// من الصيغة الدولية المخزنة، أو `null`.
  static SaudiPhone? fromE164(String e164) => tryParse(e164);

  @override
  bool operator ==(Object other) =>
      other is SaudiPhone && other.national == national;

  @override
  int get hashCode => national.hashCode;
}
