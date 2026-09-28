import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_server/kfh_server.dart';
import 'package:test/test.dart';

/// С какого месяца правка меняет расчёты ЗП (без MySQL).
void main() {
  final sept = PeriodGuard.monthKey(2026, 9), oct = PeriodGuard.monthKey(2026, 10);

  test('табель и выплаты — месяц дня, при переносе — более ранний', () {
    expect(payrollImpactFrom('timesheet', null, {'date': '2026-10-03'}), oct);
    expect(
        payrollImpactFrom(
            'timesheet', {'date': '2026-10-03'}, {'date': '2026-09-30'}),
        sept);
    expect(payrollImpactFrom('timesheet', {'date': '2026-09-30'}, null), sept,
        reason: 'удаление');
    expect(payrollImpactFrom('payments', null, {'payment_date': '2026-10-01'}),
        oct);
  });

  test('ставка — месяц начала; расчёт — свой месяц; сотрудник — все', () {
    expect(
        payrollImpactFrom('employee_rates', {'start_date': '2026-10-16'},
            {'start_date': '2026-09-16'}),
        sept);
    expect(
        payrollImpactFrom(
            'payroll_results', null, {'year': 2026, 'month': 10}),
        oct);
    expect(payrollImpactFrom('employees', null, {'full_name': 'И'}), 0);
  });

  test('реквизиты, больничные, отпуска и пустая правка — не влияют', () {
    expect(payrollImpactFrom('company_settings', null, {'name': 'КФХ'}), isNull);
    expect(payrollImpactFrom('sick_leave', null, {'start_date': '2026-09-01'}),
        isNull);
    expect(payrollImpactFrom('timesheet', null, null), isNull);
  });
}
