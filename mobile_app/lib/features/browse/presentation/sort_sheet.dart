import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_shapes.dart';
import '../data/listing_card.dart';

/// ورقة الترتيب (B04) المستقلة عن التصفية: ورقة سفلية قصيرة لأن الخيارات
/// قليلة. تعيد الترتيب المختار فور النقر، أو null عند الإغلاق دون اختيار.
Future<SearchSort?> showSortSheet(BuildContext context, SearchSort current) =>
    showModalBottomSheet<SearchSort>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SortSheet(selected: current),
    );

class SortSheet extends StatelessWidget {
  const SortSheet({super.key, required this.selected});

  final SearchSort selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                'ترتيب النتائج',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            _SortList(
              selected: selected,
              onChanged: (s) => Navigator.of(context).pop(s),
            ),
          ],
        ),
      ),
    );
  }
}

/// قائمة خيارات الترتيب (B04): صفوف مملوءة بفواصل رفيعة ودائرة اختيار.
class _SortList extends StatelessWidget {
  const _SortList({required this.selected, required this.onChanged});

  final SearchSort selected;
  final ValueChanged<SearchSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.soft,
        borderRadius: BorderRadius.circular(AppShapes.card),
      ),
      child: Column(
        children: [
          for (final (i, s) in SearchSort.values.indexed) ...[
            if (i > 0) Divider(height: 1, color: c.hair),
            Semantics(
              inMutuallyExclusiveGroup: true,
              checked: selected == s,
              child: InkWell(
                key: ValueKey('sort-${s.wire}'),
                onTap: () => onChanged(s),
                borderRadius: BorderRadius.circular(AppShapes.card),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppShapes.minTouchTarget,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            selected == s
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: selected == s ? c.gold : c.muted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(s.label)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
