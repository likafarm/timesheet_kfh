// packages/domain/lib/src/timesheet_rules.dart
//
// Правило отметки табеля (решение владельца 2026-09-30): у рабочего дня
// обязательны место работы (база или поле) и доля дня (1 или ½). Рабочий день
// без места — ошибка ввода: он оплачивался бы по ставке поля, но не попадал
// бы в счётчики дней. Одно правило для окон, AppProvider и сервера.

import 'models/timesheet_record.dart';

/// Места работы рабочего дня.
const workPlaces = {'base', 'field'};

/// Доли рабочего дня: целый или половина.
bool isWorkDayShare(double days) => days == 1 || days == 0.5;

/// Что не так с отметкой табеля — текст для человека; null — всё в порядке.
/// У нерабочих дней (больничный, отпуск, выходной) место не проверяется.
String? timesheetMarkProblem({
  required String dayType,
  required double days,
  String? workPlace,
}) {
  if (dayType != 'work') return null;
  if (!workPlaces.contains(workPlace)) {
    return 'У рабочего дня не указано место работы (база или поле)';
  }
  if (!isWorkDayShare(days)) {
    return 'Рабочий день — целый или половина (1 или ½), а указано $days';
  }
  return null;
}

/// [timesheetMarkProblem] для записи табеля.
String? timesheetRecordProblem(TimesheetRecord r) => timesheetMarkProblem(
  dayType: r.dayType,
  days: r.days,
  workPlace: r.workPlace,
);

/// [timesheetMarkProblem] для строки таблицы `timesheet` в формате обмена
/// (`day_type`, `days`, `work_place`). Строка неверного вида — тоже проблема.
String? timesheetRowProblem(Map<String, Object?> data) {
  final dayType = data['day_type'];
  final days = data['days'];
  final workPlace = data['work_place'];
  if (dayType is! String || days is! num || workPlace is! String?) {
    return 'Неверная запись табеля';
  }
  return timesheetMarkProblem(
    dayType: dayType,
    days: days.toDouble(),
    workPlace: workPlace,
  );
}

/// Записи с ошибкой отметки ([timesheetRecordProblem]) — по дате.
List<TimesheetRecord> invalidTimesheetRecords(
  Iterable<TimesheetRecord> records,
) => [
  for (final r in records)
    if (timesheetRecordProblem(r) != null) r,
]..sort((a, b) => a.date.compareTo(b.date));
