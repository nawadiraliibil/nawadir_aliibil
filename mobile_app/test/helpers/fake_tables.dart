import 'package:nawadir_aliibil/core/supabase/rest.dart';

/// جداول مزيفة للقراءة المباشرة: علاقة ← صفوفها. تطبق مرشح المساواة والحد
/// وترتيب بسيطًا، وتسجل الطلبات.
class FakeTables {
  FakeTables([Map<String, List<Map<String, dynamic>>>? rows])
    : rows = rows ?? {};

  final Map<String, List<Map<String, dynamic>>> rows;
  final requests = <String>[];

  /// خطأ يُرمى عند قراءة علاقة معينة مرة واحدة.
  final failures = <String, Object>{};

  TableReader get reader =>
      (relation, {eq, orderBy, ascending = true, limit}) async {
        requests.add(relation);
        final failure = failures.remove(relation);
        if (failure != null) throw failure;
        var out = [...?rows[relation]];
        for (final e in (eq ?? const <String, Object>{}).entries) {
          out = out.where((r) => r[e.key] == e.value).toList();
        }
        if (orderBy != null) {
          out.sort((a, b) {
            final c = Comparable.compare(
              a[orderBy] as Comparable,
              b[orderBy] as Comparable,
            );
            return ascending ? c : -c;
          });
        }
        if (limit != null && out.length > limit) out = out.sublist(0, limit);
        return out;
      };
}

/// ملفات حُذفت من التخزين، بترتيب الطلب.
class FakeStorage {
  final removed = <(String, List<String>)>[];

  StorageRemover get remover =>
      (bucket, paths) async => removed.add((bucket, paths));
}
