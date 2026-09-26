/// Модель сотрудника КФХ (упрощённая)
class Employee {
  final String? id;
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

  /// [clearDismissalDate] — снять увольнение: `dismissalDate: null`
  /// в copyWith означает «не менять».
  Employee copyWith({
    String? id,
    String? fullName,
    String? position,
    DateTime? hireDate,
    DateTime? dismissalDate,
    double? baseRate,
    double? fieldRate,
    bool clearDismissalDate = false,
  }) {
    return Employee(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      position: position ?? this.position,
      hireDate: hireDate ?? this.hireDate,
      dismissalDate: clearDismissalDate
          ? null
          : dismissalDate ?? this.dismissalDate,
      baseRate: baseRate ?? this.baseRate,
      fieldRate: fieldRate ?? this.fieldRate,
    );
  }

  @override
  String toString() => 'Employee(id: $id, name: $fullName)';
}
