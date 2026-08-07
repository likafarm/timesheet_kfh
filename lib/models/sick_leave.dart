/// Модель больничного листа сотрудника
class SickLeave {
  final int? id;
  final int employeeId;
  final DateTime startDate;
  final DateTime endDate;
  final String? documentNumber;
  final int daysCount;
  final double? paidByEmployer;
  final double? paidByFss;
  final String? notes;

  SickLeave({
    this.id,
    required this.employeeId,
    required this.startDate,
    required this.endDate,
    this.documentNumber,
    required this.daysCount,
    this.paidByEmployer,
    this.paidByFss,
    this.notes,
  });

  factory SickLeave.fromMap(Map<String, dynamic> map) {
    return SickLeave(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      documentNumber: map['document_number'] as String?,
      daysCount: map['days_count'] as int,
      paidByEmployer: map['paid_by_employer'] != null
          ? (map['paid_by_employer'] as num).toDouble()
          : null,
      paidByFss: map['paid_by_fss'] != null
          ? (map['paid_by_fss'] as num).toDouble()
          : null,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'document_number': documentNumber,
      'days_count': daysCount,
      'paid_by_employer': paidByEmployer,
      'paid_by_fss': paidByFss,
      'notes': notes,
    };
  }

  /// Общая сумма выплат по больничному
  double get totalPaid => (paidByEmployer ?? 0) + (paidByFss ?? 0);

  SickLeave copyWith({
    int? id,
    int? employeeId,
    DateTime? startDate,
    DateTime? endDate,
    String? documentNumber,
    int? daysCount,
    double? paidByEmployer,
    double? paidByFss,
    String? notes,
  }) {
    return SickLeave(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      documentNumber: documentNumber ?? this.documentNumber,
      daysCount: daysCount ?? this.daysCount,
      paidByEmployer: paidByEmployer ?? this.paidByEmployer,
      paidByFss: paidByFss ?? this.paidByFss,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() =>
      'SickLeave(id: $id, empId: $employeeId, $startDate - $endDate)';
}
