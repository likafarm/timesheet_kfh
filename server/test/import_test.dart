@Tags(['mysql'])
library;

import 'dart:convert';

import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_server/kfh_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support/mysql.dart';

/// Разовый перенос базы устройства на сервер: выгрузка настоящей локальной
/// базы (drift в памяти, репозитории приложения) → POST /admin/import.
void main() {
  late TestDatabase testDb;
  late Handler handler;
  late Map<Role, String> tokens;
  late User admin;
  late LocalDatabase local;
  late DriftRepositories repos;

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
    final payroll = PayrollCalculator(db: testDb.db);
    handler = buildHandler(
      db: testDb.db,
      logger: logger,
      authApi: authApi,
      syncApi: SyncApi(SyncService(db: testDb.db, logger: logger), authApi),
      adminApi: AdminApi(
          ImportService(db: testDb.db, payroll: payroll, logger: logger), authApi),
    );
    admin = await auth.createFirstAdmin(
        login: 'admin', fullName: 'Админ', password: 'admin-pass-1');
    tokens = {
      Role.admin: (await auth.login('admin', 'admin-pass-1', const RequestInfo()))
          .accessToken,
    };
    await auth.createUser(admin,
        login: 'buh',
        fullName: 'Бухгалтер',
        role: 'accountant',
        password: 'temp-pass-1',
        info: const RequestInfo());
    await auth.setPasswordFromConsole('buh', 'real-pass-1');
    tokens[Role.accountant] =
        (await auth.login('buh', 'real-pass-1', const RequestInfo())).accessToken;

    local = LocalDatabase.memory();
    repos = DriftRepositories(local);
  });

  tearDown(() async {
    if (!mysqlEnabled) return;
    await local.close();
    await testDb.dispose();
  });

  Future<(int, dynamic)> call(String method, String path,
      {Object? body, Role role = Role.admin}) async {
    final response = await handler(Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : (body is String ? body : jsonEncode(body)),
      headers: {'authorization': 'Bearer ${tokens[role]}', 'x-device-id': 'pc-1'},
    ));
    final text = await response.readAsString();
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  /// Хозяйство за июль–сентябрь 2026, как в приложении.
  Future<void> fillLocal() async {
    Future<String> employee(String name, {DateTime? dismissed}) =>
        repos.employees.add(Employee(
          fullName: name,
          position: 'Механизатор',
          hireDate: DateTime(2026, 1, 10),
          dismissalDate: dismissed,
          baseRate: 0,
          fieldRate: 0,
        ));
    final ivan = await employee('Иванов Иван «Старший»');
    final petr = await employee('Петров Пётр', dismissed: DateTime(2026, 8, 31));
    await repos.rates.add(EmployeeRate(
        employeeId: ivan, baseRate: 1234.56, fieldRate: 1777.77, startDate: DateTime(2026, 1, 1)));
    // Новая ставка с 16.09 закрывает прежнюю 15.09.
    await repos.rates.add(EmployeeRate(
        employeeId: ivan, baseRate: 1300, fieldRate: 1850.5, startDate: DateTime(2026, 9, 16)));
    await repos.rates.add(EmployeeRate(
        employeeId: petr, baseRate: 900, fieldRate: 1100, startDate: DateTime(2026, 7, 1)));
    for (final (emp, date, place, days) in [
      (ivan, DateTime(2026, 7, 31), 'field', 1.0),
      (ivan, DateTime(2026, 8, 1), 'base', 0.5),
      (ivan, DateTime(2026, 9, 15), 'field', 1.0),
      (ivan, DateTime(2026, 9, 16), 'field', 0.5),
      (petr, DateTime(2026, 8, 30), 'base', 1.0),
    ]) {
      await repos.timesheet.add(TimesheetRecord(
          employeeId: emp, date: date, dayType: 'work', days: days, workPlace: place,
          notes: 'Заметка: «кавычки» \\ и \' апостроф'));
    }
    await repos.timesheet.add(TimesheetRecord(
        employeeId: ivan, date: DateTime(2026, 9, 17), dayType: 'sick', days: 1));
    // Удалённый день — тоже переносится (с deleted).
    final wrong = await repos.timesheet.add(TimesheetRecord(
        employeeId: ivan, date: DateTime(2026, 9, 20), dayType: 'work', days: 1, workPlace: 'field'));
    await repos.timesheet.delete(wrong);
    await repos.payments.add(Payment(
        employeeId: ivan, paymentDate: DateTime(2026, 8, 5), amount: 1000.1, paymentType: 'advance'));
    await repos.payments.add(Payment(
        employeeId: petr, paymentDate: DateTime(2026, 9, 1), amount: 450));
    for (final m in [7, 8, 9]) {
      await repos.payrollService.saveMonth(2026, m);
    }
  }

  test('перенос со сверкой: все записи, расчёты и остатки сошлись', () async {
    await fillLocal();
    final export = await buildSyncExport(local);
    expect(export.counts['timesheet'], (7, 1));
    expect(export.payroll.map((c) => (c.year, c.month)).toSet(),
        {(2026, 7), (2026, 8), (2026, 9)});

    final (s, json) = await call('POST', '/admin/import', body: export.toJson());
    expect(s, 200, reason: '$json');
    expect(json['ok'], isTrue);
    expect(json['rows'], export.rows.length);
    expect(json['months'], ['07.2026', '08.2026', '09.2026']);

    // Бухгалтер получает всё обычным pull — с теми же uuid, данными и
    // edited_by устройства.
    final (ps, pulled) = await call('GET', '/sync/pull?cursor=0&limit=1000',
        role: Role.accountant);
    expect(ps, 200);
    final changes = [for (final c in pulled['changes']) SyncChange.fromJson(c)];
    expect(changes, hasLength(export.rows.length));
    final byUuid = {for (final r in export.rows) r.uuid: r};
    final deviceId = await local.deviceId();
    for (final c in changes) {
      final want = byUuid[c.uuid]!;
      expect(c.data, want.data, reason: c.uuid);
      expect(c.updatedAt, want.updatedAt);
      expect(c.deleted, want.deleted);
      expect(c.editedBy, deviceId);
    }
    final audit = await testDb.db.execute(
        "SELECT user_uuid FROM audit_log WHERE action = 'import'");
    expect(audit.rows.single.textOf('user_uuid'), admin.uuid);
  }, skip: mysqlSkip);

  test('второй импорт — 409 not_empty, данные не задеты', () async {
    await fillLocal();
    final export = await buildSyncExport(local);
    expect((await call('POST', '/admin/import', body: export.toJson())).$1, 200);
    final (s, json) = await call('POST', '/admin/import', body: export.toJson());
    expect((s, json['error']['code']), (409, 'not_empty'));
    expect(json['error']['details'], isNotEmpty);
    final r = await testDb.db.execute('SELECT COUNT(*) AS n FROM employees');
    expect(r.rows.single.intOf('n'), 2);
  }, skip: mysqlSkip);

  test('контроль не сошёлся — 422, ничего не записано', () async {
    await fillLocal();
    final json = (await buildSyncExport(local)).toJson();
    // Подменяем начисление в контроле за сентябрь.
    final checks = json['payroll'] as List;
    final sept = checks.cast<Map<String, Object?>>().firstWhere(
        (c) => c['month'] == 9 && (c['total_salary'] as num) > 0);
    sept['total_salary'] = (sept['total_salary'] as num) + 0.01;
    final (s, body) = await call('POST', '/admin/import', body: json);
    expect((s, body['error']['code']), (422, 'verification_failed'));
    expect((body['error']['details'] as List).single, contains('начислено'));
    for (final t in syncTables) {
      final r = await testDb.db.execute('SELECT COUNT(*) AS n FROM ${t.name}');
      expect(r.rows.single.intOf('n'), 0, reason: t.name);
    }
    final log = await testDb.db.execute('SELECT COUNT(*) AS n FROM change_log');
    expect(log.rows.single.intOf('n'), 0);
  }, skip: mysqlSkip);

  test('расхождение на копейку в остатке тоже ловится', () async {
    await fillLocal();
    final json = (await buildSyncExport(local)).toJson();
    final check = (json['payroll'] as List).cast<Map<String, Object?>>().firstWhere(
        (c) => c['month'] == 9 && (c['starting_balance'] as num) != 0);
    check['starting_balance'] = (check['starting_balance'] as num) - 0.01;
    final (s, body) = await call('POST', '/admin/import', body: json);
    expect(s, 422);
    expect(body['error']['details'].single, contains('остаток'));
  }, skip: mysqlSkip);

  test('испорченная выгрузка — 400 со всеми ошибками сразу', () async {
    await fillLocal();
    final json = (await buildSyncExport(local)).toJson();
    final rows = (json['rows'] as List).cast<Map<String, Object?>>();
    (rows.firstWhere((r) => r['table'] == 'timesheet')['data'] as Map)['date'] =
        '2026-02-30';
    (rows.firstWhere((r) => r['table'] == 'payments')['data'] as Map)['amount'] =
        'много';
    final (s, body) = await call('POST', '/admin/import', body: json);
    expect((s, body['error']['code']), (400, 'invalid_export'));
    expect(body['error']['details'], hasLength(2));

    // Записи верные, но counts им противоречат.
    final fresh = (await buildSyncExport(local)).toJson();
    final (s2, body2) = await call('POST', '/admin/import', body: {
      ...fresh,
      'counts': {
        ...(fresh['counts'] as Map),
        'employees': {'total': 5, 'deleted': 0},
      },
    });
    expect((s2, body2['error']['code']), (400, 'invalid_export'));
    expect(body2['error']['details'].single, contains('employees'));

    final (s3, _) = await call('POST', '/admin/import', body: {'format': 'другое'});
    expect(s3, 400);
  }, skip: mysqlSkip);

  test('не админ — 403', () async {
    await fillLocal();
    final (s, _) = await call('POST', '/admin/import',
        body: (await buildSyncExport(local)).toJson(), role: Role.accountant);
    expect(s, 403);
  }, skip: mysqlSkip);
}
