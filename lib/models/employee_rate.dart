/// Модель истории изменения ставок сотрудника
class EmployeeRate {
  final int? id;
  final int employeeId;
  final double baseRate;
  final double fieldRate;
  final DateTime startDate;
  final DateTime? endDate; // null если действует

  EmployeeRate({
    this.id,
    required this.employeeId,
    required this.baseRate,
    required this.fieldRate,
    required this.startDate,
    this.endDate,
  });

  factory EmployeeRate.fromMap(Map<String, dynamic> map) {
    return EmployeeRate(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int,
      baseRate: (map['base_rate'] as num).toDouble(),
      fieldRate: (map['field_rate'] as num).toDouble(),
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: map['end_date'] != null
          ? DateTime.parse(map['end_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'base_rate': baseRate,
      'field_rate': fieldRate,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
    };
  }

  EmployeeRate copyWith({
    int? id,
    int? employeeId,
    double? baseRate,
    double? fieldRate,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return EmployeeRate(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      baseRate: baseRate ?? this.baseRate,
      fieldRate: fieldRate ?? this.fieldRate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  String toString() => 'EmployeeRate(id: $id, emp: $employeeId, $startDate)';
}
