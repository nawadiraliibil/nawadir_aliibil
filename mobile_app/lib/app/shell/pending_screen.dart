import 'package:flutter/material.dart';

import '../../core/widgets/empty_state.dart';

/// شاشة مؤقتة لوجهة لم تُنفذ بعد.
///
/// موسومة صراحة بأنها غير منفذة وبمعرف المهمة التي ستنفذها؛ ليست من التصميم
/// المعتمد وتُستبدل عند تنفيذ الميزة.
class PendingScreen extends StatelessWidget {
  const PendingScreen({
    super.key,
    required this.title,
    required this.task,
    this.appBar,
  });

  /// اسم الوجهة.
  final String title;

  /// معرف المهمة التي ستنفذ هذه الشاشة.
  final String task;

  /// ترويسة بديلة؛ الافتراضية عنوان الوجهة.
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar ?? AppBar(title: Text(title)),
      body: SafeArea(
        child: EmptyState(
          icon: Icons.construction_outlined,
          title: '$title: قيد التنفيذ',
          message: 'هذه الشاشة لم تُنفذ بعد. المهمة: $task',
        ),
      ),
    );
  }
}
