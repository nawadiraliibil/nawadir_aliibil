import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/account_models.dart';
import '../data/account_repository.dart';

/// حساب المستخدم الحالي، أو `null` للزائر. يعاد جلبه عند تغير الجلسة، ويبطل
/// يدويًا بعد حفظ الملف أو الموافقات (`ref.invalidate`).
final myAccountProvider = FutureProvider<MyAccount?>((ref) async {
  final signedIn = ref.watch(signedInProvider).value ?? false;
  if (!signedIn) return null;
  return ref.watch(accountRepositoryProvider).myAccount();
});

/// النصوص السارية كاملة، لقراءتها قبل الموافقة.
final currentPoliciesProvider = FutureProvider<List<PolicyDocument>>(
  (ref) => ref.watch(accountRepositoryProvider).currentPolicies(),
);
