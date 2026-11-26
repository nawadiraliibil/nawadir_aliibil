import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/supabase/rpc.dart';
import 'account_models.dart';

/// دوال الحساب في الخلفية. كل خطأ يخرج [AppError].
class AccountRepository {
  AccountRepository(this._rpc);

  final RpcCaller _rpc;

  Future<MyAccount> myAccount() => guardRpc(() async {
    final res = await _rpc('get_my_account');
    return _parse(res, MyAccount.fromJson);
  });

  /// يحفظ اسم العرض والمنطقة. الاسم 2 إلى 40 حرفًا دون مسافات طرفية (الخادم يتحقق).
  Future<void> updateProfile({
    required String displayName,
    required int regionId,
  }) => guardRpc(
    () => _rpc(
      'update_my_profile',
      params: {'p_display_name': displayName, 'p_region_id': regionId},
    ),
  );

  /// يضبط الصورة من ملف مرفوع في `avatars/{uid}/`، أو يمسحها بـ`null`.
  Future<MyAccount> setAvatar(String? path) => guardRpc(() async {
    final res = await _rpc('set_my_avatar', params: {'p_path': path});
    return _parse(res, MyAccount.fromJson);
  });

  /// يسجل الموافقة على النصوص بمعرفاتها. التكرار آمن.
  Future<void> acceptPolicies(List<int> documentIds) => guardRpc(
    () => _rpc('accept_policies', params: {'p_document_ids': documentIds}),
  );

  Future<List<PolicyDocument>> currentPolicies() => guardRpc(() async {
    final res = await _rpc('get_current_policies');
    if (res is! List) throw const AppError(AppErrorCode.unknown);
    return [for (final e in res) _parse(e, PolicyDocument.fromJson)];
  });

  /// رد لا يطابق العقد خطأ توافق لا خطأ شبكة.
  static T _parse<T>(Object? raw, T Function(Map<String, dynamic>) from) {
    try {
      return from(Map<String, dynamic>.from(raw! as Map));
    } on TypeError catch (e) {
      throw AppError(AppErrorCode.unknown, cause: e);
    }
  }
}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(ref.watch(rpcProvider)),
);
