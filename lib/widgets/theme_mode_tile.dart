// lib/widgets/theme_mode_tile.dart
//
// «Оформление»: как в системе, светлое или тёмное — в «Настройках» и на
// экране «Сервер» (у оператора и специалиста по продажам настроек нет).

import 'package:flutter/material.dart';

import '../services/theme_settings.dart';

/// «Оформление»: как в системе, светлое или тёмное (на этом устройстве).
class ThemeModeTile extends StatelessWidget {
  const ThemeModeTile({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = ThemeSettings.instance;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: settings.mode,
      builder: (context, mode, _) => ListTile(
        leading: const Icon(Icons.brightness_6_outlined),
        title: const Text('Оформление'),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                for (final m in const [
                  ThemeMode.system,
                  ThemeMode.light,
                  ThemeMode.dark,
                ])
                  ButtonSegment(value: m, label: Text(themeModeTitle(m))),
              ],
              selected: {mode},
              onSelectionChanged: (s) => settings.set(s.first),
            ),
          ),
        ),
      ),
    );
  }
}
