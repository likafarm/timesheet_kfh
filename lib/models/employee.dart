/// Модель сотрудника КФХ (упрощённая)
class Employee {
  final int? id;
  final String fullName;
  final String position;
  final DateTime hireDate;
  final DateTime? dismissalDate; // дата увольнения, null если активен
  final double baseRate; // ставка за день работы на базе
  final double fieldRate; // ставка за день работы в поле

  Employee({
    this.id,
    required this.fullName,
    required this.position,
    required this.hireDate,
    this.dismissalDate,
    required this.baseRate,
    required this.fieldRate,
  });

  bool get isActive =>
      dismissalDate == null || dismissalDate!.isAfter(DateTime.now());

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as int?,
      fullName: map['full_name'] as String,
      position: map['position'] as String,
      hireDate: DateTime.parse(map['hire_date'] as String),
      dismissalDate: map['dismissal_date'] != null
          ? DateTime.parse(map['dismissal_date'] as String)
          : null,
      baseRate: (map['base_rate'] as num).toDouble(),
      fieldRate: (map['field_rate'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'position': position,
      'hire_date': hireDate.toIso8601String(),
      'dismissal_date': dismissalDate?.toIso8601String(),
      'base_rate': baseRate,
      'field_rate': fieldRate,
    };
  }

  Employee copyWith({
    int? id,
    String? fullName,
    String? position,
    DateTime? hireDate,
    DateTime? dismissalDate,
    double? baseRate,
    double? fieldRate,
  }) {
    return Employee(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      position: position ?? this.position,
      hireDate: hireDate ?? this.hireDate,
      dismissalDate: dismissalDate ?? this.dismissalDate,
      baseRate: baseRate ?? this.baseRate,
      fieldRate: fieldRate ?? this.fieldRate,
    );
  }

  @override
  String toString() => 'Employee(id: $id, name: $fullName)';
}
