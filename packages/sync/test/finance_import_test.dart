import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:test/test.dart';

import 'support/fake_server.dart';

/// Импорт финансов из выгрузки Excel — на вымышленных данных.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const device = 'import-finance-25';
  String id(int n) =>
      '01900000-0000-7000-8000-${n.toString().padLeft(12, '0')}';
  final herd = id(1), crops = id(2), key = id(3), fuel = id(4), meat = id(5);
  final cash = id(6), olga = id(7), cp = id(8), debt = id(9), emp = id(10);

  Map<String, dynamic> json({
    int fuelAmount = 1001,
    List<Map<String, dynamic>> employees = const [],
    List<Map<String, dynamic>> timesheet = const [],
    List<Map<String, dynamic>> accruals = const [],
    List<Map<String, dynamic>> payments = const [],
  }) {
    final operations = [
      {
        'id': id(20),
        'date': '2025-06-10',
        'type': 'expense',
        'amount': fuelAmount,
        'accountId': cash,
        'categoryId': fuel,
        'counterpartyId': cp,
        'employeeName': 'Иванов И.',
        'description': 'ДТ',
        'sourceRef': 'Расход!22',
      },
      {
        'id': id(21),
        'date': '2025-07-01',
        'type': 'income',
        'amount': 50000,
        'accountId': cash,
        'categoryId': meat,
        'quantity': 1.5,
        'tag': '12',
        'sourceRef': 'Доход!17',
      },
      {
        'id': id(22),
        'date': '2025-07-02',
        'type': 'transfer',
        'amount': 2000,
        'accountId': cash,
        'toAccountId': olga,
        'sourceRef': 'Переводы!2',
      },
      {
        'id': id(23),
        'date': '2025-07-03',
        'type': 'debt',
        'amount': 7000,
        'accountId': cash,
        'debtId': debt,
        'debtMove': 'take',
        'counterpartyId': cp,
        'sourceRef': 'Долги!10',
      },
    ];
    final control = <String, int>{};
    for (final o in [
      ...operations,
      for (final p in payments)
        {'sourceRef': p['sourceRef'], 'date': p['date'], 'amount': p['amount']},
    ]) {
      final sheet = (o['sourceRef'] as String).split('!').first;
      control['$sheet|всего'] =
          (control['$sheet|всего'] ?? 0) + (o['amount'] as int);
      if (sheet == 'Расход' || sheet == 'Доход') {
        final m = '$sheet|${(o['date'] as String).substring(0, 7)}';
        control[m] = (control[m] ?? 0) + (o['amount'] as int);
      }
    }
    return {
      'directions': [
        {
          'id': herd,
          'name': 'Животноводство',
          'overhead': false,
          'sortOrder': 0,
        },
        {'id': crops, 'name': 'Корма', 'overhead': false, 'sortOrder': 1},
      ],
      'allocationKeys': [
        {
          'id': key,
          'name': 'Трактора',
          'periods': [
            {
              'validFrom': '2025-01-01',
              'shares': {herd: 60, crops: 40},
            },
          ],
        },
      ],
      'categories': [
        {
          'id': fuel,
          'type': 'expense',
          'group': '04',
          'name': 'ГСМ',
          'directionId': null,
          'allocationKeyId': key,
          'kind': 'current',
          'inTaxBook': true,
          'hidden': false,
          'sortOrder': 0,
        },
        {
          'id': meat,
          'type': 'income',
          'group': '1',
          'name': 'Мясо',
          'directionId': herd,
          'allocationKeyId': null,
          'kind': 'current',
          'inTaxBook': true,
          'hidden': false,
          'sortOrder': 1,
        },
      ],
      'accounts': [
        {
          'id': cash,
          'name': 'Касса',
          'kind': 'cash',
          'openingBalance': 10000,
          'openingDate': '2025-01-01',
          'employeeName': null,
          'closed': false,
          'sortOrder': 0,
        },
        {
          'id': olga,
          'name': 'Нал Петрова',
          'kind': 'accountable',
          'openingBalance': 0,
          'openingDate': null,
          'employeeName': 'Петрова О.',
          'closed': false,
          'sortOrder': 1,
        },
      ],
      'counterparties': [
        {
          'id': cp,
          'name': 'Иванов И.',
          'kind': 'person',
          'employeeName': 'Иванов И.',
        },
      ],
      'debts': [
        {
          'id': debt,
          'counterpartyId': cp,
          'kind': 'received',
          'openingBalance': 100000,
          'openingDate': '2025-01-01',
        },
      ],
      'assets': [
        {
          'id': id(30),
          'name': 'Газель',
          'kind': 'vehicle',
          'year': null,
          'quantity': 1,
          'referenceValue': 150000000,
          'valuedOn': null,
          'directionId': herd,
          'allocationKeyId': null,
          'cadastralNumber': null,
          'areaHa': null,
          'cadastralValue': null,
          'notes': null,
        },
      ],
      'operations': operations,
      'payrollMapping': {
        'methodAccounts': {'cash': cash},
        'defaultAccountId': cash,
        'positionCategories': {'механизатор': fuel},
        'defaultCategoryId': fuel,
      },
      'employees': employees,
      'timesheet': timesheet,
      'accruals': accruals,
      'payments': payments,
      'control': control,
    };
  }

  late FakeSyncServer server;

  setUp(() {
    server = FakeSyncServer();
    server.put(
      SyncChange(
        table: 'employees',
        uuid: emp,
        updatedAt: DateTime.utc(2026, 1, 1),
        deleted: false,
        editedBy: 'pc-1',
        data: {
          'legacy_id': null,
          'full_name': 'Иванов Иван Петрович',
          'position': 'Механизатор',
          'hire_date': '2025-01-01',
          'dismissal_date': null,
          'base_rate': 1000.0,
          'field_rate': 1500.0,
        },
      ),
    );
  });

  /// Свежий клиент импорта, принявший всё с сервера.
  Future<(FinanceImporter, LocalDatabase)> importer() async {
    final db = LocalDatabase.memory();
    addTearDown(db.close);
    final store = LocalSyncStore(db);
    final engine = SyncEngine(
      store: store,
      transport: server.client(() async => device),
      journal: MemorySyncJournal(),
      transientRetries: const [],
    );
    final importer = FinanceImporter(
      db: db,
      store: store,
      engine: engine,
      importDevice: device,
    );
    await importer.download();
    return (importer, db);
  }

  test('выгрузка проверяется до сервера: правила и итоги', () {
    expect(FinanceImportData.fromJson(json()).problems(), isEmpty);
    final broken = json();
    (broken['control'] as Map)['Расход|всего'] = 1;
    expect(
      FinanceImportData.fromJson(broken).problems().single,
      contains('Расход|всего'),
    );
    final bad = json();
    ((bad['operations'] as List)[2] as Map)['toAccountId'] = cash;
    expect(
      FinanceImportData.fromJson(bad).problems(),
      contains(contains('тот же кошелёк')),
    );
  });

  test('импорт, проверка свежим клиентом, повтор ничего не меняет', () async {
    final data = FinanceImportData.fromJson(json());
    final (first, _) = await importer();
    final plan = await first.plan(data);
    expect(plan.counts['fin_operations']![ImportAction.create], 4);
    expect(plan.unmatchedEmployees, {'Петрова О.'});
    await first.run(data);
    expect(server.rows('fin_operations'), hasLength(4));
    expect(server.rows('fin_operations').map((r) => r.editedBy).toSet(), {
      device,
    });

    final (check, db) = await importer();
    expect(await check.verify(data), isEmpty);
    final ops = {
      for (final o in await DriftRepositories(db).finance.operations()) o.id: o,
    };
    expect(ops[id(20)]!.employeeId, emp, reason: 'Иванов И. — из табеля');
    expect(ops[id(20)]!.source, OperationSource.imported);
    expect(ops[id(21)]!.quantity, 1.5);
    final accounts = await DriftRepositories(db).finance.accounts();
    expect(accounts.firstWhere((a) => a.id == olga).employeeId, isNull);
    final summary = await check.summary();
    expect(
      summary,
      contains('Касса: ${formatRub(10000 - 1001 + 50000 - 2000 + 7000)}'),
    );

    final again = await check.plan(data);
    expect(again.changes, 0);
    await check.run(data);
    expect(server.rows('fin_operations'), hasLength(4));
  });

  test('исправленная выгрузка обновляет только изменённое', () async {
    final (first, _) = await importer();
    await first.run(FinanceImportData.fromJson(json()));
    final fixed = FinanceImportData.fromJson(json(fuelAmount: 1500));
    final (second, _) = await importer();
    final plan = await second.plan(fixed);
    expect(plan.changes, 1);
    expect(plan.counts['fin_operations']![ImportAction.update], 1);
    await second.run(fixed);
    expect(server.row('fin_operations', id(20))!.data['amount'], 1500);
  });

  test('правку человека после импорта не перезаписывает', () async {
    final (first, _) = await importer();
    await first.run(FinanceImportData.fromJson(json()));
    final row = server.row('fin_operations', id(20))!;
    server.put(
      SyncChange(
        table: row.table,
        uuid: row.uuid,
        updatedAt: row.updatedAt.add(const Duration(minutes: 5)),
        deleted: false,
        editedBy: 'pc-1',
        data: {...row.data, 'description': 'ДТ, поправлено руками'},
      ),
    );
    final (second, _) = await importer();
    await expectLater(
      second.run(FinanceImportData.fromJson(json())),
      throwsA(
        isA<FinanceImportException>().having(
          (e) => e.toString(),
          'текст',
          contains('pc-1'),
        ),
      ),
    );
    expect(
      server.row('fin_operations', id(20))!.data['description'],
      'ДТ, поправлено руками',
    );
  });

  test('matchEmployee: фамилия и инициал, однозначно', () {
    Employee e(String name) => Employee(
      id: name,
      fullName: name,
      position: '',
      hireDate: DateTime(2025),
      baseRate: 0,
      fieldRate: 0,
    );
    final staff = [
      e('Воробьёв Дмитрий Алексеевич'),
      e('Кольцов Сергей'),
      e('Кольцова Маргарита'),
    ];
    expect(matchEmployee('Воробьев Д.', staff), 'Воробьёв Дмитрий Алексеевич');
    expect(matchEmployee('Воробьёв А.', staff), isNull);
    expect(matchEmployee('Кольцов С.', staff), 'Кольцов Сергей');
    expect(matchEmployee('Новиков Н.', staff), isNull);
  });

  test('недостающие работники табеля Excel добавляются уволенными', () async {
    final petrova = id(40);
    final data = FinanceImportData.fromJson(
      json(
        employees: [
          {
            'id': id(41),
            'name': 'Иванов И. П.',
            'position': 'Рабочий',
            'hireDate': '2025-01-10',
            'dismissalDate': '2025-05-01',
            'rate': 2000,
          },
          {
            'id': petrova,
            'name': 'Петрова О.',
            'position': 'Рабочий',
            'hireDate': '2025-01-31',
            'dismissalDate': '2025-04-20',
            'rate': 3000,
          },
        ],
      ),
    );
    final (first, _) = await importer();
    final plan = await first.plan(data);
    expect(plan.addedEmployees, ['Петрова О.'], reason: 'Иванов уже есть');
    expect(plan.unmatchedEmployees, isEmpty);
    await first.run(data);
    expect(server.row('employees', petrova)!.editedBy, device);
    expect(server.row('employees', id(41)), isNull);

    final (check, db) = await importer();
    expect(await check.verify(data), isEmpty);
    expect((await check.plan(data)).changes, 0);
    final repos = DriftRepositories(db);
    final added = (await repos.employees.byId(petrova))!;
    expect(added.fullName, 'Петрова О.');
    expect(added.dismissalDate, DateTime(2025, 4, 20));
    final rates = await repos.rates.history(petrova);
    expect(rates.single.startDate, DateTime(2025, 1, 31));
    expect(rates.single.baseRate, 3000);
    final accounts = await repos.finance.accounts();
    expect(accounts.firstWhere((a) => a.id == olga).employeeId, petrova);

    // Удалённого после импорта не возвращает.
    final row = server.row('employees', petrova)!;
    server.put(
      SyncChange(
        table: row.table,
        uuid: row.uuid,
        updatedAt: row.updatedAt.add(const Duration(minutes: 5)),
        deleted: true,
        editedBy: 'pc-1',
        data: row.data,
      ),
    );
    final (third, _) = await importer();
    await expectLater(third.run(data), throwsA(isA<FinanceImportException>()));
  });

  test(
    'табель Excel: дни, выплаты, ставка под дни, корректировка месяца',
    () async {
      final petrova = id(40);
      final data = FinanceImportData.fromJson(
        json(
          employees: [
            {
              'id': petrova,
              'name': 'Петрова О.',
              'position': 'Продавец',
              'hireDate': '2025-02-03',
              'dismissalDate': '2025-03-01',
              'rate': 3000,
            },
          ],
          timesheet: [
            {
              'id': id(50),
              'employeeName': 'Иванов И. П.',
              'date': '2025-03-03',
              'days': 1,
            },
            {
              'id': id(51),
              'employeeName': 'Иванов И. П.',
              'date': '2025-03-04',
              'days': 0.5,
            },
            {
              'id': id(52),
              'employeeName': 'Петрова О.',
              'date': '2025-02-03',
              'days': 1,
            },
          ],
          accruals: [
            {
              'id': id(60),
              'employeeName': 'Иванов И. П.',
              'year': 2025,
              'month': 3,
              'excelDays': 2,
              'tariff': 2000,
              'bonus': 1000,
              'premium': 0,
              'accrued': 5000,
              'paid': 3000,
            },
            {
              'id': id(61),
              'employeeName': 'Петрова О.',
              'year': 2025,
              'month': 2,
              'excelDays': 1,
              'tariff': 3000,
              'bonus': 0,
              'premium': 0,
              'accrued': 3000,
              'paid': 3000,
            },
          ],
          payments: [
            {
              'id': id(70),
              'employeeName': 'Иванов И.',
              'date': '2025-04-02',
              'amount': 300000,
              'method': 'cash',
              'notes': 'Зарплата',
              'sourceRef': 'Расход!50',
            },
          ],
        ),
      );
      expect(data.problems(), isEmpty);
      final (first, _) = await importer();
      final plan = await first.plan(data);
      expect(plan.counts['timesheet']![ImportAction.create], 3);
      expect(plan.counts['payments']![ImportAction.create], 1);
      expect(plan.counts['payroll_adjustments']![ImportAction.create], 1);
      expect(
        plan.employeeFixes.single,
        contains('ставка'),
        reason: 'у Иванова нет ставки на дни табеля',
      );
      await first.run(data);

      final (check, db) = await importer();
      expect(await check.verify(data), isEmpty);
      expect(
        (await check.plan(data)).changes,
        0,
        reason: 'повтор ничего не меняет',
      );
      final repos = DriftRepositories(db);
      final rate = (await repos.rates.history(emp)).single;
      expect(rate.startDate, DateTime(2025, 3, 3));
      expect(rate.baseRate, 2000);
      // 1,5 дня по 2000 = 3000; в Excel 5000 — корректировка 2000.
      final adjustment = (await repos.adjustments.all()).single;
      expect(adjustment.amount, 2000);
      expect(adjustment.notes, contains('надбавки'));
      final march = await repos.payrollService.calculateMonth(emp, 2025, 3);
      expect(march.totalSalary, 5000);
      final pay = (await repos.payments.list()).single;
      expect(pay.amount, 3000);
      expect(pay.employeeId, emp);
      expect(pay.notes, contains('Расход!50'));

      final rows = await check.compareWithTabel(data);
      final ivanMarch = rows.firstWhere(
        (r) => r.name == 'Иванов И. П.' && r.month == 3,
      );
      expect(ivanMarch.accrued, 5000);
      expect(ivanMarch.accruedDiffers, isFalse);
      expect(ivanMarch.paidDiffers, isTrue, reason: 'выдано в апреле');
      final (text, csv) = formatTabelComparison(rows);
      expect(text, contains('Петрова О.'));
      expect(csv.split('\n').first, startsWith('Работник;Месяц'));
    },
  );
}
