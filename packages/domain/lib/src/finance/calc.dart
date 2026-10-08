// packages/domain/lib/src/finance/calc.dart
//
// Расчёты финансов: деление по ключу, направление операции, остатки
// кошельков и долгов, итоги, сверка. Всё в копейках, без потерь.

import '../utils/date_utils.dart';
import 'catalog.dart';
import 'models.dart';

/// Делит [amount] копеек пропорционально [weights] без потерь: части в
/// сумме всегда равны [amount]. Лишние копейки получают части с большим
/// остатком (при равенстве — раньше в списке). Отрицательная сумма
/// делится так же, со знаком.
List<int> allocate(int amount, List<int> weights) {
  if (weights.isEmpty) throw ArgumentError('Нет долей');
  if (weights.any((w) => w < 0)) throw ArgumentError('Отрицательная доля');
  final total = weights.fold(0, (a, b) => a + b);
  if (total == 0) throw ArgumentError('Доли в сумме 0');
  if (amount < 0) return [for (final p in allocate(-amount, weights)) -p];

  final parts = [for (final w in weights) amount * w ~/ total];
  final remainders = [for (final w in weights) amount * w % total];
  var left = amount - parts.fold(0, (a, b) => a + b);
  final order = List.generate(weights.length, (i) => i)
    ..sort((a, b) {
      final byRemainder = remainders[b].compareTo(remainders[a]);
      return byRemainder != 0 ? byRemainder : a.compareTo(b);
    });
  for (final i in order) {
    if (left == 0) break;
    parts[i]++;
    left--;
  }
  return parts;
}

/// Доли ключа на день [day]: последняя версия, начавшаяся не позже дня.
/// Операция раньше первой версии считается по первой.
AllocationPeriod periodAt(AllocationKey key, DateTime day) {
  final periods = [...key.periods]
    ..sort((a, b) => a.validFrom.compareTo(b.validFrom));
  final d = calendarDay(day);
  var result = periods.first;
  for (final p in periods) {
    if (!calendarDay(p.validFrom).isAfter(d)) result = p;
  }
  return result;
}

/// Ключ «направление не определено» в [splitByDirection].
const unassignedDirection = '';

/// Сумма дохода или расхода по направлениям: id направления → копейки.
/// Откуда направление — по порядку: указано в операции → ключ операции →
/// имущество (его направление или ключ) → статья (направление или ключ).
/// Не определилось — всё в [unassignedDirection]. Переводы и займы — не
/// доход и не расход: пустой результат.
Map<String, int> splitByDirection(FinOperation op, FinanceCatalog catalog) {
  if (op.type != OperationType.income && op.type != OperationType.expense) {
    return const {};
  }
  final asset = op.assetId == null ? null : catalog.assets[op.assetId];
  final category = op.categoryId == null
      ? null
      : catalog.categories[op.categoryId];

  final direct = op.directionId;
  if (direct != null) return {direct: op.amount};
  final keyId = op.allocationKeyId;
  if (keyId != null) return _byKey(op, catalog.keys[keyId]);
  if (asset != null) {
    if (asset.directionId != null) return {asset.directionId!: op.amount};
    if (asset.allocationKeyId != null) {
      return _byKey(op, catalog.keys[asset.allocationKeyId]);
    }
  }
  if (category != null) {
    if (category.directionId != null) {
      return {category.directionId!: op.amount};
    }
    if (category.allocationKeyId != null) {
      return _byKey(op, catalog.keys[category.allocationKeyId]);
    }
  }
  return {unassignedDirection: op.amount};
}

Map<String, int> _byKey(FinOperation op, AllocationKey? key) {
  if (key == null || key.periods.isEmpty) {
    return {unassignedDirection: op.amount};
  }
  final shares = periodAt(key, op.date).shares.entries.toList();
  final parts = allocate(op.amount, [for (final s in shares) s.value]);
  return {
    for (var i = 0; i < shares.length; i++)
      if (parts[i] != 0) shares[i].key: parts[i],
  };
}

/// Операция учитывается в кошельке или долге с начальным остатком на
/// [opening] (на начало этого дня) и до дня [at] включительно.
bool _counts(DateTime date, DateTime? opening, DateTime? at) {
  final d = calendarDay(date);
  if (opening != null && d.isBefore(calendarDay(opening))) return false;
  if (at != null && d.isAfter(calendarDay(at))) return false;
  return true;
}

/// Остатки кошельков на конец дня [at] (null — на сейчас): id → копейки.
/// Начальный остаток — на начало дня `openingDate`: операции раньше этой
/// даты в кошельке не считаются (они уже вошли в остаток). Доход —
/// приход, расход — уход, перевод — уход и приход, займ — по движению
/// ([DebtMove.cashSign]). Выплаты ЗП передавайте сюда же — см.
/// `payrollExpenses`.
Map<String, int> accountBalances(
  Iterable<FinAccount> accounts,
  Iterable<FinOperation> operations, {
  DateTime? at,
}) {
  final byId = {for (final a in accounts) a.id: a};
  final result = <String, int>{
    for (final a in byId.values)
      if (a.openingDate == null ||
          at == null ||
          !calendarDay(a.openingDate!).isAfter(calendarDay(at)))
        a.id: a.openingBalance
      else
        a.id: 0,
  };
  void move(String accountId, int delta, DateTime date) {
    final account = byId[accountId];
    if (account == null || !_counts(date, account.openingDate, at)) return;
    result[accountId] = result[accountId]! + delta;
  }

  for (final op in operations) {
    switch (op.type) {
      case OperationType.income:
        move(op.accountId, op.amount, op.date);
      case OperationType.expense:
        move(op.accountId, -op.amount, op.date);
      case OperationType.transfer:
        move(op.accountId, -op.amount, op.date);
        if (op.toAccountId != null) move(op.toAccountId!, op.amount, op.date);
      case OperationType.debt:
        final m = op.debtMove;
        if (m != null) move(op.accountId, m.cashSign * op.amount, op.date);
    }
  }
  return result;
}

