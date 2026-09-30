import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

void main() {
  String? problem(String dayType, double days, String? place) =>
      timesheetMarkProblem(dayType: dayType, days: days, workPlace: place);

  test('рабочий день: место база/поле и доля 1 или ½', () {
    for (final place in ['base', 'field']) {
      expect(problem('work', 1, place), isNull);
      expect(problem('work', 0.5, place), isNull);
    }
  });

  test('рабочий день без места или с чужим местом — ошибка', () {
    expect(problem('work', 1, null), contains('место работы'));
    expect(problem('work', 1, 'office'), contains('место работы'));
  });

  test('рабочий день с долей не 1 и не ½ — ошибка', () {
    for (final days in [0.0, 0.25, 0.75, 2.0]) {
      expect(problem('work', days, 'base'), contains('1 или ½'));
    }
  });

  test('у нерабочих дней место не проверяется', () {
    for (final type in ['sick', 'vacation', 'dayoff']) {
      expect(problem(type, 1, null), isNull);
      expect(problem(type, 1, 'field'), isNull);
    }
  });

  test('строка формата обмена', () {
    expect(
      timesheetRowProblem({
        'day_type': 'work',
        'days': 1,
        'work_place': 'base',
      }),
      isNull,
    );
    expect(
      timesheetRowProblem({
        'day_type': 'work',
        'days': 0.5,
        'work_place': null,
      }),
      contains('место работы'),
    );
    expect(
      timesheetRowProblem({
        'day_type': 'sick',
        'days': 1.0,
        'work_place': null,
      }),
      isNull,
    );
    expect(timesheetRowProblem({'day_type': 'work'}), 'Неверная запись табеля');
  });

  test('запись табеля', () {
    final r = TimesheetRecord(
      employeeId: 'a',
      date: DateTime(2026, 9, 1),
      days: 1,
    );
    expect(timesheetRecordProblem(r), isNotNull);
    expect(timesheetRecordProblem(r.copyWith(workPlace: 'field')), isNull);
  });
}
