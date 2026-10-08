// packages/domain/lib/src/finance/dds.dart
//
// ДДС — движение денежных средств по видам деятельности (этап 8Б.3, факт):
// остаток денег на начало месяца → операционная деятельность (доходы и
// текущие расходы по статьям, выплаты ЗП) → инвестиционная (капвложения)
// → финансовая (займы) → остаток на конец. Переводы между кошельками
// деньги хозяйства не меняют и в отчёт не входят.

import '../utils/date_utils.dart';
import 'calc.dart';
import 'catalog.dart';
import 'models.dart';
import 'report.dart';

class DdsReport {
  /// Первые числа месяцев.
  final List<DateTime> columns;

  /// Деньги во всех кошельках на начало месяца и на конец.
  final List<int> opening;
  final List<int> closing;

  /// Операционная: поступления и платежи по статьям (с группами).
  final CashFlowSection operatingIn;
  final CashFlowSection operatingOut;

  /// Инвестиционная: капвложения (платежи) по статьям.
  final CashFlowSection investingOut;

  /// Финансовая: займы по видам движения, со знаком (приход — плюс).
  final List<CashFlowLine> financing;

  /// Прочее: начальные остатки кошельков, заведённых в периоде, и записи
  /// раньше дня начального остатка — чтобы начало + движение = конец.
  final List<int> other;

  const DdsReport({
    required this.columns,
    required this.opening,
    required this.closing,
    required this.operatingIn,
    required this.operatingOut,
    required this.investingOut,
    required this.financing,
    required this.other,
  });

  List<int> _zip(List<int> a, List<int> b, int sign) => [
    for (var i = 0; i < columns.length; i++) a[i] + sign * b[i],
  ];

  /// Чистый поток операционной деятельности.
  List<int> get operatingNet =>
      _zip(operatingIn.values, operatingOut.values, -1);

  /// Чистый поток инвестиционной (капвложения — минус).
  List<int> get investingNet => [for (final v in investingOut.values) -v];

  List<int> get financingNet => [
    for (var i = 0; i < columns.length; i++)
      financing.fold(0, (s, l) => s + l.values[i]),
  ];

  /// Изменение денег за месяц по всем видам.
  List<int> get netFlow => [
    for (var i = 0; i < columns.length; i++)
      operatingNet[i] + investingNet[i] + financingNet[i],
  ];

  bool get hasOther => other.any((v) => v != 0);
}

/// ДДС за [count] месяцев с месяца [from]. [operations] — вместе с
/// расходами ЗП из выплат (`payrollExpenses`).
DdsReport ddsReport({
  required Iterable<FinOperation> operations,
  required FinanceCatalog catalog,
  required DateTime from,
  int count = 12,
}) {
  final ops = operations.toList();
  final start = DateTime(from.year, from.month);
  final columns = [
    for (var i = 0; i < count; i++) DateTime(start.year, start.month + i),
  ];
  bool capex(FinOperation op) =>
      op.type == OperationType.expense &&
      catalog.categories[op.categoryId]?.kind == CategoryKind.capex;

  final operating = cashFlowReport(
    operations: [
      for (final op in ops)
        if (!capex(op)) op,
    ],
    catalog: catalog,
    from: start,
    count: count,
  );
  final investing = cashFlowReport(
    operations: ops.where(capex),
    catalog: catalog,
    from: start,
    count: count,
  );

  int? indexOf(DateTime date) {
    final d = calendarDay(date);
    final i = (d.year - start.year) * 12 + d.month - start.month;
    return i >= 0 && i < count ? i : null;
  }

  final byMove = <DebtMove, List<int>>{};
  for (final op in ops) {
    final move = op.debtMove;
    final i = indexOf(op.date);
    if (op.type != OperationType.debt || move == null || i == null) continue;
    (byMove[move] ??= List.filled(count, 0))[i] += move.cashSign * op.amount;
  }
  final financing = [
    for (final m in DebtMove.values)
      if (byMove[m] case final v?)
        CashFlowLine(id: m.code, name: m.title, values: v),
  ];

  int money(DateTime endOfDay) => accountBalances(
    catalog.accounts.values,
    ops,
    at: endOfDay,
  ).values.fold(0, (s, v) => s + v);
  // На начало 1-го числа: остатки на конец прошлого дня + кошельки с
  // начальным остатком на само 1-е число (он — на начало своего дня).
  int moneyAtStart(DateTime first) =>
      money(DateTime(first.year, first.month, first.day - 1)) +
      catalog.accounts.values
          .where(
            (a) =>
                a.openingDate != null &&
                calendarDay(a.openingDate!) == calendarDay(first),
          )
          .fold(0, (s, a) => s + a.openingBalance);
  final opening = [for (final m in columns) moneyAtStart(m)];
  final closing = [
    for (final m in columns) money(DateTime(m.year, m.month + 1, 0)),
  ];

  final report = DdsReport(
    columns: columns,
    opening: opening,
    closing: closing,
    operatingIn: operating.income,
    operatingOut: operating.expense,
    investingOut: investing.expense,
    financing: financing,
    other: List.filled(count, 0),
  );
  final flow = report.netFlow;
  return DdsReport(
    columns: columns,
    opening: opening,
    closing: closing,
    operatingIn: operating.income,
    operatingOut: operating.expense,
    investingOut: investing.expense,
    financing: financing,
    other: [for (var i = 0; i < count; i++) closing[i] - opening[i] - flow[i]],
  );
}
