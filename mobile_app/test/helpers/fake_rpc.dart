import 'dart:convert';
import 'dart:io';

import 'package:nawadir_aliibil/core/supabase/rpc.dart';

/// أمثلة العقد المسجلة من الخادم (`contracts/fixtures`).
dynamic fixture(String name) =>
    jsonDecode(File('../contracts/fixtures/$name.json').readAsStringSync());

typedef RpcHandler = dynamic Function(Map<String, dynamic>? params);

/// دوال خلفية مزيفة للاختبارات. الدالة غير المضبوطة ترمي حتى لا يمر استدعاء
/// غير متوقع بصمت.
class FakeRpc {
  FakeRpc([Map<String, RpcHandler>? handlers])
    : handlers = {
        'get_published_settings': (_) => fixture('published-settings'),
        'get_current_policies': (_) => fixture('current-policies'),
        'search_listings': (_) => fixture('search-result'),
        ...?handlers,
      };

  final Map<String, RpcHandler> handlers;
  final calls = <(String, Map<String, dynamic>?)>[];

  RpcCaller get caller => (fn, {params}) async {
    calls.add((fn, params));
    final h = handlers[fn];
    if (h == null) throw StateError('rpc غير مضبوط: $fn');
    return h(params);
  };

  Iterable<Map<String, dynamic>?> paramsOf(String fn) =>
      calls.where((c) => c.$1 == fn).map((c) => c.$2);
}

/// خادم مسودات مزيف: ينشئ مسودة ويطبق الرقع على نسخة ويعيد شكل رد المعلن.
class FakeListingServer {
  FakeListingServer({this.failNextSave});

  static const listingId = '4670cf73-a453-4293-927d-d97e0a512f14';

  /// خطأ يُرمى مرة واحدة عند الحفظ التالي.
  Object? failNextSave;

  final version = <String, dynamic>{};

  /// أخطاء تُرمى بالترتيب عند الإرسال (واحد لكل استدعاء، ثم نجاح).
  final submitFailures = <Object>[];
  final submitRequestIds = <String>[];
  final patches = <Map<String, dynamic>>[];
  final createRequestIds = <String>[];
  var createCalls = 0;

  Map<String, dynamic> _owner() {
    final base = Map<String, dynamic>.from(
      fixture('listing-owner-draft') as Map,
    );
    final v = Map<String, dynamic>.from(base['version'] as Map);
    for (final k in v.keys.toList()) {
      if (!{
        'id',
        'listing_id',
        'version_no',
        'status',
        'created_at',
        'updated_at',
        'decided_at',
      }.contains(k)) {
        v[k] = null;
      }
    }
    v.addAll(version);
    base['version'] = v;
    base['media'] = <dynamic>[];
    return base;
  }

  Map<String, RpcHandler> get handlers => {
    'create_listing_draft': (p) {
      createCalls++;
      createRequestIds.add(p!['p_request_id'] as String);
      return _owner();
    },
    'submit_listing': (p) {
      submitRequestIds.add(p!['p_request_id'] as String);
      if (submitFailures.isNotEmpty) throw submitFailures.removeAt(0);
      return _owner();
    },
    'save_listing_draft': (p) {
      final fail = failNextSave;
      if (fail != null) {
        failNextSave = null;
        throw fail;
      }
      final patch = Map<String, dynamic>.from(p!['p_patch'] as Map);
      patches.add(patch);
      for (final e in patch.entries) {
        if (e.key == 'owner_declaration') {
          version['owner_declaration_at'] = e.value == true
              ? '2026-11-23T00:00:00+00:00'
              : null;
        } else {
          version[e.key] = e.value;
        }
      }
      return _owner();
    },
  };
}
