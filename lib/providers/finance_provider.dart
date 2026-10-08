// lib/providers/finance_provider.dart
//
// Раздел «Финансы» (этап 8.5): справочники, операции и расходы ЗП из
// табеля поверх базы [AppProvider]. Проверки — те же, что у сервера:
// правила операций (`operationProblem`), ключей (`allocationKeyProblem`),
// закрытые месяцы (`PeriodGuard` через [AppProvider.allowedInOpenPeriod]),
// оператор финансы не правит. Нарушение — сообщение внизу окна и false.

import 'package:flutter/foundation.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart' show newUuid;

import 'app_provider.dart';

/// Отбор операций списка. null в поле — «все».
class FinanceFilter {
  /// Месяц (первое число); null — за всё время.
  final DateTime? month;
  final String? accountId;
  final String? categoryId;
  final String? directionId;
  final String? counterpartyId;
  final OperationType? type;

  const FinanceFilter({
    this.month,
    this.accountId,
    this.categoryId,
    this.directionId,
    this.counterpartyId,
    this.type,
  });

  FinanceFilter copyWith({
    DateTime? Function()? month,
    String? Function()? accountId,
    String? Function()? categoryId,
    String? Function()? directionId,
    String? Function()? counterpartyId,
    OperationType? Function()? type,
  }) => FinanceFilter(
    month: month == null ? this.month : month(),
    accountId: accountId == null ? this.accountId : accountId(),
    categoryId: categoryId == null ? this.categoryId : categoryId(),
    directionId: directionId == null ? this.directionId : directionId(),
    counterpartyId: counterpartyId == null
        ? this.counterpartyId
        : counterpartyId(),
    type: type == null ? this.type : type(),
  );

  /// Есть отбор, кроме месяца.
  bool get narrowed =>
      accountId != null ||
      categoryId != null ||
      directionId != null ||
      counterpartyId != null ||
      type != null;
}

class FinanceProvider extends ChangeNotifier {
  FinanceProvider(this._app) : _seenVersion = _app.dataVersion {
    _app.addListener(_onApp);
  }

  final AppProvider _app;
  int _seenVersion;

  FinanceRepository get _repo => _app.repos.finance;

  bool _loaded = false;
  bool _loading = false;
  bool get loaded => _loaded;
  bool get loading => _loading;

  List<FinAccount> _accounts = const [];
  List<FinDirection> _directions = const [];
  List<AllocationKey> _keys = const [];
  List<Asset> _assets = const [];
  List<FinCategory> _categories = const [];
  List<Counterparty> _counterparties = const [];
  List<FinDebt> _debts = const [];
  PayrollFinanceMapping? _mapping;
  List<FinOperation> _manual = const [];
  List<FinOperation> _payroll = const [];
  Map<String, Employee> _employees = const {};
  FinanceCatalog _catalog = FinanceCatalog();

  List<FinAccount> get accounts => _accounts;
  List<FinDirection> get directions => _directions;
  List<AllocationKey> get allocationKeys => _keys;
  List<Asset> get assets => _assets;
  List<FinCategory> get categories => _categories;
  List<Counterparty> get counterparties => _counterparties;
  List<FinDebt> get debts => _debts;
  PayrollFinanceMapping? get payrollMapping => _mapping;
  FinanceCatalog get catalog => _catalog;
  Map<String, Employee> get employees => _employees;

