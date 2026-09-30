// packages/domain/lib/src/production_calendar.dart
//
// Производственный календарь РФ (этап 6.6, решение владельца 2026-09-29):
// нерабочие (выходные и праздничные) и сокращённые предпраздничные дни по
// годам — встроены в программу, новые годы приходят с обновлением.
// Своей правки календаря нет. Для лет без данных — обычная пятидневка
// (суббота и воскресенье).
//
// Источники (сверены день в день): 2025, 2026 — КонсультантПлюс и
// xmlcalendar.ru; 2027 — КонсультантПлюс и duma.gov.ru (постановление
// Правительства РФ от 17.09.2026 № 1187 «О переносе выходных дней в 2027
// году»). В каждом году 247 рабочих дней.

/// Нерабочие праздничные дни (ст. 112 ТК РФ): месяц → числа.
const _statutoryHolidays = <int, Set<int>>{
  1: {1, 2, 3, 4, 5, 6, 7, 8},
  2: {23},
  3: {8},
  5: {1, 9},
  6: {12},
  11: {4},
};

/// Год → по месяцам (нерабочие дни, сокращённые рабочие дни).
const _years = <int, List<(List<int>, List<int>)>>{
  2025: [
    ([1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 18, 19, 25, 26], []), // 01
    ([1, 2, 8, 9, 15, 16, 22, 23], []), // 02
    ([1, 2, 8, 9, 15, 16, 22, 23, 29, 30], [7]), // 03
    ([5, 6, 12, 13, 19, 20, 26, 27], [30]), // 04
    ([1, 2, 3, 4, 8, 9, 10, 11, 17, 18, 24, 25, 31], []), // 05
    ([1, 7, 8, 12, 13, 14, 15, 21, 22, 28, 29], [11]), // 06
    ([5, 6, 12, 13, 19, 20, 26, 27], []), // 07
    ([2, 3, 9, 10, 16, 17, 23, 24, 30, 31], []), // 08
    ([6, 7, 13, 14, 20, 21, 27, 28], []), // 09
    ([4, 5, 11, 12, 18, 19, 25, 26], []), // 10
    ([2, 3, 4, 8, 9, 15, 16, 22, 23, 29, 30], [1]), // 11
    ([6, 7, 13, 14, 20, 21, 27, 28, 31], []), // 12
  ],
  2026: [
    ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 17, 18, 24, 25, 31], []), // 01
    ([1, 7, 8, 14, 15, 21, 22, 23, 28], []), // 02
    ([1, 7, 8, 9, 14, 15, 21, 22, 28, 29], []), // 03
    ([4, 5, 11, 12, 18, 19, 25, 26], [30]), // 04
    ([1, 2, 3, 9, 10, 11, 16, 17, 23, 24, 30, 31], [8]), // 05
    ([6, 7, 12, 13, 14, 20, 21, 27, 28], [11]), // 06
    ([4, 5, 11, 12, 18, 19, 25, 26], []), // 07
    ([1, 2, 8, 9, 15, 16, 22, 23, 29, 30], []), // 08
    ([5, 6, 12, 13, 19, 20, 26, 27], []), // 09
    ([3, 4, 10, 11, 17, 18, 24, 25, 31], []), // 10
    ([1, 4, 7, 8, 14, 15, 21, 22, 28, 29], [3]), // 11
    ([5, 6, 12, 13, 19, 20, 26, 27, 31], []), // 12
  ],
  2027: [
    ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 16, 17, 23, 24, 30, 31], []), // 01
    ([6, 7, 13, 14, 21, 22, 23, 27, 28], [20]), // 02
    ([6, 7, 8, 13, 14, 20, 21, 27, 28], []), // 03
    ([3, 4, 10, 11, 17, 18, 24, 25], [30]), // 04
    ([1, 2, 3, 8, 9, 10, 15, 16, 22, 23, 29, 30], []), // 05
    ([5, 6, 12, 13, 14, 19, 20, 26, 27], [11]), // 06
    ([3, 4, 10, 11, 17, 18, 24, 25, 31], []), // 07
    ([1, 7, 8, 14, 15, 21, 22, 28, 29], []), // 08
    ([4, 5, 11, 12, 18, 19, 25, 26], []), // 09
    ([2, 3, 9, 10, 16, 17, 23, 24, 30, 31], []), // 10
    ([4, 5, 6, 7, 13, 14, 20, 21, 27, 28], [3]), // 11
    ([4, 5, 11, 12, 18, 19, 25, 26, 31], []), // 12
  ],
};

/// Вид дня по производственному календарю.
enum CalendarDayKind {
  /// Рабочий день.
  workday,

  /// Рабочий, сокращённый на час (предпраздничный).
  shortWorkday,

  /// Выходной (суббота, воскресенье или перенесённый выходной).
  dayOff,

  /// Нерабочий праздничный день (ст. 112 ТК РФ).
  holiday,
}

class ProductionCalendar {
  const ProductionCalendar._();

  /// Годы, за которые календарь известен.
  static Iterable<int> get years => _years.keys;

  static bool knows(int year) => _years.containsKey(year);

  static CalendarDayKind kindOf(DateTime day) {
    final months = _years[day.year];
    if (months == null) {
      return day.weekday >= DateTime.saturday
          ? CalendarDayKind.dayOff
          : CalendarDayKind.workday;
    }
    final (off, short) = months[day.month - 1];
    if (off.contains(day.day)) {
      return _statutoryHolidays[day.month]?.contains(day.day) ?? false
          ? CalendarDayKind.holiday
          : CalendarDayKind.dayOff;
    }
    return short.contains(day.day)
        ? CalendarDayKind.shortWorkday
        : CalendarDayKind.workday;
  }

  /// Рабочий ли день (в том числе сокращённый и рабочая суббота).
  static bool isWorkingDay(DateTime day) {
    final kind = kindOf(day);
    return kind == CalendarDayKind.workday ||
        kind == CalendarDayKind.shortWorkday;
  }

  /// Пояснение к дню, если он не обычный: праздник, перенесённый выходной,
  /// рабочая суббота или воскресенье, сокращённый день. null — обычный
  /// рабочий день или обычные суббота и воскресенье.
  static String? note(DateTime day) {
    final weekend = day.weekday >= DateTime.saturday;
    return switch (kindOf(day)) {
      CalendarDayKind.holiday => 'Праздничный день',
      CalendarDayKind.dayOff when !weekend => 'Перенесённый выходной',
      CalendarDayKind.workday when weekend => 'Рабочий день (перенос)',
      CalendarDayKind.shortWorkday =>
        weekend ? 'Рабочий день (перенос), сокращённый' : 'Сокращённый день',
      _ => null,
    };
  }

  /// Норма месяца: рабочих дней и из них сокращённых.
  static ({int workdays, int shortDays}) monthNorm(int year, int month) {
    var work = 0, short = 0;
    final days = DateTime(year, month + 1, 0).day;
    for (var d = 1; d <= days; d++) {
      final kind = kindOf(DateTime(year, month, d));
      if (kind == CalendarDayKind.workday) work++;
      if (kind == CalendarDayKind.shortWorkday) {
        work++;
        short++;
      }
    }
    return (workdays: work, shortDays: short);
  }

  /// Нерабочие дни месяца (числа).
  static List<int> daysOff(int year, int month) => [
    for (var d = 1; d <= DateTime(year, month + 1, 0).day; d++)
      if (!isWorkingDay(DateTime(year, month, d))) d,
  ];
}
