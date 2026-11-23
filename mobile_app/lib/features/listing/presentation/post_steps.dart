import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/settings/published_settings.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/widgets/app_note.dart';
import '../../auth/domain/saudi_phone.dart';
import '../application/post_controller.dart';
import '../data/draft_form.dart';
import '../domain/draft_validation.dart';
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
      onContinue: () async {
        final t = state.form.offerType;
        if (t != null) await choose(t);
      },
      continueLabel: 'متابعة',
      onSaveDraft: state.form.offerType == null ? null : onSaveDraft,
      children: [
        _OfferCard(
          title: 'سعر محدد',
          subtitle: 'أدخل السعر المطلوب',
          icon: Icons.sell_outlined,
          selected: state.form.offerType == DraftForm.offerFixed,
          onTap: state.busy ? null : () => choose(DraftForm.offerFixed),
        ),
        const SizedBox(height: 12),
        _OfferCard(
          title: 'مزاد حضوري',
          subtitle: 'حدد المكان والموعد',
          icon: Icons.gavel_outlined,
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
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$title، $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppShapes.card),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? c.tintGold : c.soft,
            borderRadius: BorderRadius.circular(AppShapes.card),
            border: Border.all(
              color: selected ? c.gold : c.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: c.gold),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
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
        DraftDropdown<String>(
          label: 'الجنس',
          value: f.sex,
          items: const {'MALE': 'ذكر', 'FEMALE': 'أنثى'},
          error: errorOf(errors, 'sex'),
          onChanged: (v) => post.set('sex', v),
        ),
        DraftTextField(
          controller: _age,
          label: 'العمر · شهر',
          hint: '36',
          keyboardType: TextInputType.number,
          ltr: true,
          error: errorOf(errors, 'age_months'),
          onChanged: (v) => post.set('age_months', DraftValidation.parseInt(v)),
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
        Row(
          children: [
            Expanded(
              child: _PickerField(
                label: 'التاريخ',
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

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppShapes.field),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          value ?? 'اختر',
          style: value == null ? TextStyle(color: context.colors.muted) : null,
        ),
      ),
    );
  }
}

/// D08 — رقم التواصل. رقم واحد بقناتين: اتصال وواتساب.
class ContactStep extends ConsumerStatefulWidget {
  const ContactStep({super.key, required this.onSaveDraft});

  final Future<void> Function() onSaveDraft;

  @override
  ConsumerState<ContactStep> createState() => _ContactStepState();
}

class _ContactStepState extends _StepState<ContactStep> {
  final _phone = TextEditingController();

  static String _display(String? stored) =>
      stored == null ? '' : SaudiPhone.tryParse(stored)?.local ?? stored;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(postControllerProvider).form;
    _phone.text = _display(initial.contactPhone);
    // قناة الاتصال مفعلة افتراضيًا في إعلان جديد.
    final f = ref.read(postControllerProvider).form;
    if (f.contactPhone == null && !f.callEnabled && !f.whatsappEnabled) {
      Future(() => post.set('contact_call_enabled', true));
    }
  }

  @override
  void dispose() {
    _phone.dispose();
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
          controller: _phone,
          label: 'رقم الجوال',
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('اتصال هاتفي'),
          value: f.callEnabled,
          onChanged: (v) => post.set('contact_call_enabled', v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('واتساب'),
          value: f.whatsappEnabled,
          onChanged: (v) => post.set('contact_whatsapp_enabled', v),
        ),
        if (errorOf(errors, 'contact_channels') case final msg?)
          AppNote(msg, kind: AppNoteKind.error),
        const SizedBox(height: 8),
        const AppNote(
          'الرقم الذي تدخله سيظهر في الإعلان لمن يشاهده. لا يُؤخذ رقم دخولك تلقائيًا.',
        ),
      ],
    );
  }
}
