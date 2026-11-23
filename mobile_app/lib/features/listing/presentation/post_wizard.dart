import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/media_controller.dart';
import '../application/post_controller.dart';
import '../data/draft_form.dart';
import '../data/listing_repository.dart';
import 'media_step.dart';
import 'post_steps.dart';
import 'preview_step.dart';
import 'step_widgets.dart' show stepSubtitle;

enum _LeaveChoice { save, keepEditing, discard }

/// «إعلان جديد»: معالج بخطوات داخل مسار واحد. الحالة في [postControllerProvider]
/// وتُتلف عند الإغلاق، والمسودة المحفوظة تبقى في الخادم.
class PostWizardScreen extends ConsumerWidget {
  const PostWizardScreen({super.key, this.draftId, this.editId});

  /// مسودة محفوظة تُستأنف (قراءة مباشرة).
  final String? draftId;

  /// إعلان منشور أو مرفوض يُعدَّل بمسودة جديدة (`start_listing_edit`).
  final String? editId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(publishedSettingsProvider);
    return settings.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('إعلان جديد')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          title: const Text('إعلان جديد'),
          leading: BackButton(onPressed: () => _close(context)),
        ),
        body: SafeArea(
          child: EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'تعذّر تحميل البيانات',
            message: errorMessage(AppError.from(e)),
            actionLabel: 'إعادة المحاولة',
            onAction: () => ref.invalidate(publishedSettingsProvider),
          ),
        ),
      ),
      data: (_) => draftId != null || editId != null
          ? _ResumeLoader(draftId: draftId, editId: editId)
          : const _Wizard(),
    );
  }
}

void _close(BuildContext context) =>
    context.canPop() ? context.pop() : context.go(Routes.home);

class _Wizard extends ConsumerWidget {
  const _Wizard();

  static const _titles = {
    PostStep.offer: 'نوع العرض',
    PostStep.data: 'بيانات الإبل',
    PostStep.description: 'الوصف والحالة الصحية',
    PostStep.location: 'موقع الإعلان',
    PostStep.details: 'تفاصيل العرض',
    PostStep.media: 'صور الإعلان والفيديو',
    PostStep.contact: 'رقم التواصل',
    PostStep.preview: 'معاينة الإعلان',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(postControllerProvider);
    final post = ref.read(postControllerProvider.notifier);
    // يبقي صور المسودة حية أثناء التنقل بين الخطوات.
    ref.watch(mediaControllerProvider.select((_) => 0));

    Future<void> saveDraft() async {
      if (await post.save(DraftKeys.all) && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ المسودة.')));
        _close(context);
      }
    }

    Future<void> back() async {
      if (state.step != PostStep.offer) {
        post.goTo(PostStep.values[state.step.index - 1]);
        return;
      }
      if (!state.dirty) return _close(context);
      // D12 — مغادرة وحفظ المسودة.
      final choice = await showDialog<_LeaveChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('حفظ المسودة؟'),
          content: const Text('يمكنك إكمال إعلانك لاحقًا.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _LeaveChoice.discard),
              child: const Text('تجاهل التغييرات'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _LeaveChoice.keepEditing),
              child: const Text('متابعة التحرير'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _LeaveChoice.save),
              child: const Text('حفظ ومغادرة'),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
      switch (choice) {
        case _LeaveChoice.save:
          await saveDraft();
        case _LeaveChoice.discard:
          _close(context);
        case _LeaveChoice.keepEditing || null:
          break;
      }
    }

    // D11: بعد الإرسال لا يوجد ما يُحفظ ولا خطوات للرجوع إليها.
    if (state.submitted) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'رجوع',
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => _close(context),
          ),
          title: const Text('تم الإرسال'),
        ),
        body: const SafeArea(child: SentView()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'رجوع',
            icon: const Icon(Icons.arrow_forward),
            onPressed: back,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_titles[state.step]!),
              Text(
                stepSubtitle(state.step),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        body: SafeArea(child: _stepView(state.step, saveDraft)),
      ),
    );
  }

  Widget _stepView(PostStep step, Future<void> Function() saveDraft) =>
      switch (step) {
        PostStep.offer => OfferStep(onSaveDraft: saveDraft),
        PostStep.data => DataStep(onSaveDraft: saveDraft),
        PostStep.description => DescriptionStep(onSaveDraft: saveDraft),
        PostStep.location => LocationStep(onSaveDraft: saveDraft),
        PostStep.details => DetailsStep(onSaveDraft: saveDraft),
        PostStep.media => MediaStep(onSaveDraft: saveDraft),
        PostStep.contact => ContactStep(onSaveDraft: saveDraft),
        PostStep.preview => PreviewStep(onSaveDraft: saveDraft),
      };
}

/// يحمّل مسودة من الخادم إلى المعالج قبل عرضه. يبقي المتحكمين حيين أثناء التحميل.
class _ResumeLoader extends ConsumerStatefulWidget {
  const _ResumeLoader({this.draftId, this.editId});

  final String? draftId;
  final String? editId;

  @override
  ConsumerState<_ResumeLoader> createState() => _ResumeLoaderState();
}

class _ResumeLoaderState extends ConsumerState<_ResumeLoader> {
  bool _ready = false;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final repo = ref.read(listingRepositoryProvider);
    try {
      final listing = widget.draftId != null
          ? await repo.loadDraft(widget.draftId!)
          : await repo.startEdit(widget.editId!);
      if (!mounted) return;
      ref.read(postControllerProvider.notifier).resume(listing);
      ref.read(mediaControllerProvider.notifier).preload(listing.media);
      setState(() => _ready = true);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // بقاء الحالة حية بين التحميل وعرض المعالج.
    ref.watch(postControllerProvider.select((_) => 0));
    ref.watch(mediaControllerProvider.select((_) => 0));
    if (_ready) return const _Wizard();
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعلان جديد'),
        leading: BackButton(onPressed: () => _close(context)),
      ),
      body: SafeArea(
        child: _error == null
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'تعذّر تحميل الإعلان',
                message: errorMessage(_error!),
                actionLabel: 'إعادة المحاولة',
                onAction: _load,
              ),
      ),
    );
  }
}
