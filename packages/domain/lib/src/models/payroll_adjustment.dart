/// Корректировка начисления за месяц (решение владельца 2026-10-08):
/// доплата (плюс) или удержание (минус) к расчёту ЗП сотрудника — то, что
/// не выражается днями табеля: надбавки, премии, переработки, вычеты.
/// Входит в начислено за месяц и в остатки.
class PayrollAdjustment {
  final String? id;
  final String employeeId;
  final int year;
  final int month;

  /// Рубли; плюс — доплата, минус — удержание.
  final double amount;
  final String? notes;

  const PayrollAdjustment({
    this.id,
    required this.employeeId,
    required this.year,
    required this.month,
    required this.amount,
    this.notes,
  });

  PayrollAdjustment copyWith({
    String? id,
    double? amount,
    String? notes,
    int? year,
    int? month,
  }) => PayrollAdjustment(
    id: id ?? this.id,
    employeeId: employeeId,
    year: year ?? this.year,
    month: month ?? this.month,
    amount: amount ?? this.amount,
    notes: notes ?? this.notes,
  );
}

/// Сумма корректировок по (сотрудник, месяц [monthKey]).
Map<(String, int), double> adjustmentSums(
  Iterable<PayrollAdjustment> adjustments,
) {
  final sums = <(String, int), double>{};
  for (final a in adjustments) {
    final key = (a.employeeId, a.year * 12 + a.month - 1);
    sums[key] = (sums[key] ?? 0) + a.amount;
  }
  return sums;
}
