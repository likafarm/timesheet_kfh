// Перенос финансов из Excel (шаг 8.4): JSON выгрузки
// (`docs/stage-8/export_import.py`) → справочники и операции финансов →
// сервер обычной синхронизацией. Импортёр — «мини-клиент»: своя база в
// памяти, вход админом, приём всего с сервера, запись через репозитории,
// отправка движком синхронизации. Все проверки сервера — как для программы.
//
// uuid записей приходят из выгрузки и не меняются между запусками: повтор
// ничего не дублирует. Запись, которую после импорта правили не им
// (`edited_by` другого устройства), импорт не перезаписывает — останавливается.
//
// «Табель 25» (решения владельца 2026-10-08): работники, которых нет в
// табеле программы (по «Фамилия И.»), добавляются уволенными со ставкой с
// даты приёма; дни 2025 года — в табель (1 или 0,5, место — база);
// начислено за месяц — как «Сумма» Excel: разницу с расчётом программы
// импорт пишет корректировкой месяца. Выплаты ЗП «Финансов 25» — выплатами
// табеля (расход из них программа строит сама). Уже добавленных сотрудников
// импорт не правит; если дни табеля раньше даты приёма или без ставки —
// дата приёма сдвигается, ставка добавляется (тариф Excel).

import 'package:drift/drift.dart' show Value, Variable;
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';

import 'sync_engine.dart';

/// Импорт нельзя продолжать; [problems] — что не так.
class FinanceImportException implements Exception {
  final List<String> problems;
  const FinanceImportException(this.problems);

  @override
  String toString() => problems.join('\n');
}

/// Выгрузка для импорта, прочитанная из JSON.
class FinanceImportData {
  final List<FinDirection> directions;
  final List<AllocationKey> keys;
  final List<FinCategory> categories;
  final List<FinAccount> accounts;
  final List<Counterparty> counterparties;
  final List<FinDebt> debts;
  final List<Asset> assets;
  final List<FinOperation> operations;
  final PayrollFinanceMapping payroll;

  /// Работники из табеля Excel: имя — как в Excel («Иванов И. И.»), ставка
  /// базы и поля — тариф. Для плана и записи — только недостающие.
  final List<Employee> employees;

  /// Дни табеля из Excel: имя работника и запись (id — из выгрузки).
  final List<(String, TimesheetRecord)> timesheet;

  /// Начислено по табелю Excel за месяц (для корректировок и сравнения).
  final List<TabelMonth> accruals;

  /// Выплаты ЗП из «Финансов 25»: имя, выплата, источник (`Расход!N`).
  final List<(String, Payment, String)> payments;

  /// Сотрудник табеля по имени из Excel («Иванов И.»): у кошелька
  /// (подотчёт), контрагента и операции зарплаты. Ключ — id записи.
  final Map<String, String> accountEmployees;
  final Map<String, String> counterpartyEmployees;
  final Map<String, String> operationEmployees;

  /// Контрольные итоги из Excel (копейки): «лист|гггг-мм» и «лист|всего».
  final Map<String, int> control;

  FinanceImportData._({
    required this.directions,
    required this.keys,
    required this.categories,
    required this.accounts,
    required this.counterparties,
    required this.debts,
    required this.assets,
    required this.operations,
    required this.payroll,
    required this.employees,
    required this.timesheet,
    required this.accruals,
    required this.payments,
    required this.accountEmployees,
    required this.counterpartyEmployees,
    required this.operationEmployees,
    required this.control,
  });

