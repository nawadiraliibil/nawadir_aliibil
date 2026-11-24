import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:nawadir_aliibil/features/listing/data/video_playback.dart';

import 'fake_rpc.dart';

/// رد الإعدادات المنشورة مع تفعيل الفيديو (أو تعطيله) لاختبارات الواجهة.
Map<String, dynamic> settingsWithVideo({bool enabled = true}) {
  final base = Map<String, dynamic>.from(fixture('published-settings') as Map);
  final settings = Map<String, dynamic>.from(base['settings'] as Map);
  settings['media'] = {
    ...Map<String, dynamic>.from(settings['media'] as Map),
    'video_enabled': enabled,
  };
  return base..['settings'] = settings;
}

/// مشغل مزيف: لا يشغل video_player الحقيقي. يسجل عمليات التشغيل.
class FakeVideoPlayback implements VideoPlayback {
  FakeVideoPlayback(this.url, {this.failInit = false});

  final String url;
  final bool failInit;
  final events = <String>[];
  final _snap = ValueNotifier(const VideoSnapshot());
  var disposed = false;

  @override
  ValueListenable<VideoSnapshot> get snapshot => _snap;

  @override
  Future<void> initialize() async {
    events.add('initialize');
    if (failInit) throw StateError('init failed');
    _snap.value = const VideoSnapshot(initialized: true);
  }

  @override
  Future<void> play() async {
    events.add('play');
    _snap.value = const VideoSnapshot(initialized: true, playing: true);
  }

  @override
  Future<void> pause() async {
    events.add('pause');
    _snap.value = const VideoSnapshot(initialized: true);
  }

  @override
  Widget buildView() => const SizedBox.expand(key: ValueKey('fake-video'));

  @override
  Future<void> dispose() async => disposed = true;
}
