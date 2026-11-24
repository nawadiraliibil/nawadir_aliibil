import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_shapes.dart';

/// وسط افتراضي (الرياض) حين لا موقع معروف.
const defaultMapCenter = LatLng(24.7136, 46.6753);

const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _tilePackage = 'com.nawadiraliibil.app';

/// طبقة الخريطة الأساسية (OpenStreetMap) مع الإسناد المطلوب لشروط الاستخدام.
List<Widget> baseMapLayers() => [
  TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _tilePackage),
  const RichAttributionWidget(
    alignment: AttributionAlignment.bottomLeft,
    attributions: [TextSourceAttribution('© مساهمو OpenStreetMap')],
  ),
];

/// دبوس الموقع.
class MapPin extends StatelessWidget {
  const MapPin({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.location_on, size: size, color: context.colors.error);
}

/// خريطة مصغرة ثابتة بدبوس على [point]؛ النقر يستدعي [onTap] (فتح الاتجاهات
/// أو التعديل). لا تفاعل بالسحب لئلا تعيق تمرير الصفحة.
class MiniMap extends StatelessWidget {
  const MiniMap({
    super.key,
    required this.point,
    this.height = 150,
    this.onTap,
    this.semanticLabel = 'موقع المزاد على الخريطة',
  });

  final LatLng point;
  final double height;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppShapes.card),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              ExcludeSemantics(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    ...baseMapLayers(),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 44,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: const MapPin(size: 44),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(onTap: onTap),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
