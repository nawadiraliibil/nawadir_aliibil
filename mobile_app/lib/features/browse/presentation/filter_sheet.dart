import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/format/digits.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/settings/published_settings.dart';
import '../../../core/settings/settings_repository.dart';
import '../data/listing_card.dart';

/// صفحة التصفية (B03)؛ الترتيب في صفحة مستقلة (sort_sheet.dart). تعيد المرشحات الجديدة عند «عرض النتائج»،
/// أو null عند الرجوع دون تطبيق.
Future<SearchFilters?> showFilterSheet(
  BuildContext context,
  SearchFilters current,
) => Navigator.of(context, rootNavigator: true).push<SearchFilters>(
  MaterialPageRoute(builder: (_) => FilterSheet(initial: current)),
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
    final settings = ref.watch(publishedSettingsProvider).value;
    final lookups = settings?.lookups;
    final cities = (lookups != null && _f.regionId != null)
        ? lookups.citiesOf(_f.regionId!)
        : const <City>[];
    final pricing = _priceMin.text.isNotEmpty || _priceMax.text.isNotEmpty;
    final theme = Theme.of(context);
    // قيمة القائمة بوزن النص العادي لا بوزن العناوين.
    final valueStyle = theme.textTheme.bodyLarge;

    Widget gap([double h = 20]) => SizedBox(height: h);
    Widget chips(List<Widget> children) =>
        Wrap(spacing: 8, runSpacing: 8, children: children);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('تصفية الإعلانات'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  16 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  if (lookups == null)
                    Text(
                      'تعذّر تحميل قوائم المناطق والسلالات.',
                      style: theme.textTheme.bodyMedium,
                    )
                  else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Labeled(
                            label: 'المنطقة',
                            child: DropdownButtonFormField<int?>(
                              key: const ValueKey('filter-region'),
                              initialValue: _f.regionId,
                              isExpanded: true,
                              style: valueStyle,
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
                                () =>
                                    _f = _f.copyWith(regionId: v, cityId: null),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Labeled(
                            label: 'المدينة',
                            child: DropdownButtonFormField<int?>(
                              key: ValueKey('filter-city-${_f.regionId}'),
                              initialValue: _f.cityId,
                              isExpanded: true,
                              style: valueStyle,
                              decoration: InputDecoration(
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
                                  : (v) => setState(
                                      () => _f = _f.copyWith(cityId: v),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    gap(12),
                    _Labeled(
                      label: 'السلالة',
                      child: DropdownButtonFormField<int?>(
                        key: const ValueKey('filter-breed'),
                        initialValue: _f.breedId,
                        isExpanded: true,
                        style: valueStyle,
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
                    ),
                  ],
                  gap(),
                  const SectionTitle('الجنس'),
                  gap(10),
                  chips([
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
                  ]),
                  gap(),
                  const SectionTitle('نوع العرض'),
                  gap(10),
                  chips([
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
                      key: const ValueKey('sheet-type-auction'),
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
                  ]),
                  gap(),
                  const SectionTitle('العمر · بالأشهر'),
                  gap(10),
                  _RangeRow(
                    minController: _ageMin,
                    maxController: _ageMax,
                    minKey: const ValueKey('filter-age-min'),
                    maxKey: const ValueKey('filter-age-max'),
                    error: _ageError,
                  ),
                  gap(),
                  const SectionTitle('السعر · ريال'),
                  gap(10),
                  _RangeRow(
                    minController: _priceMin,
                    maxController: _priceMax,
                    minKey: const ValueKey('filter-price-min'),
                    maxKey: const ValueKey('filter-price-max'),
                    error: _priceError,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'تحديد السعر يستبعد المزادات.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            // خط رفيع يفصل شريط الأزرار عن المحتوى المتحرك فوقه.
            Divider(height: 1, color: context.colors.hair),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _apply,
                      child: const Text('عرض النتائج'),
                    ),
                  ),
                  TextButton(onPressed: _clear, child: const Text('مسح الكل')),
                ],
              ),
            ),
          ],
        ),
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
        decoration: InputDecoration(hintText: label),
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

/// حقل بتسمية ثابتة فوقه، بدل التسمية العائمة التي تركب حافة الحقل.
class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        child,
      ],
    );
  }
}
