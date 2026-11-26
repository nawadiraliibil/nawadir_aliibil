import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/format/money.dart';
import '../../../core/location/map_widgets.dart';
import '../../../core/settings/published_settings.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/section_title.dart';
import '../../../core/widgets/wasm_ring.dart';
import '../../account/application/account_providers.dart';
import '../../auth/domain/saudi_phone.dart';
import '../../browse/domain/labels.dart';
import '../../browse/presentation/auction_widgets.dart';
import '../application/media_controller.dart';
import '../application/post_controller.dart';
import '../data/draft_form.dart';
import 'media_image.dart';
import 'step_widgets.dart';

/// الخطوة التي يُصلح فيها حقل رفضه الخادم عند الإرسال.
PostStep stepForField(String field) {
  switch (field) {
    case 'title' ||
        'breed_id' ||
        'breed_note' ||
        'sex' ||
        'age_months' ||
        'color':
      return PostStep.data;
    case 'description' || 'health_notes':
      return PostStep.description;
    case 'region_id' ||
        'city_id' ||
        'auction_region_id' ||
        'auction_city_id':
      return PostStep.location;
    case 'offer_type':
      return PostStep.offer;
    case 'price' ||
        'auction_venue' ||
        'auction_starts_at' ||
        'auction_lat' ||
        'auction_lng':
      return PostStep.details;
    case 'contact_phone' || 'contact_whatsapp_phone' || 'contact_channels':
      return PostStep.contact;
    case 'images' || 'media_ids' || 'cover_id':
      return PostStep.media;
    default:
      return PostStep.data;
  }
}

/// D09 / D10 — معاينة الإعلان، والإقرار، والنشر المباشر (TEAM-DEC-013).
class PreviewStep extends ConsumerStatefulWidget {
  const PreviewStep({super.key, required this.onSaveDraft});

  final Future<void> Function() onSaveDraft;

  @override
  ConsumerState<PreviewStep> createState() => _PreviewStepState();
}

class _PreviewStepState extends ConsumerState<PreviewStep> {
  /// الخطوات التي يجب إصلاحها بحسب رد الخادم، لعرض زر الانتقال إليها.
  List<PostStep> _fixSteps = const [];

