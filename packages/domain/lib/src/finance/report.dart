// packages/domain/lib/src/finance/report.dart
//
// Отчёт «статьи / направления × месяцы» (вторая очередь этапа 8): доходы и
// расходы по месяцам — строками по статьям (с группами) или по
// направлениям (с раскладкой ключей), итоги групп, разделов и результат.
// Переводы и займы — не доход и не расход, в отчёт не входят.

import '../utils/date_utils.dart';
import 'calc.dart';
import 'catalog.dart';
import 'models.dart';

/// Чем строки отчёта.
enum CashFlowBy {
  category('По статьям'),
  direction('По направлениям');

  final String title;
  const CashFlowBy(this.title);
}

/// Id строки «статья не указана» в отчёте по статьям.
const noCategory = '';

/// Строка отчёта: статья или направление ([unassignedDirection] — «не
/// определено»), суммы по месяцам в копейках.
class CashFlowLine {
  final String id;
  final String name;
  final List<int> months;

  const CashFlowLine({
    required this.id,
    required this.name,
    required this.months,
  });

  int get total => months.fold(0, (a, b) => a + b);
}

/// Группа строк: группа статей (по направлениям — одна группа без
/// названия).
class CashFlowGroup {
  /// Id группы статей; null — группы нет в справочнике (или отчёт по
  /// направлениям).
  final String? id;
  final String name;
  final List<CashFlowLine> lines;

  const CashFlowGroup({this.id, required this.name, required this.lines});

  List<int> get months => _sum([for (final l in lines) l.months]);
  int get total => months.fold(0, (a, b) => a + b);
}

/// Доходы или расходы.
class CashFlowSection {
  final CategoryType type;
  final List<CashFlowGroup> groups;

  /// В расходах — капвложения по месяцам (в доходах — возвраты): они уже
  /// входят в [months], показываются строкой «в т. ч.».
  final List<int> special;

  const CashFlowSection({
    required this.type,
    required this.groups,
    required this.special,
  });

  List<int> get months =>
      _sum([for (final g in groups) g.months], length: special.length);
  int get total => months.fold(0, (a, b) => a + b);
  int get specialTotal => special.fold(0, (a, b) => a + b);
  bool get isEmpty => groups.every((g) => g.lines.isEmpty);
}

class CashFlowReport {
  final CashFlowBy by;

  /// Первые числа месяцев отчёта по порядку.
  final List<DateTime> months;
  final CashFlowSection income;
  final CashFlowSection expense;

  const CashFlowReport({
    required this.by,
    required this.months,
    required this.income,
    required this.expense,
  });

  /// Доходы минус расходы по месяцам.
  List<int> get result => [
    for (var i = 0; i < months.length; i++)
      income.months[i] - expense.months[i],
  ];

  int get resultTotal => income.total - expense.total;
  bool get isEmpty => income.isEmpty && expense.isEmpty;
}

List<int> _sum(List<List<int>> rows, {int? length}) {
  final n = length ?? (rows.isEmpty ? 0 : rows.first.length);
  final result = List.filled(n, 0);
  for (final r in rows) {
    for (var i = 0; i < n; i++) {
      result[i] += r[i];
    }
  }
  return result;
}

