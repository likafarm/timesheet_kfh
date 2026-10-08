// packages/domain/lib/src/finance/summary.dart
//
// Сводка финансов (этап 8.7): остатки кошельков и займов на день, итоги
// месяца — для плиток главного экрана и окна «Остатки». Статьи
// корректировки для сверки остатка.

import '../utils/date_utils.dart';
import 'calc.dart';
import 'catalog.dart';
import 'models.dart';

/// Остаток кошелька на день.
class AccountBalance {
  final FinAccount account;
  final int balance;

  const AccountBalance(this.account, this.balance);
}

/// Остаток займа на день: сколько осталось вернуть (хозяйству или
/// хозяйством — по виду займа).
class DebtBalance {
  final FinDebt debt;
  final int balance;

  const DebtBalance(this.debt, this.balance);
}

class FinanceSummary {
  /// День, на конец которого посчитаны остатки (местная полночь).
  final DateTime day;

  /// Кошельки: открытые — все, закрытые — только с ненулевым остатком; по
  /// порядку справочника.
  final List<AccountBalance> accounts;

  /// Займы с ненулевым остатком (и закрытые, если остаток не сошёлся в
  /// ноль) — по убыванию остатка.
  final List<DebtBalance> debts;

  /// Итоги месяца дня [day] (с первого числа по конец месяца — операции
  /// позже [day] тоже входят: запланированное уже записано).
  final FinanceTotals month;

  const FinanceSummary({
    required this.day,
    required this.accounts,
    required this.debts,
    required this.month,
  });

  /// Все деньги хозяйства: сумма остатков кошельков. Минус кредитки — долг
  /// банку — уменьшает итог.
  int get total => accounts.fold(0, (s, a) => s + a.balance);

  /// Хозяйство должно по полученным займам.
  int get weOwe => _debtSum(DebtKind.received);

  /// Хозяйству должны по выданным займам.
  int get owedToUs => _debtSum(DebtKind.given);

  int _debtSum(DebtKind kind) =>
      debts.where((d) => d.debt.kind == kind).fold(0, (s, d) => s + d.balance);

  /// Финансов ещё нет — плитки не нужны.
  bool get isEmpty =>
      accounts.every((a) => a.balance == 0) &&
      debts.isEmpty &&
      month.income + month.refunds + month.expense + month.capex == 0;
}

/// Сводка на конец дня [day] по всем [operations] (с расходами ЗП из
/// выплат — `payrollExpenses`).
FinanceSummary buildFinanceSummary({
  required FinanceCatalog catalog,
  required Iterable<FinOperation> operations,
  required DateTime day,
}) {
  final d = calendarDay(day);
  final ops = operations.toList();
  final accountsSorted = [...catalog.accounts.values]
    ..sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
  final balances = accountBalances(accountsSorted, ops, at: d);
  final debtSums = debtBalances(catalog.debts.values, ops, at: d);
  return FinanceSummary(
    day: d,
    accounts: [
      for (final a in accountsSorted)
        if (!a.closed || balances[a.id] != 0)
          AccountBalance(a, balances[a.id]!),
    ],
    debts: [
      for (final debt in catalog.debts.values)
        if (debtSums[debt.id] != 0) DebtBalance(debt, debtSums[debt.id]!),
    ]..sort((a, b) => b.balance.compareTo(a.balance)),
    month: financeTotals(
      ops.where((o) => o.date.year == d.year && o.date.month == d.month),
      catalog,
    ),
  );
}

/// Статья корректировки при излишке (доход) — заведена импортом
/// «Финансов 25»; если её нет, программа заводит её сама.
const reconciliationSurplusCategory = 'Корректировка остатка (излишек)';

/// Статья корректировки при недостаче (расход).
const reconciliationShortageCategory = 'Корректировка остатка (недостача)';

/// Статья корректировки нужного вида ([CategoryType.income] — излишек,
/// [CategoryType.expense] — недостача) по названию; null — не заведена.
FinCategory? reconciliationCategory(FinanceCatalog catalog, CategoryType type) {
  final name = type == CategoryType.income
      ? reconciliationSurplusCategory
      : reconciliationShortageCategory;
  for (final c in catalog.categories.values) {
    if (c.type == type && c.name == name) return c;
  }
  return null;
}

/// Направление корректировки: общехозяйственное (накладные), иначе —
/// первое по порядку; null — направлений нет.
String? reconciliationDirection(FinanceCatalog catalog) {
  final directions = [...catalog.directions.values]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  for (final d in directions) {
    if (d.overhead) return d.id;
  }
  return directions.firstOrNull?.id;
}
