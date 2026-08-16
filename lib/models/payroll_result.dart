// lib/models/payroll_result.dart

/// Результат расчёта зарплаты за месяц для сотрудника
class PayrollResult {
  final int? id;
  final int employeeId;
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
  }) : calculatedAt = calculatedAt ?? DateTime.now();

  factory PayrollResult.fromMap(Map<String, dynamic> map) {
    return PayrollResult(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int,
      year: map['year'] as int,
      month: map['month'] as int,
      baseDays: (map['base_days'] as num).toDouble(),
      fieldDays: (map['field_days'] as num).toDouble(),
      sickDays: (map['sick_days'] as num).toDouble(),
      vacationDays: (map['vacation_days'] as num).toDouble(),
      totalSalary: (map['total_salary'] as num).toDouble(),
      baseRateUsed: map['base_rate_used'] != null
          ? (map['base_rate_used'] as num).toDouble()
          : null,
      fieldRateUsed: map['field_rate_used'] != null
          ? (map['field_rate_used'] as num).toDouble()
          : null,
      calculatedAt: DateTime.parse(map['calculated_at'] as String),
      status: map['status'] as String? ?? 'calculated',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'year': year,
      'month': month,
      'base_days': baseDays,
      'field_days': fieldDays,
      'sick_days': sickDays,
      'vacation_days': vacationDays,
      'total_salary': totalSalary,
      'base_rate_used': baseRateUsed,
      'field_rate_used': fieldRateUsed,
      'calculated_at': calculatedAt.toIso8601String(),
      'status': status,
    };
  }

  PayrollResult copyWith({
    int? id,
    int? employeeId,
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
    );
  }

  @override
  String toString() =>
      'PayrollResult(emp: $employeeId, $year-$month, salary: $totalSalary)';
}
