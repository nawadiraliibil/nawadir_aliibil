import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/rpc.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../browse/application/browse_providers.dart'
    show deviceViewIdProvider;
import '../data/promotion.dart';
import '../data/promotions_repository.dart';

final promotionsRepositoryProvider = Provider<PromotionsRepository>(
  (ref) => PromotionsRepository(ref.watch(rpcProvider)),
);

/// مدة إبقاء الدعايات المجلوبة لموضع ومنطقة قبل إعادة الجلب.
const promotionsCacheFor = Duration(minutes: 5);

typedef PromotionsQuery = ({PromotionPlacement placement, int? regionId});

/// الدعايات الجارية لموضع ومنطقة. أي فشل يعيد [ActivePromotions.none]:
/// الدعايات لا تعطل القائمة ولا تظهر خطأ (INT-010).
final activePromotionsProvider = FutureProvider.autoDispose
    .family<ActivePromotions, PromotionsQuery>((ref, q) async {
      final link = ref.keepAlive();
      final timer = Timer(promotionsCacheFor, link.close);
      ref.onDispose(timer.cancel);
      try {
        return await ref
            .read(promotionsRepositoryProvider)
            .active(q.placement, regionId: q.regionId);
      } on Object {
        return ActivePromotions.none;
      }
    });

/// رابط الصورة العام في bucket ‏promotions (العقد 1.6.0، storage.md).
final promotionImageUrlProvider = Provider<String Function(String path)>((ref) {
  final base = ref
      .watch(envProvider)
      .supabaseUrl
      .replaceAll(RegExp(r'/+$'), '');
  return (path) => '$base/storage/v1/object/public/promotions/$path';
});

/// معرفات الدعايات التي سُجل ظهورها في هذه الجلسة (مرة لكل دعاية).
final _impressionsThisSession = Provider<Set<String>>((ref) => <String>{});

/// يسجل حدث دعاية دون انتظار ولا أثر للفشل. الظهور مرة لكل دعاية في الجلسة.
typedef PromotionEventRecorder =
    void Function(String promotionId, PromotionEvent event);

final promotionEventRecorderProvider = Provider<PromotionEventRecorder>((ref) {
  final seen = ref.watch(_impressionsThisSession);
  return (id, event) {
    if (event == PromotionEvent.impression && !seen.add(id)) return;
    unawaited(() async {
      try {
        final device = await ref.read(deviceViewIdProvider.future);
        await ref
            .read(promotionsRepositoryProvider)
            .record(id, event, deviceId: device);
      } on Object {
        // العدادات لا تعطل العرض.
      }
    }());
  };
});
