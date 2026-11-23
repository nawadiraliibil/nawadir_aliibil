import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_providers.dart';

/// رسائل جديدة تصل عبر Realtime في المحادثات التي يشارك فيها صاحب الجلسة.
/// سياسة القراءة على `messages` هي التي تحصر ما يصل (طرفا المحادثة فقط).
/// تُستبدل في الاختبارات.
final messageInsertsProvider = Provider<Stream<Map<String, dynamic>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<Map<String, dynamic>>.broadcast();
  final channel = client
      .channel('messages-inserts')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) => controller.add(payload.newRecord),
      )
      .subscribe();
  ref.onDispose(() {
    unawaited(client.removeChannel(channel));
    unawaited(controller.close());
  });
  return controller.stream;
});
