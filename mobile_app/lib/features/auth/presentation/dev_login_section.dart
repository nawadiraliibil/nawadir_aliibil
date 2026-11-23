import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';

import '../../../core/widgets/app_note.dart';
import '../application/auth_providers.dart';
import '../data/auth_backend.dart';
import 'auth_messages.dart';

/// دخول بديل بالبريد وكلمة المرور **لبيئة التطوير فقط**، لتجربة التطبيق قبل ربط
/// مزود رسائل نصية. لا يظهر في بناء الإنتاج ولا خارج `APP_ENV=dev`. نجاحه يفتح
/// جلسة حقيقية فيعيد الحارس المستخدم إلى وجهته كما في الدخول بالهاتف.
class DevLoginSection extends ConsumerStatefulWidget {
  const DevLoginSection({super.key, this.from});

  /// الوجهة التي يعود إليها المستخدم بعد الدخول.
  final String? from;

  @override
  ConsumerState<DevLoginSection> createState() => _DevLoginSectionState();
}

class _DevLoginSectionState extends ConsumerState<DevLoginSection> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  AuthFailureKind? _failure;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _email.text.trim().isEmpty || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref
          .read(authBackendProvider)
          .signInWithPassword(_email.text.trim(), _password.text);
      // توجيه صريح: الشاشة قد تكون وصلت بتحويل من push فلا يعيد الحارس تقييمها.
      if (mounted) context.go(Routes.safeFrom(widget.from));
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _failure = e.kind);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(devLoginEnabledProvider)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: ExpansionTile(
        title: const Text('دخول للتطوير (بريد)'),
        subtitle: const Text('يظهر في بيئة التطوير فقط'),
        childrenPadding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          TextField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'البريد'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: true,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'كلمة المرور'),
            onSubmitted: (_) => _submit(),
          ),
          if (_failure != null) ...[
            const SizedBox(height: 12),
            AppNote(
              _failure == AuthFailureKind.invalidCode
                  ? 'بيانات الدخول غير صحيحة.'
                  : authFailureMessage(_failure!),
              kind: AppNoteKind.error,
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: _busy ? null : _submit,
            child: const Text('دخول للتطوير'),
          ),
        ],
      ),
    );
  }
}