  factory FinanceImportData.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) =>
        (json[key] as List).cast<Map<String, dynamic>>();
    DateTime? date(Object? v) => v == null ? null : parseDateIso(v as String);
    List<Map<String, dynamic>> optional(String key) =>
        (json[key] as List? ?? const []).cast<Map<String, dynamic>>();
    Map<String, String> names(String key) => {
      for (final e in list(key))
        if (e['employeeName'] != null) e['id'] as String: e['employeeName'],
    };

    final payroll = json['payrollMapping'] as Map<String, dynamic>;
    return FinanceImportData._(
      directions: [
        for (final e in list('directions'))
          FinDirection(
            id: e['id'],
            name: e['name'],
            overhead: e['overhead'],
            sortOrder: e['sortOrder'],
          ),
      ],
      keys: [
        for (final e in list('allocationKeys'))
          AllocationKey(
            id: e['id'],
            name: e['name'],
            periods: [
              for (final p in (e['periods'] as List).cast<Map>())
                AllocationPeriod(
                  validFrom: date(p['validFrom'])!,
                  shares: (p['shares'] as Map).cast<String, int>(),
                ),
            ],
          ),
      ],
      categories: [
        for (final e in list('categories'))
          FinCategory(
            id: e['id'],
            type: CategoryType.fromCode(e['type']),
            group: e['group'],
            name: e['name'],
            directionId: e['directionId'],
            allocationKeyId: e['allocationKeyId'],
            kind: CategoryKind.fromCode(e['kind']),
            inTaxBook: e['inTaxBook'],
            hidden: e['hidden'],
            sortOrder: e['sortOrder'],
          ),
      ],
      accounts: [
        for (final e in list('accounts'))
          FinAccount(
            id: e['id'],
            name: e['name'],
            kind: AccountKind.fromCode(e['kind']),
            openingBalance: e['openingBalance'],
            openingDate: date(e['openingDate']),
            closed: e['closed'],
            sortOrder: e['sortOrder'],
          ),
      ],
      counterparties: [
        for (final e in list('counterparties'))
          Counterparty(
            id: e['id'],
            name: e['name'],
            kind: CounterpartyKind.fromCode(e['kind']),
          ),
      ],
      debts: [
        for (final e in list('debts'))
          FinDebt(
            id: e['id'],
            counterpartyId: e['counterpartyId'],
            kind: DebtKind.fromCode(e['kind']),
            openingBalance: e['openingBalance'],
            openingDate: date(e['openingDate']),
          ),
      ],
      assets: [
        for (final e in list('assets'))
          Asset(
            id: e['id'],
            name: e['name'],
            kind: AssetKind.fromCode(e['kind']),
            year: e['year'],
            quantity: e['quantity'],
            referenceValue: e['referenceValue'],
            valuedOn: date(e['valuedOn']),
            directionId: e['directionId'],
            allocationKeyId: e['allocationKeyId'],
            cadastralNumber: e['cadastralNumber'],
            areaHa: (e['areaHa'] as num?)?.toDouble(),
            cadastralValue: e['cadastralValue'],
            notes: e['notes'],
          ),
      ],
      operations: [
        for (final e in list('operations'))
          FinOperation(
            id: e['id'],
            date: date(e['date'])!,
            type: OperationType.fromCode(e['type']),
            amount: e['amount'],
            accountId: e['accountId'],
            toAccountId: e['toAccountId'],
            categoryId: e['categoryId'],
            directionId: e['directionId'],
            allocationKeyId: e['allocationKeyId'],
            assetId: e['assetId'],
            season: e['season'],
            counterpartyId: e['counterpartyId'],
            debtId: e['debtId'],
            debtMove: e['debtMove'] == null
                ? null
                : DebtMove.fromCode(e['debtMove']),
            description: e['description'],
            quantity: (e['quantity'] as num?)?.toDouble(),
            unit: e['unit'],
            tag: e['tag'],
            notes: e['notes'],
            source: OperationSource.imported,
            sourceRef: e['sourceRef'],
            createdBy: 'import',
          ),
      ],
      payroll: PayrollFinanceMapping(
        methodAccounts: (payroll['methodAccounts'] as Map)
            .cast<String, String>(),
        defaultAccountId: payroll['defaultAccountId'],
        positionCategories: (payroll['positionCategories'] as Map)
            .cast<String, String>(),
        defaultCategoryId: payroll['defaultCategoryId'],
      ),
      employees: [
        for (final e in optional('employees'))
          Employee(
            id: e['id'],
            fullName: e['name'],
            position: e['position'],
            hireDate: date(e['hireDate'])!,
            dismissalDate: date(e['dismissalDate']),
            baseRate: (e['rate'] as num).toDouble(),
            fieldRate: (e['rate'] as num).toDouble(),
          ),
      ],
      timesheet: [
        for (final e in optional('timesheet'))
          (
            e['employeeName'] as String,
            TimesheetRecord(
              id: e['id'],
              employeeId: '',
              date: date(e['date'])!,
              dayType: 'work',
              days: (e['days'] as num).toDouble(),
              workPlace: 'base',
            ),
          ),
      ],
      accruals: [for (final e in optional('accruals')) TabelMonth.fromJson(e)],
      payments: [
        for (final e in optional('payments'))
          (
            e['employeeName'] as String,
            Payment(
              id: e['id'],
              employeeId: '',
              paymentDate: date(e['date'])!,
              amount: (e['amount'] as int) / 100,
              paymentMethod: e['method'],
              notes: [
                ?e['notes'] as String?,
                'Финансы 25: ${e['sourceRef']}',
              ].join('; '),
            ),
            e['sourceRef'] as String,
          ),
      ],
      accountEmployees: names('accounts'),
      counterpartyEmployees: names('counterparties'),
      operationEmployees: names('operations'),
      control: (json['control'] as Map).cast<String, int>(),
    );
  }

  FinanceCatalog get catalog => FinanceCatalog(
    accounts: accounts,
    directions: directions,
    keys: keys,
    assets: assets,
    categories: categories,
    counterparties: counterparties,
    debts: debts,
  );

  /// Ошибки выгрузки без сервера: правила домена и контрольные итоги
  /// Excel (до копейки). Пусто — всё в порядке.
  List<String> problems() {
    final result = <String>[];
    final catalog = this.catalog;
    for (final key in keys) {
      final p = allocationKeyProblem(key, catalog);
      if (p != null) result.add('Ключ «${key.name}»: $p');
    }
    for (final op in operations) {
      final p = operationProblem(op, catalog);
      if (p != null) result.add('${op.sourceRef}: $p');
    }
    final sums = <String, int>{};
    void add(String key, int value) => sums[key] = (sums[key] ?? 0) + value;
    void count(String? ref, DateTime date, int amount) {
      final sheet = (ref ?? '').split('!').first;
      add('$sheet|всего', amount);
      if (sheet == 'Расход' || sheet == 'Доход') {
        add('$sheet|${formatDateIso(date).substring(0, 7)}', amount);
      }
    }

    for (final op in operations) {
      count(op.sourceRef, op.date, op.amount);
    }
    // Выплаты ЗП — те же строки «Расхода», только записываются выплатами.
    for (final (_, p, ref) in payments) {
      count(ref, p.paymentDate, toKopecks(p.amount));
    }
    for (final (name, r) in timesheet) {
      final p = timesheetRecordProblem(r);
      if (p != null) result.add('Табель $name ${formatDateIso(r.date)}: $p');
    }
    for (final key in {...control.keys, ...sums.keys}) {
      if (control[key] != sums[key]) {
        result.add(
          'Итог «$key»: в Excel ${formatRub(control[key] ?? 0)}, '
          'в операциях ${formatRub(sums[key] ?? 0)}',
        );
      }
    }
    return result;
  }
}

