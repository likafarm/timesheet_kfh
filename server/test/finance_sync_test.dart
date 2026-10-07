@Tags(['mysql'])
library;

import 'dart:convert';

import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_server/kfh_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support/mysql.dart';

/// Финансы (этап 8) в синхронизации: права, проверки, закрытые месяцы и
/// старые программы, которые не знают таблиц финансов.
void main() {
  late TestDatabase testDb;
  late Handler handler;
  late Map<Role, String> tokens;
  late String adminUuid;

  DateTime at(int minutesAgo) =>
      DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo));

  setUp(() async {
    if (!mysqlEnabled) return;
    testDb = await TestDatabase.create(maxConnections: 6);
    final logger = Logger(write: (_) {});
    await MigrationRunner(testDb.db, logger).migrate(projectMigrations());
    final auth = AuthService(
      db: testDb.db,
      accessTokens: AccessTokens(utf8.encode('k' * 32)),
      logger: logger,
      hasher: const PasswordHasher(memoryKiB: 1024, iterations: 1),
    );
    final authApi = AuthApi(auth);
    handler = buildHandler(
      db: testDb.db,
      logger: logger,
      authApi: authApi,
      syncApi: SyncApi(SyncService(db: testDb.db, logger: logger), authApi),
    );
    final admin = await auth.createFirstAdmin(
      login: 'admin',
      fullName: 'Админ',
      password: 'admin-pass-1',
    );
    adminUuid = admin.uuid;
    tokens = {
      Role.admin: (await auth.login(
        'admin',
        'admin-pass-1',
        const RequestInfo(),
      )).accessToken,
    };
    for (final role in [Role.accountant, Role.operator]) {
      await auth.createUser(
        admin,
        login: role.name,
        fullName: role.name,
        role: role.name,
        password: 'temp-pass-1',
        info: const RequestInfo(),
      );
      await auth.setPasswordFromConsole(role.name, 'real-pass-1');
      tokens[role] = (await auth.login(
        role.name,
        'real-pass-1',
        const RequestInfo(),
      )).accessToken;
    }
  });

  tearDown(() async {
    if (mysqlEnabled) await testDb.dispose();
  });

  Future<(int, dynamic)> call(
    String method,
    String path, {
    Object? body,
    Role role = Role.accountant,
  }) async {
    final response = await handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        body: body == null ? null : jsonEncode(body),
        headers: {
          'authorization': 'Bearer ${tokens[role]}',
          'x-device-id': 'pc-1',
        },
      ),
    );
    final text = await response.readAsString();
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  Future<List<Map<String, dynamic>>> push(
    List<Object?> changes, {
    Role role = Role.accountant,
  }) async {
    final (status, json) = await call(
      'POST',
      '/sync/push',
      body: {'changes': changes},
      role: role,
    );
    expect(status, 200, reason: '$json');
    return (json['results'] as List).cast<Map<String, dynamic>>();
  }

  /// Изменения из pull; [tables] — список таблиц (null — как старая
  /// программа, без списка).
  Future<List<Map<String, dynamic>>> pull({
    Set<String>? tables,
    Role role = Role.accountant,
  }) async {
    final query = [
      'cursor=0',
      if (tables != null) 'tables=${tables.join(',')}',
    ].join('&');
    final (status, json) = await call('GET', '/sync/pull?$query', role: role);
    expect(status, 200, reason: '$json');
    return (json['changes'] as List).cast<Map<String, dynamic>>();
  }

  final all = {for (final t in syncTables) t.name};
  const fixedKey = '00000000-0000-7000-8000-000000000001';

  var n = 0;
  String uuid() =>
      '01900000-0000-7000-8000-${(++n).toString().padLeft(12, '0')}';

  Map<String, Object?> row(
    String table,
    String id,
    Map<String, Object?> data, {
    DateTime? updatedAt,
    bool deleted = false,
  }) => SyncChange(
    table: table,
    uuid: id,
    updatedAt: updatedAt ?? at(10),
    deleted: deleted,
    changeId: '$table-${++n}',
    data: {'legacy_id': null, ...data},
  ).toJson();

  Map<String, Object?> direction(String id, String name) => row(
    'fin_directions',
    id,
    {'name': name, 'overhead': false, 'sort_order': 0},
  );

  Map<String, Object?> account(
    String id,
    String name, {
    int opening = 0,
    String? openingDate,
    DateTime? updatedAt,
  }) => row('fin_accounts', id, {
    'name': name,
    'kind': 'cash',
    'opening_balance': opening,
    'opening_date': openingDate,
    'employee_uuid': null,
    'closed': false,
    'sort_order': 0,
  }, updatedAt: updatedAt);

  Map<String, Object?> category(String id, String name, String directionId) =>
      row('fin_categories', id, {
        'type': 'expense',
        'group_name': '04. Техника и транспорт',
        'name': name,
        'direction_uuid': directionId,
        'allocation_key_uuid': null,
        'kind': 'current',
        'in_tax_book': true,
        'hidden': false,
        'sort_order': 0,
      });

  Map<String, Object?> operation(
    String id,
    String accountId, {
    String type = 'expense',
    String? categoryId,
    String? toAccountId,
    String? debtId,
    String? debtMove,
    int amount = 150000,
    String date = '2026-09-10',
  }) => row('fin_operations', id, {
    'date': date,
    'type': type,
    'amount': amount,
    'account_uuid': accountId,
    'to_account_uuid': toAccountId,
    'category_uuid': categoryId,
    'direction_uuid': null,
    'allocation_key_uuid': null,
    'asset_uuid': null,
    'season': null,
    'counterparty_uuid': null,
    'employee_uuid': null,
    'debt_uuid': debtId,
    'debt_move': debtMove,
    'description': 'ДТ',
    'quantity': null,
    'unit': null,
    'tag': null,
    'notes': null,
    'source': 'manual',
    'source_ref': null,
    'created_by': 'buh',
    'created_at': '2026-09-10T12:00:00.000',
  });

  List<String> statuses(List<Map<String, dynamic>> results) => [
    for (final r in results) r['status'] as String,
  ];

  /// Справочник: направление, два кошелька, статья.
  Future<(String, String, String, String)> catalog() async {
    final dir = uuid(), cash = uuid(), bank = uuid(), fuel = uuid();
    // Порядок в пачке не важен: сервер пишет по порядку таблиц.
    final results = await push([
      category(fuel, 'ГСМ', dir),
      account(cash, 'Касса'),
      account(bank, 'Счёт', opening: 2900301, openingDate: '2025-01-01'),
      direction(dir, 'Животноводство'),
    ]);
    expect(statuses(results), everyElement('applied'), reason: '$results');
    return (dir, cash, bank, fuel);
  }

  group('старые и новые программы', () {
    test(
      'без списка таблиц финансы не отдаются, со списком — отдаются',
      () async {
        final (_, cash, _, fuel) = await catalog();
        await push([operation(uuid(), cash, categoryId: fuel)]);
        final legacy = await pull();
        expect(
          legacy.map((c) => c['table']).toSet(),
          everyElement(isIn(legacySyncTableNames)),
        );
        final full = await pull(tables: all);
        final tables = full.map((c) => c['table']).toSet();
        expect(
          tables,
          containsAll([
            'fin_directions',
            'fin_accounts',
            'fin_categories',
            'fin_operations',
          ]),
        );
        // Порядок выдачи — порядок таблиц (сначала то, на что ссылаются).
        final order = [
          for (final c in full) syncTableOrder(c['table'] as String),
        ];
        expect(order, [...order]..sort());
      },
      skip: mysqlSkip,
    );

    test('полный круг без потерь: копейки, даты, коды, JSON долей', () async {
      final (dir, cash, bank, fuel) = await catalog();
      final crops = uuid(), key = uuid(), period = uuid(), cp = uuid();
      final debt = uuid(), op = uuid(), tr = uuid(), loan = uuid();
      final results = await push([
        direction(crops, 'Растениеводство (корма)'),
        row('fin_allocation_keys', key, {'name': 'Трактора'}),
        row('fin_allocation_periods', period, {
          'key_uuid': key,
          'valid_from': '2025-01-01',
          'shares': '{"$crops":40,"$dir":60}',
        }),
        row('counterparties', cp, {
          'name': 'Займодавец',
          'kind': 'person',
          'inn': null,
          'phone': null,
          'employee_uuid': null,
          'notes': null,
        }),
        row('fin_debts', debt, {
          'counterparty_uuid': cp,
          'kind': 'received',
          'opening_balance': 3500000000,
          'opening_date': '2025-01-01',
          'closed': false,
          'notes': null,
        }),
        operation(op, cash, categoryId: fuel, amount: 80497100),
        operation(tr, cash, type: 'transfer', toAccountId: bank),
        operation(
          loan,
          bank,
          type: 'debt',
          debtId: debt,
          debtMove: 'take',
          amount: 20000000,
        ),
      ]);
      expect(statuses(results), everyElement('applied'), reason: '$results');

      final pulled = {
        for (final c in await pull(tables: all)) c['uuid']: c['data'],
      };
      expect(pulled[op]['amount'], 80497100);
      expect(pulled[op]['date'], '2026-09-10');
      expect(pulled[debt]['opening_balance'], 3500000000);
      expect(pulled[period]['shares'], '{"$crops":40,"$dir":60}');
      expect(pulled[loan]['debt_move'], 'take');
      expect(pulled[tr]['to_account_uuid'], bank);
      expect(pulled[bank]['opening_date'], '2025-01-01');
    }, skip: mysqlSkip);
  });

  group('отказы', () {
    test(
      'неверная операция, доли не на 100, нет связанной записи, дубль',
      () async {
        final (dir, cash, _, fuel) = await catalog();
        final dup = uuid();
        final results = await push([
          operation(uuid(), cash, type: 'transfer', toAccountId: cash),
          operation(uuid(), cash),
          row('fin_allocation_keys', fixedKey, {'name': 'Ключ'}),
          operation(uuid(), uuid(), categoryId: fuel),
          account(dup, 'Касса'),
        ]);
        expect(statuses(results), [
          'rejected',
          'rejected',
          'applied',
          'rejected',
          'rejected',
        ]);
        expect(results[0]['code'], 'invalid');
        expect(results[0]['message'], contains('тот же кошелёк'));
        expect(results[1]['message'], contains('статья'));
        expect(results[3]['code'], 'unknown_reference');
        expect(results[4]['code'], 'unique_conflict');
        expect(results[4]['conflict_uuid'], cash);

        final shares = await push([
          row('fin_allocation_periods', uuid(), {
            'key_uuid': fixedKey,
            'valid_from': '2025-01-01',
            'shares': '{"$dir":90}',
          }),
        ]);
        expect(shares.single['code'], 'invalid');
        expect(shares.single['message'], contains('90 %'));

        // Ноль копеек — неверный формат обмена.
        final zero = await push([
          operation(uuid(), cash, categoryId: fuel, amount: 0),
        ]);
        expect(zero.single['code'], 'invalid');
      },
      skip: mysqlSkip,
    );

    test('оператор финансы не пишет и не получает', () async {
      final (_, cash, _, fuel) = await catalog();
      final results = await push([
        operation(uuid(), cash, categoryId: fuel),
      ], role: Role.operator);
      expect(results.single['code'], 'forbidden');
      final pulled = await pull(tables: all, role: Role.operator);
      expect(
        pulled.map((c) => c['table']).toSet(),
        everyElement(isIn({'employees', 'timesheet'})),
      );
    }, skip: mysqlSkip);
  });

  group('закрытые месяцы', () {
    setUp(() async {
      if (!mysqlEnabled) return;
      await testDb.db.execute(
        'INSERT INTO period_locks (year, month, locked_by) VALUES '
        '(2026, 8, :u)',
        {'u': adminUuid},
      );
    });

    test(
      'операция закрытого месяца — period_locked, открытого — проходит',
      () async {
        final (_, cash, _, fuel) = await catalog();
        final results = await push([
          operation(uuid(), cash, categoryId: fuel, date: '2026-08-31'),
          operation(uuid(), cash, categoryId: fuel, date: '2026-09-01'),
        ]);
        expect(statuses(results), ['rejected', 'applied']);
        expect(results.first['code'], 'period_locked');
      },
      skip: mysqlSkip,
    );

    test(
      'начальный остаток в закрытом месяце не меняется, название — можно',
      () async {
        final id = uuid();
        expect(
          statuses(
            await push([
              account(id, 'Касса', opening: 100, openingDate: '2026-08-01'),
            ]),
          ),
          ['rejected'],
          reason: 'новый кошелёк с остатком в закрытом месяце',
        );
        expect(statuses(await push([account(id, 'Касса', opening: 0)])), [
          'applied',
        ]);
        expect(
          statuses(
            await push([
              account(id, 'Касса нал', opening: 0, updatedAt: at(5)),
            ]),
          ),
          ['applied'],
        );
        expect(
          statuses(
            await push([
              account(
                id,
                'Касса нал',
                opening: 500,
                openingDate: '2026-08-15',
                updatedAt: at(1),
              ),
            ]),
          ),
          ['rejected'],
        );
      },
      skip: mysqlSkip,
    );
  });

  test('финансы пишут журнал действий, расчёты ЗП не трогают', () async {
    final (_, cash, _, fuel) = await catalog();
    final op = uuid();
    await push([operation(op, cash, categoryId: fuel)]);
    final audit = await testDb.db.execute(
      "SELECT COUNT(*) AS n FROM audit_log WHERE entity = 'fin_operations' "
      'AND entity_uuid = :u',
      {'u': op},
    );
    expect(audit.rows.single.text('n'), '1');
    final payroll = await testDb.db.execute(
      'SELECT COUNT(*) AS n FROM payroll_results',
    );
    expect(payroll.rows.single.text('n'), '0');
    expect(
      payrollImpactFrom('fin_operations', null, {'date': '2026-09-10'}),
      isNull,
    );
  }, skip: mysqlSkip);
}
