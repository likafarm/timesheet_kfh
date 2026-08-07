/// Модель записи табеля учёта рабочего времени
class TimesheetRecord {
  final int? id;
  final int employeeId;
  final DateTime date;
  final double hoursWorked;
  final double? overtimeHours;
  final int? workTypeId;
  final int? workSiteId;
  final int? machineryId;
  final double? quantityDone;
  final String? quantityUnit; // 'ha', 't', 'km', 'pcs'
  final double? pieceworkRate;
  final double? bonus;
  final double? penalty;
  final String? weatherCondition;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TimesheetRecord({
    this.id,
    required this.employeeId,
    required this.date,
    required this.hoursWorked,
    this.overtimeHours,
    this.workTypeId,
    this.workSiteId,
    this.machineryId,
    this.quantityDone,
    this.quantityUnit,
    this.pieceworkRate,
    this.bonus,
    this.penalty,
    this.weatherCondition,
    this.notes,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TimesheetRecord.fromMap(Map<String, dynamic> map) {
    return TimesheetRecord(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int,
      date: DateTime.parse(map['date'] as String),
      hoursWorked: (map['hours_worked'] as num).toDouble(),
      overtimeHours: map['overtime_hours'] != null
          ? (map['overtime_hours'] as num).toDouble()
          : null,
      workTypeId: map['work_type_id'] as int?,
      workSiteId: map['work_site_id'] as int?,
      machineryId: map['machinery_id'] as int?,
      quantityDone: map['quantity_done'] != null
          ? (map['quantity_done'] as num).toDouble()
          : null,
      quantityUnit: map['quantity_unit'] as String?,
      pieceworkRate: map['piecework_rate'] != null
          ? (map['piecework_rate'] as num).toDouble()
          : null,
      bonus: map['bonus'] != null ? (map['bonus'] as num).toDouble() : null,
      penalty: map['penalty'] != null
          ? (map['penalty'] as num).toDouble()
          : null,
      weatherCondition: map['weather_condition'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'date': date.toIso8601String(),
      'hours_worked': hoursWorked,
      'overtime_hours': overtimeHours,
      'work_type_id': workTypeId,
      'work_site_id': workSiteId,
      'machinery_id': machineryId,
      'quantity_done': quantityDone,
      'quantity_unit': quantityUnit,
      'piecework_rate': pieceworkRate,
      'bonus': bonus,
      'penalty': penalty,
      'weather_condition': weatherCondition,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Расчёт зарплаты за день (почасовая ставка)
  double calculateDailySalary(double hourlyRate) {
    double basePay = hoursWorked * hourlyRate;
    double overtimePay = (overtimeHours ?? 0) * hourlyRate * 1.5;
    double pieceworkPay = 0;
    if (quantityDone != null && pieceworkRate != null) {
      pieceworkPay = quantityDone! * pieceworkRate!;
    }
    double bonusAmount = bonus ?? 0;
    double penaltyAmount = penalty ?? 0;
    return basePay + overtimePay + pieceworkPay + bonusAmount - penaltyAmount;
  }

  TimesheetRecord copyWith({
    int? id,
    int? employeeId,
    DateTime? date,
    double? hoursWorked,
    double? overtimeHours,
    int? workTypeId,
    int? workSiteId,
    int? machineryId,
    double? quantityDone,
    String? quantityUnit,
    double? pieceworkRate,
    double? bonus,
    double? penalty,
    String? weatherCondition,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimesheetRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      hoursWorked: hoursWorked ?? this.hoursWorked,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      workTypeId: workTypeId ?? this.workTypeId,
      workSiteId: workSiteId ?? this.workSiteId,
      machineryId: machineryId ?? this.machineryId,
      quantityDone: quantityDone ?? this.quantityDone,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      pieceworkRate: pieceworkRate ?? this.pieceworkRate,
      bonus: bonus ?? this.bonus,
      penalty: penalty ?? this.penalty,
      weatherCondition: weatherCondition ?? this.weatherCondition,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'TimesheetRecord(id: $id, empId: $employeeId, date: $date)';
}