/// Месяц работника по табелю Excel: дни, тариф, надбавки, премия,
/// начислено («Сумма») и выдано («Выдал»). [id] — uuid корректировки.
class TabelMonth {
  final String id;
  final String name;
  final int year;
  final int month;
  final double excelDays;
  final double tariff;
  final double bonus;
  final double premium;
  final double accrued;
  final double paid;

  const TabelMonth({
    required this.id,
    required this.name,
    required this.year,
    required this.month,
    required this.excelDays,
    required this.tariff,
    required this.bonus,
    required this.premium,
    required this.accrued,
    required this.paid,
  });

  factory TabelMonth.fromJson(Map<String, dynamic> e) {
    double n(String key) => (e[key] as num).toDouble();
    return TabelMonth(
      id: e['id'],
      name: e['employeeName'],
      year: e['year'],
      month: e['month'],
      excelDays: n('excelDays'),
      tariff: n('tariff'),
      bonus: n('bonus'),
      premium: n('premium'),
      accrued: n('accrued'),
      paid: n('paid'),
    );
  }

  int get key => PeriodGuard.monthKey(year, month);
}

/// Сотрудник табеля по имени из Excel: «Фамилия И.» — фамилия и первая
/// буква имени; полное имя — точно. null — не найден или неоднозначно.
String? matchEmployee(String excelName, Iterable<Employee> employees) {
  final found = matchingEmployees(excelName, employees);
  return found.length == 1 ? found.single.id : null;
}

/// Все сотрудники, подходящие к имени из Excel.
List<Employee> matchingEmployees(
  String excelName,
  Iterable<Employee> employees,
) {
  final parts = excelName.replaceAll('.', ' ').split(RegExp(r'\s+'))
    ..removeWhere((p) => p.isEmpty);
  if (parts.isEmpty) return const [];
  final surname = parts.first.toLowerCase().replaceAll('ё', 'е');
  final initial = parts.length > 1 ? parts[1][0].toLowerCase() : null;
  return [
    for (final e in employees)
      if (_matches(e.fullName, surname, initial)) e,
  ];
}

bool _matches(String fullName, String surname, String? initial) {
  final parts = fullName
      .toLowerCase()
      .replaceAll('ё', 'е')
      .split(RegExp(r'\s+'));
  if (parts.first != surname) return false;
  return initial == null || (parts.length > 1 && parts[1].startsWith(initial));
}

/// Что сделает импорт с записью.
enum ImportAction { create, update, same }

/// План импорта: по таблицам — сколько добавить, изменить, оставить.
class FinanceImportPlan {
  final Map<String, Map<ImportAction, int>> counts = {};

  /// Записи, которые после импорта правили не им: (таблица, uuid, кем).
  final List<(String, String, String?)> editedElsewhere = [];

  /// Имена из Excel, не найденные среди сотрудников табеля.
  final Set<String> unmatchedEmployees = {};

  /// Работники Excel, которых импорт добавит в табель.
  final List<String> addedEmployees = [];

  /// Правки сотрудников под дни табеля Excel (дата приёма, ставка).
  final List<String> employeeFixes = [];

  void _count(String table, ImportAction action) {
    final t = counts.putIfAbsent(table, () => {});
    t[action] = (t[action] ?? 0) + 1;
  }

  int get changes => counts.values.fold(
    0,
    (a, t) => a + (t[ImportAction.create] ?? 0) + (t[ImportAction.update] ?? 0),
  );

  @override
  String toString() => [
    for (final MapEntry(key: table, value: t) in counts.entries)
      '$table: добавить ${t[ImportAction.create] ?? 0}, '
          'изменить ${t[ImportAction.update] ?? 0}, '
          'без изменений ${t[ImportAction.same] ?? 0}',
    if (addedEmployees.isNotEmpty)
      'Добавить в табель (уволенными): ${addedEmployees.join(', ')}',
    ...employeeFixes,
    if (unmatchedEmployees.isNotEmpty)
      'Не найдены в табеле (останутся без связи): '
          '${(unmatchedEmployees.toList()..sort()).join(', ')}',
  ].join('\n');
}

/// Импорт в базу [db] клиента, связанного с сервером через [engine].
class FinanceImporter {
  final LocalDatabase db;
  final LocalSyncStore store;
  final SyncEngine engine;

  /// Id устройства импорта (так сервер пишет `edited_by`).
  final String importDevice;

  FinanceImporter({
    required this.db,
    required this.store,
    required this.engine,
    required this.importDevice,
  });

  late final FinanceRepository _fin = DriftRepositories(db).finance;
  late final EmployeeRepository _employees = DriftRepositories(db).employees;
  late final DriftRepositories _repos = DriftRepositories(db);

  /// Месяц табеля Excel ([TabelMonth.id]) → id сотрудника; заполняет
  /// `_withEmployees`.
  Map<String, String> _accrualEmployees = const {};

  /// Пустая база импорта принимает всё с сервера (ничего не отправляя).
  Future<void> download() async {
    await store.markAllSynced();
    final report = await engine.run();
    if (report.rejected > 0 || report.pendingLeft > 0) {
      throw FinanceImportException([
        'Приём с сервера: отклонено ${report.rejected}, '
            'не отправлено ${report.pendingLeft}',
      ]);
    }
  }

