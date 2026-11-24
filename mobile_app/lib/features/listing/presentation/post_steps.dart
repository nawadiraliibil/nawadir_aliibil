import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/location/map_widgets.dart';
import '../../../core/settings/published_settings.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/widgets/app_note.dart';
import '../../auth/domain/saudi_phone.dart';
import '../application/post_controller.dart';
import '../data/draft_form.dart';
import '../domain/draft_validation.dart';
import 'location_picker_screen.dart';
import 'step_widgets.dart';

/// أساس الخطوات: الوصول إلى المتحكم والإعدادات المنشورة.
abstract class _StepState<W extends ConsumerStatefulWidget>
    extends ConsumerState<W>
    with StepErrors<W> {
  PostController get post => ref.read(postControllerProvider.notifier);
  DraftForm get form => ref.watch(postControllerProvider).form;
  PublishedSettings get settings => ref.watch(publishedSettingsProvider).value!;

  /// يتحقق ثم يحفظ [keys] ثم ينتقل إلى [next].
  Future<void> advance(
    FieldErrors errors,
    Set<String> keys,
    PostStep next,
  ) async {
    if (!check(errors)) return;
    if (await post.save(keys)) post.goTo(next);
  }
}

/// D01 — نوع العرض. اختيار النوع يحفظه وينتقل.
class OfferStep extends ConsumerWidget {
  const OfferStep({super.key, required this.onSaveDraft});

  final Future<void> Function() onSaveDraft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(postControllerProvider);
    final post = ref.read(postControllerProvider.notifier);

    Future<void> choose(String type) async {
      post.setOfferType(type);
      if (await post.save(DraftKeys.offer)) post.goTo(PostStep.data);
    }

    return StepFrame(
      // اختيار البطاقة هو المتابعة (D01).
      onContinue: null,
      onSaveDraft: state.form.offerType == null ? null : onSaveDraft,
      children: [
        _OfferCard(
          title: 'سعر محدد',
          subtitle: 'أدخل السعر المطلوب',
          icon: Icons.sell_outlined,
          tint: DraftForm.offerFixed,
          selected: state.form.offerType == DraftForm.offerFixed,
          onTap: state.busy ? null : () => choose(DraftForm.offerFixed),
        ),
        const SizedBox(height: 12),
        _OfferCard(
          title: 'مزاد حضوري',
          subtitle: 'حدد المكان والموعد',
          icon: Icons.schedule_outlined,
          tint: DraftForm.offerAuction,
          selected: state.form.offerType == DraftForm.offerAuction,
          onTap: state.busy ? null : () => choose(DraftForm.offerAuction),
        ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// نوع العرض؛ يحدد لون مربع الأيقونة (ذهبي للسعر، أزرق للمزاد).
  final String tint;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final auction = tint == DraftForm.offerAuction;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title، $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: c.soft,
        borderRadius: BorderRadius.circular(AppShapes.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppShapes.card),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppShapes.card),
              border: selected ? Border.all(color: c.gold, width: 2) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: auction ? c.tintBlue : c.tintGold,
                    borderRadius: BorderRadius.circular(AppShapes.field),
                  ),
                  child: Icon(icon, color: auction ? c.info : c.gold),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: c.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// D02 — بيانات الإبل.
class DataStep extends ConsumerStatefulWidget {
  const DataStep({super.key, required this.onSaveDraft});

  final Future<void> Function() onSaveDraft;

  @override
  ConsumerState<DataStep> createState() => _DataStepState();
}

class _DataStepState extends _StepState<DataStep> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _age = TextEditingController();
  final _color = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = ref.read(postControllerProvider).form;
    _title.text = initial.title ?? '';
    _note.text = initial.breedNote ?? '';
    _age.text = initial.ageMonths?.toString() ?? '';
    _color.text = initial.color ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _age.dispose();
    _color.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = form;
    final errors = DraftValidation.data(f, settings);
    final breed = settings.lookups.breed(f.breedId);
    return StepFrame(
      onContinue: () => advance(errors, DraftKeys.data, PostStep.description),
      onSaveDraft: widget.onSaveDraft,
      children: [
        DraftTextField(
          controller: _title,
          label: 'عنوان الإعلان',
          hint: 'مثال: ناقة وضح أصيلة',
          maxLength: settings.listing.titleMax,
          error: errorOf(errors, 'title'),
          onChanged: (v) => post.set('title', v),
        ),
        DraftDropdown<int>(
          label: 'السلالة',
          value: f.breedId,
          items: {for (final b in settings.lookups.breeds) b.id: b.nameAr},
          error: errorOf(errors, 'breed_id'),
          onChanged: (v) {
            final needsNote = settings.lookups.breed(v)?.requiresNote ?? false;
            if (!needsNote) _note.clear();
            post.setAll({'breed_id': v, if (!needsNote) 'breed_note': null});
          },
        ),
        if (breed?.requiresNote ?? false)
          DraftTextField(
            controller: _note,
            label: 'اسم السلالة',
            maxLength: DraftValidation.breedNoteMax,
            error: errorOf(errors, 'breed_note'),
            onChanged: (v) => post.set('breed_note', v),
          ),
        // الجنس والعمر جنبًا إلى جنب (D02)، وفي عمود عند تكبير النص.
        LayoutBuilder(
          builder: (context, box) {
            final sex = DraftDropdown<String>(
              label: 'الجنس',
              value: f.sex,
              items: const {'MALE': 'ذكر', 'FEMALE': 'أنثى'},
              error: errorOf(errors, 'sex'),
              onChanged: (v) => post.set('sex', v),
            );
            final age = DraftTextField(
              controller: _age,
              label: 'العمر · شهر',
              hint: '36',
              keyboardType: TextInputType.number,
              ltr: true,
              error: errorOf(errors, 'age_months'),
              onChanged: (v) =>
                  post.set('age_months', DraftValidation.parseInt(v)),
            );
            final stacked = MediaQuery.textScalerOf(context).scale(14) > 18;
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [sex, age],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: sex),
                const SizedBox(width: 12),
                Expanded(child: age),
              ],
            );
          },
        ),
        DraftTextField(
          controller: _color,
          label: 'اللون · اختياري',
          hint: 'وضح',
          maxLength: DraftValidation.colorMax,
          error: errorOf(errors, 'color'),
          onChanged: (v) =>
              post.set('color', v.trim().isEmpty ? null : v.trim()),
        ),
      ],
    );
  }
}

