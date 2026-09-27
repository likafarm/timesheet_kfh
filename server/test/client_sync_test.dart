@Tags(['mysql'])
library;

import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:http/http.dart' as http;
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_server/kfh_server.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

import 'support/mysql.dart';

/// HTTP-клиент, который отдаёт запросы обработчику сервера в этом же
/// процессе: клиент синхронизации проверяется по настоящему HTTP-слою и
/// MySQL, без сети. [online] = false — «нет сети».
class _InProcessClient extends http.BaseClient {
  final shelf.Handler handler;
  bool online = true;

  _InProcessClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!online) throw http.ClientException('нет сети', request.url);
    final body = await request.finalize().toBytes();
    final response = await handler(
      shelf.Request(
        request.method,
        request.url,
        body: body,
        headers: request.headers,
      ),
    );
    return http.StreamedResponse(
      response.read(),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

/// ПК: своя локальная база, вход на сервер, движок.
class _Pc {
  final LocalDatabase db = LocalDatabase.memory();
  late final DriftRepositories repo = DriftRepositories(db);
  late final LocalSyncStore store = LocalSyncStore(db);
  final _InProcessClient http;
  late final KfhApiClient api;
  late final SyncEngine engine;
  final journal = MemorySyncJournal();

  _Pc(shelf.Handler handler) : http = _InProcessClient(handler);

  Future<void> signIn(String login, String password) async {
    api = KfhApiClient(
      baseUrl: Uri.parse('http://localhost'),
      deviceId: await db.deviceId(),
      tokens: MemoryTokenStore(),
      client: http,
    );
    await api.login(login, password);
    engine = SyncEngine(
      store: store,
      transport: HttpSyncTransport(api),
      journal: journal,
      transientRetries: const [],
    );
  }

  Future<SyncReport> sync({bool retryRejected = false}) =>
      engine.run(retryRejected: retryRejected);

  Future<String> addEmployee(String name) => repo.employees.add(
    Employee(
      fullName: name,
      position: 'Рабочий',
      hireDate: DateTime(2025, 3, 1),
      baseRate: 1000,
      fieldRate: 1500,
    ),
  );

  Future<String> addWork(String employee, DateTime day, {double days = 1}) =>
      repo.timesheet.add(
        TimesheetRecord(
          employeeId: employee,
          date: day,
          dayType: 'work',
          days: days,
          workPlace: 'field',
        ),
      );
}

/// Сквозная проверка: движок клиента (`packages/sync`) ↔ API сервера на
/// MySQL стенда. Сценарии приёмки этапа 3 «два ПК» и «офлайн».
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late TestDatabase testDb;
  late shelf.Handler handler;
  late AuthService auth;
  late PeriodService periods;
  late User accountant;
  late _Pc pc1, pc2;
  final sep1 = DateTime(2026, 9, 1);

  setUp(() async {
    if (!mysqlEnabled) return;
    testDb = await TestDatabase.create(maxConnections: 6);
    final logger = Logger(write: (_) {});
    await MigrationRunner(testDb.db, logger).migrate(projectMigrations());
    auth = AuthService(
      db: testDb.db,
      accessTokens: AccessTokens(utf8.encode('k' * 32)),
      logger: logger,
      hasher: const PasswordHasher(memoryKiB: 1024, iterations: 1),
    );
    periods = PeriodService(db: testDb.db);
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
    await auth.createUser(
      admin,
      login: 'buh',
      fullName: 'Бухгалтер',
      role: 'accountant',
      password: 'temp-pass-1',
      info: const RequestInfo(),
    );
    await auth.setPasswordFromConsole('buh', 'real-pass-1');
    accountant = (await auth.login(
      'buh',
      'real-pass-1',
      const RequestInfo(),
    )).user;

    pc1 = _Pc(handler);
    pc2 = _Pc(handler);
    await pc1.signIn('admin', 'admin-pass-1');
    await pc2.signIn('buh', 'real-pass-1');
    // Первый ПК выгружает свою базу (настройки хозяйства), второй — пустой.
    await pc1.sync();
    await pc2.store.markAllSynced();
  });

  tearDown(() async {
    if (!mysqlEnabled) return;
    await pc1.db.close();
    await pc2.db.close();
    await testDb.dispose();
  });

  Future<int> serverCount(String table) async {
    final r = await testDb.db.execute(
      'SELECT COUNT(*) AS n FROM $table WHERE deleted = 0',
    );
    return int.parse(r.rows.first.text('n')!);
  }

  test('два ПК: ввод на первом появляется на втором, и наоборот', () async {
    final emp = await pc1.addEmployee('Иванов Иван');
    await pc1.addWork(emp, sep1);
    final r1 = await pc1.sync();
    expect(r1.pushed, 2);
    expect(r1.pendingLeft, 0);

    final r2 = await pc2.sync();
    expect(r2.received, greaterThanOrEqualTo(2));
    expect((await pc2.repo.timesheet.on(emp, sep1))!.days, 1);

    final rec = (await pc2.repo.timesheet.on(emp, sep1))!;
    await pc2.repo.timesheet.update(rec.copyWith(days: 0.5));
    await pc2.addWork(emp, DateTime(2026, 9, 2));
    await pc2.sync();
    await pc1.sync();
    expect((await pc1.repo.timesheet.on(emp, sep1))!.days, 0.5);
    expect(await pc1.repo.timesheet.on(emp, DateTime(2026, 9, 2)), isNotNull);

    // Повторные прогоны ничего не гоняют туда-обратно.
    final quiet = await pc1.sync();
    expect(quiet.pushed + quiet.received + quiet.lost, 0);
    expect(pc1.journal.entries, isEmpty);
    expect(pc2.journal.entries, isEmpty);
    expect(await serverCount('timesheet'), 2);

    // Кто менял — видно на сервере (id устройства).
    final r = await testDb.db.execute(
      'SELECT edited_by FROM timesheet WHERE uuid = :u',
      {'u': rec.id},
    );
    expect(r.rows.first.text('edited_by'), await pc2.db.deviceId());
  });

  test(
    'офлайн: ввод без сети уходит после подключения, дубликатов нет',
    () async {
      final emp = await pc1.addEmployee('Иванов Иван');
      await pc1.sync();

      pc1.http.online = false;
      for (var d = 1; d <= 3; d++) {
        await pc1.addWork(emp, DateTime(2026, 9, d));
      }
      await expectLater(pc1.sync(), throwsA(isA<NetworkFailure>()));
      expect(await pc1.store.pendingCount(), 3);

      pc1.http.online = true;
      final report = await pc1.sync();
      expect(report.pushed, 3);
      expect(report.pendingLeft, 0);
      expect(await serverCount('timesheet'), 3);

      await pc2.sync();
      expect(
        await pc2.repo.timesheet.inPeriod(sep1, DateTime(2026, 9, 30)),
        hasLength(3),
      );
    },
  );

  test(
    'один день на двух ПК офлайн: побеждает пришедший на сервер первым',
    () async {
      final emp = await pc1.addEmployee('Иванов Иван');
      await pc1.sync();
      await pc2.sync();

      final lost = await pc1.addWork(emp, sep1);
      final won = await pc2.addWork(emp, sep1, days: 0.5);
      await pc2.sync();
      final report = await pc1.sync();

      expect(report.lost, 1);
      expect(report.pendingLeft, 0);
      expect((await pc1.repo.timesheet.on(emp, sep1))!.id, won);
      final entry = pc1.journal.entries.single;
      expect(entry.kind, JournalKind.lostUnique);
      expect(entry.uuid, lost);
      expect(await serverCount('timesheet'), 1);
    },
  );

  test('закрытый месяц: отказ сервера; после открытия правка уходит', () async {
    final emp = await pc1.addEmployee('Иванов Иван');
    await pc1.sync();
    await periods.lock(accountant, 2026, 8, 'сдан');

    await pc1.addWork(emp, DateTime(2026, 8, 3));
    final report = await pc1.sync();
    expect(report.rejected, 1);
    expect(report.pendingLeft, 1);
    expect(pc1.journal.entries.single.code, 'period_locked');
    expect(pc1.journal.entries.single.message, contains('08.2026'));
    expect(await serverCount('timesheet'), 0);

    await periods.unlock(accountant, '2026', '8');
    final retry = await pc1.sync(retryRejected: true);
    expect(retry.pushed, 1);
    expect(await serverCount('timesheet'), 1);
  });

  test('сервер восстановлен из копии (новая эпоха): приём с нуля', () async {
    final emp = await pc1.addEmployee('Иванов Иван');
    await pc1.addWork(emp, sep1);
    await pc1.sync();
    await pc2.sync();
    await testDb.db.execute('UPDATE sync_serial SET epoch = UUID()');

    final report = await pc2.sync();
    expect(report.resynced, isTrue);
    expect(report.lost, 0);
    expect((await pc2.repo.timesheet.on(emp, sep1))!.days, 1);
    final quiet = await pc2.sync();
    expect(quiet.resynced, isFalse);
  });
}
