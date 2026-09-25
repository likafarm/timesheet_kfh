// packages/domain/lib/src/payroll.dart
//
// Чистая логика расчёта зарплаты: без БД, файлов и Flutter.
// Хранилище загружает данные и передаёт их сюда.

import 'models/employee_rate.dart';
import 'models/timesheet_record.dart';

/// Итог расчёта зарплаты сотрудника за месяц.
class PayrollCalculation {
  final int employeeId;
  final int year;
  final int month;
  final double baseDays;
  final double fieldDays;
  final double sickDays;
  final double vacationDays;
  final double totalSalary;

  /// Ставки последнего оплаченного рабочего дня (для справки).
  final double? baseRateUsed;
  final double? fieldRateUsed;

  /// Рабочие дни без действующей ставки — не вошли в сумму.
  final int skippedWorkDays;

  const PayrollCalculation({
    required this.employeeId,
    required this.year,
    required this.month,
    required this.baseDays,
    required this.fieldDays,
    required this.sickDays,
    required this.vacationDays,
    required this.totalSalary,
    this.baseRateUsed,
    this.fieldRateUsed,
    this.skippedWorkDays = 0,
  });

  /// Формат, который исторически возвращал DatabaseService.
  Map<String, dynamic> toMap() => {
    'employeeId': employeeId,
    'year': year,
    'month': month,
    'baseDays': baseDays,
    'fieldDays': fieldDays,
    'sickDays': sickDays,
    'vacationDays': vacationDays,
    'totalSalary': totalSalary,
    'baseRateUsed': baseRateUsed,
    'fieldRateUsed': fieldRateUsed,
    'skippedWorkDays': skippedWorkDays,
  };
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Ставка, действующая на [date]: `start_date <= date <= end_date`
/// (end_date == null — действует бессрочно). При пересечении периодов
/// выигрывает ставка с самой поздней датой начала.
EmployeeRate? findRateAtDate(List<EmployeeRate> rates, DateTime date) {
  final day = _dayOnly(date);
  EmployeeRate? best;
  for (final rate in rates) {
    final start = _dayOnly(rate.startDate);
    if (start.isAfter(day)) continue;
    final end = rate.endDate;
    if (end != null && _dayOnly(end).isBefore(day)) continue;
    if (best == null || start.isAfter(_dayOnly(best.startDate))) {
      best = rate;
    }
  }
  return best;
}

/// Расчёт зарплаты за месяц.
///
/// [records] — записи табеля сотрудника (записи вне месяца игнорируются),
/// [rates] — полная история ставок сотрудника.
///
/// Рабочий день оплачивается по ставке базы (`workPlace == 'base'`),
/// иначе — по ставке поля. Больничные и отпуск только подсчитываются.
PayrollCalculation calculateMonthlySalary({
  required int employeeId,
  required int year,
  required int month,
  required List<TimesheetRecord> records,
  required List<EmployeeRate> rates,
}) {
  double baseDays = 0.0;
  double fieldDays = 0.0;
  double sickDays = 0.0;
  double vacationDays = 0.0;
  double totalSalary = 0.0;
  double? lastBaseRate;
  double? lastFieldRate;
  int skippedWorkDays = 0;

  for (final record in records) {
    if (record.date.year != year || record.date.month != month) continue;

    switch (record.dayType) {
      case 'work':
        final rate = findRateAtDate(rates, record.date);
        if (rate == null) {
          skippedWorkDays++;
          continue;
        }
        lastBaseRate = rate.baseRate;
        lastFieldRate = rate.fieldRate;
        final dayRate = record.workPlace == 'base'
            ? rate.baseRate
            : rate.fieldRate;
        totalSalary += record.days * dayRate;
        if (record.workPlace == 'base') {
          baseDays += record.days;
        } else if (record.workPlace == 'field') {
          fieldDays += record.days;
        }
      case 'sick':
        sickDays += record.days;
      case 'vacation':
        vacationDays += record.days;
    }
  }

  return PayrollCalculation(
    employeeId: employeeId,
    year: year,
    month: month,
    baseDays: baseDays,
    fieldDays: fieldDays,
    sickDays: sickDays,
    vacationDays: vacationDays,
    totalSalary: totalSalary,
    baseRateUsed: lastBaseRate,
    fieldRateUsed: lastFieldRate,
    skippedWorkDays: skippedWorkDays,
  );
}

/// Входящий остаток по сотрудникам: начислено − выплачено.
/// Положительное значение — долг хозяйства перед сотрудником.
Map<int, double> combineBalances({
  required Map<int, double> accrued,
  required Map<int, double> paid,
}) {
  final balances = <int, double>{...accrued};
  paid.forEach((empId, sum) {
    balances[empId] = (balances[empId] ?? 0.0) - sum;
  });
  return balances;
}
