import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// موقع الجهاز الحالي. تُستبدل في الاختبارات؛ الافتراضي يطلب إذن
/// «أثناء الاستخدام» مرة ويعيد `null` عند الرفض أو تعطل الخدمة.
typedef DeviceLocator = Future<LatLng?> Function({bool askPermission});

Future<LatLng?> _geolocate({bool askPermission = true}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied && askPermission) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    // آخر موقع معروف يكفي للمسافة التقريبية ويجيب فورًا.
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return LatLng(last.latitude, last.longitude);
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return LatLng(p.latitude, p.longitude);
  } on Object {
    return null;
  }
}

final deviceLocatorProvider = Provider<DeviceLocator>((ref) => _geolocate);

/// موقع المتصفح لحساب بعد المزادات عنه. يحمل مرة لكل جلسة؛ `null` يعني
/// أن المسافة لا تعرض.
final browserLocationProvider = FutureProvider<LatLng?>(
  (ref) => ref.read(deviceLocatorProvider)(askPermission: true),
);

/// المسافة بالكيلومتر على سطح الأرض (هافرساين).
double distanceKm(LatLng a, LatLng b) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

/// «850 م» دون كيلومتر، و«3.2 كم» حتى 10، ثم كيلومترات صحيحة.
String formatDistance(double km) {
  if (km < 1) return '${(km * 1000).round().clamp(10, 999)} م';
  if (km < 10) return '${km.toStringAsFixed(1)} كم';
  return '${km.round()} كم';
}
