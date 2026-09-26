import 'package:kfh_server/src/sync/period_guard.dart';
import 'package:test/test.dart';

void main() {
  // Закрыты январь и февраль 2026.
  final guard = PeriodGuard({
    PeriodGuard.monthKey(2026, 1),
    PeriodGuard.monthKey(2026, 2),
  });

  Map<String, Object?> day(String date, {String notes = ''}) =>
      {'date': date, 'notes': notes, 'day_type': 'work'};

  Map<String, Object?> rate(String start, String? end, {double base = 1000}) =>
      {
        'employee_uuid': 'e',
        'legacy_id': null,
        'base_rate': base,
        'field_rate': 1500.0,
        'start_date': start,
        'end_date': end,
      };

  group('табель', () {
    test('новый день: в закрытом месяце — отказ, в открытом — можно', () {
      expect(guard.violation('timesheet', null, false, day('2026-02-28'), false),
          (2026, 2));
      expect(guard.violation('timesheet', null, false, day('2026-03-01'), false),
          isNull);
      expect(guard.violation('timesheet', null, false, day('2025-12-31'), false),
          isNull);
    });

    test('правка заметки закрытого дня — отказ', () {
      expect(
          guard.violation('timesheet', day('2026-01-10'), false,
              day('2026-01-10', notes: 'x'), false),
          (2026, 1));
    });

    test('удаление и перенос дня из закрытого месяца — отказ', () {
      expect(
          guard.violation('timesheet', day('2026-01-10'), false,
              day('2026-01-10'), true),
          (2026, 1));
      expect(
          guard.violation('timesheet', day('2026-01-10'), false,
              day('2026-03-10'), false),
          (2026, 1));
    });

    test('правка уже удалённой записи, оставшейся удалённой, — можно', () {
      expect(
          guard.violation('timesheet', day('2026-01-10'), true,
              day('2026-01-10', notes: 'x'), true),
          isNull);
    });

    test('восстановление удалённого дня закрытого месяца — отказ', () {
      expect(
          guard.violation('timesheet', day('2026-01-10'), true,
              day('2026-01-10'), false),
          (2026, 1));
    });
  });

  group('ставки', () {
    test('новая ставка с начала закрытого месяца — отказ', () {
      expect(guard.violation('employee_rates', null, false,
          rate('2026-02-01', null), false), (2026, 2));
    });

    test('новая ставка с открытого месяца — можно', () {
      expect(guard.violation('employee_rates', null, false,
          rate('2026-03-01', null), false), isNull);
    });

    test('закрытие прежней ставки (начата в закрытом) датой в открытом — можно',
        () {
      expect(
          guard.violation('employee_rates', rate('2025-06-01', null), false,
              rate('2025-06-01', '2026-03-31'), false),
          isNull);
    });

    test('закрытие прежней ставки датой внутри закрытого месяца — отказ', () {
      expect(
          guard.violation('employee_rates', rate('2025-06-01', null), false,
              rate('2025-06-01', '2026-01-31'), false),
          (2026, 2));
    });

    test('изменение суммы ставки, действующей в закрытых месяцах, — отказ',
        () {
      expect(
          guard.violation('employee_rates', rate('2025-06-01', null), false,
              rate('2025-06-01', null, base: 2000), false),
          (2026, 1));
    });

    test('сумма ставки, закончившейся до закрытых месяцев, — можно', () {
      expect(
          guard.violation('employee_rates', rate('2025-06-01', '2025-12-31'),
              false, rate('2025-06-01', '2025-12-31', base: 2000), false),
          isNull);
    });

    test('перенос начала через закрытые месяцы — отказ', () {
      expect(
          guard.violation('employee_rates', rate('2025-12-01', '2025-12-31'),
              false, rate('2026-03-01', '2026-03-31'), false),
          isNull,
          reason: 'непересекающиеся периоды вне закрытых месяцев');
      expect(
          guard.violation('employee_rates', rate('2025-12-01', '2026-03-31'),
              false, rate('2026-03-01', '2026-03-31'), false),
          (2026, 1));
    });
  });

  test('отпуск, задевающий закрытый месяц краем, — отказ', () {
    Map<String, Object?> vacation(String from, String to) => {
          'employee_uuid': 'e',
          'legacy_id': null,
          'start_date': from,
          'end_date': to,
          'vacation_type': 'annual',
          'days_count': 14,
          'is_approved': true,
          'notes': null,
        };
    expect(guard.violation('vacation', null, false,
        vacation('2025-12-25', '2026-01-02'), false), (2026, 1));
    expect(guard.violation('vacation', null, false,
        vacation('2026-03-01', '2026-03-14'), false), isNull);
  });

  test('расчёт за закрытый месяц — отказ; сотрудники не привязаны', () {
    expect(
        guard.violation('payroll_results', null, false,
            {'year': 2026, 'month': 1}, false),
        (2026, 1));
    expect(
        guard.violation('employees', null, false, {'hire_date': '2026-01-15'},
            false),
        isNull);
  });

  test('нет закрытых месяцев — всё можно', () {
    expect(
        PeriodGuard({}).violation(
            'timesheet', null, false, day('2026-01-10'), false),
        isNull);
  });
}
