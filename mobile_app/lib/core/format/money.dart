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

/// ساعة ودقيقة بنظام 12 ساعة: «6:30 م». [t] محوَّل مسبقًا للتوقيت المطلوب.
String _clock12(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final suffix = t.hour < 12 ? 'ص' : 'م';
  return '$h:${t.minute.toString().padLeft(2, '0')} $suffix';
}

/// موعد بتوقيت السعودية (UTC+3) بصيغة «5/1/2099 6:30 م».
String formatSaudiMoment(DateTime utc) {
  final t = utc.toUtc().add(const Duration(hours: 3));
  return '${t.day}/${t.month}/${t.year} ${_clock12(t)}';
}

/// وقت قصير لقوائم المحادثات بتوقيت السعودية: «6:30 م» إن كان اليوم، وإلا «5/1».
String formatShortTime(DateTime utc, {DateTime? now}) {
  final t = utc.toUtc().add(const Duration(hours: 3));
  final n = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
  if (t.year == n.year && t.month == n.month && t.day == n.day) {
    return _clock12(t);
  }
  return '${t.day}/${t.month}';
}
