// packages/domain/lib/src/finance/rules.dart
//
// Правила операций и ключей распределения — одни для окон, AppProvider и
// сервера (как `timesheetMarkProblem`): текст для человека или null.

import 'dart:convert';

import 'catalog.dart';
import 'models.dart';

/// Что не так с операцией [op] — текст для человека; null — всё в порядке.
/// [before] — прежняя версия при правке: закрытый кошелёк и выбывшее
/// имущество запрещены только для новых привязок, старые записи с ними
/// править можно.
String? operationProblem(
  FinOperation op,
  FinanceCatalog catalog, {
  FinOperation? before,
}) {
  if (op.amount <= 0) return 'Сумма должна быть больше нуля';
  final season = op.season;
  if (season != null && (season < 2000 || season > 2100)) {
    return 'Сезон урожая — год, а указано $season';
  }

  String? account(String id, String role) {
    final a = catalog.accounts[id];
    if (a == null) return '$role не найден';
    final kept =
        before != null && (before.accountId == id || before.toAccountId == id);
    if (a.closed && !kept) return 'Кошелёк «${a.name}» закрыт';
    return null;
  }

  final accountProblem = account(op.accountId, 'Кошелёк');
  if (accountProblem != null) return accountProblem;

  switch (op.type) {
    case OperationType.income:
    case OperationType.expense:
      if (op.toAccountId != null) {
        return 'У дохода и расхода нет второго кошелька';
      }
      if (op.debtId != null || op.debtMove != null) {
        return 'Займ — отдельный вид операции, не доход и не расход';
      }
      final categoryId = op.categoryId;
      if (categoryId == null) return 'Не указана статья';
      final category = catalog.categories[categoryId];
      if (category == null) return 'Статья не найдена';
      final wanted = op.type == OperationType.income
          ? CategoryType.income
          : CategoryType.expense;
      if (category.type != wanted) {
        return 'Статья «${category.name}» — ${category.type.title.toLowerCase()}, '
            'а операция — ${op.type.title.toLowerCase()}';
      }
      return _directionProblem(op, category, catalog, before);
    case OperationType.transfer:
      final to = op.toAccountId;
      if (to == null) return 'У перевода не указан кошелёк, куда';
      if (to == op.accountId) return 'Перевод в тот же кошелёк';
      final toProblem = account(to, 'Кошелёк, куда');
      if (toProblem != null) return toProblem;
      if (op.categoryId != null) return 'У перевода нет статьи';
      if (op.debtId != null || op.debtMove != null) {
        return 'Перевод не бывает займом';
      }
      return null;
    case OperationType.debt:
      if (op.toAccountId != null) return 'У займа нет второго кошелька';
      if (op.categoryId != null) return 'У займа нет статьи';
      final debtId = op.debtId;
      if (debtId == null) return 'Не указан займ';
      final debt = catalog.debts[debtId];
      if (debt == null) return 'Займ не найден';
      final move = op.debtMove;
      if (move == null) return 'Не указано, что сделали с займом';
      if (move.debtKind != debt.kind) {
        return '«${move.title}» не подходит к займу вида '
            '«${debt.kind.title.toLowerCase()}»';
      }
      return null;
  }
}

String? _directionProblem(
  FinOperation op,
  FinCategory category,
  FinanceCatalog catalog,
  FinOperation? before,
) {
  if (op.directionId != null && op.allocationKeyId != null) {
    return 'Укажите направление или ключ — не оба сразу';
  }
  final directionId = op.directionId;
  if (directionId != null && !catalog.directions.containsKey(directionId)) {
    return 'Направление не найдено';
  }
  final keyId = op.allocationKeyId;
  if (keyId != null && !catalog.keys.containsKey(keyId)) {
    return 'Ключ распределения не найден';
  }
  final assetId = op.assetId;
  Asset? asset;
  if (assetId != null) {
    asset = catalog.assets[assetId];
    if (asset == null) return 'Имущество не найдено';
    final kept = before?.assetId == assetId;
    if (asset.disposedBy(op.date) && !kept) {
      return '«${asset.name}» выбыло — к нему нельзя привязать новую операцию';
    }
  }
  final resolvable =
      directionId != null ||
      keyId != null ||
      asset?.directionId != null ||
      asset?.allocationKeyId != null ||
      category.directionId != null ||
      category.allocationKeyId != null;
  if (!resolvable) return 'Не указано направление';
  return null;
}

