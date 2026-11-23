import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/format/money.dart';
import '../../../core/settings/published_settings.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_note.dart';
import '../../account/application/account_providers.dart';
import '../../auth/domain/saudi_phone.dart';
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
    case 'region_id' || 'city_id':
      return PostStep.location;
    case 'offer_type':
      return PostStep.offer;
    case 'price' ||
        'auction_region_id' ||
        'auction_city_id' ||
        'auction_venue' ||
        'auction_starts_at':
      return PostStep.details;
    case 'contact_phone' || 'contact_channels':
      return PostStep.contact;
    case 'images' || 'media_ids' || 'cover_id':
      return PostStep.media;
    default:
      return PostStep.data;
  }
}

/// D09 / D10 — معاينة الإعلان، والإقرار، والإرسال للمراجعة.
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
      continueLabel: 'إرسال للمراجعة',
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
        Text(form.title ?? '', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        if (!form.isAuction && form.price != null)
          Text(
            '${formatMoney(form.price!)} ريال',
            style: theme.textTheme.titleMedium?.copyWith(color: c.gold),
          ),
        Text(_place(settings.lookups, form), style: theme.textTheme.bodyMedium),
        if (form.isAuction) ..._auctionLines(context, settings.lookups, form),
        const Divider(height: 32),
        _Fact('السلالة', _breed(settings.lookups, form)),
        _Fact('الجنس', form.sex == 'MALE' ? 'ذكر' : 'أنثى'),
        _Fact('العمر', '${form.ageMonths ?? ''} شهرًا'),
        if ((form.color ?? '').isNotEmpty) _Fact('اللون', form.color!),
        _Fact('الحالة الصحية', '${form.healthNotes ?? ''} · حسب المعلن'),
        const SizedBox(height: 12),
        Text(form.description ?? '', style: theme.textTheme.bodyLarge),
        const Divider(height: 32),
        _Fact('المعلن', account?.displayName ?? '—'),
        _Fact('التواصل', _contact(form)),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: form.ownerDeclaration,
          onChanged: state.busy
              ? null
              : (v) => post.set('owner_declaration', v ?? false),
          title: const Text('أقر بصحة البيانات وأحقيتي في العرض'),
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
    final phone = SaudiPhone.tryParse(f.contactPhone ?? '')?.local ?? '';
    final channels = [
      if (f.callEnabled) 'اتصال',
      if (f.whatsappEnabled) 'واتساب',
    ].join(' و');
    return '$phone · $channels';
  }

  static List<Widget> _auctionLines(
    BuildContext context,
    Lookups l,
    DraftForm f,
  ) {
    final at = f.auctionStartsAt?.add(const Duration(hours: 3));
    final place = [
      ?l.region(f.auctionRegionId)?.nameAr,
      ?l.city(f.auctionCityId)?.nameAr,
    ].join(' · ');
    return [
      const SizedBox(height: 8),
      _Fact('مكان المزاد', '$place — ${f.auctionVenue ?? ''}'),
      if (at != null)
        _Fact(
          'موعد المزاد',
          '${at.day}/${at.month}/${at.year} '
              '${at.hour.toString().padLeft(2, '0')}:'
              '${at.minute.toString().padLeft(2, '0')} بتوقيت السعودية',
        ),
    ];
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

/// D11 — تم إرسال الإعلان للمراجعة.
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
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: context.colors.success,
            ),
            const SizedBox(height: 16),
            Text('أُرسل للمراجعة', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'سيظهر إعلانك بعد اعتماد الإدارة.',
              style: theme.textTheme.bodyLarge,
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