/// D03 — الوصف والحالة الصحية.
class DescriptionStep extends ConsumerStatefulWidget {
  const DescriptionStep({super.key, required this.onSaveDraft});

  final Future<void> Function() onSaveDraft;

  @override
  ConsumerState<DescriptionStep> createState() => _DescriptionStepState();
}

class _DescriptionStepState extends _StepState<DescriptionStep> {
  final _description = TextEditingController();
  final _health = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = ref.read(postControllerProvider).form;
    _description.text = initial.description ?? '';
    _health.text = initial.healthNotes ?? '';
  }

  @override
  void dispose() {
    _description.dispose();
    _health.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errors = DraftValidation.description(form, settings);
    return StepFrame(
      onContinue: () =>
          advance(errors, DraftKeys.description, PostStep.location),
      onSaveDraft: widget.onSaveDraft,
      children: [
        DraftTextField(
          controller: _description,
          label: 'الوصف',
          hint: 'أهم معلومات الإبل',
          maxLines: 6,
          maxLength: settings.listing.descriptionMax,
          error: errorOf(errors, 'description'),
          onChanged: (v) => post.set('description', v),
        ),
        DraftTextField(
          controller: _health,
          label: 'الحالة الصحية والعيوب',
          hint: 'مثال: لا توجد عيوب معروفة',
          maxLines: 3,
          maxLength: DraftValidation.healthNotesMax,
          error: errorOf(errors, 'health_notes'),
          onChanged: (v) => post.set('health_notes', v),
        ),
      ],
    );
  }
}

/// D04 — موقع الإعلان.
class LocationStep extends ConsumerStatefulWidget {
  const LocationStep({super.key, required this.onSaveDraft});

  final Future<void> Function() onSaveDraft;

  @override
  ConsumerState<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends _StepState<LocationStep> {
  @override
  Widget build(BuildContext context) {
    final f = form;
    final errors = DraftValidation.location(f, settings);
    return StepFrame(
      onContinue: () => advance(errors, DraftKeys.location, PostStep.details),
      onSaveDraft: widget.onSaveDraft,
      children: [
        _PlacePickers(
          lookups: settings.lookups,
          regionId: f.regionId,
          cityId: f.cityId,
          regionKey: 'region_id',
          cityKey: 'city_id',
          regionError: errorOf(errors, 'region_id'),
          cityError: errorOf(errors, 'city_id'),
          onChanged: post.setAll,
        ),
      ],
    );
  }
}

/// منطقة ثم مدينتها. تغيير المنطقة يمسح المدينة.
class _PlacePickers extends StatelessWidget {
  const _PlacePickers({
    required this.lookups,
    required this.regionId,
    required this.cityId,
    required this.regionKey,
    required this.cityKey,
    required this.onChanged,
    this.regionError,
    this.cityError,
  });

