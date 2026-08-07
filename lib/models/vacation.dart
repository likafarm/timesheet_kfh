/// Модель отпуска сотрудника
class Vacation {
  final int? id;
  final int employeeId;
  final DateTime startDate;
  final DateTime endDate;
  final String vacationType; // 'annual', 'unpaid', 'maternity', 'study'
  final int daysCount;
  final bool isApproved;
  final String? notes;

  Vacation({
    this.id,
    required this.employeeId,
    required this.startDate,
    required this.endDate,
    this.vacationType = 'annual',
    required this.daysCount,
    this.isApproved = false,
    this.notes,
  });

  factory Vacation.fromMap(Map<String, dynamic> map) {
    return Vacation(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      vacationType: map['vacation_type'] as String? ?? 'annual',
      daysCount: map['days_count'] as int,
      isApproved: (map['is_approved'] as int? ?? 0) == 1,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'vacation_type': vacationType,
      'days_count': daysCount,
      'is_approved': isApproved ? 1 : 0,
      'notes': notes,
    };
  }

  /// Название типа отпуска на русском
  String get vacationTypeName {
    switch (vacationType) {
      case 'annual':
        return 'Ежегодный';
      case 'unpaid':
        return 'Без сохранения з/п';
      case 'maternity':
        return 'Декретный';
      case 'study':
        return 'Учебный';
      default:
        return 'Прочее';
    }
  }

  Vacation copyWith({
    int? id,
    int? employeeId,
    DateTime? startDate,
    DateTime? endDate,
    String? vacationType,
    int? daysCount,
    bool? isApproved,
    String? notes,
  }) {
    return Vacation(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      vacationType: vacationType ?? this.vacationType,
      daysCount: daysCount ?? this.daysCount,
      isApproved: isApproved ?? this.isApproved,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() =>
      'Vacation(id: $id, empId: $employeeId, $startDate - $endDate)';
}
