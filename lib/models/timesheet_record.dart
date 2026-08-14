/// Модель записи табеля (упрощённая)
class TimesheetRecord {
  final int? id;
  final int employeeId;
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

  factory TimesheetRecord.fromMap(Map<String, dynamic> map) {
    return TimesheetRecord(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int,
      date: DateTime.parse(map['date'] as String),
      dayType: map['day_type'] as String? ?? 'work',
      days: (map['days'] as num?)?.toDouble() ?? 0.0,
      workPlace: map['work_place'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'date': date.toIso8601String(),
      'day_type': dayType,
      'days': days,
      'work_place': workPlace,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TimesheetRecord copyWith({
    int? id,
    int? employeeId,
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
