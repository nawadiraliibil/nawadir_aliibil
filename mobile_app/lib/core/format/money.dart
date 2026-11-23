/// مبلغ بفواصل الآلاف: 48000 ← «48,000»، و1250.5 ← «1,250.50».
String formatMoney(num n) {
  final whole = n.truncate().toString();
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  if (n == n.truncate()) return grouped;
  return '$grouped.${n.toStringAsFixed(2).split('.').last}';
}

/// موعد بتوقيت السعودية (UTC+3) بصيغة «5/1/2099 18:30».
String formatSaudiMoment(DateTime utc) {
  final t = utc.toUtc().add(const Duration(hours: 3));
  return '${t.day}/${t.month}/${t.year} '
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
}

/// وقت قصير لقوائم المحادثات بتوقيت السعودية: «18:30» إن كان اليوم، وإلا «5/1».
String formatShortTime(DateTime utc, {DateTime? now}) {
  final t = utc.toUtc().add(const Duration(hours: 3));
  final n = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
  if (t.year == n.year && t.month == n.month && t.day == n.day) {
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }
  return '${t.day}/${t.month}';
}
