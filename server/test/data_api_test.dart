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
      {Object? body, Role role = Role.accountant}) async {
    final response = await handler(Request(
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

  Future<void> push(List<SyncChange> changes) async {
    final results = await sync.push(
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
  /// - Ольга уволена 31.08 — расчёт есть, нулевой (как в приложении).
  Future<void> seed() async {
    await push([
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
      expect(byEmployee.keys.toSet(), {ivan, petr, olga});

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

      expect(byEmployee[olga]['calculation']['total_salary'], 0.0);
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
      expect((json['saved'], json['unchanged']), (3, 0));
      expect(json['employees'].every((e) => e['up_to_date'] == true), isTrue);

      (s, json) = await call('POST', '/payroll/calculate',
          body: {'year': 2026, 'month': 9});
      expect((json['saved'], json['unchanged']), (0, 3));

      // Результаты уходят клиентам через pull.
      final pulled = await sync.pull(accountant,
          cursor: start.cursor, epoch: start.epoch);
      expect(pulled.changes.map((c) => c.table).toSet(), {'payroll_results'});
      expect(pulled.changes, hasLength(3));
      expect(pulled.changes.first.editedBy, 'server');
      final audit = await testDb.db.execute(
          "SELECT COUNT(*) AS c FROM audit_log WHERE action = 'payroll_save'");
      expect(audit.rows.single.intOf('c'), 3);

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
      expect((json['saved'], json['unchanged']), (1, 2));
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
      expect(sept['results'], hasLength(3));
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

      (s, _) = await call('DELETE', '/periods/locks/2026/9');
      expect(s, 204);
      (s, _) = await call('DELETE', '/periods/locks/2026/9');
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