  /// Данные с подставленными сотрудниками табеля (по имени из Excel);
  /// в `employees` — только работники Excel, которых в табеле нет.
  Future<(FinanceImportData, Set<String>)> _withEmployees(
    FinanceImportData data,
  ) async {
    final existing = await _employees.all();
    final added = <Employee>[];
    for (final e in data.employees) {
      if (matchingEmployees(e.fullName, [...existing, ...added]).isEmpty) {
        added.add(e);
      }
    }
    final employees = [...existing, ...added];
    final unmatched = <String>{};
    String? find(String? name) {
      if (name == null) return null;
      final id = matchEmployee(name, employees);
      if (id == null) unmatched.add(name);
      return id;
    }

    // Табель и выплаты без сотрудника записать нельзя.
    final lost = <String>{};
    String need(String name) {
      final id = matchEmployee(name, employees);
      if (id == null) lost.add(name);
      return id ?? '';
    }

    final timesheet = [
      for (final (name, r) in data.timesheet)
        (name, r.copyWith(employeeId: need(name))),
    ];
    final payments = [
      for (final (name, p, ref) in data.payments)
        (name, p.copyWith(employeeId: need(name)), ref),
    ];
    for (final m in data.accruals) {
      need(m.name);
    }
    if (lost.isNotEmpty) {
      throw FinanceImportException([
        'Нет однозначного сотрудника для табеля и выплат: '
            '${(lost.toList()..sort()).join(', ')}',
      ]);
    }
    _accrualEmployees = {
      for (final m in data.accruals) m.id: matchEmployee(m.name, employees)!,
    };

    final accounts = [
      for (final a in data.accounts)
        a.employeeId != null || !data.accountEmployees.containsKey(a.id)
            ? a
            : FinAccount(
                id: a.id,
                name: a.name,
                kind: a.kind,
                openingBalance: a.openingBalance,
                openingDate: a.openingDate,
                employeeId: find(data.accountEmployees[a.id]),
                closed: a.closed,
                sortOrder: a.sortOrder,
              ),
    ];
    final counterparties = [
      for (final c in data.counterparties)
        Counterparty(
          id: c.id,
          name: c.name,
          kind: c.kind,
          inn: c.inn,
          phone: c.phone,
          employeeId: find(data.counterpartyEmployees[c.id]),
          notes: c.notes,
        ),
    ];
    final operations = [
      for (final o in data.operations)
        data.operationEmployees.containsKey(o.id)
            ? o.copyWith(employeeId: find(data.operationEmployees[o.id]))
            : o,
    ];
    return (
      FinanceImportData._(
        directions: data.directions,
        keys: data.keys,
        categories: data.categories,
        accounts: accounts,
        counterparties: counterparties,
        debts: data.debts,
        assets: data.assets,
        operations: operations,
        payroll: data.payroll,
        employees: added,
        timesheet: timesheet,
        accruals: data.accruals,
        payments: payments,
        accountEmployees: data.accountEmployees,
        counterpartyEmployees: data.counterpartyEmployees,
        operationEmployees: data.operationEmployees,
        control: data.control,
      ),
      unmatched,
    );
  }

  Future<Map<String, String?>> _editors(String table) async => {
    for (final r
        in await db.customSelect('SELECT uuid, edited_by FROM $table').get())
      r.read<String>('uuid'): r.readNullable<String>('edited_by'),
  };

  /// Что сделает импорт; ничего не пишет. Сначала — [download].
  Future<FinanceImportPlan> plan(FinanceImportData data) async {
    final plan = FinanceImportPlan();
    final (resolved, unmatched) = await _withEmployees(data);
    plan.unmatchedEmployees.addAll(unmatched);
    await _walk(resolved, plan, write: false);
    return plan;
  }

  /// Записывает выгрузку и отправляет на сервер. Если что-то правили не
  /// импортом или сервер что-то отклонил — [FinanceImportException].
  Future<FinanceImportPlan> run(FinanceImportData data) async {
    final problems = data.problems();
    if (problems.isNotEmpty) throw FinanceImportException(problems);
    final plan = FinanceImportPlan();
    final (resolved, unmatched) = await _withEmployees(data);
    plan.unmatchedEmployees.addAll(unmatched);
    await db.transaction(() => _walk(resolved, plan, write: true));
    final report = await engine.run();
    if (report.rejected > 0 || report.pendingLeft > 0) {
      final rejected = await store.rejectedChanges();
      throw FinanceImportException([
        'Сервер отклонил ${report.rejected}, не отправлено '
            '${report.pendingLeft}:',
        for (final r in rejected.take(20)) '${r.table} ${r.uuid}: ${r.message}',
      ]);
    }
    return plan;
  }

