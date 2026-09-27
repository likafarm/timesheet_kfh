// packages/domain/lib/src/models/payroll_result.dart

import '../payroll.dart';

/// Результат расчёта зарплаты за месяц для сотрудника
class PayrollResult {
  final String? id;
  final String employeeId;
  final int year;
  final int month;
  final double baseDays;
  final double fieldDays;
  final double sickDays;
  final double vacationDays;
  final double totalSalary;
  final double? baseRateUsed; // средняя или финальная ставка для справки
  final double? fieldRateUsed;
  final DateTime calculatedAt;
  final String status; // 'calculated', 'verified', 'discrepancy'
  /// Рабочие дни без ставки — не вошли в сумму.
  final int skippedWorkDays;

  PayrollResult({
    this.id,
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
    DateTime? calculatedAt,
    this.status = 'calculated',
    this.skippedWorkDays = 0,
  }) : calculatedAt = calculatedAt ?? DateTime.now();

  /// Результат для сохранения из свежего расчёта.
  factory PayrollResult.fromCalculation(
    PayrollCalculation calc, {
    DateTime? calculatedAt,
  }) =>
      PayrollResult(
        employeeId: calc.employeeId,
        year: calc.year,
        month: calc.month,
        baseDays: calc.baseDays,
        fieldDays: calc.fieldDays,
        sickDays: calc.sickDays,
        vacationDays: calc.vacationDays,
        totalSalary: calc.totalSalary,
        baseRateUsed: calc.baseRateUsed,
        fieldRateUsed: calc.fieldRateUsed,
        calculatedAt: calculatedAt,
        status: 'calculated',
        skippedWorkDays: calc.skippedWorkDays,
      );

  /// Сохранённый расчёт без начислений (см. [isEmptyPayroll]).
  bool get isEmpty => isEmptyPayroll(
        baseDays: baseDays,
        fieldDays: fieldDays,
        sickDays: sickDays,
        vacationDays: vacationDays,
        totalSalary: totalSalary,
        skippedWorkDays: skippedWorkDays,
      );

  PayrollResult copyWith({
    String? id,
    String? employeeId,
    int? year,
    int? month,
    double? baseDays,
    double? fieldDays,
    double? sickDays,
    double? vacationDays,
    double? totalSalary,
    double? baseRateUsed,
    double? fieldRateUsed,
    DateTime? calculatedAt,
    String? status,
    int? skippedWorkDays,
  }) {
    return PayrollResult(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      year: year ?? this.year,
      month: month ?? this.month,
      baseDays: baseDays ?? this.baseDays,
      fieldDays: fieldDays ?? this.fieldDays,
      sickDays: sickDays ?? this.sickDays,
      vacationDays: vacationDays ?? this.vacationDays,
      totalSalary: totalSalary ?? this.totalSalary,
      baseRateUsed: baseRateUsed ?? this.baseRateUsed,
      fieldRateUsed: fieldRateUsed ?? this.fieldRateUsed,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      status: status ?? this.status,
      skippedWorkDays: skippedWorkDays ?? this.skippedWorkDays,
    );
  }

  @override
  String toString() =>
      'PayrollResult(emp: $employeeId, $year-$month, salary: $totalSalary)';
}
