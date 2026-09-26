// packages/domain/lib/src/models/payroll_result.dart

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
