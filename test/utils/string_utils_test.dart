import 'package:flutter_test/flutter_test.dart';
import 'package:kfx_time_tracking/utils/string_utils.dart';

void main() {
  group('getShortName', () {
    test('полное ФИО', () {
      expect(StringUtils.getShortName('Иванов Иван Иванович'), 'Иванов И. И.');
    });

    test('только фамилия', () {
      expect(StringUtils.getShortName('Иванов'), 'Иванов');
    });

    test('фамилия и имя', () {
      expect(StringUtils.getShortName('Иванов Иван'), 'Иванов И.');
    });

    test('лишние пробелы', () {
      expect(
        StringUtils.getShortName('  Иванов   Иван    Иванович '),
        'Иванов И. И.',
      );
    });

    test('двойное имя', () {
      expect(
        StringUtils.getShortName('Петрова Анна-Мария Сергеевна'),
        'Петрова А. С.',
      );
    });

    test('пустая строка не падает', () {
      expect(StringUtils.getShortName(''), '');
      expect(StringUtils.getShortName('   '), '');
    });
  });

  group('formatDayRate', () {
    test('нет ставки', () {
      expect(StringUtils.formatDayRate(null), 'нет ставки');
    });

    test('содержит сумму и единицы', () {
      final s = StringUtils.formatDayRate(1500);
      expect(s, endsWith('₽/день'));
      expect(s.replaceAll(RegExp(r'\s'), ''), '1500₽/день');
    });
  });

  test('workPlaceLabel', () {
    expect(StringUtils.workPlaceLabel('other'), 'other');
    expect(StringUtils.workPlaceLabel('base'), 'База (нет ставки)');
    expect(
      StringUtils.workPlaceLabel('field', fieldRate: 900),
      startsWith('Поле (900'),
    );
  });
}