  Future<void> _walk(
    FinanceImportData data,
    FinanceImportPlan plan, {
    required bool write,
  }) async {
    Future<void> each<T>(
      String table,
      List<T> wanted,
      Future<List<T>> Function() current,
      String Function(T) id,
      Map<String, Object?> Function(T) fields,
      Future<void> Function(T) save,
    ) async {
      final existing = {for (final e in await current()) id(e): e};
      final editors = await _editors(table);
      for (final item in wanted) {
        final old = existing[id(item)];
        final action = old == null
            ? ImportAction.create
            : _same(fields(old), fields(item))
            ? ImportAction.same
            : ImportAction.update;
        plan._count(table, action);
        // Запись удалили после импорта (её нет среди живых, но она есть) —
        // это тоже правка человека.
        final deleted = old == null && editors.containsKey(id(item));
        if (deleted ||
            action == ImportAction.update &&
                editors[id(item)] != importDevice) {
          plan.editedElsewhere.add((
            table,
            id(item),
            deleted ? 'удалена: ${editors[id(item)]}' : editors[id(item)],
          ));
        }
        if (write && action != ImportAction.same) await save(item);
      }
    }

    if (write) {
      // Проверка правок «не импортом» — до записи: план без записи.
      final dry = FinanceImportPlan();
      await _walk(data, dry, write: false);
      if (dry.editedElsewhere.isNotEmpty) {
        throw FinanceImportException([
          'После импорта эти записи правили не импортом — не перезаписываю:',
          for (final (t, u, by) in dry.editedElsewhere) '$t $u (кем: $by)',
        ]);
      }
    }

    // Недостающие работники — до финансов: на них ссылаются операции.
    final employeeEditors = await _editors('employees');
    for (final e in data.employees) {
      plan._count('employees', ImportAction.create);
      plan.addedEmployees.add(e.fullName);
      // uuid уже есть, а живого сотрудника с таким именем нет — его удалили.
      final by = employeeEditors[e.id];
      if (employeeEditors.containsKey(e.id)) {
        plan.editedElsewhere.add(('employees', e.id!, 'удалена: $by'));
      }
      if (write) await _addEmployee(e);
    }
    await _walkTabel(data, plan, write: write, each: each);

    await each(
      'fin_directions',
      data.directions,
      _fin.directions,
      (e) => e.id,
      _directionFields,
      _fin.saveDirection,
    );
    await each(
      'fin_allocation_keys',
      data.keys,
      _fin.allocationKeys,
      (e) => e.id,
      _keyFields,
      _fin.saveAllocationKey,
    );
    await each(
      'fin_accounts',
      data.accounts,
      _fin.accounts,
      (e) => e.id,
      _accountFields,
      _fin.saveAccount,
    );
    await each(
      'fin_assets',
      data.assets,
      _fin.assets,
      (e) => e.id,
      _assetFields,
      _fin.saveAsset,
    );
    await each(
      'fin_categories',
      data.categories,
      _fin.categories,
      (e) => e.id,
      _categoryFields,
      _fin.saveCategory,
    );
    await each(
      'counterparties',
      data.counterparties,
      _fin.counterparties,
      (e) => e.id,
      _counterpartyFields,
      _fin.saveCounterparty,
    );
    await each(
      'fin_debts',
      data.debts,
      _fin.debts,
      (e) => e.id,
      _debtFields,
      _fin.saveDebt,
    );
    await each(
      'fin_operations',
      data.operations,
      _fin.operations,
      (e) => e.id,
      operationFields,
      (o) async {
        if (await _fin.operation(o.id) == null) {
          await _fin.addOperation(o);
        } else {
          await _fin.updateOperation(o);
        }
      },
    );
    final mapping = await _fin.payrollMapping();
    final same =
        mapping != null &&
        _same(_payrollFields(mapping), _payrollFields(data.payroll));
    plan._count(
      'fin_payroll_mapping',
      mapping == null
          ? ImportAction.create
          : same
          ? ImportAction.same
          : ImportAction.update,
    );
    if (write && !same) await _fin.savePayrollMapping(data.payroll);
  }

  /// Табель 2025 из Excel: дата приёма и ставки под дни, дни, выплаты ЗП,
  /// корректировки месяца (начислено = «Сумма» Excel).
  Future<void> _walkTabel(
    FinanceImportData data,
    FinanceImportPlan plan, {
    required bool write,
    required Future<void> Function<T>(
      String table,
      List<T> wanted,
      Future<List<T>> Function() current,
      String Function(T) id,
      Map<String, Object?> Function(T) fields,
      Future<void> Function(T) save,
    )
    each,
  }) async {
    if (data.timesheet.isEmpty &&
        data.accruals.isEmpty &&
        data.payments.isEmpty) {
      return;
    }
    // Сотрудники и ставки — как будут после импорта (новые ещё не в базе
    // при плане без записи).
    final people = {
      for (final e in await _employees.all()) e.id!: e,
      for (final e in data.employees) e.id!: e,
    };
    final rates = <String, List<EmployeeRate>>{
      for (final id in people.keys)
        id: data.employees.any((e) => e.id == id)
            ? [
                EmployeeRate(
                  employeeId: id,
                  baseRate: people[id]!.baseRate,
                  fieldRate: people[id]!.fieldRate,
                  startDate: people[id]!.hireDate,
                ),
              ]
            : await _repos.rates.history(id),
    };
    final days = <String, List<TimesheetRecord>>{};
    for (final (_, r) in data.timesheet) {
      (days[r.employeeId] ??= []).add(r);
    }
    final tariffs = {
      for (final m in data.accruals)
        if (m.tariff > 0) (_accrualEmployees[m.id]!, m.key): m.tariff,
    };

    for (final MapEntry(key: id, value: records) in days.entries) {
      final person = people[id]!;
      records.sort((a, b) => a.date.compareTo(b.date));
      final first = records.first.date;
      if (first.isBefore(person.hireDate)) {
        plan._count('employees', ImportAction.update);
        plan.employeeFixes.add(
          '${person.fullName}: дата приёма ${formatDateIso(person.hireDate)} '
          '→ ${formatDateIso(first)}',
        );
        final fixed = person.copyWith(hireDate: first);
        people[id] = fixed;
        if (write) await _employees.update(fixed);
      }
      final bare = records
          .where((r) => findRateAtDate(rates[id]!, r.date) == null)
          .firstOrNull;
      if (bare != null) {
        final tariff =
            tariffs[(
              id,
              PeriodGuard.monthKey(bare.date.year, bare.date.month),
            )] ??
            person.baseRate;
        final changes = planAddRate(
          rates[id]!,
          EmployeeRate(
            employeeId: id,
            baseRate: tariff,
            fieldRate: tariff,
            startDate: bare.date,
          ),
        );
        for (final c in changes) {
          plan._count(
            'employee_rates',
            c.isInsert ? ImportAction.create : ImportAction.update,
          );
        }
        plan.employeeFixes.add(
          '${person.fullName}: ставка ${formatRub(toKopecks(tariff))} '
          'с ${formatDateIso(bare.date)} (дни табеля без ставки)',
        );
        rates[id] = [
          for (final r in rates[id]!)
            if (!changes.any((c) => identical(c.before, r))) r,
          for (final c in changes) ?c.after,
        ];
        if (write) await _repos.rates.apply(changes);
      }
    }

    await each(
      'timesheet',
      [for (final (_, r) in data.timesheet) r],
      () => _repos.timesheet.inPeriod(DateTime(1900), DateTime(2200)),
      (r) => r.id!,
      _timesheetFields,
      (r) async {
        if (await _live('timesheet', r.id!)) {
          await _repos.timesheet.update(r);
        } else {
          await db.timesheetDao.insertRecord(
            TimesheetCompanion(
              uuid: Value(r.id!),
              employeeUuid: Value(r.employeeId),
              date: Value(formatDateIso(r.date)),
              dayType: Value(r.dayType),
              days: Value(r.days),
              workPlace: Value(r.workPlace),
              notes: Value(r.notes),
            ),
          );
        }
      },
    );

    await each(
      'payments',
      [for (final (_, p, _) in data.payments) p],
      () => _repos.payments.list(),
      (p) => p.id!,
      _paymentFields,
      (p) async {
        if (await _live('payments', p.id!)) {
          await _repos.payments.update(p);
        } else {
          await db.paymentsDao.insertPayment(
            PaymentsCompanion(
              uuid: Value(p.id!),
              employeeUuid: Value(p.employeeId),
              paymentDate: Value(formatDateIso(p.paymentDate)),
              amount: Value(p.amount),
              paymentType: Value(p.paymentType),
              paymentMethod: Value(p.paymentMethod),
              notes: Value(p.notes),
            ),
          );
        }
      },
    );

    // Корректировка = «Сумма» Excel − расчёт программы по дням и ставкам.
    final adjustments = <PayrollAdjustment>[];
    for (final m in data.accruals) {
      final id = _accrualEmployees[m.id]!;
      final calc = calculateMonthlySalary(
        employeeId: id,
        year: m.year,
        month: m.month,
        records: days[id] ?? const [],
        rates: rates[id]!,
      );
      final amount =
          ((m.accrued - calc.totalSalary) * 100).roundToDouble() / 100;
      if (amount.abs() < balanceEpsilon) continue;
      adjustments.add(
        PayrollAdjustment(
          id: m.id,
          employeeId: id,
          year: m.year,
          month: m.month,
          amount: amount,
          notes: _adjustmentNote(m, amount),
        ),
      );
    }
    await each(
      'payroll_adjustments',
      adjustments,
      _repos.adjustments.all,
      (a) => a.id!,
      _adjustmentFields,
      _repos.adjustments.save,
    );
  }

