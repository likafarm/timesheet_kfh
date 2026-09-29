@Tags(['mysql'])
library;

import 'dart:async';
import 'dart:convert';

import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_server/kfh_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support/mysql.dart';

/// Закрытые месяцы, расчёт ЗП на сервере и чтение данных — на MySQL.
void main() {
  late TestDatabase testDb;
  late Handler handler;
  late Map<Role, String> tokens;
  late SyncService sync;
  late User accountant;

  /// Как на боевом сервере: приём правок и открытие месяца пересчитывают
  /// открытые месяцы.
  late SyncService autoSync;
  late Handler autoHandler;

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
    sync = SyncService(db: testDb.db, logger: logger);
    handler = buildHandler(
      db: testDb.db,
      logger: logger,
      authApi: authApi,
      syncApi: SyncApi(sync, authApi),
      dataApi: DataApi(
        db: testDb.db,
        auth: authApi,
        periods: PeriodService(db: testDb.db),
        payroll: PayrollCalculator(db: testDb.db),
      ),
    );
    final payroll = PayrollCalculator(db: testDb.db);
    autoSync = SyncService(db: testDb.db, logger: logger, payroll: payroll);
    autoHandler = buildHandler(
      db: testDb.db,
      logger: logger,
      authApi: authApi,
      syncApi: SyncApi(autoSync, authApi),
      dataApi: DataApi(
        db: testDb.db,
        auth: authApi,
        periods: PeriodService(db: testDb.db, payroll: payroll),
        payroll: payroll,
      ),
    );
    final admin = await auth.createFirstAdmin(
        login: 'admin', fullName: 'Админ', password: 'admin-pass-1');
    tokens = {
      Role.admin: (await auth.login('admin', 'admin-pass-1', const RequestInfo()))
          .accessToken,
    };
    for (final role in [Role.accountant, Role.operator]) {
      await auth.createUser(admin,
          login: role.name,
          fullName: 'Пользователь ${role.name}',
          role: role.name,
          password: 'temp-pass-1',
          info: const RequestInfo());
      await auth.setPasswordFromConsole(role.name, 'real-pass-1');
      final pair =
          await auth.login(role.name, 'real-pass-1', const RequestInfo());
      tokens[role] = pair.accessToken;
      if (role == Role.accountant) accountant = pair.user;
    }
  });

  tearDown(() async {
    if (mysqlEnabled) await testDb.dispose();
  });

  Future<(int, dynamic)> call(String method, String path,
      {Object? body, Role role = Role.accountant, bool auto = false}) async {
    final response = await (auto ? autoHandler : handler)(Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {
        'authorization': 'Bearer ${tokens[role]}',
        'x-device-id': 'pc-1',
      },
    ));
    final text = await response.readAsString();
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  // ------------------------------------------------------------ данные

  var n = 0;
  String uuid() =>
      '01900000-0000-7000-8000-${(++n).toString().padLeft(12, '0')}';
  final stamp = DateTime.now().toUtc().subtract(const Duration(hours: 1));

  SyncChange row(String table, String id, Map<String, Object?> data,
          {bool deleted = false}) =>
      SyncChange(
          table: table, uuid: id, updatedAt: stamp, deleted: deleted, data: data);

  SyncChange employee(String id, String name,
          {String hire = '2026-01-01', String? dismissed}) =>
      row('employees', id, {
        'legacy_id': null,
        'full_name': name,
        'position': 'Рабочий',
        'hire_date': hire,
        'dismissal_date': dismissed,
        'base_rate': 777.0,
        'field_rate': 888.0,
      });

  SyncChange rate(String employee, double base, double field, String start,
          String? end, {bool deleted = false}) =>
      row(
          'employee_rates',
          uuid(),
          {
            'legacy_id': null,
            'employee_uuid': employee,
            'base_rate': base,
            'field_rate': field,
            'start_date': start,
            'end_date': end,
          },
          deleted: deleted);

  SyncChange day(String employee, String date,
          {String type = 'work',
          double days = 1,
          String? place = 'field',
          bool deleted = false}) =>
      row(
          'timesheet',
          uuid(),
          {
            'legacy_id': null,
            'employee_uuid': employee,
            'date': date,
            'day_type': type,
            'days': days,
            'work_place': place,
            'notes': null,
            'created_at': '2026-09-01T10:00:00',
          },
          deleted: deleted);

  SyncChange payment(String employee, String date, double amount) =>
      row('payments', uuid(), {
        'legacy_id': null,
        'employee_uuid': employee,
        'payment_date': date,
        'amount': amount,
        'payment_type': 'salary',
        'period_start': null,
        'period_end': null,
        'payment_method': 'cash',
        'document_number': null,
        'notes': null,
        'created_at': '2026-09-01T10:00:00',
      });

  Future<void> push(List<SyncChange> changes, {bool auto = false}) async {
    final results = await (auto ? autoSync : sync).push(
        accountant, 'pc-1', [for (final c in changes) c.toJson()]);
    expect(results.map((r) => r.status).toSet(), {'applied'},
        reason: [for (final r in results) '${r.code}: ${r.message}'].join('; '));
  }

  final ivan = '01900000-0000-7000-8000-00000000aaa1';
  final petr = '01900000-0000-7000-8000-00000000aaa2';
  final olga = '01900000-0000-7000-8000-00000000aaa3';

  /// Сентябрь 2026:
  /// - Иван: ставка 1000/1500 до 15.09, с 16.09 — 1200/1800; дни: 01.09 поле,
  ///   02.09 база, 03.09 поле 0.5, 16.09 поле, 17.09 база 0.5, 18.09
  ///   больничный, 19.09 отпуск, 20.09 выходной, 21.09 поле (удалён — не
  ///   считается);
  /// - Пётр: ставка с 10.09 (удалённая ставка с 01.09 не считается);
  ///   01.09 поле — без ставки, 10.09 поле;
  /// - Ольга уволена 31.08, начислений и выплат нет — в расчёт не входит.
  Future<void> seed({bool auto = false}) async {
    await push(auto: auto, [
      employee(ivan, 'Иванов Иван'),
      employee(petr, 'Петров Пётр'),
      employee(olga, 'Ольгина Ольга', dismissed: '2026-08-31'),
      rate(ivan, 1000, 1500, '2026-01-01', '2026-09-15'),
      rate(ivan, 1200, 1800, '2026-09-16', null),
      rate(petr, 5000, 5000, '2026-09-01', null, deleted: true),
      rate(petr, 900, 1100, '2026-09-10', null),
      day(ivan, '2026-09-01'),
      day(ivan, '2026-09-02', place: 'base'),
      day(ivan, '2026-09-03', days: 0.5),
      day(ivan, '2026-09-16'),
      day(ivan, '2026-09-17', place: 'base', days: 0.5),
      day(ivan, '2026-09-18', type: 'sick', place: null),
      day(ivan, '2026-09-19', type: 'vacation', place: null),
      day(ivan, '2026-09-20', type: 'dayoff', place: null),
      day(ivan, '2026-09-21', deleted: true),
      day(ivan, '2026-10-01'), // другой месяц
      day(petr, '2026-09-01'),
      day(petr, '2026-09-10'),
      payment(ivan, '2026-09-05', 1000),
      payment(ivan, '2026-10-05', 2000),
    ]);
  }

  // ------------------------------------------------------------- тесты

  group('расчёт ЗП', () {
    test('сервер считает так же, как kfh_domain; сумма Ивана — вручную',
        () async {
      await seed();
      final (s, json) =
          await call('GET', '/payroll/calculation?year=2026&month=9');
      expect(s, 200, reason: '$json');
      final byEmployee = {
        for (final e in json['employees']) e['employee_uuid']: e,
      };
      // Ольга уволена, начислений и выплат нет — в расчёт не входит.
      expect(byEmployee.keys.toSet(), {ivan, petr});

      // 1500 + 1000 + 0.5*1500 + 1800 + 0.5*1200 = 5650
      final iv = byEmployee[ivan]['calculation'];
      expect(iv['total_salary'], 5650.0);
      expect(iv['base_days'], 1.5);
      expect(iv['field_days'], 2.5);
      expect(iv['sick_days'], 1.0);
      expect(iv['vacation_days'], 1.0);
      expect(iv['skipped_work_days'], 0);
      expect(iv['base_rate_used'], 1200.0);

      final pe = byEmployee[petr]['calculation'];
      expect(pe['total_salary'], 1100.0);
      expect(pe['skipped_work_days'], 1);

      expect(byEmployee[ivan]['needed'], isTrue);
      expect(byEmployee[ivan]['saved'], isNull);
      expect(byEmployee[ivan]['up_to_date'], isFalse);

      // Тот же расчёт напрямую чистой функцией домена.
      final direct = calculateMonthlySalary(
        employeeId: ivan,
        year: 2026,
        month: 9,
        records: [
          for (final (date, place, days, type) in [
            ('2026-09-01', 'field', 1.0, 'work'),
            ('2026-09-02', 'base', 1.0, 'work'),
            ('2026-09-03', 'field', 0.5, 'work'),
            ('2026-09-16', 'field', 1.0, 'work'),
            ('2026-09-17', 'base', 0.5, 'work'),
            ('2026-09-18', null, 1.0, 'sick'),
            ('2026-09-19', null, 1.0, 'vacation'),
            ('2026-09-20', null, 1.0, 'dayoff'),
          ])
            TimesheetRecord(
                employeeId: ivan,
                date: parseDateIso(date),
                dayType: type,
                days: days,
                workPlace: place),
        ],
        rates: [
          EmployeeRate(
              employeeId: ivan,
              baseRate: 1000,
              fieldRate: 1500,
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 9, 15)),
          EmployeeRate(
              employeeId: ivan,
              baseRate: 1200,
              fieldRate: 1800,
              startDate: DateTime(2026, 9, 16)),
        ],
      );
      expect(iv['total_salary'], direct.totalSalary);
      expect(iv['field_days'], direct.fieldDays);
    }, skip: mysqlSkip);

    test('сохранение: запись, журнал, аудит; повтор — без изменений',
        () async {
      await seed();
      final start = await sync.pull(accountant, cursor: 0);
      var (s, json) = await call('POST', '/payroll/calculate',
          body: {'year': 2026, 'month': 9});
      expect(s, 200, reason: '$json');
      expect((json['saved'], json['unchanged'], json['removed']), (2, 0, 0));
      expect(json['employees'].every((e) => e['up_to_date'] == true), isTrue);

      (s, json) = await call('POST', '/payroll/calculate',
          body: {'year': 2026, 'month': 9});
      expect((json['saved'], json['unchanged']), (0, 2));

      // Результаты уходят клиентам через pull.
      final pulled = await sync.pull(accountant,
          cursor: start.cursor, epoch: start.epoch);
      expect(pulled.changes.map((c) => c.table).toSet(), {'payroll_results'});
      expect(pulled.changes, hasLength(2));
      expect(pulled.changes.first.editedBy, 'server');
      final audit = await testDb.db.execute(
          "SELECT COUNT(*) AS c FROM audit_log WHERE action = 'payroll_save'");
      expect(audit.rows.single.intOf('c'), 2);

      // Правка табеля — расчёт устарел, пересчёт трогает одного сотрудника.
      await push([day(ivan, '2026-09-22')]);
      (s, json) = await call('GET', '/payroll/calculation?year=2026&month=9');
      final stale = [
        for (final e in json['employees'])
          if (e['up_to_date'] == false) e['employee_uuid'],
      ];
      expect(stale, [ivan]);
      (s, json) = await call('POST', '/payroll/calculate',
          body: {'year': 2026, 'month': 9});
      expect((json['saved'], json['unchanged']), (1, 1));
    }, skip: mysqlSkip);

    test('расчёт, сохранённый клиентом, обновляется на месте (тот же uuid)',
        () async {
      await seed();
      final clientResult = uuid();
      await push([
        row('payroll_results', clientResult, {
          'legacy_id': 12,
          'employee_uuid': ivan,
          'year': 2026,
          'month': 9,
          'base_days': 0.0,
          'field_days': 0.0,
          'sick_days': 0.0,
          'vacation_days': 0.0,
          'total_salary': 1.0,
          'base_rate_used': null,
          'field_rate_used': null,
          'calculated_at': '2026-09-20T12:00:00',
          'status': 'calculated',
          'skipped_work_days': 0,
        }),
      ]);
      final (s, json) = await call('POST', '/payroll/calculate',
          body: {'year': 2026, 'month': 9});
      expect(s, 200);
      final saved = json['employees']
          .firstWhere((e) => e['employee_uuid'] == ivan)['saved'];
      expect(saved['uuid'], clientResult);
      expect(saved['legacy_id'], 12);
      expect(saved['total_salary'], 5650.0);
      expect(saved['calculated_at'], endsWith('Z'));
    }, skip: mysqlSkip);

    test('сохранённые расчёты и входящие остатки', () async {
      await seed();
      await call('POST', '/payroll/calculate', body: {'year': 2026, 'month': 9});
      final (s, json) = await call('GET', '/payroll?year=2026&month=10');
      expect(s, 200);
      expect(json['results'], isEmpty);
      // Иван: начислено за сентябрь 5650 − выплачено до 01.10 1000.
      expect(json['starting_balances'][ivan], 4650.0);
      expect(json['starting_balances'][petr], 1100.0);
      final (_, sept) = await call('GET', '/payroll?year=2026&month=9');
      expect(sept['results'], hasLength(2));
      expect(sept['starting_balances'][ivan], isNull);
    }, skip: mysqlSkip);

    test('оператору расчёт недоступен, неверный месяц — 400', () async {
      var (s, _) = await call('GET', '/payroll/calculation?year=2026&month=9',
          role: Role.operator);
      expect(s, 403);
      (s, _) = await call('POST', '/payroll/calculate',
          body: {'year': 2026, 'month': 9}, role: Role.operator);
      expect(s, 403);
      (s, _) = await call('GET', '/payroll/calculation?year=2026&month=13');
      expect(s, 400);
      (s, _) = await call('POST', '/payroll/calculate',
          body: {'year': '2026', 'month': 9});
      expect(s, 400);
    }, skip: mysqlSkip);
  });

  group('кто входит в расчёт', () {
    SyncChange zeroResult(String employee) => row('payroll_results', uuid(), {
          'legacy_id': null,
          'employee_uuid': employee,
          'year': 2026,
          'month': 9,
          'base_days': 0.0,
          'field_days': 0.0,
          'sick_days': 0.0,
          'vacation_days': 0.0,
          'total_salary': 0.0,
          'base_rate_used': null,
          'field_rate_used': null,
          'calculated_at': '2026-09-20T12:00:00',
          'status': 'calculated',
          'skipped_work_days': 0,
        });

    test('старый нулевой расчёт скрыт в отчёте и удаляется пересчётом',
        () async {
      await seed();
      final start = await sync.pull(accountant, cursor: 0);
      // Как у клиента до исправления: сохранён нулевой расчёт Ольги.
      final olgaResult = zeroResult(olga);
      await push([olgaResult]);

      var (s, json) = await call('GET', '/payroll?year=2026&month=9');
      expect(s, 200);
      expect([for (final r in json['results']) r['employee_uuid']],
          isNot(contains(olga)), reason: 'пустая строка в отчёт не попадает');

      (s, json) = await call('GET', '/payroll/calculation?year=2026&month=9');
      final olgaRow =
          json['employees'].firstWhere((e) => e['employee_uuid'] == olga);
      expect((olgaRow['needed'], olgaRow['up_to_date']), (false, false));

      (s, json) = await call('POST', '/payroll/calculate',
          body: {'year': 2026, 'month': 9});
      expect((json['saved'], json['removed']), (2, 1));
      expect([for (final e in json['employees']) e['employee_uuid']],
          isNot(contains(olga)));

      // Клиенты получат удаление.
      final pulled = await sync.pull(accountant,
          cursor: start.cursor, epoch: start.epoch);
      final gone = pulled.changes.firstWhere((c) => c.uuid == olgaResult.uuid);
      expect(gone.deleted, isTrue);
      final audit = await testDb.db.execute(
          "SELECT COUNT(*) AS c FROM audit_log WHERE action = 'payroll_delete'");
      expect(audit.rows.single.intOf('c'), 1);
    }, skip: mysqlSkip);

    test('одна выплата без начислений — в расчёте и в отчёте', () async {
      await seed();
      await push([payment(olga, '2026-09-30', 700)]);
      var (s, json) = await call('POST', '/payroll/calculate',
          body: {'year': 2026, 'month': 9});
      expect(json['saved'], 3);
      final olgaRow =
          json['employees'].firstWhere((e) => e['employee_uuid'] == olga);
      expect(olgaRow['calculation']['total_salary'], 0.0);
      (s, json) = await call('GET', '/payroll?year=2026&month=9');
      expect([for (final r in json['results']) r['employee_uuid']], contains(olga));
      // Выплата 1 октября — уже другой месяц: в октябре Ольга есть по
      // выплате.
      await push([payment(olga, '2026-10-01', 100)]);
      (s, json) = await call('GET', '/payroll/calculation?year=2026&month=10');
      expect([for (final e in json['employees']) e['employee_uuid']], contains(olga));
    }, skip: mysqlSkip);

    test('входящий остаток оставляет в расчёте без дней и выплат', () async {
      await seed();
      await push([payment(olga, '2026-09-30', 700)]);
      await call('POST', '/payroll/calculate', body: {'year': 2026, 'month': 9});
      // Ноябрь: ни дней, ни выплат. Иван: 5650 начислено − 1000 − 2000
      // выплачено = долг 2650; Ольга: 0 − 700 = переплата; Пётр: 1100 долг.
      var (s, json) = await call('GET', '/payroll/calculation?year=2026&month=11');
      expect(s, 200);
      final byEmployee = {
        for (final e in json['employees']) e['employee_uuid']: e,
      };
      expect(byEmployee.keys.toSet(), {ivan, petr, olga});
      expect(byEmployee[ivan]['starting_balance'], 2650.0);
      expect(byEmployee[olga]['starting_balance'], -700.0);
      expect(byEmployee[ivan]['calculation']['total_salary'], 0.0);
      (s, json) = await call('POST', '/payroll/calculate',
          body: {'year': 2026, 'month': 11});
      expect(json['saved'], 3);
      (s, json) = await call('GET', '/payroll?year=2026&month=11');
      expect(json['results'], hasLength(3));

      // Долги погашены — в декабре пусто.
      await push([
        payment(ivan, '2026-11-15', 2650),
        payment(petr, '2026-11-15', 1100),
        payment(olga, '2026-11-15', -700),
      ]);
      (s, json) = await call('GET', '/payroll/calculation?year=2026&month=12');
      expect(json['employees'], isEmpty);
    }, skip: mysqlSkip);

    test('удалили все дни — пересчёт убирает расчёт сотрудника', () async {
      await seed();
      await call('POST', '/payroll/calculate', body: {'year': 2026, 'month': 9});
      final petrDays = await testDb.db.execute(
          'SELECT uuid FROM timesheet WHERE employee_uuid = :e', {'e': petr});
      final later = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
      for (final r in petrDays.rows) {
        final current = await const SyncRows().read(testDb.db.execute,
            syncTableByName('timesheet')!, r.textOf('uuid'));
        await push([
          SyncChange(
              table: 'timesheet',
              uuid: current!.uuid,
              updatedAt: later,
              deleted: true,
              data: current.data),
        ]);
      }
      final (_, json) = await call('POST', '/payroll/calculate',
          body: {'year': 2026, 'month': 9});
      expect((json['saved'], json['unchanged'], json['removed']), (0, 1, 1));
    }, skip: mysqlSkip);
  });

  group('закрытые месяцы', () {
    test('закрыть, увидеть, запретить правки и пересчёт, открыть', () async {
      await seed();
      var (s, json) = await call('POST', '/periods/locks',
          body: {'year': 2026, 'month': 9, 'note': 'Сдали в бухгалтерию'});
      expect(s, 201, reason: '$json');
      expect(json['locked_by_name'], 'Пользователь accountant');

      (s, json) = await call('POST', '/periods/locks',
          body: {'year': 2026, 'month': 9});
      expect((s, json['error']['code']), (409, 'already_locked'));

      (s, json) = await call('GET', '/periods/locks', role: Role.operator);
      expect(s, 200);
      expect(json['locks'].single['note'], 'Сдали в бухгалтерию');

      final rejected = await sync.push(
          accountant, 'pc-1', [day(ivan, '2026-09-25').toJson()]);
      expect(rejected.single.code, 'period_locked');
      (s, json) = await call('POST', '/payroll/calculate',
          body: {'year': 2026, 'month': 9});
      expect((s, json['error']['code']), (409, 'period_locked'));

      (s, json) = await call('DELETE', '/periods/locks/2026/9');
      expect((s, json['error']['code']), (403, 'forbidden'),
          reason: 'открыть месяц может только админ');
      (s, _) = await call('DELETE', '/periods/locks/2026/9', role: Role.admin);
      expect(s, 200);
      (s, _) = await call('DELETE', '/periods/locks/2026/9', role: Role.admin);
      expect(s, 404);
      await push([day(ivan, '2026-09-25')]);

      final audit = await testDb.db.execute(
          'SELECT action, old_value FROM audit_log '
          "WHERE entity = 'period_locks' ORDER BY id");
      expect([for (final r in audit.rows) r.textOf('action')],
          ['period_lock', 'period_unlock']);
      expect(audit.rows.last.textOf('old_value'), contains('Сдали'));
    }, skip: mysqlSkip);

    test('оператор не закрывает и не открывает; неверные данные — 400',
        () async {
      var (s, _) = await call('POST', '/periods/locks',
          body: {'year': 2026, 'month': 9}, role: Role.operator);
      expect(s, 403);
      (s, _) = await call('DELETE', '/periods/locks/2026/9', role: Role.operator);
      expect(s, 403);
      (s, _) = await call('POST', '/periods/locks', body: {'year': 2026, 'month': 0});
      expect(s, 400);
      (s, _) = await call('POST', '/periods/locks',
          body: {'year': 2026, 'month': 5, 'note': 'x' * 501});
      expect(s, 400);
    }, skip: mysqlSkip);

    test('открытие: предпросмотр ничего не меняет, снимок хранит «до»',
        () async {
      await seed(); // без пересчёта: расчёты не сохранены
      var (s, json) = await call('POST', '/periods/locks',
          body: {'year': 2026, 'month': 9, 'note': 'сдан'});
      expect(s, 201);
      Future<int> count(String table) async => (await testDb.db
              .execute('SELECT COUNT(*) AS c FROM $table'))
          .rows
          .single
          .intOf('c');
      final logBefore = await count('change_log');

      (s, json) = await call('GET', '/periods/locks/2026/9/unlock-preview');
      expect((s, json['error']['code']), (403, 'forbidden'));
      (s, json) = await call('GET', '/periods/locks/2026/9/unlock-preview',
          role: Role.admin, auto: true);
      expect(s, 200, reason: '$json');
      expect(json['lock']['note'], 'сдан');
      final months = {
        for (final m in json['changes']) '${m['month']}': m['employees'],
      };
      expect(months.keys, ['9', '10']);
      final ivanSept = months['9']
          .firstWhere((e) => e['employee_uuid'] == ivan);
      expect((ivanSept['before']['accrued'], ivanSept['after']['accrued']),
          (0.0, 5650.0));
      final ivanOct = months['10']
          .firstWhere((e) => e['employee_uuid'] == ivan);
      // Остаток на 1.10: было 0 − 1000, станет 5650 − 1000.
      expect((ivanOct['before']['starting'], ivanOct['after']['starting']),
          (-1000.0, 4650.0));
      expect(ivanOct['after']['closing'], 4650.0 + 1800 - 2000);

      // Предпросмотр откатился: месяц закрыт, расчётов и журнала нет.
      expect(await count('period_locks'), 1);
      expect(await count('payroll_results'), 0);
      expect(await count('change_log'), logBefore);
      expect(await count('period_snapshots'), 0);

      (s, json) = await call('DELETE', '/periods/locks/2026/9',
          role: Role.admin, auto: true);
      expect(s, 200);
      final id = json['snapshot_id'] as int;
      expect(await count('payroll_results'), 4);

      (s, json) = await call('GET', '/periods/snapshots');
      expect(s, 200);
      final listed = json['snapshots'].single;
      expect((listed['id'], listed['year'], listed['month'], listed['reason']),
          (id, 2026, 9, 'unlock'));
      expect(listed['created_by_name'], 'Админ');
      expect(listed['lock']['locked_by_name'], 'Пользователь accountant');
      expect(listed.containsKey('months'), isFalse);

      (s, json) = await call('GET', '/periods/snapshots/$id');
      expect(s, 200);
      final snapSept = json['months'].first;
      expect((snapSept['year'], snapSept['month']), (2026, 9));
      final ivanSnap =
          snapSept['employees'].firstWhere((e) => e['employee_uuid'] == ivan);
      expect(ivanSnap['full_name'], 'Иванов Иван');
      expect((ivanSnap['accrued'], ivanSnap['paid'], ivanSnap['closing']),
          (0.0, 1000.0, -1000.0), reason: 'как было до открытия');
      // Что изменилось: снимок против расчётов сейчас.
      Future<Map<String, dynamic>> changed() async {
        final (s, json) = await call('GET', '/periods/snapshots/$id/changes');
        expect(s, 200, reason: '$json');
        expect(json.containsKey('months'), isFalse);
        expect(json['compared_at'], isNotNull);
        return {
          for (final m in json['changes'])
            '${m['month']}': {
              for (final e in m['employees']) e['employee_uuid']: e,
            },
        };
      }

      var diff = await changed();
      expect(diff.keys, ['9', '10']);
      expect(diff['9'][ivan]['before']['accrued'], 0.0);
      expect(diff['9'][ivan]['after']['accrued'], 5650.0);
      expect(diff['10'][ivan]['after']['starting'], 4650.0);
      expect(diff['9'].containsKey(olga), isFalse, reason: 'не менялось');

      // Правка после открытия тоже видна.
      await push(auto: true, [day(ivan, '2026-09-22')]);
      diff = await changed();
      expect(diff['9'][ivan]['after']['accrued'], 5650.0 + 1800);
      (s, _) = await call('GET', '/periods/snapshots/$id/changes',
          role: Role.operator);
      expect(s, 403);

      (s, _) = await call('GET', '/periods/snapshots/$id', role: Role.operator);
      expect(s, 403);
      (s, _) = await call('GET', '/periods/snapshots/999');
      expect(s, 404);
    }, skip: mysqlSkip);

    test('закрытие ждёт незавершённый приём изменений', () async {
      final release = Completer<void>();
      final reading = Completer<void>();
      // Как push: читает закрытые месяцы с FOR SHARE и держит транзакцию.
      final pushLike = testDb.db.transaction((conn) async {
        await conn.execute('SELECT year, month FROM period_locks FOR SHARE');
        reading.complete();
        await release.future;
      });
      await reading.future;
      var done = false;
      final locking = call('POST', '/periods/locks',
          body: {'year': 2026, 'month': 9}).then((r) {
        done = true;
        return r;
      });
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(done, isFalse, reason: 'закрытие должно ждать');
      release.complete();
      await pushLike;
      expect((await locking).$1, 201);
    }, skip: mysqlSkip);
  });

  group('автопересчёт открытых месяцев', () {
    /// Расчёт месяца по сотрудникам: свежий и сохранённый рядом.
    Future<Map<String, dynamic>> month(int m) async {
      final (s, json) =
          await call('GET', '/payroll/calculation?year=2026&month=$m');
      expect(s, 200, reason: '$json');
      return {for (final e in json['employees']) e['employee_uuid']: e};
    }

    Future<int> auditCount(String action) async {
      final r = await testDb.db.execute(
          'SELECT COUNT(*) AS c FROM audit_log WHERE action = :a', {'a': action});
      return r.rows.single.intOf('c');
    }

    Future<SyncChange> current(String table, String id) async =>
        (await const SyncRows()
            .read(testDb.db.execute, syncTableByName(table)!, id))!;

    test('приём правок сохраняет расчёты всех месяцев с данными', () async {
      final start = await autoSync.pull(accountant, cursor: 0);
      await seed(auto: true);
      final sept = await month(9), oct = await month(10);
      expect(sept.keys.toSet(), {ivan, petr});
      expect(oct.keys.toSet(), {ivan, petr},
          reason: 'Пётр — по входящему остатку');
      for (final e in [...sept.values, ...oct.values]) {
        expect(e['up_to_date'], isTrue, reason: '${e['full_name']}');
      }
      expect(sept[ivan]['saved']['total_salary'], 5650.0);
      expect(oct[ivan]['saved']['total_salary'], 1800.0);
      expect(await auditCount('payroll_auto_save'), 4);

      final pulled = await autoSync.pull(accountant,
          cursor: start.cursor, epoch: start.epoch);
      final results =
          pulled.changes.where((c) => c.table == 'payroll_results').toList();
      expect(results, hasLength(4));
      expect(results.every((c) => c.editedBy == 'server'), isTrue);

      // Повтор той же пачки — дубликаты, расчёты не переписываются.
      await autoSync.push(accountant, 'pc-1', [
        for (final c in pulled.changes)
          if (c.table != 'payroll_results') c.toJson(),
      ]);
      expect(await auditCount('payroll_auto_save'), 4);
    }, skip: mysqlSkip);

    test('правка в сентябре обновляет сентябрь и остаток октября', () async {
      await seed(auto: true);
      final petrSept = (await month(9))[petr]['saved'];
      await push(auto: true, [day(ivan, '2026-09-22')]); // +1800 поле
      final sept = await month(9);
      expect(sept[ivan]['saved']['total_salary'], 7450.0);
      expect(sept[petr]['saved']['updated_at'], petrSept['updated_at'],
          reason: 'расчёт Петра не менялся — не переписан');
      final (_, oct) = await call('GET', '/payroll?year=2026&month=10');
      // 7450 − выплачено до 01.10 1000.
      expect(oct['starting_balances'][ivan], 6450.0);
      expect((await month(10))[ivan]['up_to_date'], isTrue);
    }, skip: mysqlSkip);

    test('перенос дня между месяцами пересчитывает оба', () async {
      await seed(auto: true);
      final octDay = await testDb.db.execute(
          "SELECT uuid FROM timesheet WHERE date = '2026-10-01'");
      final moved = await current('timesheet', octDay.rows.single.textOf('uuid'));
      await push(auto: true, [
        SyncChange(
            table: 'timesheet',
            uuid: moved.uuid,
            updatedAt: DateTime.now().toUtc(),
            deleted: false,
            data: {...moved.data, 'date': '2026-09-25'}),
      ]);
      expect((await month(9))[ivan]['saved']['total_salary'], 5650.0 + 1800);
      final oct = await month(10);
      expect(oct[ivan]['calculation']['total_salary'], 0.0);
      expect(oct[ivan]['up_to_date'], isTrue);
      expect(oct[ivan]['saved']['total_salary'], 0.0,
          reason: 'в октябре у Ивана выплата — строка остаётся');
    }, skip: mysqlSkip);

    test('удалили все дни месяца — расчёт месяца удаляется', () async {
      await seed(auto: true);
      final petrDays = await testDb.db.execute(
          'SELECT uuid FROM timesheet WHERE employee_uuid = :e', {'e': petr});
      await push(auto: true, [
        for (final r in petrDays.rows)
          SyncChange(
              table: 'timesheet',
              uuid: r.textOf('uuid'),
              updatedAt: DateTime.now().toUtc(),
              deleted: true,
              data: (await current('timesheet', r.textOf('uuid'))).data),
      ]);
      expect((await month(9)).keys, isNot(contains(petr)));
      expect((await month(10)).keys, isNot(contains(petr)));
      expect(await auditCount('payroll_auto_delete'), 2);
    }, skip: mysqlSkip);

    test('устаревший расчёт от старого клиента исправляется тем же приёмом',
        () async {
      await seed(auto: true);
      final saved = (await month(9))[ivan]['saved'];
      // Часы клиента спешат на 2 минуты — версия сервера всё равно новее.
      final clientStamp = DateTime.now().toUtc().add(const Duration(minutes: 2));
      final results = await autoSync.push(accountant, 'pc-1', [
        SyncChange(
          table: 'payroll_results',
          uuid: saved['uuid'],
          updatedAt: clientStamp,
          deleted: false,
          data: {
            for (final e in (saved as Map<String, dynamic>).entries)
              if (e.key != 'uuid' && e.key != 'updated_at') e.key: e.value,
            'total_salary': 1.0,
          },
        ).toJson(),
      ]);
      expect(results.single.status, 'applied');
      final after = await current('payroll_results', saved['uuid']);
      expect(after.data['total_salary'], 5650.0);
      expect(after.updatedAt.isAfter(clientStamp), isTrue);
      expect(after.editedBy, 'server');
    }, skip: mysqlSkip);

    test('закрытый месяц не пересчитывается; после открытия — пересчитан',
        () async {
      await seed(); // без пересчёта: сохранённых расчётов нет
      // Закрыт без пересчёта (как до 0.4.0) — зафиксированного расчёта нет.
      var (s, json) = await call('POST', '/periods/locks',
          body: {'year': 2026, 'month': 9});
      expect(s, 201, reason: '$json');
      // Правка сотрудника задевает все месяцы.
      await push(auto: true, [
        SyncChange(
            table: 'employees',
            uuid: petr,
            updatedAt: DateTime.now().toUtc(),
            deleted: false,
            data: employee(petr, 'Петров Пётр Петрович').data),
      ]);
      final sept = await month(9);
      expect(sept.values.every((e) => e['saved'] == null), isTrue,
          reason: 'сентябрь закрыт — не трогается');
      final oct = await month(10);
      expect(oct[ivan]['up_to_date'], isTrue);
      expect(oct[ivan]['starting_balance'], -1000.0,
          reason: 'за закрытый сентябрь ничего не зафиксировано');

      (s, _) = await call('DELETE', '/periods/locks/2026/9',
          auto: true, role: Role.admin);
      expect(s, 200);
      expect((await month(9))[ivan]['saved']['total_salary'], 5650.0);
      expect((await month(10))[ivan]['starting_balance'], 4650.0);
    }, skip: mysqlSkip);

    test('закрытие сначала пересчитывает месяц — фиксируется свежий расчёт',
        () async {
      await seed(); // без пересчёта: расчёт сентября не сохранён
      final (s, json) = await call('POST', '/periods/locks',
          body: {'year': 2026, 'month': 9}, auto: true);
      expect(s, 201, reason: '$json');
      final sept = await month(9);
      expect(sept[ivan]['saved']['total_salary'], 5650.0);
      expect(sept.values.every((e) => e['up_to_date'] == true), isTrue);
    }, skip: mysqlSkip);

    test('полный пересчёт при запуске: только расхождения', () async {
      await seed();
      final payroll = PayrollCalculator(db: testDb.db);
      Future<int> run() => testDb.db.transaction((conn) async {
            await const ChangeLog().lock(conn.execute);
            return payroll.recalculateOpenMonths(conn.execute);
          });
      expect(await run(), 4);
      expect(await run(), 0);
      expect(await payroll.dataMonths(testDb.db.execute),
          (first: 2026 * 12 + 8, last: 2026 * 12 + 9));
    }, skip: mysqlSkip);
  });

  group('журнал действий (6.7)', () {
    Future<(int, dynamic)> audit(String query, {Role role = Role.admin}) =>
        call('GET', '/audit$query', role: role);

    test('отбор по сотруднику и виду, постранично, только админ', () async {
      await seed();
      await call('POST', '/periods/locks',
          body: {'year': 2026, 'month': 8, 'note': 'сдан'});

      var (s, json) = await audit('');
      expect(s, 200, reason: '$json');
      final all = json['entries'] as List;
      expect(all.first['action'], 'period_lock', reason: 'новые сверху');
      expect(all.first['user_name'], 'Пользователь accountant');
      expect(all.first['new']['note'], 'сдан');

      // Иван: сотрудник, 2 ставки, 10 дней табеля, 2 выплаты.
      (s, json) = await audit('?employee_uuid=$ivan&limit=200');
      final ivans = json['entries'] as List;
      expect(ivans, hasLength(15));
      expect(ivans.every((e) => e['employee_uuid'] == ivan), isTrue);
      expect(ivans.every((e) => e['employee_name'] == 'Иванов Иван'), isTrue);
      final day = ivans.firstWhere((e) =>
          e['entity'] == 'timesheet' && e['new']['date'] == '2026-09-02');
      expect(day['action'], 'sync_insert');
      expect(day['old'], isNull);
      expect((day['new']['work_place'], day['device_id']), ('base', 'pc-1'));

      (s, json) = await audit('?employee_uuid=$ivan&kind=payments');
      expect([for (final e in json['entries']) e['new']['amount']],
          unorderedEquals([1000.0, 2000.0]));
      (s, json) = await audit('?kind=periods');
      expect([for (final e in json['entries']) e['action']], ['period_lock']);
      (s, json) = await audit('?kind=access');
      expect({for (final e in json['entries']) e['action']}, contains('login'));

      // Постранично: по 5, без повторов и пропусков.
      final ids = <int>[];
      int? before;
      do {
        (s, json) = await audit(
            '?employee_uuid=$ivan&limit=5${before == null ? '' : '&before=$before'}');
        ids.addAll([for (final e in json['entries']) e['id'] as int]);
        before = json['next_before'] as int?;
      } while (before != null);
      expect(ids, [for (final e in ivans) e['id']]);

      // По времени: будущее — пусто.
      final later = DateTime.now().toUtc().add(const Duration(hours: 1));
      (s, json) = await audit('?since=${later.toIso8601String()}');
      expect(json['entries'], isEmpty);

      (s, json) = await audit('', role: Role.accountant);
      expect(s, 403);
      (s, _) = await audit('?kind=nothing');
      expect(s, 400);
      (s, _) = await audit('?since=2026-09-01');
      expect(s, 400, reason: 'нужен момент UTC с Z');
    }, skip: mysqlSkip);
  });

  group('чтение', () {
    test('сотрудники: все и работающие на дату; оператору — без ставок',
        () async {
      await seed();
      var (s, json) = await call('GET', '/employees');
      expect(s, 200);
      expect([for (final e in json['employees']) e['full_name']],
          ['Иванов Иван', 'Ольгина Ольга', 'Петров Пётр']);
      expect(json['employees'].first['base_rate'], 777.0);
      (s, json) = await call('GET', '/employees?active_on=2026-09-01');
      expect(json['employees'], hasLength(2));
      (s, json) = await call('GET', '/employees', role: Role.operator);
      expect(s, 200);
      expect(json['employees'].first['base_rate'], 0.0);
      expect(json['employees'].first['field_rate'], 0.0);
    }, skip: mysqlSkip);

    test('табель за месяц без удалённых, по сотруднику', () async {
      await seed();
      var (s, json) = await call('GET', '/timesheet?year=2026&month=9',
          role: Role.operator);
      expect(s, 200);
      expect(json['timesheet'], hasLength(10),
          reason: '8 дней Ивана (удалённый и октябрьский не в счёт) и 2 Петра');
      (s, json) = await call('GET',
          '/timesheet?year=2026&month=9&employee_uuid=$petr');
      expect([for (final d in json['timesheet']) d['date']],
          ['2026-09-01', '2026-09-10']);
    }, skip: mysqlSkip);

    test('ставки, выплаты, реквизиты — только бухгалтер и админ', () async {
      await seed();
      var (s, json) = await call('GET', '/rates?employee_uuid=$petr');
      expect(s, 200);
      expect(json['rates'], hasLength(1), reason: 'удалённая не видна');
      (s, json) = await call('GET', '/payments?from=2026-09-01&to=2026-09-30');
      expect([for (final p in json['payments']) p['amount']], [1000.0]);
      (s, json) = await call('GET', '/settings', role: Role.admin);
      expect((s, json['settings']), (200, null));
      for (final path in ['/rates', '/payments', '/settings']) {
        (s, _) = await call('GET', path, role: Role.operator);
        expect(s, 403, reason: path);
      }
      (s, _) = await call('GET', '/payments?from=01.09.2026');
      expect(s, 400);
      (s, _) = await call('GET', '/rates?employee_uuid=abc');
      expect(s, 400);
    }, skip: mysqlSkip);
  });
}
