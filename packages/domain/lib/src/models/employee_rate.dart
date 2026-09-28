/// Модель истории изменения ставок сотрудника
class EmployeeRate {
  final String? id;
  final String employeeId;
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

  EmployeeRate copyWith({
    String? id,
    String? employeeId,
    double? baseRate,
    double? fieldRate,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) {
    return EmployeeRate(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      baseRate: baseRate ?? this.baseRate,
      fieldRate: fieldRate ?? this.fieldRate,
      startDate: startDate ?? this.startDate,
      // endDate: null значит «не менять»; снять окончание — clearEndDate.
      endDate: clearEndDate ? null : endDate ?? this.endDate,
    );
  }

  @override
  String toString() => 'EmployeeRate(id: $id, emp: $employeeId, $startDate)';
}