  /// Все операции: записанные и расходы ЗП из выплат табеля (только
  /// чтение — правятся в «Выплатах»), новые сверху.
  List<FinOperation> get allOperations =>
      [..._manual, ..._payroll]..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });

  /// Операция построена из выплаты табеля ([payrollExpenses]).
  static bool isPayroll(FinOperation op) =>
      op.source == OperationSource.payroll;

  void _onApp() {
    if (_app.dataVersion != _seenVersion) {
      _seenVersion = _app.dataVersion;
      if (_loaded) load();
    }
  }

  @override
  void dispose() {
    _app.removeListener(_onApp);
    super.dispose();
  }

  /// Перечитать справочники и операции.
  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final repos = _app.repos;
      _accounts = await _repo.accounts();
      _directions = await _repo.directions();
      _keys = await _repo.allocationKeys();
      _assets = await _repo.assets();
      _categories = await _repo.categories();
      _counterparties = await _repo.counterparties();
      _debts = await _repo.debts();
      _mapping = await _repo.payrollMapping();
      _manual = await _repo.operations();
      _employees = {
        for (final e in await repos.employees.all())
          if (e.id != null) e.id!: e,
      };
      final mapping = _mapping;
      _payroll = mapping == null
          ? const []
          : payrollExpenses(await repos.payments.list(), _employees, mapping);
      _catalog = FinanceCatalog(
        accounts: _accounts,
        directions: _directions,
        keys: _keys,
        assets: _assets,
        categories: _categories,
        counterparties: _counterparties,
        debts: _debts,
      );
      _loaded = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- отбор

  /// Направления, на которые пошла операция (с раскладкой ключа).
  Set<String> directionsOf(FinOperation op) =>
      op.type == OperationType.income || op.type == OperationType.expense
      ? splitByDirection(op, _catalog).keys.toSet()
      : const {};

  /// Операции по отбору, новые сверху.
  List<FinOperation> operations(FinanceFilter f) => [
    for (final op in allOperations)
      if (_matches(op, f)) op,
  ];

  bool _matches(FinOperation op, FinanceFilter f) {
    final month = f.month;
    if (month != null &&
        (op.date.year != month.year || op.date.month != month.month)) {
      return false;
    }
    if (f.type != null && op.type != f.type) return false;
    if (f.accountId != null &&
        op.accountId != f.accountId &&
        op.toAccountId != f.accountId) {
      return false;
    }
    if (f.categoryId != null && op.categoryId != f.categoryId) return false;
    if (f.counterpartyId != null && op.counterpartyId != f.counterpartyId) {
      return false;
    }
    if (f.directionId != null && !directionsOf(op).contains(f.directionId)) {
      return false;
    }
    return true;
  }

  FinanceTotals totals(Iterable<FinOperation> ops) =>
      financeTotals(ops, _catalog);

  /// Остатки кошельков на конец дня [at] (null — сейчас).
  Map<String, int> accountBalancesAt([DateTime? at]) =>
      accountBalances(_accounts, allOperations, at: at);

  /// Остатки займов на конец дня [at] (null — сейчас).
  Map<String, int> debtBalancesAt([DateTime? at]) =>
      debtBalances(_debts, allOperations, at: at);

  // --------------------------------------------------------- подписи

  String accountName(String? id) => _catalog.accounts[id]?.name ?? '—';
  String categoryName(String? id) => _catalog.categories[id]?.name ?? '—';
  String counterpartyName(String? id) =>
      _catalog.counterparties[id]?.name ?? '';

  /// «На что пошло»: направление, ключ или имущество операции; иначе —
  /// направление статьи (серым в списке — «по статье»).
  String directionLabel(FinOperation op) {
    if (op.directionId case final id?) {
      return _catalog.directions[id]?.name ?? '—';
    }
    if (op.allocationKeyId case final id?) {
      return 'Ключ «${_catalog.keys[id]?.name ?? '—'}»';
    }
    if (op.assetId case final id?) {
      return _catalog.assets[id]?.name ?? '—';
    }
    final category = _catalog.categories[op.categoryId];
    if (category?.directionId case final id?) {
      return _catalog.directions[id]?.name ?? '—';
    }
    if (category?.allocationKeyId case final id?) {
      return 'Ключ «${_catalog.keys[id]?.name ?? '—'}»';
    }
    return '';
  }

  /// Займ — подписью «Контрагент (вид)».
  String debtName(String? id) {
    final debt = _catalog.debts[id];
    if (debt == null) return '—';
    return '${counterpartyName(debt.counterpartyId)} '
        '(${debt.kind.title.toLowerCase()})';
  }

  /// Новый id записи (uuid v7, как у всех записей базы).
  String newId() => newUuid();

  // ---------------------------------------------------------- операции

  static Map<String, Object?> _opRow(FinOperation op) => {
    'date': formatDateIso(op.date),
  };

  /// Записать операцию (новую или изменённую [before]); false — не
  /// записано, объяснение — внизу окна.
  Future<bool> saveOperation(FinOperation op, {FinOperation? before}) async {
    if (!_app.financeAllowed()) return false;
    if (isPayroll(op)) {
      _app.showNotice('Выплата ЗП правится в «Выплатах»');
      return false;
    }
    final problem = operationProblem(op, _catalog, before: before);
    if (problem != null) {
      _app.showNotice('Не сохранено: $problem');
      return false;
    }
    if (!_app.allowedInOpenPeriod(
      'fin_operations',
      before == null ? null : _opRow(before),
      _opRow(op),
    )) {
      return false;
    }
    return _write(() async {
      if (before == null) {
        await _repo.addOperation(op);
      } else {
        await _repo.updateOperation(op);
      }
    });
  }

  Future<bool> deleteOperation(FinOperation op) async {
    if (!_app.financeAllowed()) return false;
    if (isPayroll(op)) {
      _app.showNotice('Выплата ЗП удаляется в «Выплатах»');
      return false;
    }
    if (!_app.allowedInOpenPeriod('fin_operations', _opRow(op), null)) {
      return false;
    }
    return _write(() => _repo.deleteOperation(op.id));
  }

  /// Новая операция по образцу [op] («Повторить операцию», замена F9 в
  /// Excel): всё то же, другой id, день — [date] (по умолчанию сегодня).
  FinOperation repeat(FinOperation op, {DateTime? date}) => FinOperation(
    id: newId(),
    date: calendarDay(date ?? DateTime.now()),
    type: op.type,
    amount: op.amount,
    accountId: op.accountId,
    toAccountId: op.toAccountId,
    categoryId: op.categoryId,
    directionId: op.directionId,
    allocationKeyId: op.allocationKeyId,
    assetId: op.assetId,
    season: op.season,
    counterpartyId: op.counterpartyId,
    employeeId: op.employeeId,
    debtId: op.debtId,
    debtMove: op.debtMove,
    description: op.description,
    quantity: op.quantity,
    unit: op.unit,
    tag: op.tag,
    notes: op.notes,
  );

  // ------------------------------------------------------- справочники

  Future<bool> saveAccount(FinAccount a, {FinAccount? before}) async {
    if (!_app.financeAllowed()) return false;
    if (a.name.trim().isEmpty) return _refuse('У кошелька нет названия');
    // Начальный остаток — в дне opening_date (правило сервера).
    Map<String, Object?> row(FinAccount x) => {
      'opening_balance': x.openingBalance,
      'opening_date': x.openingDate == null
          ? null
          : formatDateIso(x.openingDate!),
    };
    if (!_app.allowedInOpenPeriod(
      'fin_accounts',
      before == null ? null : row(before),
      row(a),
    )) {
      return false;
    }
    return _write(() => _repo.saveAccount(a));
  }

  Future<bool> saveCategory(FinCategory c) async {
    if (!_app.financeAllowed()) return false;
    if (c.name.trim().isEmpty) return _refuse('У статьи нет названия');
    if (c.directionId != null && c.allocationKeyId != null) {
      return _refuse('Укажите направление или ключ — не оба сразу');
    }
    return _write(() => _repo.saveCategory(c));
  }

  Future<bool> saveCounterparty(Counterparty c) async {
    if (!_app.financeAllowed()) return false;
    if (c.name.trim().isEmpty) return _refuse('У контрагента нет названия');
    return _write(() => _repo.saveCounterparty(c));
  }

  Future<bool> saveDirection(FinDirection d) async {
    if (!_app.financeAllowed()) return false;
    if (d.name.trim().isEmpty) return _refuse('У направления нет названия');
    return _write(() => _repo.saveDirection(d));
  }

  Future<bool> saveAllocationKey(AllocationKey k) async {
    if (!_app.financeAllowed()) return false;
    final problem = allocationKeyProblem(k, _catalog);
    if (problem != null) return _refuse(problem);
    return _write(() => _repo.saveAllocationKey(k));
  }

  Future<bool> saveAsset(Asset a) async {
    if (!_app.financeAllowed()) return false;
    if (a.name.trim().isEmpty) return _refuse('У имущества нет названия');
    if (a.directionId != null && a.allocationKeyId != null) {
      return _refuse('Укажите направление или ключ — не оба сразу');
    }
    return _write(() => _repo.saveAsset(a));
  }

  Future<bool> saveDebt(FinDebt d, {FinDebt? before}) async {
    if (!_app.financeAllowed()) return false;
    if (!_catalog.counterparties.containsKey(d.counterpartyId)) {
      return _refuse('Не указан контрагент займа');
    }
    Map<String, Object?> row(FinDebt x) => {
      'opening_balance': x.openingBalance,
      'opening_date': x.openingDate == null
          ? null
          : formatDateIso(x.openingDate!),
    };
    if (!_app.allowedInOpenPeriod(
      'fin_debts',
      before == null ? null : row(before),
      row(d),
    )) {
      return false;
    }
    return _write(() => _repo.saveDebt(d));
  }

  /// Сколько операций ссылается на запись справочника (удалить можно
  /// только неиспользуемую — иначе закрыть или скрыть).
  int usages({
    String? accountId,
    String? categoryId,
    String? counterpartyId,
    String? directionId,
    String? keyId,
    String? assetId,
    String? debtId,
  }) {
    var n = 0;
    for (final op in allOperations) {
      if ((accountId != null &&
              (op.accountId == accountId || op.toAccountId == accountId)) ||
          (categoryId != null && op.categoryId == categoryId) ||
          (counterpartyId != null && op.counterpartyId == counterpartyId) ||
          (directionId != null && op.directionId == directionId) ||
          (keyId != null && op.allocationKeyId == keyId) ||
          (assetId != null && op.assetId == assetId) ||
          (debtId != null && op.debtId == debtId)) {
        n++;
      }
    }
    if (directionId != null) {
      n += _categories.where((c) => c.directionId == directionId).length;
      n += _assets.where((a) => a.directionId == directionId).length;
    }
    if (keyId != null) {
      n += _categories.where((c) => c.allocationKeyId == keyId).length;
      n += _assets.where((a) => a.allocationKeyId == keyId).length;
    }
    if (counterpartyId != null) {
      n += _debts.where((d) => d.counterpartyId == counterpartyId).length;
    }
    return n;
  }

  /// Удалить неиспользуемую запись справочника: [table] — имя таблицы.
  Future<bool> deleteCatalogItem(String table, String id) async {
    if (!_app.financeAllowed()) return false;
    final used = switch (table) {
      'fin_accounts' => usages(accountId: id),
      'fin_categories' => usages(categoryId: id),
      'counterparties' => usages(counterpartyId: id),
      'fin_allocation_keys' => usages(keyId: id),
      'fin_assets' => usages(assetId: id),
      'fin_debts' => usages(debtId: id),
      _ => throw ArgumentError(table),
    };
    if (used > 0) {
      return _refuse(
        'Запись используется ($used) — удалить нельзя. Кошелёк можно '
        'закрыть, статью — скрыть.',
      );
    }
    return _write(
      () => switch (table) {
        'fin_accounts' => _repo.deleteAccount(id),
        'fin_categories' => _repo.deleteCategory(id),
        'counterparties' => _repo.deleteCounterparty(id),
        'fin_allocation_keys' => _repo.deleteAllocationKey(id),
        'fin_assets' => _repo.deleteAsset(id),
        'fin_debts' => _repo.deleteDebt(id),
        _ => throw ArgumentError(table),
      },
    );
  }

  bool _refuse(String message) {
    _app.showNotice('Не сохранено: $message');
    return false;
  }

  Future<bool> _write(Future<void> Function() action) async {
    try {
      await action();
    } on DuplicateEntryException catch (e) {
      return _refuse(e.message);
    } catch (e) {
      return _refuse('$e');
    }
    await load();
    return true;
  }
}