/// Отчёт за [count] месяцев с месяца [from]. [operations] — операции
/// вместе с расходами ЗП из выплат (`payrollExpenses`). Строки без сумм за
/// период не показываются; статьи — по порядку групп и статей
/// справочника, направления — по порядку справочника, «не определено» —
/// последним.
CashFlowReport cashFlowReport({
  required Iterable<FinOperation> operations,
  required FinanceCatalog catalog,
  required DateTime from,
  int count = 12,
  CashFlowBy by = CashFlowBy.category,
}) {
  final start = DateTime(from.year, from.month);
  final months = [
    for (var i = 0; i < count; i++) DateTime(start.year, start.month + i),
  ];
  int? indexOf(DateTime date) {
    final d = calendarDay(date);
    final i = (d.year - start.year) * 12 + d.month - start.month;
    return i >= 0 && i < count ? i : null;
  }

  // Вид → id строки → суммы по месяцам; «в т. ч.» — отдельно.
  final amounts = {
    CategoryType.income: <String, List<int>>{},
    CategoryType.expense: <String, List<int>>{},
  };
  final special = {
    CategoryType.income: List.filled(count, 0),
    CategoryType.expense: List.filled(count, 0),
  };
  void add(CategoryType type, String id, int i, int amount) {
    (amounts[type]![id] ??= List.filled(count, 0))[i] += amount;
  }

  for (final op in operations) {
    final type = switch (op.type) {
      OperationType.income => CategoryType.income,
      OperationType.expense => CategoryType.expense,
      _ => null,
    };
    final i = indexOf(op.date);
    if (type == null || i == null) continue;
    final kind = catalog.categories[op.categoryId]?.kind;
    if (kind ==
        (type == CategoryType.income
            ? CategoryKind.refund
            : CategoryKind.capex)) {
      special[type]![i] += op.amount;
    }
    switch (by) {
      case CashFlowBy.category:
        add(type, op.categoryId ?? noCategory, i, op.amount);
      case CashFlowBy.direction:
        splitByDirection(op, catalog).forEach((d, a) => add(type, d, i, a));
    }
  }

  CashFlowSection section(CategoryType type) {
    final rows = amounts[type]!;
    final groups = switch (by) {
      CashFlowBy.category => _categoryGroups(type, rows, catalog),
      CashFlowBy.direction => [
        CashFlowGroup(name: '', lines: _directionLines(rows, catalog)),
      ],
    };
    return CashFlowSection(
      type: type,
      groups: [
        for (final g in groups)
          if (g.lines.isNotEmpty) g,
      ],
      special: special[type]!,
    );
  }

  return CashFlowReport(
    by: by,
    months: months,
    income: section(CategoryType.income),
    expense: section(CategoryType.expense),
  );
}

List<CashFlowGroup> _categoryGroups(
  CategoryType type,
  Map<String, List<int>> rows,
  FinanceCatalog catalog,
) {
  // Группа справочника — по id; статья с группой не из справочника — по
  // тексту группы; статья не указана или не найдена — «Без статьи».
  final known = <String, List<FinCategory>>{};
  final byText = <String, List<FinCategory>>{};
  var orphan = false;
  for (final id in rows.keys) {
    final c = catalog.categories[id];
    if (c == null) {
      orphan = true;
      continue;
    }
    final g = catalog.groupOf(c);
    if (g != null) {
      (known[g.id] ??= []).add(c);
    } else {
      (byText[c.group] ??= []).add(c);
    }
  }
  int byOrder(FinCategory a, FinCategory b) {
    final o = a.sortOrder.compareTo(b.sortOrder);
    return o != 0 ? o : a.name.compareTo(b.name);
  }

  List<CashFlowLine> lines(List<FinCategory> cs) => [
    for (final c in cs..sort(byOrder))
      CashFlowLine(id: c.id, name: c.name, months: rows[c.id]!),
  ];
  final unknownIds = [
    for (final id in rows.keys)
      if (!catalog.categories.containsKey(id)) id,
  ];
  return [
    for (final g in catalog.groupsOf(type))
      if (known[g.id] case final cs?)
        CashFlowGroup(id: g.id, name: g.name, lines: lines(cs)),
    for (final name in byText.keys.toList()..sort())
      CashFlowGroup(name: name, lines: lines(byText[name]!)),
    if (orphan)
      CashFlowGroup(
        name: 'Без статьи',
        lines: [
          CashFlowLine(
            id: noCategory,
            name: 'Статья не указана',
            months: _sum([for (final id in unknownIds) rows[id]!]),
          ),
        ],
      ),
  ];
}

List<CashFlowLine> _directionLines(
  Map<String, List<int>> rows,
  FinanceCatalog catalog,
) {
  final directions = [for (final id in rows.keys) ?catalog.directions[id]]
    ..sort((a, b) {
      final o = a.sortOrder.compareTo(b.sortOrder);
      return o != 0 ? o : a.name.compareTo(b.name);
    });
  final unknown = [
    for (final id in rows.keys)
      if (!catalog.directions.containsKey(id)) rows[id]!,
  ];
  return [
    for (final d in directions)
      CashFlowLine(id: d.id, name: d.name, months: rows[d.id]!),
    if (unknown.isNotEmpty)
      CashFlowLine(
        id: unassignedDirection,
        name: 'Направление не определено',
        months: _sum(unknown),
      ),
  ];
}
