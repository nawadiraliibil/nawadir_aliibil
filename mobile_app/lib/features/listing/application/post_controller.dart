import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_error.dart';
import '../data/draft_form.dart';
import '../data/listing_repository.dart';

/// خطوات معالج «إعلان جديد» بترتيبها. [number] ترقيم الشاشات في التصميم
/// («n / 7»)؛ الموقع والسعر أو المزاد تحمل الرقم 4 معًا.
enum PostStep {
  offer(1),
  data(2),
  description(3),
  location(4),
  details(4),
  media(5),
  contact(6),
  preview(7);

  const PostStep(this.number);
  final int number;

  static const total = 7;
}

class PostState {
  const PostState({
    this.form = const DraftForm(),
    this.saved = const DraftForm(),
    this.listingId,
    this.step = PostStep.offer,
    this.busy = false,
    this.error,
    this.submitted = false,
  });

  /// ما يراه المستخدم الآن.
  final DraftForm form;

  /// آخر نسخة أكدها الخادم.
  final DraftForm saved;

  /// معرف المسودة في الخادم بعد أول حفظ.
  final String? listingId;
  final PostStep step;
  final bool busy;
  final AppError? error;

  /// أُرسل الإعلان للمراجعة (D11).
  final bool submitted;

  /// هل في الجهاز ما لم يحفظ بعد.
  bool get dirty => form.diff(saved, DraftKeys.all).isNotEmpty;

  PostState copyWith({
    DraftForm? form,
    DraftForm? saved,
    String? listingId,
    PostStep? step,
    bool? busy,
    AppError? error,
    bool? submitted,
    bool clearError = false,
  }) => PostState(
    form: form ?? this.form,
    saved: saved ?? this.saved,
    listingId: listingId ?? this.listingId,
    step: step ?? this.step,
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
    submitted: submitted ?? this.submitted,
  );
}

/// حالة معالج الإعلان. تُتلف عند إغلاق المعالج، والمسودة المحفوظة تبقى في الخادم.
class PostController extends Notifier<PostState> {
  /// معرف طلب الإنشاء ثابت طوال عمر المعالج: إعادة المحاولة بعد انقطاع لا
  /// تنشئ مسودة ثانية (AD-NFR-005).
  late final String _createRequestId = const Uuid().v4();

  /// معرف طلب الإرسال ثابت: الضغط المكرر أو إعادة المحاولة بعد انقطاع لا ينشئ
  /// إرسالًا ثانيًا (AD-NFR-005).
  late final String _submitRequestId = const Uuid().v4();

  @override
  PostState build() => const PostState();

  void set(String key, Object? value) => setAll({key: value});

  void setAll(Map<String, Object?> changes) {
    state = state.copyWith(form: state.form.setAll(changes), clearError: true);
  }

  /// نوع العرض: حقول النوع الآخر تُمسح لأن الخادم يرفض إرسال قيمها.
  void setOfferType(String type) {
    if (type == state.form.offerType) return;
    setAll({
      'offer_type': type,
      if (type == DraftForm.offerFixed) ...{
        'auction_region_id': null,
        'auction_city_id': null,
        'auction_venue': null,
        'auction_starts_at': null,
      } else
        'price': null,
    });
  }

  /// يستأنف مسودة محفوظة: يملأ النموذج من الخادم ويبدأ من أول خطوة بعد نوع العرض.
  void resume(OwnerListing listing) {
    state = PostState(
      form: listing.form,
      saved: listing.form,
      listingId: listing.id,
      step: listing.form.offerType == null ? PostStep.offer : PostStep.data,
    );
  }

  void goTo(PostStep step) =>
      state = state.copyWith(step: step, clearError: true);

  /// يحفظ مفاتيح [keys] في الخادم وينشئ المسودة عند أول حفظ. يعيد `true`
  /// عند النجاح؛ عند الفشل يبقى الخطأ في [PostState.error].
  Future<bool> save(Set<String> keys) async {
    if (state.busy) return false;
    state = state.copyWith(busy: true, clearError: true);
    final repo = ref.read(listingRepositoryProvider);
    try {
      var id = state.listingId;
      if (id == null) {
        final created = await repo.createDraft(_createRequestId);
        id = created.id;
        state = state.copyWith(listingId: id, saved: created.form);
      }
      final patch = state.form.diff(state.saved, keys);
      if (patch.isNotEmpty) {
        final res = await repo.saveDraft(id, patch);
        state = state.copyWith(
          saved: res.form,
          form: state.form.adopt(res.form, keys),
        );
      }
      state = state.copyWith(busy: false);
      return true;
    } on AppError catch (e) {
      state = state.copyWith(busy: false, error: e);
      return false;
    }
  }

  /// يحفظ الإقرار ثم يرسل للمراجعة. `true` عند النجاح؛ عند الفشل يبقى الخطأ
  /// في [PostState.error].
  Future<bool> submit() async {
    if (!await save(DraftKeys.declaration)) return false;
    final id = state.listingId!;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await ref.read(listingRepositoryProvider).submit(id, _submitRequestId);
      state = state.copyWith(busy: false, submitted: true);
      return true;
    } on AppError catch (e) {
      state = state.copyWith(busy: false, error: e);
      return false;
    }
  }
}

final postControllerProvider =
    NotifierProvider.autoDispose<PostController, PostState>(PostController.new);
