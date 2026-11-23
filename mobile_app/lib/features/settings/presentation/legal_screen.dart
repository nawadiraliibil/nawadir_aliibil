import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_messages.dart';
import '../../../core/widgets/app_note.dart';
import '../../account/application/account_providers.dart';
import '../../account/data/account_models.dart';

/// أسئلة شائعة بسيطة. لا رقم دعم ولا بريد مختلق: قناة الدعم الرسمية تعلن مع الإطلاق.
const faq = <(String, String)>[
  (
    'كيف أنشر إعلانًا؟',
    'اضغط «إعلان» في الشريط السفلي، واختر نوع العرض، وأدخل بيانات الإبل وصورها ثم أرسله للمراجعة. يظهر الإعلان بعد اعتماده.',
  ),
  (
    'لماذا لم يظهر إعلاني بعد؟',
    'كل إعلان يراجع قبل نشره. تجد حالته في «حسابي ← إعلاناتي»، وإن رُفض تجد السبب هناك وتستطيع تعديله وإعادة إرساله.',
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
          icon: const Icon(Icons.arrow_forward),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.account),
        ),
        title: const Text('الشروط والخصوصية والمساعدة'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'الشروط والسياسات',
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
              data: (list) => Column(
                children: [
                  for (final d in list)
                    ListTile(
                      key: ValueKey('policy-${d.kind}'),
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        d.kind == 'PRIVACY'
                            ? Icons.privacy_tip_outlined
                            : Icons.gavel_outlined,
                      ),
                      title: Text(d.title),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PolicyReader(document: d),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            Text('أسئلة شائعة', style: Theme.of(context).textTheme.titleMedium),
            for (final (q, a) in faq)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(q),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(a)],
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