  Future<void> _submit() async {
    final post = ref.read(postControllerProvider.notifier);
    setState(() => _fixSteps = const []);

    // حاجز الحساب: ملف ناقص أو نصوص لم يوافق عليها. الخادم يفرضه أيضًا.
    final account = await ref.read(myAccountProvider.future);
    if (!mounted) return;
    if (account != null && account.needsCompletion && !account.isSuspended) {
      final done = await context.push<bool>(Routes.accountComplete);
      if (done != true || !mounted) return;
    }

    if (await post.submit() || !mounted) return;
    final error = ref.read(postControllerProvider).error;
    if (error == null) return;
    switch (error.code) {
      case AppErrorCode.validationFailed:
        final fields = (error.details['fields'] as List? ?? const []).map(
          (e) => e.toString(),
        );
        setState(() {
          _fixSteps = {for (final f in fields) stepForField(f)}.toList()
            ..sort((a, b) => a.index.compareTo(b.index));
        });
      case AppErrorCode.mediaNotReady:
        setState(() => _fixSteps = const [PostStep.media]);
      case AppErrorCode.profileIncomplete || AppErrorCode.policiesNotAccepted:
        ref.invalidate(myAccountProvider);
        await context.push<bool>(Routes.accountComplete);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postControllerProvider);
    final post = ref.read(postControllerProvider.notifier);
    final form = state.form;
    final settings = ref.watch(publishedSettingsProvider).requireValue;
    final media = ref.watch(mediaControllerProvider);
    final account = ref.watch(myAccountProvider).value;
    final theme = Theme.of(context);
    final c = context.colors;
    final suspended = account?.isSuspended ?? false;
    final cover = media.items
        .where((i) => i.key == media.effectiveCoverKey)
        .firstOrNull;

    return StepFrame(
      onContinue: () async {
        if (!form.ownerDeclaration || suspended) return;
        await _submit();
      },
      continueLabel: 'نشر الإعلان',
      onSaveDraft: widget.onSaveDraft,
      children: [
        const AppNote('معاينة — هكذا سيظهر إعلانك.'),
        const SizedBox(height: 12),
        if (suspended) ...[
          const AppNote(
            'الحساب موقوف: النشر والتعديل غير متاحين حاليًا.',
            kind: AppNoteKind.error,
          ),
          const SizedBox(height: 12),
        ],
        if (cover != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppShapes.card),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: MediaImage(
                bytes: cover.bytes,
                bucket: cover.slot?.bucket,
                path: cover.slot?.objectPath,
              ),
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppBadge(
            label: form.isAuction ? 'مزاد حضوري' : 'سعر محدد',
            kind: form.isAuction
                ? AppBadgeKind.auction
                : AppBadgeKind.fixedPrice,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          form.title ?? '',
          style: AppTypography.displayStyle(
            size: 24,
            color: c.text,
            height: 1.4,
          ),
        ),
        if (!form.isAuction && form.price != null) ...[
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatMoney(form.price!),
                  style: AppTypography.displayStyle(
                    size: 28,
                    color: c.gold,
                    height: 1.3,
                  ),
                ),
                TextSpan(
                  text: ' ريال',
                  style: theme.textTheme.bodyMedium?.copyWith(color: c.text),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 16, color: c.muted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                _place(settings.lookups, form),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        if (form.isAuction) ..._auctionLines(context, settings.lookups, form),
        const SizedBox(height: 16),
        _SpecStrip(
          items: [
            ('السلالة', _breed(settings.lookups, form)),
            ('الجنس', form.sex == 'MALE' ? 'ذكر' : 'أنثى'),
            ('العمر', '${form.ageMonths ?? ''} شهرًا'),
          ],
        ),
        if ((form.color ?? '').isNotEmpty) _Fact('اللون', form.color!),
        _Fact('الحالة الصحية', '${form.healthNotes ?? ''} · حسب المعلن'),
        const SizedBox(height: 16),
        const SectionTitle('الوصف'),
        const SizedBox(height: 4),
        Text(form.description ?? '', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 16),
        const SectionTitle('المعلن'),
        const SizedBox(height: 4),
        _Fact('المعلن', account?.displayName ?? '—'),
        _Fact('التواصل', _contact(form)),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.soft,
            borderRadius: BorderRadius.circular(AppShapes.field),
          ),
          child: CheckboxListTile(
            contentPadding: const EdgeInsetsDirectional.only(start: 8, end: 12),
            controlAffinity: ListTileControlAffinity.leading,
            value: form.ownerDeclaration,
            onChanged: state.busy
                ? null
                : (v) => post.set('owner_declaration', v ?? false),
            title: const Text('أقر بصحة البيانات وأحقيتي في العرض'),
          ),
        ),
        if (_fixSteps.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in _fixSteps)
                ActionChip(
                  label: Text('عدّل: ${_stepName(s)}'),
                  onPressed: () => post.goTo(s),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: state.busy ? null : () => post.goTo(PostStep.data),
          child: const Text('تعديل البيانات'),
        ),
      ],
    );
  }

  static String _stepName(PostStep s) => switch (s) {
    PostStep.offer => 'نوع العرض',
    PostStep.data => 'بيانات الإبل',
    PostStep.description => 'الوصف',
    PostStep.location => 'الموقع',
    PostStep.details => 'السعر أو المزاد',
    PostStep.media => 'الصور',
    PostStep.contact => 'رقم التواصل',
    PostStep.preview => 'المعاينة',
  };

  static String _place(Lookups l, DraftForm f) {
    final city = l.city(f.cityId)?.nameAr;
    final region = l.region(f.regionId)?.nameAr;
    return [?region, ?city].join(' · ');
  }

  static String _breed(Lookups l, DraftForm f) {
    final b = l.breed(f.breedId);
    if (b == null) return '';
    return b.requiresNote ? (f.breedNote ?? b.nameAr) : b.nameAr;
  }

  static String _contact(DraftForm f) {
    String local(String? v) => SaudiPhone.tryParse(v ?? '')?.local ?? '';
    final call = local(f.contactPhone);
    final wa = local(f.whatsappPhone);
    return [
      if (call.isNotEmpty) 'اتصال: $call',
      if (wa.isNotEmpty) 'واتساب: $wa',
    ].join(' · ');
  }

  /// بطاقة المزاد (بلاطة التاريخ والوقت والمكان) كما في تفاصيل الإعلان.
  static List<Widget> _auctionLines(
    BuildContext context,
    Lookups l,
    DraftForm f,
  ) {
    final startsAt = f.auctionStartsAt;
    final venue = (f.auctionVenue ?? '').trim();
    final place = [
      if (venue.isNotEmpty) venue,
      ?l.city(f.auctionCityId)?.nameAr,
    ].join(' · ');
    final c = context.colors;
    final theme = Theme.of(context);

    Widget field(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: c.info,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );

    return [
      const SizedBox(height: 16),
      DecoratedBox(
        decoration: BoxDecoration(
          color: c.tintBlue,
          borderRadius: BorderRadius.circular(AppShapes.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (startsAt != null) ...[
                AuctionDateTile(startsAt: startsAt, large: true),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (startsAt != null)
                      field(
                        'موعد المزاد (توقيت السعودية)',
                        saudiTime12(startsAt),
                      ),
                    if (place.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      field('مكان المزاد', place),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      if (f.hasAuctionLocation) ...[
        const SizedBox(height: 10),
        MiniMap(
          key: const ValueKey('preview-location'),
          point: LatLng(f.auctionLat!, f.auctionLng!),
          height: 130,
        ),
      ],
      const SizedBox(height: 8),
      Text('المزايدة حضورية خارج التطبيق.', style: theme.textTheme.bodySmall),
    ];
  }
}

/// شريط الخصائص: ثلاث خانات تفصلها خطوط رأسية (سلالة وجنس وعمر).
class _SpecStrip extends StatelessWidget {
  const _SpecStrip({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(AppShapes.card),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, thickness: 1, color: c.line),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 8,
                  ),
                  child: Column(
                    children: [
                      Text(items[i].$1, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text(
                        items[i].$2,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// صف حقيقة: التسمية في البداية والقيمة في النهاية، وفاصل رفيع أسفله.
class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.hair)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// D11 — تم نشر الإعلان مباشرة؛ يتحكم المشرف بظهوره لاحقًا بالإخفاء.
class SentView extends StatelessWidget {
  const SentView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WasmRing(
              size: 76,
              strokeWidth: 2,
              dashed: true,
              child: Icon(Icons.check, size: 30, color: context.colors.gold),
            ),
            const SizedBox(height: 16),
            Text('تم نشر إعلانك', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'إعلانك ظاهر الآن للجميع. تجد حالته وتستطيع تعديله أو إيقافه من «إعلاناتي».',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(Routes.myListings),
              child: const Text('إعلاناتي'),
            ),
            TextButton(
              onPressed: () => context.go(Routes.home),
              child: const Text('الرئيسية'),
            ),
          ],
        ),
      ),
    );
  }
}
