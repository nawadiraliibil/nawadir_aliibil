import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/widgets/app_note.dart';
import '../application/account_providers.dart';
import '../data/account_models.dart';

/// تحقق اسم العرض: 2 إلى 40 حرفًا بعد حذف المسافات الطرفية، دون أحرف تحكم.
/// الخادم يفرض القاعدة نفسها؛ هذا لرسالة فورية.
String? validateDisplayName(String raw) {
  final name = raw.trim();
  if (name.length < 2) return 'الاسم لا يقل عن حرفين.';
  if (name.length > 40) return 'الاسم لا يزيد على 40 حرفًا.';
  if (RegExp(r'[\u0000-\u001F\u007F]').hasMatch(name)) {
    return 'الاسم يحوي أحرفًا غير مسموحة.';
  }
  return null;
}

/// نموذج الاسم والمنطقة، مع موافقات النصوص المعلقة إن وُجدت. تستخدمه شاشتا
/// إكمال الحساب (A04) وتعديل الملف (G02).
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.initialName,
    this.initialRegionId,
    this.pendingPolicies = const [],
  });

  final String submitLabel;
  final String? initialName;
  final int? initialRegionId;
  final List<PendingPolicy> pendingPolicies;

  /// يستدعى بعد اجتياز التحقق المحلي. يرمي [AppError] ليعرضه النموذج.
  final Future<void> Function(
    String displayName,
    int regionId,
    List<int> acceptedPolicyIds,
  )
  onSubmit;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  late final _name = TextEditingController(text: widget.initialName);
  int? _regionId;
  final _accepted = <int>{};
  bool _touched = false;
  bool _busy = false;
  AppError? _error;

  @override
  void initState() {
    super.initState();
    _regionId = widget.initialRegionId;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _policiesAccepted =>
      widget.pendingPolicies.every((p) => _accepted.contains(p.id));

  bool get _valid =>
      validateDisplayName(_name.text) == null &&
      _regionId != null &&
      _policiesAccepted;

  Future<void> _submit() async {
    setState(() => _touched = true);
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_name.text.trim(), _regionId!, [
        for (final p in widget.pendingPolicies) p.id,
      ]);
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(publishedSettingsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        TextField(
          controller: _name,
          enabled: !_busy,
          textInputAction: TextInputAction.next,
          maxLength: 40,
          decoration: InputDecoration(
            labelText: 'الاسم المعروض',
            hintText: 'اسمك في التطبيق',
            counterText: '',
            errorText: _touched || _name.text.isNotEmpty
                ? validateDisplayName(_name.text)
                : null,
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 16),
        settings.when(
          data: (s) => DropdownButtonFormField<int>(
            initialValue: s.lookups.region(_regionId)?.id,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'المنطقة',
              errorText: _touched && _regionId == null ? 'اختر منطقتك.' : null,
            ),
            hint: const Text('اختر'),
            items: [
              for (final r in s.lookups.regions)
                DropdownMenuItem(value: r.id, child: Text(r.nameAr)),
            ],
            onChanged: _busy
                ? null
                : (v) => setState(() {
                    _regionId = v;
                    _error = null;
                  }),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppNote(errorMessage(AppError.from(e)), kind: AppNoteKind.error),
              TextButton(
                onPressed: () => ref.invalidate(publishedSettingsProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        if (widget.pendingPolicies.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final p in widget.pendingPolicies)
            _PolicyTile(
              policy: p,
              checked: _accepted.contains(p.id),
              enabled: !_busy,
              onChanged: (v) => setState(() {
                v ? _accepted.add(p.id) : _accepted.remove(p.id);
                _error = null;
              }),
            ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          AppNote(errorMessage(_error!), kind: AppNoteKind.error),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}

class _PolicyTile extends ConsumerWidget {
  const _PolicyTile({
    required this.policy,
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final PendingPolicy policy;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  String get _label => policy.kind == 'PRIVACY'
      ? 'أوافق على سياسة الخصوصية'
      : 'أوافق على شروط الاستخدام';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            value: checked,
            onChanged: enabled ? (v) => onChanged(v ?? false) : null,
            title: Text(_label),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        TextButton(
          onPressed: () => _read(context, ref),
          child: const Text('قراءة'),
        ),
      ],
    );
  }

  void _read(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final docs = ref.watch(currentPoliciesProvider);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.7,
              ),
              child: docs.when(
                loading: () => const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: AppNote(
                    errorMessage(AppError.from(e)),
                    kind: AppNoteKind.error,
                  ),
                ),
                data: (list) {
                  final doc = list.where((d) => d.id == policy.id).firstOrNull;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    shrinkWrap: true,
                    children: [
                      Text(
                        doc?.title ?? policy.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(doc?.body ?? 'تعذّر تحميل النص.'),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
