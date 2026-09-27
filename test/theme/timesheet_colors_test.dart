import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfx_time_tracking/theme/app_theme.dart';

/// Контраст текста табеля на всех фонах — не меньше 4.5:1 (WCAG AA) в
/// светлой и тёмной теме: в тёмной теме итоги были светлыми с белым
/// текстом и не читались.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets('контраст табеля: ${theme.brightness.name}', (tester) async {
      late TimesheetColors c;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              c = TimesheetColors.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      final surface = theme.colorScheme.surface;
      for (final (name, bg) in [
        ('работа', c.work),
        ('больничный', c.sick),
        ('отпуск', c.vacation),
        ('выходной', c.dayoff),
        ('итог', c.total),
        ('итог 2', c.totalAlt),
        ('сегодня', c.today),
        ('фон', surface),
      ]) {
        expect(
          _contrast(c.text, bg),
          greaterThanOrEqualTo(4.5),
          reason: '$name: текст на фоне',
        );
      }
      expect(_contrast(c.weekendText, c.weekend), greaterThanOrEqualTo(4.5));
    });
  }
}
