import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_repository.dart';

/// اختيار المظهر: يتبع النظام افتراضيًا، ويحفظ على الجهاز (G06).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const key = 'theme_mode.v1';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final raw = await ref.read(sharedPreferencesProvider).getString(key);
    final mode = ThemeMode.values.where((m) => m.name == raw).firstOrNull;
    if (mode != null && ref.mounted) state = mode;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
