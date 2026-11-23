import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/safety_repository.dart';

/// المحظورون من صاحب الجلسة (فارغة للزائر).
final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUser>>((
  ref,
) async {
  final signedIn = ref.watch(signedInProvider).value ?? false;
  if (!signedIn) return const [];
  return ref.watch(safetyRepositoryProvider).blocked();
});
