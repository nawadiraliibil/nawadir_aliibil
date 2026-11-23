import '../../../core/format/money.dart';

String sexLabel(String sex) => sex == 'MALE' ? 'ذكر' : 'أنثى';

String _monthsPhrase(int m) => switch (m) {
  1 => 'شهر',
  2 => 'شهران',
  <= 10 => '$m أشهر',
  _ => '$m شهرًا',
};

String _yearsPhrase(int y) => switch (y) {
  1 => 'سنة',
  2 => 'سنتان',
  <= 10 => '$y سنوات',
  _ => '$y سنة',
};

/// عمر بالأشهر كما يُقرأ: «8 أشهر» و«سنتان» و«3 سنوات وشهران».
String ageLabel(int months) {
  if (months < 12) return _monthsPhrase(months);
  final years = months ~/ 12;
  final rest = months % 12;
  return rest == 0
      ? _yearsPhrase(years)
      : '${_yearsPhrase(years)} و${_monthsPhrase(rest)}';
}

/// سطر السعر أو المزاد في البطاقة والتفاصيل.
String offerLine({
  required bool isAuction,
  required num? price,
  required DateTime? auctionStartsAt,
  required bool auctionPassed,
}) {
  if (isAuction) {
    if (auctionPassed) return 'مزاد حضوري · مضى موعده';
    return auctionStartsAt == null
        ? 'مزاد حضوري'
        : 'مزاد حضوري · ${formatSaudiMoment(auctionStartsAt)}';
  }
  return price == null ? '' : '${formatMoney(price)} ريال';
}

/// رقم الاتصال بصيغة محلية للعرض: `+966500000009` ← `0500000009`.
String localPhone(String e164) =>
    e164.startsWith('+966') ? '0${e164.substring(4)}' : e164;
