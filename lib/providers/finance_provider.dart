// lib/providers/finance_provider.dart
//
// Раздел «Финансы» (этап 8.5): справочники, операции и расходы ЗП из
// табеля поверх базы [AppProvider]. Проверки — те же, что у сервера:
// правила операций (`operationProblem`), ключей (`allocationKeyProblem`),
// закрытые месяцы (`PeriodGuard` через [AppProvider.allowedInOpenPeriod]),
// оператор финансы не правит. Нарушение — сообщение внизу окна и false.

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
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
  List<FinCategoryGroup> _groups = const [];
  List<Counterparty> _counterparties = const [];
  List<FinDebt> _debts = const [];
  List<FinPlan> _plans = const [];
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
  List<FinCategoryGroup> get categoryGroups => _groups;
  List<Counterparty> get counterparties => _counterparties;
  List<FinDebt> get debts => _debts;

  /// Планы платёжного календаря (8Б.4; оператору — не загружаются).
  List<FinPlan> get plans => _plans;
  PayrollFinanceMapping? get payrollMapping => _mapping;
  FinanceCatalog get catalog => _catalog;
  Map<String, Employee> get employees => _employees;

  /// Все операции: записанные и расходы ЗП из выплат табеля (только
  /// чтение — правятся в «Выплатах»), новые сверху.
  ///
  /// Оператору (8.8.4) — только свои операции, без выплат ЗП.
  List<FinOperation> get allOperations =>
      (operator
            ? [
                for (final op in _manual)
                  if (operatorSeesOperation(op.createdBy, _app.userUuid ?? ''))
                    op,
              ]
            : [..._manual, ..._payroll])
        ..sort((a, b) {
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
      _groups = await _repo.categoryGroups();
      _counterparties = await _repo.counterparties();
      _debts = await _repo.debts();
      _plans = operator ? const [] : await _repo.plans();
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
        groups: _groups,
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

  /// Остатки кошельков и займов на конец дня [day], итоги его месяца (8.7).
  FinanceSummary summaryAt(DateTime day) => buildFinanceSummary(
    catalog: _catalog,
    operations: allOperations,
    day: day,
  );

  // ------------------------------------------------ сверка остатка (8.7)

  /// Сверка кошелька [accountId] с фактом [actual] на конец дня [date].
  Reconciliation reconciliation(String accountId, DateTime date, int actual) =>
      reconcile(
        account: _catalog.accounts[accountId]!,
        operations: allOperations,
        date: date,
        actual: actual,
      );

  /// Записать корректировку по сверке [r] — доход при излишке, расход при
  /// недостаче (статьи «Корректировка остатка …»; нет — заводятся). false —
  /// не записано (расхождения нет, месяц закрыт и т. п.).
  Future<bool> applyReconciliation(Reconciliation r) async {
    if (!_allowed()) return false;
    if (r.difference == 0) return _fail('Расхождения нет — записывать нечего');
    // Закрытый месяц — до того, как заводить статью.
    if (!_open('fin_operations', null, {'date': formatDateIso(r.date)})) {
      return false;
    }
    final direction = reconciliationDirection(_catalog);
    if (direction == null) {
      return _refuse('Нет ни одного направления — заведите в справочниках');
    }
    final type = r.difference > 0 ? CategoryType.income : CategoryType.expense;
    var category = reconciliationCategory(_catalog, type);
    if (category == null) {
      final group = await _groupNamed(
        type,
        type == CategoryType.income
            ? '3. Прочие поступления'
            : '08. Управление',
      );
      if (group == null) return false;
      category = FinCategory(
        id: newId(),
        type: type,
        groupId: group.id,
        group: group.name,
        name: type == CategoryType.income
            ? reconciliationSurplusCategory
            : reconciliationShortageCategory,
        directionId: direction,
        sortOrder: _categories.length,
      );
      if (!await saveCategory(category)) return false;
    }
    final op = reconciliationAdjustment(
      r,
      id: newId(),
      incomeCategoryId: category.id,
      expenseCategoryId: category.id,
      directionId: category.directionId ?? direction,
    )!;
    return saveOperation(op);
  }

  // ------------------------------------------- быстрый ввод (8.6)

  /// Записанные вручную и импортированные операции вида [type], свежие
  /// сверху (выплаты ЗП не в счёт — их не вводят здесь).
  Iterable<FinOperation> _recent(OperationType type) =>
      allOperations.where((o) => o.type == type && !isPayroll(o));

  /// Последние статьи вида [type] (без скрытых), до [limit] штук.
  List<FinCategory> recentCategories(OperationType type, {int limit = 8}) {
    final result = <FinCategory>[];
    for (final op in _recent(type)) {
      final c = _catalog.categories[op.categoryId];
      if (c == null || c.hidden || result.contains(c)) continue;
      result.add(c);
      if (result.length == limit) break;
    }
    return result;
  }

  /// Последние контрагенты операций вида [type]; со статьёй [categoryId] —
  /// сначала те, что были с ней.
  List<Counterparty> recentCounterparties(
    OperationType type, {
    String? categoryId,
    int limit = 8,
  }) {
    final result = <Counterparty>[];
    void add(Iterable<FinOperation> ops) {
      for (final op in ops) {
        final c = _catalog.counterparties[op.counterpartyId];
        if (c == null || result.contains(c)) continue;
        result.add(c);
        if (result.length == limit) return;
      }
    }

    if (categoryId != null) {
      add(_recent(type).where((o) => o.categoryId == categoryId));
    }
    if (result.length < limit) add(_recent(type));
    return result;
  }

  /// Кошелёк последней операции вида [type] (открытый); иначе — первый
  /// открытый.
  String? lastAccount(OperationType type) {
    for (final op in _recent(type)) {
      final a = _catalog.accounts[op.accountId];
      if (a != null && !a.closed) return a.id;
    }
    return _accounts.where((a) => !a.closed).firstOrNull?.id;
  }

  // --------------------------------------------------------- подписи

  String accountName(String? id) => _catalog.accounts[id]?.name ?? '—';
  String categoryName(String? id) => _catalog.categories[id]?.name ?? '—';

  /// Название группы статьи: из справочника, иначе — текст записи 1.18.
  String groupName(FinCategory c) => _catalog.groupOf(c)?.name ?? c.group;
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

  /// Статья, «куда» перевода или займ — столбец «Статья / куда».
  String whatLabel(FinOperation op) => switch (op.type) {
    OperationType.income ||
    OperationType.expense => categoryName(op.categoryId),
    OperationType.transfer => '→ ${accountName(op.toAccountId)}',
    OperationType.debt => '${op.debtMove?.title ?? ''}: ${debtName(op.debtId)}',
  };

  /// Контрагент операции, иначе — работник (выплата ЗП, подотчёт).
  String counterpartyLabel(FinOperation op) {
    if (op.counterpartyId != null) return counterpartyName(op.counterpartyId);
    return _employees[op.employeeId]?.fullName ?? '';
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
    _lastProblem = null;
    if (isPayroll(op)) {
      return _fail('Выплата ЗП правится в «Выплатах»');
    }
    // Автор — вошедший (новая операция); у старой автор не меняется.
    if (before == null && op.createdBy == null) {
      op = op.copyWith(createdBy: _app.userUuid);
    } else if (before != null) {
      op = op.copyWith(createdBy: before.createdBy);
    }
    if (!_operatorMay(op, before: before)) return false;
    final problem = operationProblem(op, _catalog, before: before);
    if (problem != null) return _refuse(problem);
    if (!_open(
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
    _lastProblem = null;
    if (isPayroll(op)) {
      return _fail('Выплата ЗП удаляется в «Выплатах»');
    }
    if (!_operatorMay(op, before: op)) return false;
    if (!_open('fin_operations', _opRow(op), null)) return false;
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

  // ------------------------------------------------ платёжный календарь

  /// Разы планов с [from] по [to] (оплаченные и пропущенные отмечены).
  List<PlanOccurrence> occurrences(DateTime from, DateTime to) =>
      planOccurrences(plans: _plans, operations: _manual, from: from, to: to);

  /// Прогноз денег по дням с сегодня (все кошельки + неоплаченные планы;
  /// просроченные — сегодня).
  List<ForecastDay> forecast({int days = 60}) {
    final today = calendarDay(DateTime.now());
    final money = accountBalancesAt(today).values.fold(0, (s, v) => s + v);
    return paymentForecast(
      today: today,
      money: money,
      occurrences: occurrences(DateTime(2000), addCalendarDays(today, days)),
      days: days,
    );
  }

  Future<bool> savePlan(FinPlan plan) async {
    if (!_allowed()) return false;
    final problem = planProblem(plan);
    if (problem != null) return _refuse(problem);
    return _write(() => _repo.savePlan(plan));
  }

  Future<bool> deletePlan(FinPlan plan) async {
    if (!_allowed()) return false;
    return _write(() => _repo.deletePlan(plan.id));
  }

  /// «Пропустить» раз плана (или вернуть пропущенный).
  Future<bool> skipOccurrence(PlanOccurrence o, {bool skip = true}) {
    final days = {...o.plan.skipped};
    skip ? days.add(o.day) : days.remove(o.day);
    return savePlan(o.plan.copyWith(skipped: days));
  }

  /// Операция для оплаты раза плана: сумма, кошелёк, статья, контрагент из
  /// плана, день — [date] (по умолчанию сегодня), ссылка на план и день.
  /// Записывает её окно операции (можно поправить сумму и кошелёк).
  FinOperation paymentFor(PlanOccurrence o, {DateTime? date}) => FinOperation(
    id: newId(),
    date: calendarDay(date ?? DateTime.now()),
    type: o.plan.type,
    amount: o.plan.amount,
    accountId:
        o.plan.accountId ??
        lastAccount(o.plan.type) ??
        _accounts.where((a) => !a.closed).firstOrNull?.id ??
        '',
    categoryId: o.plan.categoryId,
    counterpartyId: o.plan.counterpartyId,
    description: o.plan.description,
    sourceRef: planSourceRef(o.plan.id, o.day),
  );

  // ------------------------------------------------------------- БДДС

  /// План года [year] (8Б.5); оператору — пусто.
  Future<List<BudgetEntry>> budget(int year) async =>
      operator ? const [] : await _repo.budget(year);

  /// БДДС года: план [entries] и факт по операциям (с выплатами ЗП).
  BudgetReport budgetReportFor(int year, List<BudgetEntry> entries) =>
      budgetReport(
        year: year,
        entries: entries,
        operations: allOperations,
        catalog: _catalog,
      );

  /// План года по факту прошлого (до рубля).
  Map<String, List<int>> budgetFromLastYear(int year) =>
      budgetFromFact(year: year, operations: allOperations, catalog: _catalog);

  /// Записать планы статьи [categoryId] на год [year] по месяцам.
  Future<bool> saveBudgetFor(
    int year,
    String categoryId,
    List<int> months,
  ) async {
    if (!_allowed()) return false;
    if (months.length != 12 || months.any((m) => m < 0)) {
      return _refuse('План — 12 сумм не меньше нуля');
    }
    return _write(
      () => _repo.saveBudget([
        for (var m = 0; m < 12; m++)
          BudgetEntry(
            id: newId(),
            year: year,
            month: m + 1,
            categoryId: categoryId,
            amount: months[m],
          ),
      ]),
    );
  }

  /// Заполнить план года [year] из факта прошлого: только статьи без плана.
  Future<bool> fillBudgetFromLastYear(int year) async {
    if (!_allowed()) return false;
    final planned = {for (final e in await _repo.budget(year)) e.categoryId};
    final source = budgetFromLastYear(year);
    return _write(
      () => _repo.saveBudget([
        for (final e in source.entries)
          if (!planned.contains(e.key))
            for (var m = 0; m < 12; m++)
              if (e.value[m] > 0)
                BudgetEntry(
                  id: newId(),
                  year: year,
                  month: m + 1,
                  categoryId: e.key,
                  amount: e.value[m],
                ),
      ]),
    );
  }

  // ------------------------------------------------- выписка банка (8Б.6)

  /// Строки выписки кошелька [accountId] против операций: уже загруженные,
  /// найденные введённые вручную и новые с подсказками статьи.
  List<BankLineMatch> matchStatement(
    BankStatement statement,
    String accountId, {
    String? ownInn,
  }) => matchBankLines(
    lines: statement.lines,
    accountId: accountId,
    operations: _manual,
    catalog: _catalog,
    ownInn: ownInn,
  );

  /// Записать выписку: [fresh] — новые операции (строка, статья,
  /// контрагент, второй кошелёк перевода; контрагента без справочника
  /// заводит по названию и ИНН строки; со вторым кошельком — перевод между
  /// своими кошельками, без статьи и контрагента), [matched] — ручные операции, найденные по строкам: им
  /// ставится ссылка на строку (повторная загрузка их не задвоит). Закрытые
  /// месяцы — как при обычной записи. Возвращает число записанных
  /// операций; null — отказ (объяснение — [lastProblem]).
  Future<int?> importStatement({
    required String accountId,
    required List<
      (
        BankLine,
        String? categoryId,
        String? counterpartyId,
        String? transferAccountId,
      )
    >
    fresh,
    required List<BankLineMatch> matched,
  }) async {
    if (!_allowed()) return null;
    for (final (line, category, _, transferTo) in fresh) {
      final message = _app.periodViolation('fin_operations', null, {
        'date': formatDateIso(line.date),
      });
      if (message != null) {
        _fail(message);
        return null;
      }
      final problem = operationProblem(
        bankOperation(
          id: '',
          line: line,
          accountId: accountId,
          categoryId: category,
          transferAccountId: transferTo,
        ),
        _catalog,
      );
      if (problem != null) {
        _refuse(
          '${DateFormat('dd.MM.yyyy').format(line.date)} '
          '${formatRub(line.amount)} ₽: $problem',
        );
        return null;
      }
    }
    var written = 0;
    final ok = await _write(() async {
      final byInn = <String, String>{
        for (final c in _counterparties)
          if ((c.inn ?? '').isNotEmpty) c.inn!: c.id,
      };
      final byName = <String, String>{
        for (final c in _counterparties) c.name.trim().toLowerCase(): c.id,
      };
      for (final (line, category, chosen, transferTo) in fresh) {
        var counterparty = chosen;
        final name = line.counterpartyName?.trim();
        if (transferTo == null &&
            counterparty == null &&
            name != null &&
            name.isNotEmpty &&
            !bankInns.contains(line.counterpartyInn)) {
          counterparty =
              byInn[line.counterpartyInn] ?? byName[name.toLowerCase()];
          if (counterparty == null) {
            counterparty = newId();
            await _repo.saveCounterparty(
              Counterparty(
                id: counterparty,
                name: name.length > 255 ? name.substring(0, 255) : name,
                kind: line.incoming
                    ? CounterpartyKind.buyer
                    : CounterpartyKind.supplier,
                inn: line.counterpartyInn,
              ),
            );
            if (line.counterpartyInn != null) {
              byInn[line.counterpartyInn!] = counterparty;
            }
            byName[name.toLowerCase()] = counterparty;
          }
        }
        await _repo.addOperation(
          bankOperation(
            id: newId(),
            line: line,
            accountId: accountId,
            categoryId: category,
            counterpartyId: counterparty,
            transferAccountId: transferTo,
            createdBy: _app.userUuid,
          ),
        );
        written++;
      }
      for (final m in matched) {
        final op = m.operation;
        if (op == null || op.sourceRef != null) continue;
        await _repo.updateOperation(op.copyWith(sourceRef: m.line.key));
      }
    });
    return ok ? written : null;
  }

  // ------------------------------------------------------- справочники

  Future<bool> saveAccount(FinAccount a, {FinAccount? before}) async {
    if (!_allowed()) return false;
    if (a.name.trim().isEmpty) return _refuse('У кошелька нет названия');
    // Начальный остаток — в дне opening_date (правило сервера).
    Map<String, Object?> row(FinAccount x) => {
      'opening_balance': x.openingBalance,
      'opening_date': x.openingDate == null
          ? null
          : formatDateIso(x.openingDate!),
    };
    if (!_open('fin_accounts', before == null ? null : row(before), row(a))) {
      return false;
    }
    return _write(() => _repo.saveAccount(a));
  }

  /// Группа вида [type] с названием [name] (нет — заводится); null — не
  /// записано.
  Future<FinCategoryGroup?> _groupNamed(CategoryType type, String name) async {
    for (final g in _catalog.groupsOf(type)) {
      if (g.name == name) return g;
    }
    final group = FinCategoryGroup(
      id: newId(),
      type: type,
      name: name,
      sortOrder: _catalog.groupsOf(type).length + 1,
    );
    return await saveCategoryGroup(group) ? group : null;
  }

  Future<bool> saveCategoryGroup(
    FinCategoryGroup g, {
    FinCategoryGroup? before,
  }) async {
    if (!_allowed()) return false;
    if (g.name.trim().isEmpty) return _refuse('У группы нет названия');
    if (before != null && before.type != g.type && groupUsages(g.id) > 0) {
      return _refuse(
        'В группе есть статьи — сменить доход/расход нельзя. Перенесите '
        'статьи в другую группу',
      );
    }
    return _write(() => _repo.saveCategoryGroup(g));
  }

  /// Сколько статей в группе (по ссылке или, у записей 1.18, по названию).
  int groupUsages(String groupId) =>
      _categories.where((c) => _catalog.groupOf(c)?.id == groupId).length;

  Future<bool> saveCategory(FinCategory c) async {
    if (!_allowed()) return false;
    if (c.name.trim().isEmpty) return _refuse('У статьи нет названия');
    final group = _catalog.groups[c.groupId];
    if (group == null) return _refuse('Выберите группу статьи');
    if (group.type != c.type) {
      return _refuse(
        'Группа «${group.name}» — для ${group.type == CategoryType.income ? 'доходов' : 'расходов'}',
      );
    }
    if (c.directionId != null && c.allocationKeyId != null) {
      return _refuse('Укажите направление или ключ — не оба сразу');
    }
    return _write(() => _repo.saveCategory(c));
  }

  Future<bool> saveCounterparty(Counterparty c) async {
    if (operator) {
      _lastProblem = null;
      if (_catalog.counterparties.containsKey(c.id)) {
        return _fail(
          'Оператор только заводит новых контрагентов — исправляют '
          'бухгалтер и администратор.',
        );
      }
    } else if (!_allowed()) {
      return false;
    }
    if (c.name.trim().isEmpty) return _refuse('У контрагента нет названия');
    return _write(() => _repo.saveCounterparty(c));
  }

  Future<bool> saveDirection(FinDirection d) async {
    if (!_allowed()) return false;
    if (d.name.trim().isEmpty) return _refuse('У направления нет названия');
    return _write(() => _repo.saveDirection(d));
  }

  Future<bool> saveAllocationKey(AllocationKey k) async {
    if (!_allowed()) return false;
    final problem = allocationKeyProblem(k, _catalog);
    if (problem != null) return _refuse(problem);
    return _write(() => _repo.saveAllocationKey(k));
  }

  Future<bool> saveAsset(Asset a) async {
    if (!_allowed()) return false;
    if (a.name.trim().isEmpty) return _refuse('У имущества нет названия');
    if (a.directionId != null && a.allocationKeyId != null) {
      return _refuse('Укажите направление или ключ — не оба сразу');
    }
    return _write(() => _repo.saveAsset(a));
  }

  Future<bool> saveDebt(FinDebt d, {FinDebt? before}) async {
    if (!_allowed()) return false;
    if (!_catalog.counterparties.containsKey(d.counterpartyId)) {
      return _refuse('Не указан контрагент займа');
    }
    Map<String, Object?> row(FinDebt x) => {
      'opening_balance': x.openingBalance,
      'opening_date': x.openingDate == null
          ? null
          : formatDateIso(x.openingDate!),
    };
    if (!_open('fin_debts', before == null ? null : row(before), row(d))) {
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
    if (!_allowed()) return false;
    final used = switch (table) {
      'fin_accounts' => usages(accountId: id),
      'fin_categories' => usages(categoryId: id),
      'fin_category_groups' => groupUsages(id),
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
        'fin_category_groups' => _repo.deleteCategoryGroup(id),
        'counterparties' => _repo.deleteCounterparty(id),
        'fin_allocation_keys' => _repo.deleteAllocationKey(id),
        'fin_assets' => _repo.deleteAsset(id),
        'fin_debts' => _repo.deleteDebt(id),
        _ => throw ArgumentError(table),
      },
    );
  }

  /// Почему последняя правка не записана (для окна правки); null — записана.
  String? get lastProblem => _lastProblem;
  String? _lastProblem;

  bool _fail(String message) {
    _lastProblem = message;
    _app.showNotice(message);
    return false;
  }

  bool _refuse(String message) => _fail('Не сохранено: $message');

  /// Отказ окна правки (поле не разобрано) — как отказ проверки.
  bool reject(String message) => _refuse(message);

  /// Финансы оператора (8.8.4): свои расходы и доходы и новые контрагенты.
  bool get operator => _app.operatorMode;

  /// Справочники, переводы и займы — бухгалтер и администратор.
  bool _allowed() {
    _lastProblem = null;
    if (!operator) return true;
    return _fail(
      'Оператор вносит только свои расходы и доходы — справочники, '
      'переводы и займы ведут бухгалтер и администратор.',
    );
  }

  /// Правило сервера для оператора: только свои операции, только доходы и
  /// расходы.
  bool _operatorMay(FinOperation op, {FinOperation? before}) {
    if (!operator) return true;
    final user = _app.userUuid;
    if (user == null) return _fail('Войдите на сервер — тогда можно вносить');
    final problem = operatorOperationProblem(
      userUuid: user,
      exists: before != null,
      existingCreatedBy: before?.createdBy,
      type: op.type.code,
      createdBy: op.createdBy,
    );
    return problem == null || _fail(problem);
  }

  bool _open(
    String table,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
  ) {
    final message = _app.periodViolation(table, before, after);
    return message == null || _fail(message);
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
