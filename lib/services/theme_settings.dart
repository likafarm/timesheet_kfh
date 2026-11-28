// lib/services/theme_settings.dart
//
// Оформление программы: как в системе (по умолчанию), светлое или тёмное.
// Выбор хранится на этом устройстве (SharedPreferences), меняется в
// «Настройки → Оформление» и сразу применяется ко всему окну.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeSettings {
  ThemeSettings._();
  static final instance = ThemeSettings._();

  static const _key = 'kfh_theme_mode';

  /// Текущее оформление; MaterialApp слушает его.
  final mode = ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Прочитать сохранённый выбор (не дольше 2 с — иначе как в системе).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      mode.value = _parse(prefs.getString(_key));
    } catch (_) {
      // Нет хранилища — остаётся «как в системе».
    }
  }

  Future<void> set(ThemeMode value) async {
    mode.value = value;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      await prefs.setString(_key, value.name);
    } catch (_) {
      // Не сохранилось — действует до перезапуска.
    }
  }

  static ThemeMode _parse(String? s) => ThemeMode.values.firstWhere(
    (m) => m.name == s,
    orElse: () => ThemeMode.system,
  );
}

/// Название оформления для человека.
String themeModeTitle(ThemeMode m) => switch (m) {
  ThemeMode.system => 'Как в системе',
  ThemeMode.light => 'Светлое',
  ThemeMode.dark => 'Тёмное',
};
