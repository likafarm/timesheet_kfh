/// Модель выплаты сотруднику
class Payment {
  final String? id;
  final String employeeId;
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
    String? id,
    String? employeeId,
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
