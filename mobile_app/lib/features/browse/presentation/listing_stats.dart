import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/location/location_service.dart';

/// عدد مختصر: 950 ← «950»، و1250 ← «1.2K»، و3,400,000 ← «3.4M».
String formatCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final k = n / 1000;
    return '${k < 10 ? k.toStringAsFixed(1) : k.round()}K'.replaceFirst(
      '.0K',
      'K',
    );
  }
  final m = n / 1000000;
  return '${m < 10 ? m.toStringAsFixed(1) : m.round()}M'.replaceFirst(
    '.0M',
    'M',
  );
}

/// أيقونة وعدد بنص واحد لقارئ الشاشة، مثل «12 إعجاب».
class StatLabel extends StatelessWidget {
  const StatLabel({
    super.key,
    required this.icon,
    required this.count,
    required this.noun,
    this.size = 15,
  });

  final IconData icon;
  final int count;

  /// «إعجاب» أو «مشاهدة» لقارئ الشاشة.
  final String noun;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$count $noun',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: size + 1, color: c.muted),
          const SizedBox(width: 3),
          Text(
            formatCount(count),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: c.muted, fontSize: size - 2),
          ),
        ],
      ),
    );
  }
}

/// «يبعد 3.2 كم عنك» لموقع المزاد؛ لا يظهر ما لم يعرف موقع المتصفح.
class DistanceLabel extends ConsumerWidget {
  const DistanceLabel({super.key, required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final here = ref.watch(browserLocationProvider).value;
    if (here == null) return const SizedBox.shrink();
    final c = context.colors;
    final text =
        'يبعد ${formatDistance(distanceKm(here, LatLng(lat, lng)))} عنك';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.near_me_outlined, size: 15, color: c.info),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: c.info,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
