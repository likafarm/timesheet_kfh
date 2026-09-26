// packages/domain/lib/src/payroll.dart
//
// Чистая логика расчёта зарплаты: без БД, файлов и Flutter.
// Хранилище загружает данные и передаёт их сюда.

import 'models/employee_rate.dart';
import 'models/timesheet_record.dart';

/// Итог расчёта зарплаты сотрудника за месяц.
class PayrollCalculation {
  final String employeeId;
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
  required String employeeId,
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

/// Расчёт без начислений: ни рабочих, ни больничных, ни отпускных дней,
/// ни неоплаченных рабочих дней (без ставки), сумма — ноль. Выходные не
/// считаются: месяц из одних выходных — пустой.
bool isEmptyPayroll({
  required double baseDays,
  required double fieldDays,
  required double sickDays,
  required double vacationDays,
  required double totalSalary,
  required int skippedWorkDays,
}) =>
    baseDays == 0 &&
    fieldDays == 0 &&
    sickDays == 0 &&
    vacationDays == 0 &&
    totalSalary == 0 &&
    skippedWorkDays == 0;

extension PayrollCalculationEmpty on PayrollCalculation {
  bool get isEmpty => isEmptyPayroll(
        baseDays: baseDays,
        fieldDays: fieldDays,
        sickDays: sickDays,
        vacationDays: vacationDays,
        totalSalary: totalSalary,
        skippedWorkDays: skippedWorkDays,
      );
}

/// Нужен ли сотруднику расчёт за месяц (и строка в отчёте): есть начисления
/// или выплаты в этом месяце. Сотрудник без того и другого в расчёт не
/// входит — расчёт не сохраняется, прежний сохранённый удаляется. Входящий
/// остаток на это не влияет (решение владельца 2026-09-26).
bool payrollNeeded({required bool emptyPayroll, required bool paidInMonth}) =>
    !emptyPayroll || paidInMonth;

/// Входящий остаток по сотрудникам: начислено − выплачено.
/// Положительное значение — долг хозяйства перед сотрудником.
Map<String, double> combineBalances({
  required Map<String, double> accrued,
  required Map<String, double> paid,
}) {
  final balances = <String, double>{...accrued};
  paid.forEach((empId, sum) {
    balances[empId] = (balances[empId] ?? 0.0) - sum;
  });
  return balances;
}