  Future<bool> _live(String table, String uuid) async =>
      (await db
              .customSelect(
                'SELECT 1 FROM $table WHERE uuid = ? AND deleted = 0',
                variables: [Variable<String>(uuid)],
              )
              .get())
          .isNotEmpty;

  /// Сотрудник с uuid выгрузки и первой ставкой с даты приёма (как
  /// `AppProvider.addEmployee`).
  Future<void> _addEmployee(Employee e) async {
    await db.employeesDao.insertEmployee(
      EmployeesCompanion(
        uuid: Value(e.id!),
        fullName: Value(e.fullName),
        position: Value(e.position),
        hireDate: Value(formatDateIso(e.hireDate)),
        dismissalDate: Value(formatDateIsoOrNull(e.dismissalDate)),
        baseRate: Value(e.baseRate),
        fieldRate: Value(e.fieldRate),
      ),
    );
    await DriftRepositories(db).rates.add(
      EmployeeRate(
        employeeId: e.id!,
        baseRate: e.baseRate,
        fieldRate: e.fieldRate,
        startDate: e.hireDate,
      ),
    );
  }

  /// Проверка после импорта: эта база (свежий клиент, принявший всё с
  /// сервера) содержит выгрузку поле в поле. Пусто — совпало.
  Future<List<String>> verify(FinanceImportData data) async {
    final (resolved, _) = await _withEmployees(data);
    final plan = FinanceImportPlan();
    await _walk(resolved, plan, write: false);
    return [
      for (final MapEntry(key: table, value: t) in plan.counts.entries)
        if ((t[ImportAction.create] ?? 0) + (t[ImportAction.update] ?? 0) > 0)
          '$table: не хватает ${t[ImportAction.create] ?? 0}, '
              'отличается ${t[ImportAction.update] ?? 0}',
    ];
  }

  /// Итоги для отчёта: остатки кошельков и займов, расходы по направлениям.
  Future<String> summary() async {
    // Выплаты ЗП — расходы, построенные из табеля (как в программе).
    final mapping = await _fin.payrollMapping();
    final ops = [
      ...await _fin.operations(),
      if (mapping != null)
        ...payrollExpenses(await _repos.payments.list(), {
          for (final e in await _employees.all()) e.id!: e,
        }, mapping),
    ];
    final accounts = await _fin.accounts();
    final debts = await _fin.debts();
    final directions = await _fin.directions();
    final catalog = FinanceCatalog(
      accounts: accounts,
      directions: directions,
      keys: await _fin.allocationKeys(),
      assets: await _fin.assets(),
      categories: await _fin.categories(),
      counterparties: await _fin.counterparties(),
      debts: debts,
    );
    final balances = accountBalances(accounts, ops);
    final owed = debtBalances(debts, ops);
    final byDirection = expensesByDirection(ops, catalog);
    final names = {for (final c in catalog.counterparties.values) c.id: c.name};
    return [
      'Операций: ${ops.length}',
      'Остатки кошельков (без сверки):',
      for (final a in accounts) '  ${a.name}: ${formatRub(balances[a.id]!)}',
      'Займы:',
      for (final d in debts)
        '  ${names[d.counterpartyId]}: ${formatRub(owed[d.id]!)}',
      'Расходы по направлениям:',
      for (final d in directions)
        '  ${d.name}: ${formatRub(byDirection[d.id] ?? 0)}',
    ].join('\n');
  }
}

