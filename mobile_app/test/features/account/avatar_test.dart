import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nawadir_aliibil/core/errors/app_error.dart';
import 'package:nawadir_aliibil/core/supabase/rpc.dart';
import 'package:nawadir_aliibil/features/account/application/account_providers.dart';
import 'package:nawadir_aliibil/features/account/application/avatar_controller.dart';
import 'package:nawadir_aliibil/features/account/data/account_models.dart';
import 'package:nawadir_aliibil/features/account/data/account_repository.dart';
import 'package:nawadir_aliibil/features/account/data/avatar_storage.dart';
import 'package:nawadir_aliibil/features/listing/data/media_backend.dart';
import 'package:nawadir_aliibil/features/listing/data/media_models.dart';

import '../../helpers/fake_media.dart';
import '../../helpers/fake_rpc.dart';

class _FakeAvatarStorage implements AvatarStorage {
  final uploaded = <String>[];
  final removed = <String>[];

  @override
  Future<String> upload(Uint8List bytes, {required String mimeType}) async {
    final path = 'u/${uploaded.length + 1}.jpg';
    uploaded.add(path);
    return path;
  }

  @override
  String urlFor(String path) => 'https://example.test/$path';

  @override
  Future<void> remove(String path) async => removed.add(path);
}

Map<String, dynamic> _account({String? avatar}) => {
  ...Map<String, dynamic>.from(fixture('account-ready') as Map),
  'avatar_path': avatar,
};

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);

ProviderContainer _container({
  required FakeRpc rpc,
  required _FakeAvatarStorage storage,
  required FakePhotoSource photos,
  String? current,
}) {
  final c = ProviderContainer(
    overrides: [
      rpcProvider.overrideWithValue(rpc.caller),
      avatarStorageProvider.overrideWithValue(storage),
      photoSourceProvider.overrideWithValue(photos),
      myAccountProvider.overrideWith(
        (ref) async => MyAccount.fromJson(_account(avatar: current)),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('النموذج والمستودع يمرّران avatar_path', () async {
    expect(MyAccount.fromJson(_account()).avatarPath, isNull);
    final rpc = FakeRpc({'set_my_avatar': (_) => _account(avatar: 'u/1.jpg')});
    final a = await AccountRepository(rpc.caller).setAvatar('u/1.jpg');
    expect(a.avatarPath, 'u/1.jpg');
    expect(rpc.paramsOf('set_my_avatar'), [
      {'p_path': 'u/1.jpg'},
    ]);
  });

  test('التغيير يرفع ثم يضبط المسار ثم يحذف القديم', () async {
    final rpc = FakeRpc({'set_my_avatar': (_) => _account(avatar: 'u/1.jpg')});
    final storage = _FakeAvatarStorage();
    final photos = FakePhotoSource(
      avatar: PickedImage(name: 'a.jpg', bytes: _jpeg),
    );
    final c = _container(
      rpc: rpc,
      storage: storage,
      photos: photos,
      current: 'u/old.jpg',
    );
    await c.read(myAccountProvider.future);

    expect(await c.read(avatarControllerProvider).change(camera: true), isTrue);
    expect(photos.avatarRequests, [true]);
    expect(rpc.paramsOf('set_my_avatar'), [
      {'p_path': 'u/1.jpg'},
    ]);
    expect(storage.removed, ['u/old.jpg']);
  });

  test('الإلغاء من المنتقي لا يغير شيئًا', () async {
    final rpc = FakeRpc();
    final storage = _FakeAvatarStorage();
    final c = _container(rpc: rpc, storage: storage, photos: FakePhotoSource());
    expect(
      await c.read(avatarControllerProvider).change(camera: false),
      isFalse,
    );
    expect(storage.uploaded, isEmpty);
    expect(rpc.calls.where((x) => x.$1 == 'set_my_avatar'), isEmpty);
  });

  test('ملف غير صورة مدعومة يرفض قبل الرفع', () async {
    final storage = _FakeAvatarStorage();
    final c = _container(
      rpc: FakeRpc(),
      storage: storage,
      photos: FakePhotoSource(
        avatar: PickedImage(name: 'a.gif', bytes: Uint8List(16)),
      ),
    );
    await expectLater(
      c.read(avatarControllerProvider).change(camera: false),
      throwsA(isA<AppError>()),
    );
    expect(storage.uploaded, isEmpty);
  });

  test('فشل الضبط يحذف الملف المرفوع ولا يمس القديم', () async {
    final rpc = FakeRpc({'set_my_avatar': (_) => throw StateError('x')});
    final storage = _FakeAvatarStorage();
    final c = _container(
      rpc: rpc,
      storage: storage,
      photos: FakePhotoSource(
        avatar: PickedImage(name: 'a.jpg', bytes: _jpeg),
      ),
      current: 'u/old.jpg',
    );
    await c.read(myAccountProvider.future);
    await expectLater(
      c.read(avatarControllerProvider).change(camera: false),
      throwsA(anything),
    );
    expect(storage.removed, ['u/1.jpg']);
  });

  test('الإزالة تمسح المسار وتحذف الملف', () async {
    final rpc = FakeRpc({'set_my_avatar': (_) => _account()});
    final storage = _FakeAvatarStorage();
    final c = _container(
      rpc: rpc,
      storage: storage,
      photos: FakePhotoSource(),
      current: 'u/old.jpg',
    );
    await c.read(myAccountProvider.future);
    await c.read(avatarControllerProvider).remove();
    expect(rpc.paramsOf('set_my_avatar'), [
      {'p_path': null},
    ]);
    expect(storage.removed, ['u/old.jpg']);
  });
}
