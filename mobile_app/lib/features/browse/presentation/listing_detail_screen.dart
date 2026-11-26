import 'package:flutter/material.dart';
import '../../../core/widgets/app_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/format/money.dart';
import '../../../core/location/map_widgets.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/application/auth_providers.dart';
import '../../chat/application/chat_providers.dart';
import '../../chat/data/chat_repository.dart';
import '../../comments/presentation/comments_section.dart';
import '../../favorites/presentation/favorite_button.dart';
import '../../safety/data/safety_repository.dart';
import '../../safety/presentation/safety_actions.dart';
import '../../listing/presentation/media_image.dart';
import '../../listing/presentation/video_player_view.dart';
import '../application/browse_providers.dart';
import '../data/listing_detail.dart';
import '../domain/labels.dart';
import 'auction_widgets.dart';
import 'listing_stats.dart';
import 'listing_card_tile.dart' show PriceText;

/// يفتح رابطًا خارج التطبيق (اتصال أو واتساب)؛ تُستبدل في الاختبارات.
typedef ExternalLauncher = Future<bool> Function(Uri uri);

final externalLauncherProvider = Provider<ExternalLauncher>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// يشارك نصًا عبر ورقة المشاركة في النظام؛ تُستبدل في الاختبارات.
typedef ShareText = Future<void> Function(String text, String subject);

final shareTextProvider = Provider<ShareText>(
  (ref) =>
      (text, subject) => SharePlus.instance
          .share(ShareParams(text: text, subject: subject))
          .then((_) {}),
);

/// رابط مشاركة الإعلان الثابت `<SHARE_BASE_URL>/l/<public_ref>` (INT-005)،
/// أو `null` ما دام النطاق غير مضبوط أو لا معرف عامًا. لا يحمل بيانات خاصة.
String? listingShareLink(String baseUrl, String? publicRef) {
  final base = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  if (base.isEmpty || publicRef == null) return null;
  return '$base/l/$publicRef';
}