/// Что не так с ключом распределения — текст или null. С [catalog]
/// проверяется ещё, что направления существуют.
String? allocationKeyProblem(AllocationKey key, [FinanceCatalog? catalog]) {
  if (key.name.trim().isEmpty) return 'У ключа нет названия';
  if (key.periods.isEmpty) return 'У ключа нет долей';
  final starts = <DateTime>{};
  for (final p in key.periods) {
    if (!starts.add(p.validFrom)) {
      return 'Две версии ключа с одной даты';
    }
    if (p.shares.isEmpty) return 'У ключа нет долей';
    var sum = 0;
    for (final MapEntry(key: direction, value: share) in p.shares.entries) {
      if (share < 0) return 'Доля не может быть отрицательной';
      if (catalog != null && !catalog.directions.containsKey(direction)) {
        return 'Направление ключа не найдено';
      }
      sum += share;
    }
    if (sum != 100) return 'Доли ключа в сумме $sum %, а нужно 100 %';
  }
  return null;
}

/// Проверка строки `fin_operations` в формате обмена (сервер, без
/// справочников): поля согласованы с видом операции. Типы, коды и границы
/// уже проверил `SyncChange`; связи — внешние ключи базы. null — в порядке.
String? operationRowProblem(Map<String, Object?> data) {
  final type = data['type'];
  bool has(String column) => data[column] != null;
  switch (type) {
    case 'income' || 'expense':
      if (!has('category_uuid')) return 'Не указана статья';
      if (has('to_account_uuid')) {
        return 'У дохода и расхода нет второго кошелька';
      }
      if (has('debt_uuid') || has('debt_move')) {
        return 'Займ — отдельный вид операции, не доход и не расход';
      }
      if (has('direction_uuid') && has('allocation_key_uuid')) {
        return 'Укажите направление или ключ — не оба сразу';
      }
      return null;
    case 'transfer':
      if (!has('to_account_uuid')) return 'У перевода не указан кошелёк, куда';
      if (data['to_account_uuid'] == data['account_uuid']) {
        return 'Перевод в тот же кошелёк';
      }
      if (has('category_uuid')) return 'У перевода нет статьи';
      if (has('debt_uuid') || has('debt_move')) {
        return 'Перевод не бывает займом';
      }
      return null;
    case 'debt':
      if (!has('debt_uuid')) return 'Не указан займ';
      if (!has('debt_move')) return 'Не указано, что сделали с займом';
      if (has('category_uuid')) return 'У займа нет статьи';
      if (has('to_account_uuid')) return 'У займа нет второго кошелька';
      return null;
    default:
      return 'Неизвестный вид операции: $type';
  }
}

/// Проверка строки `fin_allocation_periods`: доли — JSON-объект
/// «направление → целый процент», неотрицательные, в сумме 100.
String? allocationPeriodRowProblem(Map<String, Object?> data) {
  final Object? decoded;
  try {
    decoded = jsonDecode(data['shares'] as String);
  } catch (_) {
    return 'Доли ключа — не JSON';
  }
  if (decoded is! Map || decoded.isEmpty) return 'У ключа нет долей';
  var sum = 0;
  for (final MapEntry(key: direction, value: share) in decoded.entries) {
    if (direction is! String || direction.isEmpty || share is! int) {
      return 'Доля ключа — целый процент направления';
    }
    if (share < 0) return 'Доля не может быть отрицательной';
    sum += share;
  }
  if (sum != 100) return 'Доли ключа в сумме $sum %, а нужно 100 %';
  return null;
}

/// Проверка строки финансов в формате обмена; null — в порядке или
/// таблица без своих правил.
String? financeRowProblem(String table, Map<String, Object?> data) =>
    switch (table) {
      'fin_operations' => operationRowProblem(data),
      'fin_allocation_periods' => allocationPeriodRowProblem(data),
      _ => null,
    };
