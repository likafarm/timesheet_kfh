import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

/// Производственный календарь РФ (6.6): итоги по годам — как в
/// официальных календарях, переносы — по постановлениям.
void main() {
  CalendarDayKind kind(int y, int m, int d) =>
      ProductionCalendar.kindOf(DateTime(y, m, d));

  test('годы 2025–2027: 247 рабочих и 118 нерабочих дней', () {
    for (final y in [2025, 2026, 2027]) {
      expect(ProductionCalendar.knows(y), isTrue);
      var work = 0, off = 0, short = 0;
      for (var m = 1; m <= 12; m++) {
        final norm = ProductionCalendar.monthNorm(y, m);
        work += norm.workdays;
        short += norm.shortDays;
        off += ProductionCalendar.daysOff(y, m).length;
      }
      expect((work, off), (247, 118), reason: '$y');
      expect(short, 4, reason: '$y: сокращённых');
    }
  });

  test('2026: новогодние каникулы, переносы, сокращённые дни', () {
    for (var d = 1; d <= 11; d++) {
      expect(
        ProductionCalendar.isWorkingDay(DateTime(2026, 1, d)),
        isFalse,
        reason: '$d января',
      );
    }
    expect(kind(2026, 1, 12), CalendarDayKind.workday);
    expect(kind(2026, 1, 7), CalendarDayKind.holiday);
    // 3 января (суббота) перенесено на 9 января (пятница).
    expect(kind(2026, 1, 9), CalendarDayKind.dayOff);
    expect(
      ProductionCalendar.note(DateTime(2026, 1, 9)),
      'Перенесённый выходной',
    );
    // 8 марта — воскресенье, отдыхаем 9 марта.
    expect(kind(2026, 3, 9), CalendarDayKind.dayOff);
    expect(kind(2026, 4, 30), CalendarDayKind.shortWorkday);
    expect(ProductionCalendar.note(DateTime(2026, 4, 30)), 'Сокращённый день');
    expect(kind(2026, 12, 31), CalendarDayKind.dayOff);
    expect(ProductionCalendar.monthNorm(2026, 9), (workdays: 22, shortDays: 0));
    expect(ProductionCalendar.monthNorm(2026, 1), (workdays: 15, shortDays: 0));
  });

  test('2027: рабочая суббота 20 февраля, отдых 22–23 февраля и 5 ноября', () {
    expect(kind(2027, 2, 20), CalendarDayKind.shortWorkday);
    expect(
      ProductionCalendar.note(DateTime(2027, 2, 20)),
      'Рабочий день (перенос), сокращённый',
    );
    expect(kind(2027, 2, 22), CalendarDayKind.dayOff);
    expect(kind(2027, 2, 23), CalendarDayKind.holiday);
    expect(kind(2027, 11, 5), CalendarDayKind.dayOff);
    expect(kind(2027, 12, 31), CalendarDayKind.dayOff);
    for (var d = 1; d <= 10; d++) {
      expect(ProductionCalendar.isWorkingDay(DateTime(2027, 1, d)), isFalse);
    }
  });

  test('год без данных — обычная пятидневка', () {
    expect(ProductionCalendar.knows(2030), isFalse);
    expect(kind(2030, 1, 1), CalendarDayKind.workday, reason: 'вторник');
    expect(kind(2030, 1, 5), CalendarDayKind.dayOff, reason: 'суббота');
    expect(ProductionCalendar.note(DateTime(2030, 1, 5)), isNull);
  });
}
