import 'package:flutter/material.dart';

import 'wasm_ring.dart';

/// عنوان قسم تسبقه حلقة «الوسم»، مع إجراء اختياري في نهاية السطر.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;

  /// إجراء في نهاية السطر، مثل «عرض الكل».
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const WasmRing(),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
