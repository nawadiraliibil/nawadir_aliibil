import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_error.dart';
import 'supabase_providers.dart';

/// استدعاء دالة خلفية بالاسم والمعاملات. يعيد الرد الخام (`jsonb`).
typedef RpcCaller =
    Future<dynamic> Function(String fn, {Map<String, dynamic>? params});

/// المنفذ الوحيد لدوال الخلفية؛ تُستبدل في الاختبارات.
final rpcProvider = Provider<RpcCaller>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return (fn, {params}) => client.rpc(fn, params: params);
});

/// ينفذ [call] ويحوّل أي استثناء إلى [AppError].
Future<T> guardRpc<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on Object catch (e) {
    throw AppError.from(e);
  }
}
