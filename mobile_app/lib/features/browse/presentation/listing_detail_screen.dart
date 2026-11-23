import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/format/money.dart';
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
import '../application/browse_providers.dart';
import '../data/listing_detail.dart';
import '../domain/labels.dart';

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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_forward),
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
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذّر فتح التطبيق. حاول مرة أخرى.')),
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
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            err.code == AppErrorCode.notFound
                ? 'الإعلان لم يعد متاحًا.'
                : errorMessage(err),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.colors;
    final d = detail;
    final offer = offerLine(
      isAuction: d.isAuction,
      price: d.price,
      auctionStartsAt: d.auctionStartsAt,
      auctionPassed: d.auctionPassed,
    );
    final digits = d.contactPhone.replaceAll(RegExp(r'\D'), '');
    // لا مراسلة لمعلن إعلانه؛ الزائر يرى الزر ويُوجَّه للدخول.
    final myId = ref.watch(authBackendProvider).userId;
    final canMessage = myId == null || myId != d.ownerId;

    final facts = <(String, String)>[
      ('السلالة', d.breedLabel),
      ('الجنس', sexLabel(d.sex)),
      ('العمر', ageLabel(d.ageMonths)),
      if (d.color != null && d.color!.isNotEmpty) ('اللون', d.color!),
      ('الموقع', '${d.regionName} · ${d.cityName}'),
    ];

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
                    const SizedBox(height: 16),
                    Text(d.title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppBadge(
                          label: d.isAuction ? 'مزاد حضوري' : 'سعر محدد',
                          kind: d.isAuction
                              ? AppBadgeKind.auction
                              : AppBadgeKind.fixedPrice,
                        ),
                        Text(offer, style: theme.textTheme.titleLarge),
                      ],
                    ),
                    if (d.isAuction) ...[
                      const SizedBox(height: 12),
                      _AuctionBox(detail: d),
                    ],
                    const SizedBox(height: 16),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.soft,
                        borderRadius: BorderRadius.circular(AppShapes.card),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            for (final (label, value) in facts)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        label,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: c.muted),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        value,
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('الوصف', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(d.description, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    Text(
                      'الحالة الصحية (حسب المعلن)',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(d.healthNotes, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 8),
                    const AppNote(
                      'المعلومات المعروضة إفادة من المعلن ولا تتحقق منها المنصة.',
                    ),
                    const SizedBox(height: 16),
                    _OwnerRow(detail: d),
                    const SizedBox(height: 4),
                    Text(
                      'نُشر ${formatSaudiMoment(d.publishedAt).split(' ').first}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    CommentsSection(detail: d),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (canMessage || d.callEnabled || d.whatsappEnabled)
          Material(
            elevation: 6,
            color: c.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canMessage)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('contact-message'),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('راسل المعلن'),
                        onPressed: () => _startChat(context, ref),
                      ),
                    ),
                  if (canMessage && (d.callEnabled || d.whatsappEnabled))
                    const SizedBox(height: 8),
                  if (d.callEnabled || d.whatsappEnabled)
                    Row(
                      children: [
                        if (d.callEnabled)
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const ValueKey('contact-call'),
                              icon: const Icon(Icons.call_outlined),
                              label: const Text('اتصال'),
                              onPressed: () => _launch(
                                context,
                                ref,
                                Uri(scheme: 'tel', path: d.contactPhone),
                              ),
                            ),
                          ),
                        if (d.callEnabled && d.whatsappEnabled)
                          const SizedBox(width: 12),
                        if (d.whatsappEnabled)
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const ValueKey('contact-whatsapp'),
                              icon: const Icon(Icons.chat_outlined),
                              label: const Text('واتساب'),
                              onPressed: () => _launch(
                                context,
                                ref,
                                Uri.https('wa.me', '/$digits'),
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AuctionBox extends StatelessWidget {
  const _AuctionBox({required this.detail});

  final ListingDetail detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final place = [
      d.auctionRegionName,
      d.auctionCityName,
    ].whereType<String>().join(' · ');
    final lines = [
      if (d.auctionStartsAt != null)
        'الموعد: ${formatSaudiMoment(d.auctionStartsAt!)} (توقيت السعودية)',
      if (place.isNotEmpty) 'المكان: $place',
      if (d.auctionVenue != null && d.auctionVenue!.isNotEmpty) d.auctionVenue!,
    ];
    return AppNote(
      d.auctionPassed ? 'مضى موعد هذا المزاد.' : lines.join('\n'),
      kind: d.auctionPassed ? AppNoteKind.error : AppNoteKind.info,
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
          const Icon(Icons.chevron_left),
        ],
      ),
    );
  }
}

/// معرض صور الإعلان: تمرير أفقي، ومؤشر الصفحة، والنقر يفتح عرضًا كاملًا
/// قابلًا للتكبير. الفيديو لا يعمل تلقائيًا؛ لا يُعرض هنا إلى أن يُبنى مشغله.
class ListingGallery extends StatefulWidget {
  const ListingGallery({super.key, required this.media});

  final List<DetailMedia> media;

  @override
  State<ListingGallery> createState() => _ListingGalleryState();
}

class _ListingGalleryState extends State<ListingGallery> {
  var _page = 0;

  List<DetailMedia> get _images =>
      widget.media.where((m) => m.isImage).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final images = _images;
    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: ColoredBox(
          color: c.soft,
          child: Icon(Icons.image_outlined, color: c.muted, size: 48),
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
            itemBuilder: (context, i) => Semantics(
              button: true,
              label: 'صورة ${i + 1} من ${images.length}. اضغط للتكبير',
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => ImageViewer(images: images, initial: i),
                  ),
                ),
                child: ExcludeSemantics(
                  child: MediaImage(
                    bucket: images[i].bucket,
                    path: images[i].path,
                  ),
                ),
              ),
            ),
          ),
          if (images.length > 1)
            PositionedDirectional(
              bottom: 8,
              start: 0,
              end: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < images.length; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page ? c.gold : c.line,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// عرض كامل للصور بتكبير بالقرص.
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
        title: Text('${_page + 1} / ${widget.images.length}'),
      ),
      body: PageView.builder(
        key: const ValueKey('viewer'),
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (context, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: MediaImage(
              bucket: widget.images[i].bucket,
              path: widget.images[i].path,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