/// Строка сравнения «Табель 25» ↔ программа: месяц работника (или итог
/// года: [month] == 0).
class TabelCompareRow {
  final String name;
  final int year;
  final int month;
  final double excelDays, excelAccrued, excelPaid;
  final double days, accrued, paid;

  const TabelCompareRow({
    required this.name,
    required this.year,
    required this.month,
    required this.excelDays,
    required this.excelAccrued,
    required this.excelPaid,
    required this.days,
    required this.accrued,
    required this.paid,
  });

  bool get accruedDiffers => (excelAccrued - accrued).abs() >= balanceEpsilon;
  bool get paidDiffers => (excelPaid - paid).abs() >= balanceEpsilon;
}

extension TabelComparison on FinanceImporter {
  /// Сравнение программы (эта база — свежий клиент после импорта) с
  /// «Табелем 25» по месяцам [year] и итогам года. Выдано в Excel — по
  /// месяцу начисления, выплаты программы — по дню выдачи.
  Future<List<TabelCompareRow>> compareWithTabel(
    FinanceImportData data, {
    int year = 2025,
  }) async {
    final employees = await _employees.all();
    final payments = await _repos.payments.list(
      start: DateTime(year, 1, 1),
      end: DateTime(year, 12, 31),
    );
    final records = await _repos.timesheet.inPeriod(
      DateTime(year, 1, 1),
      DateTime(year, 12, 31),
    );
    final rows = <TabelCompareRow>[];
    final names = {for (final m in data.accruals) m.name}.toList()..sort();
    for (final name in names) {
      final id = matchEmployee(name, employees);
      if (id == null) continue;
      final months = {
        for (final m in data.accruals)
          if (m.name == name && m.year == year) m.month: m,
      };
      var total = const TabelCompareRow(
        name: '',
        year: 0,
        month: 0,
        excelDays: 0,
        excelAccrued: 0,
        excelPaid: 0,
        days: 0,
        accrued: 0,
        paid: 0,
      );
      for (var month = 1; month <= 12; month++) {
        final m = months[month];
        bool inMonth(DateTime d) => d.year == year && d.month == month;
        final paid = payments
            .where((p) => p.employeeId == id && inMonth(p.paymentDate))
            .fold(0.0, (s, p) => s + p.amount);
        final days = records
            .where((r) => r.employeeId == id && inMonth(r.date))
            .fold(0.0, (s, r) => s + (r.dayType == 'work' ? r.days : 0));
        final calc = await _repos.payrollService.calculateMonth(
          id,
          year,
          month,
        );
        if (m == null && paid == 0 && calc.totalSalary == 0 && days == 0) {
          continue;
        }
        final row = TabelCompareRow(
          name: name,
          year: year,
          month: month,
          excelDays: m?.excelDays ?? 0,
          excelAccrued: m?.accrued ?? 0,
          excelPaid: m?.paid ?? 0,
          days: days,
          accrued: calc.totalSalary,
          paid: paid,
        );
        rows.add(row);
        total = TabelCompareRow(
          name: name,
          year: year,
          month: 0,
          excelDays: total.excelDays + row.excelDays,
          excelAccrued: total.excelAccrued + row.excelAccrued,
          excelPaid: total.excelPaid + row.excelPaid,
          days: total.days + row.days,
          accrued: total.accrued + row.accrued,
          paid: total.paid + row.paid,
        );
      }
      rows.add(total);
    }
    return rows;
  }
}

/// Сравнение текстом (таблица по работникам) и CSV для Excel.
(String, String) formatTabelComparison(List<TabelCompareRow> rows) {
  String rub(double v) => formatRub(toKopecks(v));
  String days(double v) {
    final r = (v * 100).roundToDouble() / 100;
    return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  }

  String pad(String v, int w) => v.padLeft(w);
  final text = StringBuffer();
  final csv = StringBuffer(
    'Работник;Месяц;Дни Excel;Дни программа;Начислено Excel;'
    'Начислено программа;Разница начислено;Выдано Excel (месяц начисления);'
    'Выплачено программа (день выдачи);Разница выдано\n',
  );
  String? current;
  for (final r in rows) {
    if (r.name != current) {
      current = r.name;
      text.writeln('\n${r.name}');
      text.writeln(
        '  месяц   дни Excel/прогр.   начислено Excel     программа   '
        'выдано Excel   выплачено прогр.',
      );
    }
    final label = r.month == 0
        ? 'ИТОГО'
        : '${r.month.toString().padLeft(2, '0')}.${r.year}';
    final mark = [
      if (r.accruedDiffers) 'начисл.≠',
      if (r.paidDiffers) 'выдано≠',
    ].join(' ');
    text.writeln(
      '  ${label.padRight(7)} ${pad('${days(r.excelDays)}/${days(r.days)}', 17)}'
      '${pad(rub(r.excelAccrued), 18)}${pad(rub(r.accrued), 14)}'
      '${pad(rub(r.excelPaid), 15)}${pad(rub(r.paid), 19)}  $mark',
    );
    csv.writeln(
      [
        r.name,
        label,
        days(r.excelDays),
        days(r.days),
        rub(r.excelAccrued),
        rub(r.accrued),
        rub(r.accrued - r.excelAccrued),
        rub(r.excelPaid),
        rub(r.paid),
        rub(r.paid - r.excelPaid),
      ].join(';'),
    );
  }
  final totals = rows.where((r) => r.month == 0);
  double sum(double Function(TabelCompareRow) f) =>
      totals.fold(0.0, (s, r) => s + f(r));
  text.writeln(
    '\nВсего за год: начислено Excel ${rub(sum((r) => r.excelAccrued))}, '
    'программа ${rub(sum((r) => r.accrued))}; выдано Excel '
    '${rub(sum((r) => r.excelPaid))}, выплачено в программе '
    '${rub(sum((r) => r.paid))}.',
  );
  text.writeln('Остаток на 31.12 по работникам (Excel → программа):');
  for (final r in totals) {
    text.writeln(
      '  ${r.name}: ${rub(r.excelAccrued - r.excelPaid)} → '
      '${rub(r.accrued - r.paid)}',
    );
  }
  return (text.toString(), csv.toString());
}