/// Остатки займов на конец дня [at]: id долга → сколько осталось вернуть
/// (хозяйству или хозяйством — по виду долга).
Map<String, int> debtBalances(
  Iterable<FinDebt> debts,
  Iterable<FinOperation> operations, {
  DateTime? at,
}) {
  final byId = {for (final d in debts) d.id: d};
  // До дня начального остатка займа ещё не было (как у кошельков).
  final result = {
    for (final d in byId.values)
      d.id:
          d.openingDate == null ||
              at == null ||
              !calendarDay(d.openingDate!).isAfter(calendarDay(at))
          ? d.openingBalance
          : 0,
  };
  for (final op in operations) {
    final debt = op.debtId == null ? null : byId[op.debtId];
    final m = op.debtMove;
    if (op.type != OperationType.debt || debt == null || m == null) continue;
    if (!_counts(op.date, debt.openingDate, at)) continue;
    result[debt.id] = result[debt.id]! + m.debtSign * op.amount;
  }
  return result;
}

/// Итоги набора операций (например, по фильтру списка). Возвраты — не
/// выручка, капвложения — отдельно от текущих расходов, займы и переводы —
/// не доход и не расход.
class FinanceTotals {
  final int income;
  final int refunds;
  final int expense;
  final int capex;
  final int transfers;
  final int debtIn;
  final int debtOut;

  const FinanceTotals({
    this.income = 0,
    this.refunds = 0,
    this.expense = 0,
    this.capex = 0,
    this.transfers = 0,
    this.debtIn = 0,
    this.debtOut = 0,
  });

  /// Доходы с возвратами минус расходы с капвложениями.
  int get result => income + refunds - expense - capex;
}

FinanceTotals financeTotals(
  Iterable<FinOperation> operations,
  FinanceCatalog catalog,
) {
  var income = 0, refunds = 0, expense = 0, capex = 0;
  var transfers = 0, debtIn = 0, debtOut = 0;
  for (final op in operations) {
    final kind = catalog.categories[op.categoryId]?.kind;
    switch (op.type) {
      case OperationType.income:
        if (kind == CategoryKind.refund) {
          refunds += op.amount;
        } else {
          income += op.amount;
        }
      case OperationType.expense:
        if (kind == CategoryKind.capex) {
          capex += op.amount;
        } else {
          expense += op.amount;
        }
      case OperationType.transfer:
        transfers += op.amount;
      case OperationType.debt:
        if ((op.debtMove?.cashSign ?? 0) > 0) {
          debtIn += op.amount;
        } else {
          debtOut += op.amount;
        }
    }
  }
  return FinanceTotals(
    income: income,
    refunds: refunds,
    expense: expense,
    capex: capex,
    transfers: transfers,
    debtIn: debtIn,
    debtOut: debtOut,
  );
}

/// Расходы (текущие и капвложения) по направлениям: id → копейки, с
/// раскладкой ключей.
Map<String, int> expensesByDirection(
  Iterable<FinOperation> operations,
  FinanceCatalog catalog,
) {
  final result = <String, int>{};
  for (final op in operations) {
    if (op.type != OperationType.expense) continue;
    splitByDirection(op, catalog).forEach((direction, amount) {
      result[direction] = (result[direction] ?? 0) + amount;
    });
  }
  return result;
}

/// Сверка остатка кошелька с фактом на конец дня [date].
class Reconciliation {
  final String accountId;
  final DateTime date;
  final int expected;
  final int actual;

  const Reconciliation({
    required this.accountId,
    required this.date,
    required this.expected,
    required this.actual,
  });

  /// Факт минус расчёт: больше нуля — денег больше, чем записано.
  int get difference => actual - expected;
}

Reconciliation reconcile({
  required FinAccount account,
  required Iterable<FinOperation> operations,
  required DateTime date,
  required int actual,
}) => Reconciliation(
  accountId: account.id,
  date: calendarDay(date),
  expected: accountBalances([account], operations, at: date)[account.id]!,
  actual: actual,
);

/// Корректировка, после которой расчётный остаток равен факту: доход при
/// излишке, расход при недостаче; null — расхождения нет.
FinOperation? reconciliationAdjustment(
  Reconciliation r, {
  required String id,
  required String incomeCategoryId,
  required String expenseCategoryId,
  required String directionId,
  String? createdBy,
}) {
  final diff = r.difference;
  if (diff == 0) return null;
  return FinOperation(
    id: id,
    date: r.date,
    type: diff > 0 ? OperationType.income : OperationType.expense,
    amount: diff.abs(),
    accountId: r.accountId,
    categoryId: diff > 0 ? incomeCategoryId : expenseCategoryId,
    directionId: directionId,
    description: 'Корректировка по сверке остатка',
    createdBy: createdBy,
  );
}