  final Lookups lookups;
  final int? regionId;
  final int? cityId;
  final String regionKey;
  final String cityKey;
  final String? regionError;
  final String? cityError;
  final void Function(Map<String, Object?>) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DraftDropdown<int>(
          label: 'المنطقة',
          value: regionId,
          items: {for (final r in lookups.regions) r.id: r.nameAr},
          error: regionError,
          onChanged: (v) => onChanged({regionKey: v, cityKey: null}),
        ),
        DraftDropdown<int>(
          // مفتاح يعيد بناء القائمة عند تغير المنطقة فتفرغ المدينة المختارة.
          key: ValueKey('city-$regionId'),
          label: 'المدينة',
          value: cityId,
          items: regionId == null
              ? const {}
              : {for (final c in lookups.citiesOf(regionId!)) c.id: c.nameAr},
          error: cityError,
          onChanged: (v) => onChanged({cityKey: v}),
        ),
      ],
    );
  }
}

/// D05 — السعر، أو D06 — موعد ومكان المزاد، بحسب نوع العرض.
class DetailsStep extends ConsumerStatefulWidget {
  const DetailsStep({super.key, required this.onSaveDraft, this.now});

  final Future<void> Function() onSaveDraft;

  /// الوقت الحالي للتحقق من مستقبلية الموعد؛ يُحقن في الاختبارات.
  final DateTime Function()? now;

  @override
  ConsumerState<DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends _StepState<DetailsStep> {
  final _price = TextEditingController();
  final _venue = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = ref.read(postControllerProvider).form;
    _price.text = initial.price?.toString() ?? '';
    _venue.text = initial.auctionVenue ?? '';
  }

  @override
  void dispose() {
    _price.dispose();
    _venue.dispose();
    super.dispose();
  }

  DateTime _now() => (widget.now ?? DateTime.now)().toUtc();

  @override
  Widget build(BuildContext context) {
    final f = form;
    return f.isAuction ? _auction(context, f) : _fixed(context, f);
  }

  Widget _fixed(BuildContext context, DraftForm f) {
    final errors = DraftValidation.price(f);
    return StepFrame(
      onContinue: () => advance(errors, DraftKeys.price, PostStep.media),
      onSaveDraft: widget.onSaveDraft,
      children: [
        DraftTextField(
          controller: _price,
          label: 'السعر المطلوب · ريال',
          hint: '48,000',
          help: 'أدخل مبلغًا موجبًا.',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ltr: true,
          error: errorOf(errors, 'price'),
          onChanged: (v) => post.set('price', DraftValidation.parsePrice(v)),
        ),
      ],
    );
  }

