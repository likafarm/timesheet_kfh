/// Модель сотрудника КФХ
class Employee {
  final int? id;
  final String fullName;
  final String position;
  final String? phone;
  final DateTime hireDate;
  final DateTime? birthDate;
  final String? passportSeries;
  final String? passportNumber;
  final String? snils;
  final String? inn;
  final double hourlyRate;
  final double? fixedSalary;
  final String paymentType; // 'hourly', 'salary', 'piecework'
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime? dismissalDate;
  final String? dismissalReason;

  // Новые поля для учёта графиков работы
  final int? scheduleTypeId; // id типа графика из таблицы work_schedules
  final DateTime? scheduleStartDate; // дата начала действия графика
  final bool isShiftWorker; // флаг, что сотрудник работает по сменному графику

  Employee({
    this.id,
    required this.fullName,
    required this.position,
    this.phone,
    required this.hireDate,
    this.birthDate,
    this.passportSeries,
    this.passportNumber,
    this.snils,
    this.inn,
    required this.hourlyRate,
    this.fixedSalary,
    this.paymentType = 'hourly',
    this.isActive = true,
    this.notes,
    DateTime? createdAt,
    this.dismissalDate,
    this.dismissalReason,
    this.scheduleTypeId,
    this.scheduleStartDate,
    this.isShiftWorker = false,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'] as int?,
      fullName: map['full_name'] as String,
      position: map['position'] as String,
      phone: map['phone'] as String?,
      hireDate: DateTime.parse(map['hire_date'] as String),
      birthDate: map['birth_date'] != null
          ? DateTime.parse(map['birth_date'] as String)
          : null,
      passportSeries: map['passport_series'] as String?,
      passportNumber: map['passport_number'] as String?,
      snils: map['snils'] as String?,
      inn: map['inn'] as String?,
      hourlyRate: (map['hourly_rate'] as num).toDouble(),
      fixedSalary: map['fixed_salary'] != null
          ? (map['fixed_salary'] as num).toDouble()
          : null,
      paymentType: map['payment_type'] as String? ?? 'hourly',
      isActive: (map['is_active'] as int? ?? 1) == 1,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      dismissalDate: map['dismissal_date'] != null
          ? DateTime.parse(map['dismissal_date'] as String)
          : null,
      dismissalReason: map['dismissal_reason'] as String?,
      scheduleTypeId: map['schedule_type_id'] as int?,
      scheduleStartDate: map['schedule_start_date'] != null
          ? DateTime.parse(map['schedule_start_date'] as String)
          : null,
      isShiftWorker: (map['is_shift_worker'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'position': position,
      'phone': phone,
      'hire_date': hireDate.toIso8601String(),
      'birth_date': birthDate?.toIso8601String(),
      'passport_series': passportSeries,
      'passport_number': passportNumber,
      'snils': snils,
      'inn': inn,
      'hourly_rate': hourlyRate,
      'fixed_salary': fixedSalary,
      'payment_type': paymentType,
      'is_active': isActive ? 1 : 0,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'dismissal_date': dismissalDate?.toIso8601String(),
      'dismissal_reason': dismissalReason,
      'schedule_type_id': scheduleTypeId,
      'schedule_start_date': scheduleStartDate?.toIso8601String(),
      'is_shift_worker': isShiftWorker ? 1 : 0,
    };
  }

  Employee copyWith({
    int? id,
    String? fullName,
    String? position,
    String? phone,
    DateTime? hireDate,
    DateTime? birthDate,
    String? passportSeries,
    String? passportNumber,
    String? snils,
    String? inn,
    double? hourlyRate,
    double? fixedSalary,
    String? paymentType,
    bool? isActive,
    String? notes,
    DateTime? createdAt,
    DateTime? dismissalDate,
    String? dismissalReason,
    int? scheduleTypeId,
    DateTime? scheduleStartDate,
    bool? isShiftWorker,
  }) {
    return Employee(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      position: position ?? this.position,
      phone: phone ?? this.phone,
      hireDate: hireDate ?? this.hireDate,
      birthDate: birthDate ?? this.birthDate,
      passportSeries: passportSeries ?? this.passportSeries,
      passportNumber: passportNumber ?? this.passportNumber,
      snils: snils ?? this.snils,
      inn: inn ?? this.inn,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      fixedSalary: fixedSalary ?? this.fixedSalary,
      paymentType: paymentType ?? this.paymentType,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      dismissalDate: dismissalDate ?? this.dismissalDate,
      dismissalReason: dismissalReason ?? this.dismissalReason,
      scheduleTypeId: scheduleTypeId ?? this.scheduleTypeId,
      scheduleStartDate: scheduleStartDate ?? this.scheduleStartDate,
      isShiftWorker: isShiftWorker ?? this.isShiftWorker,
    );
  }

  @override
  String toString() => 'Employee(id: $id, name: $fullName)';
}
