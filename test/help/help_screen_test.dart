import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfx_time_tracking/help/help_content.dart';
import 'package:kfx_time_tracking/screens/help_screen.dart';

/// Справка по ролям (шаг 4 «Дальнейших работ»).
void main() {
  test('разделы по ролям: у каждой роли — своё', () {
    final operator = helpFor(HelpRole.operator).map((c) => c.id).toList();
    final accountant = helpFor(HelpRole.accountant).map((c) => c.id).toList();
    final admin = helpFor(HelpRole.admin).map((c) => c.id).toList();
    expect(operator, containsAll(['phone-input', 'timesheet', 'sign-in']));
    expect(operator, isNot(contains('payments')));
    expect(accountant, containsAll(['payments', 'reports', 'periods']));
    expect(accountant, isNot(contains('backups')));
    expect(admin, containsAll([...accountant, 'audit', 'backups']));
  });

  test('картинки справки сняты (иначе — KFH_HELP_SHOTS, см. тест снимков)', () {
    for (final name in helpImageNames) {
      expect(File('assets/help/$name.png').existsSync(), isTrue, reason: name);
    }
  });

  test('ни в одном разделе нет пустых кусков для роли', () {
    for (final role in HelpRole.values) {
      for (final c in helpFor(role)) {
        expect(c.blocksFor(role), isNotEmpty, reason: '${c.id} / $role');
      }
    }
  });

  testWidgets('справка: своя роль, смена роли, раздел и переход дальше', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: HelpScreen(role: HelpRole.operator)),
    );
    expect(find.text('Табель на телефоне: ввод за день'), findsOneWidget);
    expect(find.text('Выплаты'), findsNothing);

    await tester.tap(find.text('Бухгалтер'));
    await tester.pumpAndSettle();
    expect(find.text('Выплаты'), findsOneWidget);
    expect(find.text('Резервные копии'), findsNothing);

    await tester.tap(find.text('Выплаты'));
    await tester.pumpAndSettle();
    expect(find.text('Выплаты за месяц'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    await tester.tap(find.text('Главная'));
    await tester.pumpAndSettle();
    expect(find.text('Главная'), findsWidgets);
    expect(find.textContaining('Долг'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