  Widget _auction(BuildContext context, DraftForm f) {
    final errors = DraftValidation.auction(f, settings, _now());
    // الموعد المعروض بتوقيت السعودية (UTC+3).
    final local = f.auctionStartsAt?.add(const Duration(hours: 3));
    return StepFrame(
      onContinue: () => advance(errors, DraftKeys.auction, PostStep.media),
      onSaveDraft: widget.onSaveDraft,
      children: [
        _PlacePickers(
          lookups: settings.lookups,
          regionId: f.auctionRegionId,
          cityId: f.auctionCityId,
          regionKey: 'auction_region_id',
          cityKey: 'auction_city_id',
          regionError: errorOf(errors, 'auction_region_id'),
          cityError: errorOf(errors, 'auction_city_id'),
          onChanged: post.setAll,
        ),
        DraftTextField(
          controller: _venue,
          label: 'مكان المزاد',
          hint: 'اسم المكان أو العنوان',
          maxLines: 2,
          maxLength: DraftValidation.venueMax,
          error: errorOf(errors, 'auction_venue'),
          onChanged: (v) => post.set('auction_venue', v),
        ),
        _AuctionLocationField(
          lat: f.auctionLat,
          lng: f.auctionLng,
          error:
              errorOf(errors, 'auction_location') ??
              errorOf(errors, 'auction_lat') ??
              errorOf(errors, 'auction_lng'),
          onPicked: (p) => post.setAll({
            'auction_lat': p.latitude,
            'auction_lng': p.longitude,
          }),
        ),
        Row(
          children: [
            Expanded(
              child: _PickerField(
                label: 'التاريخ',
                icon: Icons.calendar_today_outlined,
                value: local == null
                    ? null
                    : '${local.day}/${local.month}/${local.year}',
                onTap: () => _pickDate(local),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PickerField(
                label: 'الوقت',
                icon: Icons.schedule_outlined,
                value: local == null
                    ? null
                    : '${local.hour.toString().padLeft(2, '0')}:'
                          '${local.minute.toString().padLeft(2, '0')}',
                onTap: () => _pickTime(local),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            errorOf(errors, 'auction_starts_at') ?? 'بتوقيت السعودية',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: errorOf(errors, 'auction_starts_at') != null
                  ? context.colors.error
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(DateTime? local) async {
    final today = _now().add(const Duration(hours: 3));
    final picked = await showDatePicker(
      context: context,
      initialDate: local ?? today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 2),
    );
    if (picked == null) return;
    _setMoment(picked, local?.hour ?? 9, local?.minute ?? 0);
  }

  Future<void> _pickTime(DateTime? local) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: local?.hour ?? 9,
        minute: local?.minute ?? 0,
      ),
    );
    if (picked == null) return;
    final base = local ?? _now().add(const Duration(hours: 3));
    _setMoment(base, picked.hour, picked.minute);
  }

  void _setMoment(DateTime date, int hour, int minute) => post.set(
    'auction_starts_at',
    DraftValidation.auctionMoment(date, hour, minute),
  );
}

/// الموقع الدقيق للمزاد: زر يفتح الخريطة، وبعد الاختيار معاينة مصغرة قابلة للتعديل.
class _AuctionLocationField extends StatelessWidget {
  const _AuctionLocationField({
    required this.lat,
    required this.lng,
    required this.error,
    required this.onPicked,
  });

  final double? lat;
  final double? lng;
  final String? error;
  final ValueChanged<LatLng> onPicked;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final point = lat != null && lng != null ? LatLng(lat!, lng!) : null;

    Future<void> pick() async {
      final picked = await Navigator.of(context).push<LatLng>(
        MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: point)),
      );
      if (picked != null) onPicked(picked);
    }

    return LabeledField(
      label: 'الموقع الدقيق على الخريطة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (point == null)
            OutlinedButton.icon(
              key: const ValueKey('pick-location'),
              onPressed: pick,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('تحديد الموقع على الخريطة'),
            )
          else ...[
            MiniMap(
              key: const ValueKey('location-preview'),
              point: point,
              onTap: pick,
            ),
            TextButton.icon(
              key: const ValueKey('edit-location'),
              onPressed: pick,
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: const Text('تعديل الموقع'),
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                error!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LabeledField(
      label: label,
      child: Material(
        color: c.soft,
        borderRadius: BorderRadius.circular(AppShapes.field),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppShapes.field),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppShapes.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value ?? 'اختر',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: value == null ? c.muted : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 18, color: c.text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// D08 — رقم التواصل: رقم اتصال ورقم واتساب مستقلان، ويلزم أحدهما (TEAM-DEC-012).
class ContactStep extends ConsumerStatefulWidget {
  const ContactStep({super.key, required this.onSaveDraft});

  final Future<void> Function() onSaveDraft;

  @override
  ConsumerState<ContactStep> createState() => _ContactStepState();
}

class _ContactStepState extends _StepState<ContactStep> {
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();

  static String _display(String? stored) =>
      stored == null ? '' : SaudiPhone.tryParse(stored)?.local ?? stored;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(postControllerProvider).form;
    _phone.text = _display(initial.contactPhone);
    _whatsapp.text = _display(initial.whatsappPhone);
  }

  @override
  void dispose() {
    _phone.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = form;
    final errors = DraftValidation.contact(f);
    return StepFrame(
      onContinue: () => advance(errors, DraftKeys.contact, PostStep.preview),
      continueLabel: 'معاينة الإعلان',
      onSaveDraft: widget.onSaveDraft,
      children: [
        DraftTextField(
          key: const ValueKey('contact-call-field'),
          controller: _phone,
          label: 'رقم الاتصال',
          hint: '5X XXX XXXX',
          keyboardType: TextInputType.phone,
          ltr: true,
          prefix: '+966 · ',
          error: errorOf(errors, 'contact_phone'),
          onChanged: (v) {
            final parsed = SaudiPhone.tryParse(v);
            post.set('contact_phone', parsed?.local ?? (v.isEmpty ? null : v));
          },
        ),
        DraftTextField(
          key: const ValueKey('contact-whatsapp-field'),
          controller: _whatsapp,
          label: 'رقم واتساب',
          hint: '5X XXX XXXX',
          keyboardType: TextInputType.phone,
          ltr: true,
          prefix: '+966 · ',
          error: errorOf(errors, 'contact_whatsapp_phone'),
          onChanged: (v) {
            final parsed = SaudiPhone.tryParse(v);
            post.set(
              'contact_whatsapp_phone',
              parsed?.local ?? (v.isEmpty ? null : v),
            );
          },
        ),
        if (errorOf(errors, 'contact_channels') case final msg?) ...[
          const SizedBox(height: 8),
          AppNote(msg, kind: AppNoteKind.error),
        ],
        const SizedBox(height: 16),
        const AppNote(
          'الأرقام التي تدخلها ستظهر في الإعلان لمن يشاهده. الرقمان مستقلان: يمكن أن يختلف رقم واتساب عن رقم الاتصال، ويكفي أحدهما. لا يُؤخذ رقم دخولك تلقائيًا.',
        ),
      ],
    );
  }
}
