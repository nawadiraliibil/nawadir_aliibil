import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/digits.dart';
import '../../../core/settings/published_settings.dart';
import '../../../core/settings/settings_repository.dart';
import '../data/listing_card.dart';

/// ورقة المرشحات والفرز (B04). تعيد المرشحات الجديدة عند «تطبيق»، أو `null`
/// عند الإغلاق دون تطبيق.
Future<SearchFilters?> showFilterSheet(
  BuildContext context,
  SearchFilters current,
) => showModalBottomSheet<SearchFilters>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => FilterSheet(initial: current),
);

class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key, required this.initial});

  final SearchFilters initial;

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late SearchFilters _f = widget.initial;
  late final _ageMin = TextEditingController(text: _text(_f.ageMin));
  late final _ageMax = TextEditingController(text: _text(_f.ageMax));
  late final _priceMin = TextEditingController(text: _text(_f.priceMin));
  late final _priceMax = TextEditingController(text: _text(_f.priceMax));
  String? _ageError;
  String? _priceError;

  static String _text(num? n) => n == null ? '' : n.toString();

  @override
  void dispose() {
    _ageMin.dispose();
    _ageMax.dispose();
    _priceMin.dispose();
    _priceMax.dispose();
    super.dispose();
  }

  num? _num(TextEditingController c) =>
      num.tryParse(toWesternDigits(c.text.trim()));

  void _clear() {
    setState(() {
      _f = SearchFilters(query: _f.query);
      for (final c in [_ageMin, _ageMax, _priceMin, _priceMax]) {
        c.clear();
      }
      _ageError = null;
      _priceError = null;
    });
  }

  void _apply() {
    final ageMin = _num(_ageMin)?.toInt();
    final ageMax = _num(_ageMax)?.toInt();
    final priceMin = _num(_priceMin);
    final priceMax = _num(_priceMax);
    // التحقق المحلي يطابق الخادم: لا سالب ولا نطاق معكوس.
    String? ageError;
    if ((ageMin != null && ageMin < 0) || (ageMax != null && ageMax < 0)) {
      ageError = 'العمر لا يكون سالبًا.';
    } else if (ageMin != null && ageMax != null && ageMin > ageMax) {
      ageError = 'الحد الأدنى للعمر أكبر من الأعلى.';
    }
    String? priceError;
    if ((priceMin != null && priceMin < 0) ||
        (priceMax != null && priceMax < 0)) {
      priceError = 'السعر لا يكون سالبًا.';
    } else if (priceMin != null && priceMax != null && priceMin > priceMax) {
      priceError = 'الحد الأدنى للسعر أكبر من الأعلى.';
    }
    if (ageError != null || priceError != null) {
      setState(() {
        _ageError = ageError;
        _priceError = priceError;
      });
      return;
    }
    // نطاق السعر يستبعد المزادات؛ فلا يجتمع مع نوع «مزاد».
    final offer =
        (priceMin != null || priceMax != null) &&
            _f.offerType == 'IN_PERSON_AUCTION'
        ? null
        : _f.offerType;
    Navigator.of(context).pop(
      _f.copyWith(
        ageMin: ageMin,
        ageMax: ageMax,
        priceMin: priceMin,
        priceMax: priceMax,
        offerType: offer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(publishedSettingsProvider).value;
    final lookups = settings?.lookups;
    final cities = (lookups != null && _f.regionId != null)
        ? lookups.citiesOf(_f.regionId!)
        : const <City>[];
    final pricing = _priceMin.text.isNotEmpty || _priceMax.text.isNotEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'المرشحات والفرز',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: _clear,
                      child: const Text('مسح الكل'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('الفرز', style: theme.textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in SearchSort.values)
                      ChoiceChip(
                        label: Text(s.label),
                        selected: _f.sort == s,
                        onSelected: (_) =>
                            setState(() => _f = _f.copyWith(sort: s)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('نوع العرض', style: theme.textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('الكل'),
                      selected: _f.offerType == null,
                      onSelected: (_) =>
                          setState(() => _f = _f.copyWith(offerType: null)),
                    ),
                    ChoiceChip(
                      label: const Text('سعر محدد'),
                      selected: _f.offerType == 'FIXED_PRICE',
                      onSelected: (_) => setState(
                        () => _f = _f.copyWith(offerType: 'FIXED_PRICE'),
                      ),
                    ),
                    ChoiceChip(
                      label: const Text('مزاد حضوري'),
                      selected: _f.offerType == 'IN_PERSON_AUCTION',
                      onSelected: pricing
                          ? null
                          : (_) => setState(
                              () => _f = _f.copyWith(
                                offerType: 'IN_PERSON_AUCTION',
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('الجنس', style: theme.textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('الكل'),
                      selected: _f.sex == null,
                      onSelected: (_) =>
                          setState(() => _f = _f.copyWith(sex: null)),
                    ),
                    ChoiceChip(
                      label: const Text('ذكر'),
                      selected: _f.sex == 'MALE',
                      onSelected: (_) =>
                          setState(() => _f = _f.copyWith(sex: 'MALE')),
                    ),
                    ChoiceChip(
                      label: const Text('أنثى'),
                      selected: _f.sex == 'FEMALE',
                      onSelected: (_) =>
                          setState(() => _f = _f.copyWith(sex: 'FEMALE')),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (lookups == null)
                  Text(
                    'تعذّر تحميل قوائم المناطق والسلالات.',
                    style: theme.textTheme.bodyMedium,
                  )
                else ...[
                  DropdownButtonFormField<int?>(
                    key: const ValueKey('filter-region'),
                    initialValue: _f.regionId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'المنطقة'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('كل المناطق'),
                      ),
                      for (final r in lookups.regions)
                        DropdownMenuItem<int?>(
                          value: r.id,
                          child: Text(r.nameAr),
                        ),
                    ],
                    // تغيير المنطقة يمسح المدينة (تعرض مدن المنطقة فقط).
                    onChanged: (v) => setState(
                      () => _f = _f.copyWith(regionId: v, cityId: null),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    key: ValueKey('filter-city-${_f.regionId}'),
                    initialValue: _f.cityId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'المدينة',
                      helperText: _f.regionId == null
                          ? 'اختر المنطقة أولًا'
                          : null,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('كل المدن'),
                      ),
                      for (final c in cities)
                        DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.nameAr),
                        ),
                    ],
                    onChanged: _f.regionId == null
                        ? null
                        : (v) => setState(() => _f = _f.copyWith(cityId: v)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    key: const ValueKey('filter-breed'),
                    initialValue: _f.breedId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'السلالة'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('كل السلالات'),
                      ),
                      for (final b in lookups.breeds)
                        DropdownMenuItem<int?>(
                          value: b.id,
                          child: Text(b.nameAr),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _f = _f.copyWith(breedId: v)),
                  ),
                ],
                const SizedBox(height: 16),
                Text('العمر · شهر', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                _RangeRow(
                  minController: _ageMin,
                  maxController: _ageMax,
                  minKey: const ValueKey('filter-age-min'),
                  maxKey: const ValueKey('filter-age-max'),
                  error: _ageError,
                ),
                const SizedBox(height: 16),
                Text('السعر · ريال', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                _RangeRow(
                  minController: _priceMin,
                  maxController: _priceMax,
                  minKey: const ValueKey('filter-price-min'),
                  maxKey: const ValueKey('filter-price-max'),
                  error: _priceError,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 4),
                Text(
                  'تحديد نطاق سعر يستبعد إعلانات المزاد الحضوري لأنها بلا سعر.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _apply,
                  child: const Text('تطبيق'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeRow extends StatelessWidget {
  const _RangeRow({
    required this.minController,
    required this.maxController,
    required this.minKey,
    required this.maxKey,
    this.error,
    this.onChanged,
  });

  final TextEditingController minController;
  final TextEditingController maxController;
  final Key minKey;
  final Key maxKey;
  final String? error;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    Widget field(Key key, TextEditingController c, String label) => Expanded(
      child: TextField(
        key: key,
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => onChanged?.call(),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            field(minKey, minController, 'من'),
            const SizedBox(width: 12),
            field(maxKey, maxController, 'إلى'),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
