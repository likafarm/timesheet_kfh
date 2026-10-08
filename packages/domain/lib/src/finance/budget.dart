// packages/domain/lib/src/finance/budget.dart
//
// Бюджет движения денег — БДДС (этап 8Б.5): план поступлений и платежей
// по статьям и месяцам и сравнение с фактом (`cashFlowReport` по
// статьям). План необязателен: без него отчёт показывает факт. Займы и
// переводы — вне бюджета (как в отчёте «по месяцам»).

import 'catalog.dart';
import 'models.dart';
import 'report.dart';

/// План статьи на месяц (копейки, не меньше нуля; знак — по виду статьи).
class BudgetEntry {
  final String id;
  final int year;
  final int month;
  final String categoryId;
  final int amount;

  const BudgetEntry({
    required this.id,
    required this.year,
    required this.month,
    required this.categoryId,
    required this.amount,
  });

  BudgetEntry copyWith({int? amount}) => BudgetEntry(
    id: id,
    year: year,
    month: month,
    categoryId: categoryId,
    amount: amount ?? this.amount,
  );
}

/// Строка бюджета: статья, план и факт по 12 месяцам.
class BudgetLine {
  final String categoryId;
  final String name;
  final List<int> plan;
  final List<int> fact;

  const BudgetLine({
    required this.categoryId,
    required this.name,
    required this.plan,
    required this.fact,
  });

  /// План и факт за месяцы [months] (1–12; пусто — весь год).
  int planOf([Iterable<int>? months]) => _sum(plan, months);
  int factOf([Iterable<int>? months]) => _sum(fact, months);
}

int _sum(List<int> values, Iterable<int>? months) {
  final ms = months ?? [for (var m = 1; m <= 12; m++) m];
  return ms.fold(0, (s, m) => s + values[m - 1]);
}

class BudgetGroup {
  final String name;
  final List<BudgetLine> lines;

  const BudgetGroup(this.name, this.lines);

  int planOf([Iterable<int>? months]) =>
      lines.fold(0, (s, l) => s + l.planOf(months));
  int factOf([Iterable<int>? months]) =>
      lines.fold(0, (s, l) => s + l.factOf(months));
}

class BudgetSection {
  final CategoryType type;
  final List<BudgetGroup> groups;

  const BudgetSection(this.type, this.groups);

  int planOf([Iterable<int>? months]) =>
      groups.fold(0, (s, g) => s + g.planOf(months));
  int factOf([Iterable<int>? months]) =>
      groups.fold(0, (s, g) => s + g.factOf(months));
}

class BudgetReport {
  final int year;
  final BudgetSection income;
  final BudgetSection expense;

  const BudgetReport({
    required this.year,
    required this.income,
    required this.expense,
  });

  bool get isEmpty => income.groups.isEmpty && expense.groups.isEmpty;
}

/// БДДС за год [year]: строки — статьи с планом или фактом за год (по
/// порядку групп и статей справочника; скрытые статьи без плана и факта
/// — не показываются). [operations] — вместе с расходами ЗП из выплат.
BudgetReport budgetReport({
  required int year,
  required Iterable<BudgetEntry> entries,
  required Iterable<FinOperation> operations,
  required FinanceCatalog catalog,
}) {
  final fact = cashFlowReport(
    operations: operations,
    catalog: catalog,
    from: DateTime(year),
  );
  final plan = <String, List<int>>{};
  for (final e in entries) {
    if (e.year != year || e.month < 1 || e.month > 12) continue;
    (plan[e.categoryId] ??= List.filled(12, 0))[e.month - 1] += e.amount;
  }

  BudgetSection section(CategoryType type, CashFlowSection factSection) {
    final factById = {
      for (final g in factSection.groups)
        for (final l in g.lines) l.id: l.values,
    };
    // Статьи вида [type] с планом или фактом.
    final ids = {
      ...factById.keys,
      for (final id in plan.keys)
        if (catalog.categories[id]?.type == type) id,
    };
    final groups = <String, List<FinCategory>>{};
    final groupOrder = <String, (int, String)>{};
    final orphans = <BudgetLine>[];
    for (final id in ids) {
      final c = catalog.categories[id];
      if (c == null) {
        // Факт без статьи («Статья не указана»).
        orphans.add(
          BudgetLine(
            categoryId: id,
            name: 'Статья не указана',
            plan: List.filled(12, 0),
            fact: factById[id] ?? List.filled(12, 0),
          ),
        );
        continue;
      }
      final g = catalog.groupOf(c);
      final name = g?.name ?? c.group;
      (groups[name] ??= []).add(c);
      groupOrder[name] = (g?.sortOrder ?? 1 << 30, name);
    }
    final names = groups.keys.toList()
      ..sort((a, b) {
        final x = groupOrder[a]!, y = groupOrder[b]!;
        final o = x.$1.compareTo(y.$1);
        return o != 0 ? o : x.$2.compareTo(y.$2);
      });
    return BudgetSection(type, [
      for (final name in names)
        BudgetGroup(name, [
          for (final c
              in groups[name]!..sort((a, b) {
                final o = a.sortOrder.compareTo(b.sortOrder);
                return o != 0 ? o : a.name.compareTo(b.name);
              }))
            BudgetLine(
              categoryId: c.id,
              name: c.name,
              plan: plan[c.id] ?? List.filled(12, 0),
              fact: factById[c.id] ?? List.filled(12, 0),
            ),
        ]),
      if (orphans.isNotEmpty) BudgetGroup('Без статьи', orphans),
    ]);
  }

  return BudgetReport(
    year: year,
    income: section(CategoryType.income, fact.income),
    expense: section(CategoryType.expense, fact.expense),
  );
}

/// План года [year] по факту года [year] − 1 (до рубля): статья → суммы по
/// месяцам; месяцы без факта — не попадают.
Map<String, List<int>> budgetFromFact({
  required int year,
  required Iterable<FinOperation> operations,
  required FinanceCatalog catalog,
}) {
  final fact = cashFlowReport(
    operations: operations,
    catalog: catalog,
    from: DateTime(year - 1),
  );
  int rubles(int k) => (k + 50) ~/ 100 * 100;
  return {
    for (final s in [fact.income, fact.expense])
      for (final g in s.groups)
        for (final l in g.lines)
          if (l.id != noCategory) l.id: [for (final v in l.values) rubles(v)],
  };
}
