/// Модель выплаты сотруднику
class Payment {
  final int? id;
  final int employeeId;
  final DateTime paymentDate;
  final double amount;
  final String
  paymentType; // 'salary', 'advance', 'bonus', 'vacation', 'sick_leave'
  final String? periodStart;
  final String? periodEnd;
  final String? paymentMethod; // 'cash', 'card', 'transfer'
  final String? documentNumber;
  final String? notes;
  final DateTime createdAt;

  Payment({
    this.id,
    required this.employeeId,
    required this.paymentDate,
    required this.amount,
    this.paymentType = 'salary',
    this.periodStart,
    this.periodEnd,
    this.paymentMethod,
    this.documentNumber,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as int,
      paymentDate: DateTime.parse(map['payment_date'] as String),
      amount: (map['amount'] as num).toDouble(),
      paymentType: map['payment_type'] as String? ?? 'salary',
      periodStart: map['period_start'] as String?,
      periodEnd: map['period_end'] as String?,
      paymentMethod: map['payment_method'] as String?,
      documentNumber: map['document_number'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'payment_date': paymentDate.toIso8601String(),
      'amount': amount,
      'payment_type': paymentType,
      'period_start': periodStart,
      'period_end': periodEnd,
      'payment_method': paymentMethod,
      'document_number': documentNumber,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Название типа выплаты на русском
  String get paymentTypeName {
    switch (paymentType) {
      case 'salary':
        return 'Зарплата';
      case 'advance':
        return 'Аванс';
      case 'bonus':
        return 'Премия';
      case 'vacation':
        return 'Отпускные';
      case 'sick_leave':
        return 'Больничные';
      default:
        return 'Другое';
    }
  }

  /// Название способа оплаты на русском
  String get paymentMethodName {
    switch (paymentMethod) {
      case 'cash':
        return 'Наличные';
      case 'card':
        return 'На карту';
      case 'transfer':
        return 'Перевод';
      default:
        return 'Не указано';
    }
  }

  Payment copyWith({
    int? id,
    int? employeeId,
    DateTime? paymentDate,
    double? amount,
    String? paymentType,
    String? periodStart,
    String? periodEnd,
    String? paymentMethod,
    String? documentNumber,
    String? notes,
    DateTime? createdAt,
  }) {
    return Payment(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      paymentDate: paymentDate ?? this.paymentDate,
      amount: amount ?? this.amount,
      paymentType: paymentType ?? this.paymentType,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      documentNumber: documentNumber ?? this.documentNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Payment(id: $id, empId: $employeeId, amount: $amount)';
}