bool _same(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final MapEntry(:key, :value) in a.entries) {
    final other = b[key];
    if (value is Map && other is Map) {
      if (!_same(value.cast(), other.cast())) return false;
    } else if (value is List && other is List) {
      if (value.length != other.length) return false;
      for (var i = 0; i < value.length; i++) {
        final x = value[i], y = other[i];
        if (x is Map && y is Map) {
          if (!_same(x.cast(), y.cast())) return false;
        } else if (x != y) {
          return false;
        }
      }
    } else if (value != other) {
      return false;
    }
  }
  return true;
}

String? _day(DateTime? d) => d == null ? null : formatDateIso(d);

Map<String, Object?> _directionFields(FinDirection d) => {
  'name': d.name,
  'overhead': d.overhead,
  'sort': d.sortOrder,
};

Map<String, Object?> _keyFields(AllocationKey k) => {
  'name': k.name,
  'periods': [
    for (final p in [
      ...k.periods,
    ]..sort((a, b) => a.validFrom.compareTo(b.validFrom)))
      {'from': _day(p.validFrom), ...p.shares},
  ],
};

Map<String, Object?> _accountFields(FinAccount a) => {
  'name': a.name,
  'kind': a.kind.code,
  'opening': a.openingBalance,
  'openingDate': _day(a.openingDate),
  'employee': a.employeeId,
  'closed': a.closed,
  'sort': a.sortOrder,
};

Map<String, Object?> _assetFields(Asset a) => {
  'name': a.name,
  'kind': a.kind.code,
  'year': a.year,
  'quantity': a.quantity,
  'value': a.referenceValue,
  'valuedOn': _day(a.valuedOn),
  'direction': a.directionId,
  'key': a.allocationKeyId,
  'cadastral': a.cadastralNumber,
  'area': a.areaHa,
  'cadastralValue': a.cadastralValue,
  'disposedOn': _day(a.disposedOn),
  'notes': a.notes,
};

Map<String, Object?> _categoryFields(FinCategory c) => {
  'type': c.type.code,
  'group': c.group,
  'name': c.name,
  'direction': c.directionId,
  'key': c.allocationKeyId,
  'kind': c.kind.code,
  'tax': c.inTaxBook,
  'hidden': c.hidden,
  'sort': c.sortOrder,
};

Map<String, Object?> _counterpartyFields(Counterparty c) => {
  'name': c.name,
  'kind': c.kind.code,
  'employee': c.employeeId,
};

Map<String, Object?> _debtFields(FinDebt d) => {
  'counterparty': d.counterpartyId,
  'kind': d.kind.code,
  'opening': d.openingBalance,
  'openingDate': _day(d.openingDate),
};

/// Поля операции для сравнения «выгрузка — база».
Map<String, Object?> operationFields(FinOperation o) => {
  'date': _day(o.date),
  'type': o.type.code,
  'amount': o.amount,
  'account': o.accountId,
  'to': o.toAccountId,
  'category': o.categoryId,
  'direction': o.directionId,
  'key': o.allocationKeyId,
  'asset': o.assetId,
  'season': o.season,
  'counterparty': o.counterpartyId,
  'employee': o.employeeId,
  'debt': o.debtId,
  'move': o.debtMove?.code,
  'description': o.description,
  'quantity': o.quantity,
  'unit': o.unit,
  'tag': o.tag,
  'notes': o.notes,
  'source': o.source.code,
  'ref': o.sourceRef,
};

Map<String, Object?> _timesheetFields(TimesheetRecord r) => {
  'employee': r.employeeId,
  'date': _day(r.date),
  'type': r.dayType,
  'days': r.days,
  'place': r.workPlace,
  'notes': r.notes,
};

Map<String, Object?> _paymentFields(Payment p) => {
  'employee': p.employeeId,
  'date': _day(p.paymentDate),
  'amount': p.amount,
  'type': p.paymentType,
  'method': p.paymentMethod,
  'notes': p.notes,
};

Map<String, Object?> _adjustmentFields(PayrollAdjustment a) => {
  'employee': a.employeeId,
  'year': a.year,
  'month': a.month,
  'amount': a.amount,
  'notes': a.notes,
};

/// Из чего сложилась корректировка: надбавки и премия Excel, остальное —
/// дни сверх 1 и доли дня, другой тариф, вычеты.
String _adjustmentNote(TabelMonth m, double amount) {
  String rub(double v) => formatRub(toKopecks(v));
  final rest = amount - m.bonus - m.premium;
  final parts = [
    if (m.bonus != 0) 'надбавки ${rub(m.bonus)}',
    if (m.premium != 0) 'премия ${rub(m.premium)}',
    if (rest.abs() >= balanceEpsilon) 'дни и тариф ${rub(rest)}',
  ];
  return 'Табель 25: ${parts.join(', ')}';
}

Map<String, Object?> _payrollFields(PayrollFinanceMapping m) => {
  'methods': m.methodAccounts,
  'account': m.defaultAccountId,
  'positions': m.positionCategories,
  'category': m.defaultCategoryId,
};
