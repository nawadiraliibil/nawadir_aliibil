import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/widgets/app_note.dart';
import '../application/auth_providers.dart';
import '../data/auth_backend.dart';
import '../domain/saudi_phone.dart';
import 'auth_messages.dart';
import 'dev_login_section.dart';

/// A02 — رقم الجوال: يطلب رمزًا لمرة واحدة.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key, this.from});

  /// الوجهة التي يعود إليها المستخدم بعد الدخول.
  final String? from;

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  AuthFailureKind? _failure;

  SaudiPhone? get _phone => SaudiPhone.tryParse(_controller.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phone;
    if (phone == null || _busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(authBackendProvider).sendOtp(phone.e164);
      if (!mounted) return;
      // go لا push: حارس الدخول يعيد تقييم الموقع الأساسي عند تغير الجلسة.
      context.go(
        Uri(
          path: Routes.loginOtp,
          queryParameters: {if (widget.from != null) 'from': widget.from},
        ).toString(),
        extra: phone.e164,
      );
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _failure = e.kind);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showInvalid = _controller.text.isNotEmpty && _phone == null;
    return Scaffold(
      appBar: AppBar(leading: _backButton(context)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text('رقم الجوال', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'أدخل جوالك لاستلام رمز التحقق.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              enabled: !_busy,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩\s+]')),
                LengthLimitingTextInputFormatter(16),
              ],
              decoration: InputDecoration(
                labelText: 'رقم الجوال',
                hintText: '5X XXX XXXX',
                prefixText: '+966 · السعودية  ',
                errorText: showInvalid
                    ? 'أدخل رقم جوال سعوديًا يبدأ بـ5 ويتكون من 9 أرقام.'
                    : null,
              ),
              onChanged: (_) => setState(() => _failure = null),
              onSubmitted: (_) => _submit(),
            ),
            if (_failure != null) ...[
              const SizedBox(height: 16),
              AppNote(authFailureMessage(_failure!), kind: AppNoteKind.error),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _phone == null || _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('إرسال الرمز'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy ? null : () => _close(context),
              child: const Text('إلغاء'),
            ),
            DevLoginSection(from: widget.from),
          ],
        ),
      ),
    );
  }

  Widget _backButton(BuildContext context) => IconButton(
    tooltip: 'رجوع',
    icon: const Icon(Icons.arrow_forward),
    onPressed: () => _close(context),
  );

  void _close(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(Routes.home);
}
