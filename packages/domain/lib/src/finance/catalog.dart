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
  final Map<String, Counterparty> counterparties;
  final Map<String, FinDebt> debts;

  FinanceCatalog({
    Iterable<FinAccount> accounts = const [],
    Iterable<FinDirection> directions = const [],
    Iterable<AllocationKey> keys = const [],
    Iterable<Asset> assets = const [],
    Iterable<FinCategory> categories = const [],
    Iterable<Counterparty> counterparties = const [],
    Iterable<FinDebt> debts = const [],
  }) : accounts = {for (final a in accounts) a.id: a},
       directions = {for (final d in directions) d.id: d},
       keys = {for (final k in keys) k.id: k},
       assets = {for (final a in assets) a.id: a},
       categories = {for (final c in categories) c.id: c},
       counterparties = {for (final c in counterparties) c.id: c},
       debts = {for (final d in debts) d.id: d};
}