/// تفاصيل الإعلان (C01): معرض الصور، السعر أو المزاد، المواصفات، الوصف،
/// المعلن، وأزرار التواصل للقنوات المفعلة فقط. غير المنشور «غير متاح» دون سبب.
class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(listingDetailProvider(listingId));
    final shareBase = ref.watch(envProvider).shareBaseUrl;
    // مشاهدة واحدة لكل فتح، بعد وصول التفاصيل فعلًا.
    if (detail.hasValue) ref.watch(recordListingViewProvider(listingId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        title: const Text('تفاصيل الإعلان'),
        actions: [
          if (detail.value case final d?) ...[
            if (listingShareLink(shareBase, d.publicRef) case final link?)
              IconButton(
                key: const ValueKey('share'),
                tooltip: 'مشاركة',
                icon: const Icon(Icons.ios_share),
                onPressed: () =>
                    ref.read(shareTextProvider)('${d.title}\n$link', d.title),
              ),
            FavoriteButton(listingId: d.listingId, initial: d.isFavorite),
            if (ref.watch(authBackendProvider).userId != d.ownerId)
              PopupMenuButton<String>(
                key: const ValueKey('detail-menu'),
                tooltip: 'المزيد',
                onSelected: (v) {
                  switch (v) {
                    case 'report':
                      showReportSheet(
                        context,
                        ref,
                        target: ReportTarget.listing,
                        targetId: d.listingId,
                        targetLabel: 'الإعلان',
                      );
                    case 'report_user':
                      showReportSheet(
                        context,
                        ref,
                        target: ReportTarget.account,
                        targetId: d.ownerId,
                        targetLabel: 'المعلن',
                      );
                    case 'block':
                      confirmAndBlock(
                        context,
                        ref,
                        userId: d.ownerId,
                        name: d.ownerName,
                      );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'report',
                    child: Text('الإبلاغ عن الإعلان'),
                  ),
                  PopupMenuItem(
                    value: 'report_user',
                    child: Text('الإبلاغ عن المعلن'),
                  ),
                  PopupMenuItem(value: 'block', child: Text('حظر المعلن')),
                ],
              ),
          ],
        ],
      ),
      body: SafeArea(
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            final err = AppError.from(e);
            // لا نكشف سبب عدم التوفر: مخفي أو محذوف أو غير موجود سواء.
            if (err.code == AppErrorCode.notFound) {
              return EmptyState(
                icon: Icons.visibility_off_outlined,
                title: 'الإعلان غير متاح',
                message: 'قد يكون أُزيل أو لم يعد معروضًا.',
                actionLabel: 'العودة للرئيسية',
                onAction: () => context.go(Routes.home),
              );
            }
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'تعذّر تحميل الإعلان',
              message: errorMessage(err),
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(listingDetailProvider(listingId)),
            );
          },
          data: (d) => _DetailBody(detail: d),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});

  final ListingDetail detail;

  Future<void> _launch(BuildContext context, WidgetRef ref, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await ref.read(externalLauncherProvider)(uri);
    } on Object {
      ok = false;
    }
    if (!ok) {
      messenger.showApp(
        'تعذّر فتح التطبيق. حاول مرة أخرى.',
        kind: AppNoteKind.error,
      );
    }
  }

  /// يبدأ محادثة مع المعلن (أو يفتح الموجودة). الزائر يُوجَّه إلى الدخول ثم يعود.
  Future<void> _startChat(BuildContext context, WidgetRef ref) async {
    final signedIn = ref.read(signedInProvider).value ?? false;
    if (!signedIn) {
      context.push(
        Uri(
          path: Routes.login,
          queryParameters: {'from': Routes.listing(detail.listingId)},
        ).toString(),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final id = await ref.read(chatRepositoryProvider).start(detail.listingId);
      // القائمة حديثة قبل الفتح: تحمل اسم الطرف الآخر وقابلية الكتابة.
      try {
        ref.invalidate(conversationsProvider);
        await ref.read(conversationsProvider.future);
      } on Object {
        // الشاشة تعيد قراءتها بنفسها إن غابت.
      }
      router.push(Routes.chat(id));
    } on Object catch (e) {
      final err = AppError.from(e);
      messenger.showApp(
        err.code == AppErrorCode.notFound
            ? 'الإعلان لم يعد متاحًا.'
            : errorMessage(err),
        kind: AppNoteKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.colors;
    final d = detail;
    final digits = (d.whatsappPhone ?? '').replaceAll(RegExp(r'\D'), '');
    // لا مراسلة لمعلن إعلانه؛ الزائر يرى الزر ويُوجَّه للدخول.
    final myId = ref.watch(authBackendProvider).userId;
    final canMessage = myId == null || myId != d.ownerId;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              ListingGallery(media: d.media),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppBadge(
                      label: d.isAuction ? 'مزاد حضوري' : 'سعر محدد',
                      kind: d.isAuction
                          ? AppBadgeKind.auction
                          : AppBadgeKind.fixedPrice,
                    ),
                    const SizedBox(height: 10),
                    Text(d.title, style: theme.textTheme.headlineSmall),
                    if (!d.isAuction && d.price != null) ...[
                      const SizedBox(height: 8),
                      PriceText(d.price!, size: 34),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: c.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${d.regionName} · ${d.cityName}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StatLabel(
                          key: const ValueKey('detail-likes'),
                          icon: Icons.favorite_border,
                          count: d.favoriteCount,
                          noun: 'إعجاب',
                        ),
                        const SizedBox(width: 14),
                        StatLabel(
                          key: const ValueKey('detail-views'),
                          icon: Icons.visibility_outlined,
                          count: d.viewCount,
                          noun: 'مشاهدة',
                        ),
                      ],
                    ),
                    if (d.isAuction) ...[
                      const SizedBox(height: 16),
                      _AuctionCard(detail: d),
                    ],
                    const SizedBox(height: 16),
                    _SpecStrip(
                      items: [
                        ('السلالة', d.breedLabel),
                        ('الجنس', sexLabel(d.sex)),
                        ('العمر', ageLabel(d.ageMonths)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailTabs(detail: d),
                  ],
                ),
              ),
            ],
          ),
        ),
        // المعلن لا يرى شريط التواصل في إعلانه إطلاقًا.
        if (canMessage)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            // شريط التواصل العائم: كبسولة بظل، وزر المحادثة هو الرئيسي.
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppShapes.nav + 4),
                border: Border.all(color: c.line),
                boxShadow: c.floatingShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    if (canMessage)
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('contact-message'),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('محادثة'),
                          onPressed: () => _startChat(context, ref),
                        ),
                      )
                    else
                      const Spacer(),
                    if (d.callEnabled) ...[
                      const SizedBox(width: 8),
                      _ChannelButton(
                        key: const ValueKey('contact-call'),
                        icon: Icons.call_outlined,
                        label: 'اتصال',
                        onTap: () => _launch(
                          context,
                          ref,
                          Uri(scheme: 'tel', path: d.contactPhone!),
                        ),
                      ),
                    ],
                    if (d.whatsappEnabled) ...[
                      const SizedBox(width: 8),
                      _ChannelButton(
                        key: const ValueKey('contact-whatsapp'),
                        icon: Icons.chat_outlined,
                        label: 'واتساب',
                        onTap: () => _launch(
                          context,
                          ref,
                          Uri.https('wa.me', '/$digits'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// تبويبات التفاصيل (C01): تفاصيل ووصف ومعلن، بشريط كبسولي.
class _DetailTabs extends StatefulWidget {
  const _DetailTabs({required this.detail});

  final ListingDetail detail;

  @override
  State<_DetailTabs> createState() => _DetailTabsState();
}

class _DetailTabsState extends State<_DetailTabs> {
  var _tab = 0;

  static const _labels = ['التفاصيل', 'الوصف', 'المعلن'];
  static const _keys = ['tab-details', 'tab-description', 'tab-owner'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final d = widget.detail;

    final content = switch (_tab) {
      0 => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.color != null && d.color!.isNotEmpty)
            _FactRow(label: 'اللون', value: d.color!),
          _FactRow(label: 'الحالة الصحية', value: d.healthNotes),
        ],
      ),
      1 => Text(d.description, style: theme.textTheme.bodyLarge),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OwnerRow(detail: d),
          const SizedBox(height: 6),
          Text(
            'نُشر ${formatSaudiMoment(d.publishedAt).split(' ').first}',
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
          ),
        ],
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: ShapeDecoration(
            color: c.soft,
            shape: const StadiumBorder(),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                for (var i = 0; i < _labels.length; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: _tab == i,
                      child: Material(
                        color: _tab == i ? c.tintGold : Colors.transparent,
                        shape: const StadiumBorder(),
                        child: InkWell(
                          key: ValueKey(_keys[i]),
                          customBorder: const StadiumBorder(),
                          onTap: () => setState(() => _tab = i),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: AppShapes.minTouchTarget - 4,
                            ),
                            child: Center(
                              child: Text(
                                _labels[i],
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: _tab == i ? c.gold : c.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        content,
        // الأسئلة والردود جزء من حاوية التبويبات (تظهر تحت محتوى كل تبويب)،
        // وحالة الكتابة تبقى عند التنقل بين التبويبات.
        const SizedBox(height: 20),
        CommentsSection(detail: d),
      ],
    );
  }
}

/// بطاقة المزاد في التفاصيل: بلاطة تاريخ كبيرة مع الموعد والمكان، وتنبيه بأن
/// المزايدة حضورية خارج التطبيق. المزاد الماضي ينبَّه إليه دون بلاطة.
class _AuctionCard extends ConsumerWidget {
  const _AuctionCard({required this.detail});

  final ListingDetail detail;

  /// يفتح موقع المزاد في تطبيق الخرائط الافتراضي.
  Future<void> _openDirections(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${detail.auctionLat},${detail.auctionLng}',
    });
    var ok = false;
    try {
      ok = await ref.read(externalLauncherProvider)(uri);
    } on Object {
      ok = false;
    }
    if (!ok) {
      messenger.showApp(
        'تعذّر فتح الخرائط. حاول مرة أخرى.',
        kind: AppNoteKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = detail;
    final c = context.colors;
    final theme = Theme.of(context);
    final startsAt = d.auctionStartsAt;
    if (d.auctionPassed || startsAt == null) {
      return AppNote(
        d.auctionPassed ? 'مضى موعد هذا المزاد.' : 'موعد المزاد غير محدد.',
        kind: d.auctionPassed ? AppNoteKind.error : AppNoteKind.info,
      );
    }
    final place = [
      if (d.auctionVenue != null && d.auctionVenue!.isNotEmpty) d.auctionVenue!,
      ?d.auctionCityName,
    ].join(' · ');

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                AuctionDateTile(startsAt: startsAt, large: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
        if (d.hasAuctionLocation) ...[
          const SizedBox(height: 10),
          DistanceLabel(lat: d.auctionLat!, lng: d.auctionLng!),
          const SizedBox(height: 8),
          MiniMap(
            key: const ValueKey('auction-map'),
            point: LatLng(d.auctionLat!, d.auctionLng!),
            height: 170,
            onTap: () => _openDirections(context, ref),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const ValueKey('auction-directions'),
              onPressed: () => _openDirections(context, ref),
              icon: const Icon(Icons.directions_outlined),
              label: const Text('فتح الموقع في الخرائط'),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text('المزايدة حضورية خارج التطبيق.', style: theme.textTheme.bodySmall),
      ],
    );
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          items[i].$2,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall,
                        ),
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
class _FactRow extends StatelessWidget {
  const _FactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.hair)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const Spacer(),
            Text(value, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

/// زر قناة تواصل في الشريط العائم: خلفية خضراء هادئة بأيقونة وتسمية.
class _ChannelButton extends StatelessWidget {
  const _ChannelButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: c.tintGreen,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppShapes.minTouchTarget + 8,
              minHeight: AppShapes.minTouchTarget + 4,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: c.green),
                Text(
                  label,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerRow extends StatelessWidget {
  const _OwnerRow({required this.detail});

  final ListingDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    return InkWell(
      key: const ValueKey('owner-row'),
      onTap: () => context.push(Routes.seller(detail.ownerId)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: c.tintGold,
            child: Text(
              detail.ownerName.characters.first,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detail.ownerName, style: theme.textTheme.titleMedium),
                Text(
                  'عضو منذ ${detail.ownerJoinedAt.toUtc().year}',
                  style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

/// معرض صور الإعلان: تمرير أفقي، ومؤشر الصفحة، والنقر يفتح عرضًا كاملًا
/// قابلًا للتكبير. الفيديو (C04) يظهر فقط حين يكون `media.video_enabled`
/// مفعلًا، ويُشغَّل يدويًا فقط.
class ListingGallery extends ConsumerStatefulWidget {
  const ListingGallery({super.key, required this.media});

  final List<DetailMedia> media;

  @override
  ConsumerState<ListingGallery> createState() => _ListingGalleryState();
}

class _ListingGalleryState extends ConsumerState<ListingGallery> {
  var _page = 0;

  /// الصور، ومعها الفيديو إن كان مفعلًا في الإعدادات المنشورة.
  List<DetailMedia> get _images {
    final videoEnabled =
        ref.watch(publishedSettingsProvider).value?.media.videoEnabled ?? false;
    return widget.media
        .where((m) => m.isImage || videoEnabled)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final images = _images;
    // حافة الورقة المرتفعة (زوايا 28) تغطي أسفل الصورة.
    final sheetCap = PositionedDirectional(
      bottom: 0,
      start: 0,
      end: 0,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: AppShapes.sheetRadius,
          ),
          child: const SizedBox(height: AppShapes.sheet),
        ),
      ),
    );
    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: c.soft,
                child: Icon(Icons.image_outlined, color: c.muted, size: 48),
              ),
            ),
            sheetCap,
          ],
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        children: [
          PageView.builder(
            key: const ValueKey('gallery'),
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              void openViewer() => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => ImageViewer(images: images, initial: i),
                ),
              );
              if (!images[i].isImage) {
                return VideoPlayerView(
                  key: ValueKey('video-${images[i].mediaId}'),
                  bucket: images[i].bucket,
                  path: images[i].path,
                  onFullscreen: openViewer,
                );
              }
              return Semantics(
                button: true,
                label: 'صورة ${i + 1} من ${images.length}. اضغط للتكبير',
                child: GestureDetector(
                  onTap: openViewer,
                  child: ExcludeSemantics(
                    child: MediaImage(
                      bucket: images[i].bucket,
                      path: images[i].path,
                    ),
                  ),
                ),
              );
            },
          ),
          sheetCap,
          if (images.length > 1)
            PositionedDirectional(
              bottom: AppShapes.sheet + 12,
              start: 16,
              child: ExcludeSemantics(
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: c.surface,
                    shape: const StadiumBorder(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_page + 1}/${images.length}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.image_outlined, size: 16, color: c.text),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// عرض كامل للصور (بتكبير بالقرص) والفيديو (تشغيل يدوي).
class ImageViewer extends StatefulWidget {
  const ImageViewer({super.key, required this.images, required this.initial});

  final List<DetailMedia> images;
  final int initial;

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late final _controller = PageController(initialPage: widget.initial);
  late var _page = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        // سمة التطبيق تلوّن العنوان والأيقونات بالداكن فتختفي على الأسود.
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(color: Colors.white),
        // الأرقام تُرتّب «1 / 3» حتى داخل واجهة RTL.
        title: Directionality(
          textDirection: TextDirection.ltr,
          child: Text('${_page + 1} / ${widget.images.length}'),
        ),
      ),
      body: PageView.builder(
        key: const ValueKey('viewer'),
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (context, i) {
          final m = widget.images[i];
          if (!m.isImage) {
            return VideoPlayerView(
              key: ValueKey('viewer-video-${m.mediaId}'),
              bucket: m.bucket,
              path: m.path,
            );
          }
          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: MediaImage(
                bucket: m.bucket,
                path: m.path,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
