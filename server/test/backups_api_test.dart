@Tags(['mysql'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_server/kfh_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support/mysql.dart';

/// Выгрузки сервера для модуля «Резервные копии»: снимок всех записей и
/// выдача зашифрованных файлов администратору.
void main() {
  late TestDatabase testDb;
  late Directory dir;
  late Handler handler;
  late SyncService sync;
  late User admin;
  late Map<Role, String> tokens;

  setUp(() async {
    if (!mysqlEnabled) return;
    testDb = await TestDatabase.create(maxConnections: 4);
    dir = await Directory.systemTemp.createTemp('kfh_backups_');
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
      backupsApi: BackupsApi(dir: dir.path, db: testDb.db, auth: authApi),
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
        role: Role.accountant.name,
        password: 'temp-pass-1',
        info: const RequestInfo());
    await auth.setPasswordFromConsole('buh', 'real-pass-1');
    tokens[Role.accountant] =
        (await auth.login('buh', 'real-pass-1', const RequestInfo()))
            .accessToken;
  });

  tearDown(() async {
    if (!mysqlEnabled) return;
    await testDb.dispose();
    await dir.delete(recursive: true);
  });

  Future<Response> get(String path, {Role role = Role.admin}) =>
      Future.sync(() => handler(Request(
            'GET',
            Uri.parse('http://localhost$path'),
            headers: {
              'authorization': 'Bearer ${tokens[role]}',
              'x-device-id': 'pc-1',
            },
          )));

  const first = 'kfh-20260929-003000.json.gz.age';
  const second = 'kfh-20260930-003000.json.gz.age';

  test('список — новые первыми, чужие файлы не показываются', () async {
    await File('${dir.path}/$first').writeAsBytes([1, 2, 3]);
    await File('${dir.path}/$second').writeAsBytes([1, 2, 3, 4, 5]);
    await File('${dir.path}/kfh.sql.gz').writeAsBytes([9]);
    final r = await get('/admin/backups');
    expect(r.statusCode, 200);
    expect(jsonDecode(await r.readAsString()), {
      'backups': [
        {'name': second, 'size': 5, 'created_at': '2026-09-30T00:30:00.000Z'},
        {'name': first, 'size': 3, 'created_at': '2026-09-29T00:30:00.000Z'},
      ],
    });
  }, skip: mysqlSkip);

  test('скачивание — файл как есть и запись в журнале действий', () async {
    final bytes = List.generate(3000, (i) => i % 251);
    await File('${dir.path}/$first').writeAsBytes(bytes);
    final r = await get('/admin/backups/$first');
    expect(r.statusCode, 200);
    expect(r.headers['content-type'], 'application/octet-stream');
    expect(await r.read().expand((c) => c).toList(), bytes);
    final audit = await testDb.db.execute(
        "SELECT user_uuid, new_value FROM audit_log "
        "WHERE action = 'backup_download'");
    expect(audit.rows.single.textOf('user_uuid'), admin.uuid);
    expect(audit.rows.single.textOf('new_value'), contains(first));
  }, skip: mysqlSkip);

  test('нет файла, чужое имя, путь наружу — 404', () async {
    await File('${dir.path}/kfh.sql.gz').writeAsBytes([9]);
    for (final name in [second, 'kfh.sql.gz', '..%2F$first', 'x']) {
      final r = await get('/admin/backups/$name');
      expect(r.statusCode, 404, reason: name);
    }
  }, skip: mysqlSkip);

  test('бухгалтеру — отказ', () async {
    await File('${dir.path}/$first').writeAsBytes([1]);
    for (final path in ['/admin/backups', '/admin/backups/$first']) {
      final r = await get(path, role: Role.accountant);
      expect(r.statusCode, 403, reason: path);
      expect(jsonDecode(await r.readAsString())['error']['code'], 'forbidden');
    }
  }, skip: mysqlSkip);

  test('снимок: все записи, и удалённые; читается программой', () async {
    const emp = '01900000-0000-7000-8000-000000000001';
    const day = '01900000-0000-7000-8000-000000000002';
    const gone = '01900000-0000-7000-8000-000000000003';
    final stamp = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    SyncChange row(String table, String id, Map<String, Object?> data,
            {bool deleted = false}) =>
        SyncChange(
            table: table,
            uuid: id,
            updatedAt: stamp,
            deleted: deleted,
            data: data,
            changeId: id);
    Map<String, Object?> work(String date) => {
          'legacy_id': null,
          'employee_uuid': emp,
          'date': date,
          'day_type': 'work',
          'days': 1.0,
          'work_place': 'field',
          'notes': null,
          'created_at': '2026-09-01T10:00:00.123456',
        };
    final results = await sync.push(admin, 'pc-1', [
      row('employees', emp, {
        'legacy_id': null,
        'full_name': 'Иванов Иван',
        'position': 'Рабочий',
        'hire_date': '2026-01-01',
        'dismissal_date': null,
        'base_rate': 1000.0,
        'field_rate': 1500.0,
      }).toJson(),
      row('timesheet', day, work('2026-09-03')).toJson(),
      row('timesheet', gone, work('2026-09-04'), deleted: true).toJson(),
    ]);
    expect(results.map((r) => r.status), everyElement('applied'));

    final file = await exportSnapshot(testDb.db,
        now: DateTime.utc(2026, 9, 30, 0, 30));
    final back =
        SnapshotFile.fromJson(jsonDecode(jsonEncode(file.toJson())));
    expect(back.source, 'server $serverVersion');
    final snapshot = back.snapshot;
    expect(snapshot.live('employees', emp)!.data['full_name'], 'Иванов Иван');
    expect(snapshot.live('timesheet', day)!.data['work_place'], 'field');
    expect(snapshot.row('timesheet', gone)!.deleted, isTrue);
    expect(snapshot.counts['timesheet'], 1);
    // Строка настроек хозяйства создаётся миграцией — она тоже в снимке.
    expect(snapshot.counts['company_settings'], lessThanOrEqualTo(1));
  }, skip: mysqlSkip);
}
