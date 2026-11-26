import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../listing/data/media_backend.dart';
import '../../listing/domain/image_sniff.dart';
import '../data/account_repository.dart';
import '../data/avatar_storage.dart';
import 'account_providers.dart';

/// تغيير الصورة الشخصية: اختيار ثم رفع ثم ضبط المسار ثم حذف القديم.
/// كل خطأ يخرج [AppError]. الإلغاء من المنتقي يعيد `false` دون تغيير.
class AvatarController {
  AvatarController(this._ref);

  final Ref _ref;

  /// يعيد `true` إن تغيرت الصورة.
  Future<bool> change({required bool camera}) async {
    final picked = await _ref
        .read(photoSourceProvider)
        .pickAvatar(camera: camera);
    if (picked == null) return false;
    // الخادم يقبل jpeg وpng وwebp؛ المنتقي يعيد ترميز الصور فيبقى jpeg وpng.
    final mime = ImageSniff.mimeOf(picked.bytes);
    if (mime == null) throw const AppError(AppErrorCode.validationFailed);
    final storage = _ref.read(avatarStorageProvider);
    final old = _ref.read(myAccountProvider).value?.avatarPath;
    final path = await storage.upload(picked.bytes, mimeType: mime);
    try {
      await _ref.read(accountRepositoryProvider).setAvatar(path);
    } on Object {
      // لا يبقى ملف مرفوع لم يُربط بالحساب.
      await storage.remove(path);
      rethrow;
    }
    if (old != null && old != path) await storage.remove(old);
    _ref.invalidate(myAccountProvider);
    return true;
  }

  Future<void> remove() async {
    final old = _ref.read(myAccountProvider).value?.avatarPath;
    await _ref.read(accountRepositoryProvider).setAvatar(null);
    if (old != null) await _ref.read(avatarStorageProvider).remove(old);
    _ref.invalidate(myAccountProvider);
  }
}

final avatarControllerProvider = Provider<AvatarController>(
  AvatarController.new,
);
