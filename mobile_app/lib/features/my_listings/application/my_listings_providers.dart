import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/rest.dart';
import '../../auth/application/auth_providers.dart';
import '../data/my_listing.dart';

/// إعلانات صاحب الجلسة من `my_listings`، الأحدث تعديلًا أولًا. حتى 100 إعلان؛
/// حد المسودات 20 وحد الإرسال اليومي 5، فالعدد عمليًا أقل (التصفح على دفعات
/// يلزم عند نمو القائمة).
final myListingsProvider = FutureProvider.autoDispose<List<MyListing>>((
  ref,
) async {
  final signedIn = ref.watch(signedInProvider).value ?? false;
  if (!signedIn) return const [];
  final read = ref.watch(tableReaderProvider);
  try {
    final rows = await read(
      'my_listings',
      orderBy: 'updated_at',
      ascending: false,
      limit: 100,
    );
    return [for (final r in rows) MyListing.fromJson(r)];
  } on TypeError catch (e) {
    // صف لا يطابق العقد خطأ توافق لا خطأ شبكة.
    throw AppError(AppErrorCode.unknown, cause: e);
  }
});
