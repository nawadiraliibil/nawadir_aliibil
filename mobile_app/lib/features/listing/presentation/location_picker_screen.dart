import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/location/location_service.dart';
import '../../../core/location/map_widgets.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/app_snack.dart';

/// اختيار موقع المزاد الدقيق: يحرك المعلن الخريطة فيبقى الدبوس في وسطها،
/// أو يبدأ بموقعه الحالي. يعيد النقطة المختارة أو `null` عند الإلغاء.
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  final LatLng? initial;

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _controller = MapController();
  late LatLng _center = widget.initial ?? defaultMapCenter;
  var _locating = false;

  @override
  void initState() {
    super.initState();
    // بلا موقع محفوظ: يبدأ من موقع المعلن إن أتاحه.
    if (widget.initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _useMyLocation());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    final messenger = ScaffoldMessenger.of(context);
    final at = await ref.read(deviceLocatorProvider)(askPermission: true);
    if (!mounted) return;
    setState(() => _locating = false);
    if (at == null) {
      messenger.showApp(
        'تعذر تحديد موقعك. فعّل خدمة الموقع وأذن للتطبيق، أو حرّك الخريطة يدويًا.',
        kind: AppNoteKind.info,
      );
      return;
    }
    _controller.move(at, 16);
    setState(() => _center = at);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('موقع المزاد')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: widget.initial == null ? 6 : 16,
              onPositionChanged: (camera, _) => _center = camera.center,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: baseMapLayers(),
          ),
          // الدبوس ثابت في الوسط؛ طرفه السفلي هو النقطة المختارة.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: MapPin(size: 44),
              ),
            ),
          ),
          PositionedDirectional(
            end: 12,
            bottom: 120,
            child: FloatingActionButton.small(
              key: const ValueKey('use-my-location'),
              tooltip: 'موقعي الحالي',
              heroTag: null,
              onPressed: _useMyLocation,
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(AppShapes.screenPadding),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppShapes.card),
                  border: Border.all(color: c.line),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'حرّك الخريطة حتى يستقر الدبوس على مكان المزاد بدقة.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      key: const ValueKey('confirm-location'),
                      onPressed: () => Navigator.of(context).pop(_center),
                      child: const Text('تأكيد الموقع'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
