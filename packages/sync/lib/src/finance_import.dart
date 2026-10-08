// Перенос финансов из Excel (шаг 8.4): JSON выгрузки
// (`docs/stage-8/export_import.py`) → справочники и операции финансов →
// сервер обычной синхронизацией. Импортёр — «мини-клиент»: своя база в
// памяти, вход админом, приём всего с сервера, запись через репозитории,
// отправка движком синхронизации. Все проверки сервера — как для программы.
//
// uuid записей приходят из выгрузки и не меняются между запусками: повтор
// ничего не дублирует. Запись, которую после импорта правили не им
// (`edited_by` другого устройства), импорт не перезаписывает — останавливается.

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
    required this.accountEmployees,
    required this.counterpartyEmployees,
    required this.operationEmployees,
    required this.control,
  });

  factory FinanceImportData.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) =>
        (json[key] as List).cast<Map<String, dynamic>>();
    DateTime? date(Object? v) => v == null ? null : parseDateIso(v as String);
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
    for (final op in operations) {
      final sheet = (op.sourceRef ?? '').split('!').first;
      add('$sheet|всего', op.amount);
      if (sheet == 'Расход' || sheet == 'Доход') {
        final month = formatDateIso(op.date).substring(0, 7);
        add('$sheet|$month', op.amount);
      }
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

/// Сотрудник табеля по имени из Excel: «Фамилия И.» — фамилия и первая
/// буква имени; полное имя — точно. null — не найден или неоднозначно.
String? matchEmployee(String excelName, Iterable<Employee> employees) {
  final parts = excelName.replaceAll('.', ' ').split(RegExp(r'\s+'))
    ..removeWhere((p) => p.isEmpty);
  if (parts.isEmpty) return null;
  final surname = parts.first.toLowerCase().replaceAll('ё', 'е');
  final initial = parts.length > 1 ? parts[1][0].toLowerCase() : null;
  final found = [
    for (final e in employees)
      if (_matches(e.fullName, surname, initial)) e,
  ];
  return found.length == 1 ? found.single.id : null;
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

  /// Данные с подставленными сотрудниками табеля (по имени из Excel).
  Future<(FinanceImportData, Set<String>)> _withEmployees(
    FinanceImportData data,
  ) async {
    final employees = await _employees.all();
    final unmatched = <String>{};
    String? find(String? name) {
      if (name == null) return null;
      final id = matchEmployee(name, employees);
      if (id == null) unmatched.add(name);
      return id;
    }

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
    final ops = await _fin.operations();
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

Map<String, Object?> _payrollFields(PayrollFinanceMapping m) => {
  'methods': m.methodAccounts,
  'account': m.defaultAccountId,
  'positions': m.positionCategories,
  'category': m.defaultCategoryId,
};
