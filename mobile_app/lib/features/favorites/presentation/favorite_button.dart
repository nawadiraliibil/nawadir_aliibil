import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../auth/application/auth_providers.dart';
import '../application/favorites_providers.dart';

/// زر القلب: يحفظ الإعلان في المفضلة أو يزيله. الزائر يُوجَّه إلى الدخول ثم يعود.
class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({
    super.key,
    required this.listingId,
    this.initial = false,
  });

  final String listingId;

  /// الحالة المعروفة قبل تحميل القائمة (مثل `is_favorite` في التفاصيل).
  final bool initial;

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  var _busy = false;

  Future<void> _toggle(bool saved) async {
    final signedIn = ref.read(signedInProvider).value ?? false;
    if (!signedIn) {
      final from = GoRouterState.of(context).uri.toString();
      context.push(
        Uri(path: Routes.login, queryParameters: {'from': from}).toString(),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final notifier = ref.read(favoritesProvider.notifier);
      if (saved) {
        await notifier.remove(widget.listingId);
      } else {
        await notifier.add(widget.listingId);
      }
    } on Object catch (e) {
      final err = AppError.from(e);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            err.code == AppErrorCode.notFound
                ? 'الإعلان لم يعد متاحًا.'
                : errorMessage(err),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved =
        ref.watch(isFavoriteProvider(widget.listingId)) ?? widget.initial;
    final c = context.colors;
    return IconButton(
      tooltip: saved ? 'إزالة من المفضلة' : 'حفظ في المفضلة',
      onPressed: _busy ? null : () => _toggle(saved),
      icon: Icon(
        saved ? Icons.favorite : Icons.favorite_border,
        color: saved ? c.error : c.muted,
      ),
    );
  }
}
