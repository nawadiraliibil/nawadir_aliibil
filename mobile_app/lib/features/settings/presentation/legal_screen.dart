import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_note.dart';
import '../../../core/widgets/section_title.dart';
import '../../account/application/account_providers.dart';
import '../../account/data/account_models.dart';
import '../../account/presentation/menu_group.dart';

/// أسئلة شائعة بسيطة. لا رقم دعم ولا بريد مختلق: قناة الدعم الرسمية تعلن مع الإطلاق.
const faq = <(String, String)>[
  (
    'كيف أنشر إعلانًا؟',
    'اضغط «إعلان» في الشريط السفلي، واختر نوع العرض، وأدخل بيانات الإبل وصورها ثم انشره. يظهر الإعلان فور نشره.',
  ),
  (
    'لماذا لم يظهر إعلاني بعد؟',
    'الإعلان يُنشر فور إرساله. تجد حالته في «حسابي ← إعلاناتي»، وقد تخفيه الإدارة إن خالف الشروط وتجد السبب هناك.',
  ),
  (
    'كيف أتواصل مع المعلن؟',
    'من صفحة الإعلان: «راسل المعلن» لمحادثة خاصة، أو الاتصال وواتساب إن فعّلهما المعلن. المعلومات المعروضة إفادة من المعلن.',
  ),
  (
    'كيف أبلّغ عن إعلان أو مستخدم؟',
    'من قائمة «المزيد» في صفحة الإعلان أو المحادثة أو ملف المعلن، واختر السبب. بلاغك خاص ولا يظهر لمن تبلّغ عنه.',
  ),
  (
    'ماذا يعني التقييم؟',
    'يعبّر عن تجربة المقيّم في التعامل بعد تبادل رسائل مع المعلن، ولا يثبت عملية شراء.',
  ),
];

/// الشروط والخصوصية والمساعدة (G09): قائمة نصوص ساري بقارئ، وأسئلة شائعة.
/// النص المؤقت يوسم صراحة بأنه ينتظر النص القانوني المعتمد.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(currentPoliciesProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'رجوع',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.account),
        ),
        title: const Text('الشروط والمساعدة'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const SectionTitle('الشروط والخصوصية'),
            const SizedBox(height: 12),
            docs.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Column(
                children: [
                  Text(errorMessage(AppError.from(e))),
                  TextButton(
                    onPressed: () => ref.invalidate(currentPoliciesProvider),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
              data: (list) => MenuGroup(
                children: [
                  for (final d in list)
                    MenuRow(
                      key: ValueKey('policy-${d.kind}'),
                      icon: d.kind == 'PRIVACY'
                          ? Icons.lock_outline
                          : Icons.description_outlined,
                      title: d.title,
                      subtitle: 'اقرأ النص كاملًا',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PolicyReader(document: d),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle('مساعدة'),
            const SizedBox(height: 4),
            for (final (q, a) in faq)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(q, style: Theme.of(context).textTheme.titleSmall),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.muted,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// قارئ نص سياسة كامل.
class PolicyReader extends StatelessWidget {
  const PolicyReader({super.key, required this.document});

  final PolicyDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (document.isPlaceholder)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: AppNote(
                  'هذا نص مؤقت ينتظر اعتماد النص القانوني، وليس الشروط النهائية.',
                ),
              ),
            Text(document.body, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
