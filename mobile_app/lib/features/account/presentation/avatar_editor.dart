import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/widgets/initial_avatar.dart';
import '../application/avatar_controller.dart';
import '../data/account_models.dart';
import '../data/avatar_storage.dart';

/// الصورة الشخصية في تعديل الملف: الضغط يفتح ورقة (المعرض، الكاميرا، إزالة).
/// التغيير يُحفظ فورًا ولا ينتظر زر «حفظ التغييرات».
class AvatarEditor extends ConsumerStatefulWidget {
  const AvatarEditor({super.key, required this.account});

  final MyAccount account;

  @override
  ConsumerState<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends ConsumerState<AvatarEditor> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(AppError.from(e)))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open() async {
    final hasPhoto = widget.account.avatarPath != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('التقاط صورة'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('إزالة الصورة'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final controller = ref.read(avatarControllerProvider);
    await _run(() async {
      if (choice == 'remove') {
        await controller.remove();
      } else {
        await controller.change(camera: choice == 'camera');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final path = widget.account.avatarPath;
    return Center(
      child: Semantics(
        button: true,
        label: 'تغيير الصورة الشخصية',
        child: GestureDetector(
          key: const ValueKey('avatar-editor'),
          onTap: _busy ? null : _open,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InitialAvatar(
                name: widget.account.displayName,
                imageUrl: path == null
                    ? null
                    : ref.watch(avatarStorageProvider).urlFor(path),
                radius: 48,
                background: c.tintGold,
                foreground: c.gold,
                textStyle: theme.textTheme.headlineMedium,
              ),
              if (_busy)
                const SizedBox.square(
                  dimension: 96,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              PositionedDirectional(
                bottom: 0,
                end: 0,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: c.gold,
                  child: Icon(
                    Icons.photo_camera,
                    size: 16,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
