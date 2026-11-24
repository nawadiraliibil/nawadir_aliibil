import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_note.dart';
import '../../account/presentation/menu_group.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/auth_providers.dart';
import '../data/auth_backend.dart';
import '../domain/saudi_phone.dart';
import 'auth_messages.dart';
import 'otp_field.dart';

/// A03 — رمز التحقق، وA05 — تعذر التحقق عند رمز غير صالح.
///
/// نجاح التحقق يفتح الجلسة، فيعيد الحارس في الموجّه توجيه المستخدم إلى وجهته.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phoneE164, this.from});

  final String phoneE164;

  /// الوجهة التي يعود إليها المستخدم بعد الدخول.
  final String? from;

  /// أقل مدة قبل إعادة الإرسال (SRS 10.1). يفرضها الخادم أيضًا.
  static const resendDelay = Duration(seconds: 60);

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  int _secondsLeft = OtpScreen.resendDelay.inSeconds;
  bool _busy = false;
  bool _rejected = false;
  AuthFailureKind? _failure;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = OtpScreen.resendDelay.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, 999));
      if (_secondsLeft == 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (_code.text.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref
          .read(authBackendProvider)
          .verifyOtp(widget.phoneE164, _code.text);
      // نجاح: تغير الجلسة يحرّك الحارس. لا تنقل يدوي هنا.
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.kind == AuthFailureKind.invalidCode) {
          _rejected = true;
        } else {
          _failure = e.kind;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _busy) return;
    setState(() {
      _busy = true;
      _failure = null;
      _rejected = false;
      _code.clear();
    });
    try {
      await ref.read(authBackendProvider).sendOtp(widget.phoneE164);
      if (mounted) _startCountdown();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _failure = e.kind);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _retry() => setState(() {
    _rejected = false;
    _failure = null;
    _code.clear();
  });

  void _changeNumber() => context.go(
    Uri(
      path: Routes.login,
      queryParameters: {if (widget.from != null) 'from': widget.from},
    ).toString(),
  );

  @override
  Widget build(BuildContext context) {
    final phone = SaudiPhone.fromE164(widget.phoneE164);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: _changeNumber,
        ),
        title: Text(_rejected ? 'تعذر التحقق' : 'رمز التحقق'),
      ),
      body: SafeArea(child: _rejected ? _rejectedView() : _entryView(phone)),
    );
  }

  /// A05.
  Widget _rejectedView() => Column(
    children: [
      Expanded(
        child: EmptyState(
          icon: Icons.lock_outline,
          title: 'تعذر تأكيد الرمز',
          message: 'تحقق من الرمز أو اطلب رمزًا جديدًا.',
          actionLabel: 'حاول مجددًا',
          onAction: _retry,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: MenuRow(
          icon: Icons.phone_outlined,
          title: 'تغيير رقم الجوال',
          circleColor: context.colors.tintGold,
          onTap: _changeNumber,
        ),
      ),
    ],
  );

  Widget _entryView(SaudiPhone? phone) {
    final theme = Theme.of(context);
    final canResend = _secondsLeft == 0 && !_busy;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const SizedBox(height: 8),
        Text(
          phone == null
              ? 'أدخل الرمز المكوّن من 6 أرقام.'
              : 'أدخل الرمز المكوّن من 6 أرقام المرسل إلى ${phone.masked}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        OtpField(
          controller: _code,
          enabled: !_busy,
          hasError: _failure != null,
          onChanged: (_) => setState(() => _failure = null),
          onCompleted: (_) => _verify(),
        ),
        if (_failure != null) ...[
          const SizedBox(height: 16),
          AppNote(authFailureMessage(_failure!), kind: AppNoteKind.error),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _code.text.length == 6 && !_busy ? _verify : null,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('تأكيد'),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: _busy ? null : _changeNumber,
              child: const Text('تغيير الرقم'),
            ),
            TextButton(
              onPressed: canResend ? _resend : null,
              child: Text(
                _secondsLeft > 0
                    ? 'إعادة الإرسال بعد $_secondsLeft ثانية'
                    : 'إعادة الإرسال',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
