/// Модель записи табеля (упрощённая)
class TimesheetRecord {
  final String? id;
  final String employeeId;
  final DateTime date;
  final String dayType; // 'work', 'sick', 'vacation', 'dayoff'
  final double days; // количество дней (для work: 1 или 0.5, для остальных 0)
  final String? workPlace; // 'base' или 'field' (только для dayType == 'work')
  final String? notes;
  final DateTime createdAt;

  TimesheetRecord({
    this.id,
    required this.employeeId,
    required this.date,
    this.dayType = 'work',
    this.days = 0.0,
    this.workPlace,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  TimesheetRecord copyWith({
    String? id,
    String? employeeId,
    DateTime? date,
    String? dayType,
    double? days,
    String? workPlace,
    String? notes,
    DateTime? createdAt,
  }) {
    return TimesheetRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      date: date ?? this.date,
      dayType: dayType ?? this.dayType,
      days: days ?? this.days,
      workPlace: workPlace ?? this.workPlace,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'TimesheetRecord(id: $id, emp: $employeeId, date: $date)';
}
