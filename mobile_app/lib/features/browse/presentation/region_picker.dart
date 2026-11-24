import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/settings/published_settings.dart';
import '../../../core/widgets/section_title.dart';

/// اختيار المنطقة والمدينة (B05).
typedef RegionChoice = ({int? regionId, int? cityId});

/// صفحة اختيار منطقة ثم مدينتها. تعيد الاختيار عند «تطبيق»، و`null` عند الرجوع.
/// تغيير المنطقة يمسح المدينة.
Future<RegionChoice?> showRegionPicker(
  BuildContext context, {
  required Lookups lookups,
  required int? regionId,
  required int? cityId,
}) => Navigator.of(context, rootNavigator: true).push<RegionChoice>(
  MaterialPageRoute(
    builder: (_) =>
        RegionPicker(lookups: lookups, regionId: regionId, cityId: cityId),
  ),
);

class RegionPicker extends StatefulWidget {
  const RegionPicker({
    super.key,
    required this.lookups,
    required this.regionId,
    required this.cityId,
  });

  final Lookups lookups;
  final int? regionId;
  final int? cityId;

  @override
  State<RegionPicker> createState() => _RegionPickerState();
}

class _RegionPickerState extends State<RegionPicker> {
  late int? _region = widget.regionId;
  late int? _city = widget.cityId;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final q = _query.trim();
    final regions = [
      for (final r in widget.lookups.regions)
        if (q.isEmpty || r.nameAr.contains(q)) r,
    ];
    final cities = _region == null
        ? const <City>[]
        : [
            for (final city in widget.lookups.citiesOf(_region!))
              if (q.isEmpty || city.nameAr.contains(q)) city,
          ];
    final regionName = widget.lookups.region(_region)?.nameAr;

    Widget radioRow(String label, bool selected, VoidCallback onTap) =>
        Semantics(
          inMutuallyExclusiveGroup: true,
          checked: selected,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppShapes.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected ? c.gold : c.muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(label)),
                  ],
                ),
              ),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('اختيار المنطقة والمدينة'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  TextField(
                    key: const ValueKey('region-search'),
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن منطقة أو مدينة',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionTitle('المنطقة'),
                  const SizedBox(height: 10),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.soft,
                      borderRadius: BorderRadius.circular(AppShapes.card),
                    ),
                    child: Column(
                      children: [
                        radioRow(
                          'كل المناطق',
                          _region == null,
                          () => setState(() {
                            _region = null;
                            _city = null;
                          }),
                        ),
                        for (final r in regions) ...[
                          Divider(height: 1, color: c.hair),
                          radioRow(
                            r.nameAr,
                            _region == r.id,
                            () => setState(() {
                              if (_region != r.id) _city = null;
                              _region = r.id;
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_region != null) ...[
                    const SizedBox(height: 20),
                    SectionTitle('المدينة · $regionName'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('كل المدن'),
                          selected: _city == null,
                          onSelected: (_) => setState(() => _city = null),
                        ),
                        for (final city in cities)
                          ChoiceChip(
                            label: Text(city.nameAr),
                            selected: _city == city.id,
                            onSelected: (_) => setState(() => _city = city.id),
                          ),
                      ],
                    ),
                  ],
                  if (regions.isEmpty && cities.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'لا نتائج مطابقة.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: c.hair),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('region-apply'),
                      onPressed: () => Navigator.of(
                        context,
                      ).pop<RegionChoice>((regionId: _region, cityId: _city)),
                      child: const Text('تطبيق'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop<RegionChoice>((regionId: null, cityId: null)),
                    child: const Text('مسح الاختيار'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
