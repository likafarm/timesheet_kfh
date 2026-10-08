// packages/domain/lib/src/finance/balance.dart
//
// Управленческий баланс на дату (этап 8Б.2): что у хозяйства есть (актив)
// и что оно должно (пассив); капитал — разница. Только расчёт по уже
// введённым данным, новых таблиц нет. Стадо и запасы появятся позже
// (этап 9).

import '../utils/date_utils.dart';
import 'calc.dart';
import 'catalog.dart';
import 'models.dart';

/// Строка баланса: что и сколько (копейки, всегда не меньше нуля).
class BalanceLine {
  final String name;
  final int amount;

  /// Пояснение: вид кошелька, дата оценки имущества.
  final String? note;

  const BalanceLine(this.name, this.amount, {this.note});
}

/// Раздел актива или пассива.
class BalanceSection {
  final String title;
  final List<BalanceLine> lines;

  const BalanceSection(this.title, this.lines);

  int get total => lines.fold(0, (s, l) => s + l.amount);
}

class ManagementBalance {
  final DateTime day;
  final List<BalanceSection> assets;
  final List<BalanceSection> liabilities;

  const ManagementBalance({
    required this.day,
    required this.assets,
    required this.liabilities,
  });

  int get totalAssets => assets.fold(0, (s, x) => s + x.total);
  int get totalLiabilities => liabilities.fold(0, (s, x) => s + x.total);

  /// Капитал хозяйства: актив минус пассив.
  int get equity => totalAssets - totalLiabilities;
}

/// Баланс на конец дня [day].
///
/// - Деньги — остатки кошельков ([accountBalances]); кошелёк в минусе
///   (кредитная карта, перерасход подотчёта) — не актив, а долг (пассив).
/// - Займы — остатки реестра ([debtBalances]): выданные — актив,
///   полученные — пассив.
/// - Имущество — по справочной стоимости (у земли без неё — кадастровая);
///   выбывшее к дню и купленное позже года дня — не входит.
/// - Зарплата — [payrollBalances]: сотрудник → копейки (плюс — долг
///   хозяйства, минус — переплата, она в активе).
///
/// [operations] — вместе с расходами ЗП из выплат (`payrollExpenses`):
/// иначе остатки кошельков не сойдутся.
ManagementBalance buildManagementBalance({
  required DateTime day,
  required FinanceCatalog catalog,
  required Iterable<FinOperation> operations,
  Map<String, int> payrollBalances = const {},
  String Function(String employeeId)? employeeName,
}) {
  final d = calendarDay(day);
  final ops = operations.toList();

  final money = <BalanceLine>[];
  final overdrawn = <BalanceLine>[];
  final balances = accountBalances(catalog.accounts.values, ops, at: d);
  final accounts = [...catalog.accounts.values]
    ..sort((a, b) {
      final o = a.sortOrder.compareTo(b.sortOrder);
      return o != 0 ? o : a.name.compareTo(b.name);
    });
  for (final a in accounts) {
    final b = balances[a.id] ?? 0;
    if (b > 0) money.add(BalanceLine(a.name, b, note: a.kind.title));
    if (b < 0) overdrawn.add(BalanceLine(a.name, -b, note: a.kind.title));
  }

  final lent = <BalanceLine>[];
  final borrowed = <BalanceLine>[];
  final debts = debtBalances(catalog.debts.values, ops, at: d);
  for (final debt in catalog.debts.values) {
    final b = debts[debt.id] ?? 0;
    if (b == 0) continue;
    final name = catalog.counterparties[debt.counterpartyId]?.name ?? '—';
    final line = BalanceLine(name, b.abs());
    // Остаток «наоборот» (вернули больше) — на другой стороне.
    final given = debt.kind == DebtKind.given;
    if (given == (b > 0)) {
      lent.add(line);
    } else {
      borrowed.add(line);
    }
  }

  final property = <BalanceLine>[];
  final assets = [...catalog.assets.values]
    ..sort((a, b) => a.name.compareTo(b.name));
  for (final a in assets) {
    if (a.disposedBy(d)) continue;
    if (a.year != null && a.year! > d.year) continue;
    final value =
        a.referenceValue ??
        (a.kind == AssetKind.land ? a.cadastralValue : null);
    if (value == null || value <= 0) continue;
    property.add(BalanceLine(a.name, value, note: a.kind.title));
  }

  final owed = <BalanceLine>[];
  final advances = <BalanceLine>[];
  final names = employeeName ?? (id) => id;
  for (final e in payrollBalances.entries) {
    if (e.value > 0) owed.add(BalanceLine(names(e.key), e.value));
    if (e.value < 0) advances.add(BalanceLine(names(e.key), -e.value));
  }
  int byAmount(BalanceLine a, BalanceLine b) => b.amount.compareTo(a.amount);
  owed.sort(byAmount);
  advances.sort(byAmount);
  lent.sort(byAmount);
  borrowed.sort(byAmount);

  return ManagementBalance(
    day: d,
    assets: [
      BalanceSection('Деньги', money),
      BalanceSection('Займы выданные', lent),
      BalanceSection('Переплата сотрудникам', advances),
      BalanceSection('Имущество (справочная стоимость)', property),
    ],
    liabilities: [
      BalanceSection('Займы полученные', borrowed),
      BalanceSection('Кредитные карты и кошельки в минусе', overdrawn),
      BalanceSection('Долг по зарплате', owed),
    ],
  );
}
