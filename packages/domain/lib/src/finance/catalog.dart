// packages/domain/lib/src/finance/catalog.dart
//
// Справочники финансов одним объектом: правила и расчёты ищут в нём
// кошельки, статьи, направления, ключи, имущество и долги по id.

import 'models.dart';

class FinanceCatalog {
  final Map<String, FinAccount> accounts;
  final Map<String, FinDirection> directions;
  final Map<String, AllocationKey> keys;
  final Map<String, Asset> assets;
  final Map<String, FinCategory> categories;
  final Map<String, FinCategoryGroup> groups;
  final Map<String, Counterparty> counterparties;
  final Map<String, FinDebt> debts;

  FinanceCatalog({
    Iterable<FinAccount> accounts = const [],
    Iterable<FinDirection> directions = const [],
    Iterable<AllocationKey> keys = const [],
    Iterable<Asset> assets = const [],
    Iterable<FinCategory> categories = const [],
    Iterable<FinCategoryGroup> groups = const [],
    Iterable<Counterparty> counterparties = const [],
    Iterable<FinDebt> debts = const [],
  }) : accounts = {for (final a in accounts) a.id: a},
       directions = {for (final d in directions) d.id: d},
       keys = {for (final k in keys) k.id: k},
       assets = {for (final a in assets) a.id: a},
       categories = {for (final c in categories) c.id: c},
       groups = {for (final g in groups) g.id: g},
       counterparties = {for (final c in counterparties) c.id: c},
       debts = {for (final d in debts) d.id: d};

  /// Группа статьи: по ссылке, иначе (запись старой программы) — группа
  /// того же вида с тем же названием; null — такой группы в справочнике нет.
  FinCategoryGroup? groupOf(FinCategory category) {
    final byId = groups[category.groupId];
    if (byId != null) return byId;
    for (final g in groups.values) {
      if (g.type == category.type && g.name == category.group) return g;
    }
    return null;
  }

  /// Группы вида [type] по порядку (порядок, затем название).
  List<FinCategoryGroup> groupsOf(CategoryType type) => [
    for (final g in groups.values)
      if (g.type == type) g,
  ]..sort(compareCategoryGroups);
}

/// Порядок групп: [FinCategoryGroup.sortOrder], затем название.
int compareCategoryGroups(FinCategoryGroup a, FinCategoryGroup b) {
  final byOrder = a.sortOrder.compareTo(b.sortOrder);
  return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
}
