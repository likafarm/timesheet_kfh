@Tags(['mysql'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
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
  final LocalDatabase db;
  late final DriftRepositories repo = DriftRepositories(db);
  late final LocalSyncStore store = LocalSyncStore(db);
  final _InProcessClient http;
  late final KfhApiClient api;
  late final SyncEngine engine;
  late final SyncBootstrap bootstrap;
  final journal = MemorySyncJournal();
  var backups = 0;

  _Pc(shelf.Handler handler, [LocalDatabase? db])
    : db = db ?? LocalDatabase.memory(),
      http = _InProcessClient(handler);

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
    bootstrap = SyncBootstrap(
      store: store,
      api: api,
      transport: HttpSyncTransport(api),
      engine: engine,
      server: 'http://localhost',
    );
  }

  /// Первый вход: анализ и выполнение (с «резервной копией»).
  Future<(BootstrapPlan, SyncReport)> firstSignIn() async {
    final plan = await bootstrap.analyze((await api.currentUser())!);
    final report = await bootstrap.execute(plan, backup: () async => backups++);
    return (plan, report);
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
      dataApi: DataApi(
        db: testDb.db,
        auth: authApi,
        periods: periods,
        payroll: PayrollCalculator(db: testDb.db),
      ),
      adminApi: AdminApi(
        ImportService(
          db: testDb.db,
          payroll: PayrollCalculator(db: testDb.db),
          logger: logger,
        ),
        authApi,
      ),
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

  group('синхронизация', () {
    // Первый ПК выгрузил свою базу (настройки хозяйства), второй — пустой;
    // оба привязаны.
    setUp(() async {
      if (!mysqlEnabled) return;
      await pc1.sync();
      await pc2.store.markAllSynced();
    });

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

    test(
      'закрытый месяц: отказ сервера; после открытия правка уходит',
      () async {
        final emp = await pc1.addEmployee('Иванов Иван');
        await pc1.sync();
        await periods.lock(accountant, 2026, 8, 'сдан');
      // Клиент видит список закрытых месяцев (для отметок в интерфейсе).
      expect(await pc1.api.lockedMonths(), [(2026, 8)]);

        await pc1.addWork(emp, DateTime(2026, 8, 3));
        final report = await pc1.sync();
        expect(report.rejected, 1);
        expect(report.pendingLeft, 1);
        expect(pc1.journal.entries.single.code, 'period_locked');
        expect(pc1.journal.entries.single.message, contains('08.2026'));
        expect(await serverCount('timesheet'), 0);

        await periods.unlock(accountant, '2026', '8');
      expect(await pc1.api.lockedMonths(), isEmpty);
        final retry = await pc1.sync(retryRejected: true);
        expect(retry.pushed, 1);
        expect(await serverCount('timesheet'), 1);
      },
    );

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
  }, skip: mysqlSkip);

  group('первый вход', () {
    test('пустой сервер: база ПК выгружается, всё сходится', () async {
      final emp = await pc1.addEmployee('Иванов Иван');
      await pc1.addWork(emp, sep1);
      await pc1.addWork(emp, DateTime(2026, 9, 2), days: 0.5);
      final other = await pc1.addEmployee('Петров Пётр');
      await pc1.repo.employees.delete(other);

      final (plan, report) = await pc1.firstSignIn();
      expect(plan.kind, BootstrapKind.upload);
      expect(plan.localRows, 4);
      expect(plan.serverRows, 0);
      expect(pc1.backups, 1);
      expect(report.pushed, 0, reason: 'сервер уже всё знает после импорта');
      expect(report.duplicates, 5, reason: '4 записи и настройки');
      expect(report.lost + report.rejected + report.received, 0);
      expect(report.pendingLeft, 0);
      expect(await pc1.bootstrap.isLinked(), isTrue);
      expect(await serverCount('timesheet'), 2);
      expect(await serverCount('employees'), 1);

      // Дальше — обычная синхронизация.
      final rec = (await pc1.repo.timesheet.on(emp, sep1))!;
      await pc1.repo.timesheet.update(rec.copyWith(days: 0.5));
      expect((await pc1.sync()).pushed, 1);
    });

    test('бухгалтер не выгружает базу на пустой сервер', () async {
      await pc2.addEmployee('Петров Пётр');
      final plan = await pc2.bootstrap.analyze((await pc2.api.currentUser())!);
      expect(plan.kind, BootstrapKind.upload);
      expect(plan.allowed, isFalse);
      expect(plan.refusal, contains('администратор'));
      await expectLater(
        pc2.bootstrap.execute(plan, backup: () async => pc2.backups++),
        throwsStateError,
      );
      expect(pc2.backups, 0);
      expect(await serverCount('employees'), 0);
    });

    test(
      'пустой ПК: всё принимается с сервера, настройки — серверные',
      () async {
        await pc1.db.settingsDao.updateSettings(
          const CompanySettingsCompanion(companyName: Value('КФХ Иванова')),
        );
        final emp = await pc1.addEmployee('Иванов Иван');
        await pc1.addWork(emp, sep1);
        await pc1.firstSignIn();

        final (plan, report) = await pc2.firstSignIn();
        expect(plan.kind, BootstrapKind.download);
        expect(plan.serverRows, 2);
        expect(report.pushed, 0);
        expect(report.pendingLeft, 0);
        expect((await pc2.repo.settings.get()).companyName, 'КФХ Иванова');
        expect((await pc2.repo.timesheet.on(emp, sep1))!.days, 1);
        final r = await testDb.db.execute(
          'SELECT company_name FROM company_settings',
        );
        expect(r.rows.single.text('company_name'), 'КФХ Иванова');
      },
    );

    test('привязка ПК, чья база уже импортирована на сервер', () async {
      // Как у владельца: база ПК выгружена на сервер отдельно (импорт),
      // потом на ПК продолжали работать, а на сервере — другой ПК.
      final emp = await pc1.addEmployee('Иванов Иван');
      await pc1.addWork(emp, sep1);
      final early = await buildSyncExport(pc1.db);
      await pc1.api.postJson('/admin/import', early.toJson());

      final (_, downloaded) = await pc2.firstSignIn();
      expect(downloaded.received, greaterThanOrEqualTo(2));
      final onServer = (await pc2.repo.timesheet.on(emp, sep1))!;
      await pc2.repo.timesheet.update(onServer.copyWith(days: 0.5));
      await pc2.addWork(emp, DateTime(2026, 9, 3));
      await pc2.sync();

      await pc1.addWork(emp, DateTime(2026, 9, 2));
      final (plan, report) = await pc1.firstSignIn();
      expect(plan.kind, BootstrapKind.link);
      expect(plan.commonRows, 2);
      expect(plan.onlyLocal, 1);
      expect(plan.onlyServer, 1);
      expect(plan.description, contains('общих записей — 2'));
      expect(report.pushed, 1);
      // День 1-го на этом ПК не меняли после импорта, но после привязки он
      // «не отправлен» и уступает серверной правке — в журнале без упрёка.
      expect(report.lost, 1);
      final entry = pc1.journal.entries.single;
      expect(entry.kind, JournalKind.lost);
      expect(entry.message, contains('при привязке'));
      expect(report.pendingLeft, 0);
      expect((await pc1.repo.timesheet.on(emp, sep1))!.days, 0.5);
      expect(await pc1.repo.timesheet.on(emp, DateTime(2026, 9, 3)), isNotNull);
      expect(await serverCount('timesheet'), 3);

      await pc2.sync();
      expect(await pc2.repo.timesheet.on(emp, DateTime(2026, 9, 2)), isNotNull);
    });

    test('разные базы не смешиваются', () async {
      await pc1.addEmployee('Иванов Иван');
      await pc1.firstSignIn();
      await pc2.addEmployee('Сидоров Сидор');
      final plan = await pc2.bootstrap.analyze((await pc2.api.currentUser())!);
      expect(plan.kind, BootstrapKind.foreign);
      expect(plan.allowed, isFalse);
      expect(plan.refusal, contains('разные базы'));
      expect(
        await pc2.store.pendingCount(),
        2,
        reason: 'анализ ничего не меняет',
      );
    });

    test('прерванный первый вход повторяется без потерь', () async {
      final emp = await pc1.addEmployee('Иванов Иван');
      await pc1.addWork(emp, sep1);
      await pc1.firstSignIn();

      final plan = await pc2.bootstrap.analyze((await pc2.api.currentUser())!);
      expect(plan.kind, BootstrapKind.download);
      pc2.http.online = false; // связь пропала посреди первого входа
      await expectLater(
        pc2.bootstrap.execute(plan, backup: () async => pc2.backups++),
        throwsA(isA<NetworkFailure>()),
      );
      expect(await pc2.bootstrap.isLinked(), isFalse);

      pc2.http.online = true;
      final (again, report) = await pc2.firstSignIn();
      expect(again.kind, BootstrapKind.download);
      expect(pc2.backups, 2);
      expect(report.pendingLeft, 0);
      expect(await pc2.bootstrap.isLinked(), isTrue);
      expect((await pc2.repo.timesheet.on(emp, sep1))!.days, 1);
    });
  }, skip: mysqlSkip);

  // Приёмка на копии настоящей базы: KFH_ACCEPTANCE_DB — путь к копии
  // базы v2 (например, Документыackups\daily_…db). Файл не меняется:
  // тест работает с его копией во временной папке.
  final acceptanceDb = Platform.environment['KFH_ACCEPTANCE_DB'];
  group('приёмка на копии реальной базы', () {
    late Directory temp;
    late _Pc real;

    setUp(() async {
      if (!mysqlEnabled || acceptanceDb == null) return;
      temp = await Directory.systemTemp.createTemp('kfh_link');
      final copy = await File(acceptanceDb).copy('${temp.path}/copy.db');
      real = _Pc(handler, LocalDatabase.file(copy));
      await real.signIn('admin', 'admin-pass-1');
    });

    tearDown(() async {
      if (!mysqlEnabled || acceptanceDb == null) return;
      await real.db.close();
      await temp.delete(recursive: true);
    });

    test('база, импортированная на сервер, привязывается без потерь, второй ПК '
        'получает её целиком', () async {
      final before = await readAllSyncRows(real.db);
      // Как на этапе 2: выгрузка → /admin/import отдельно от привязки.
      final export = await buildSyncExport(real.db);
      await real.api.postJson('/admin/import', export.toJson());

      final (plan, report) = await real.firstSignIn();
      expect(plan.kind, BootstrapKind.link);
      expect(plan.onlyLocal, 0);
      expect(plan.onlyServer, 0);
      expect(plan.commonRows, plan.localRows);
      expect(report.pushed + report.rejected + report.lost, 0);
      expect(report.duplicates, before.length);
      expect(report.pendingLeft, 0);
      expect(real.journal.entries, isEmpty);

      // Данные ПК не изменились (кроме отметки «кто менял» у записей, где
      // её не было).
      final after = await readAllSyncRows(real.db);
      expect(_versions(after), _versions(before));

      final (down, received) = await pc2.firstSignIn();
      expect(down.kind, BootstrapKind.download);
      expect(received.pendingLeft, 0);
      expect(_versions(await readAllSyncRows(pc2.db)), _versions(before));

      // Расчёт ЗП на втором ПК — тот же, что на первом.
      for (final c in export.payroll.take(200)) {
        final mine = await pc2.repo.payrollService.calculateMonth(
          c.employeeUuid,
          c.year,
          c.month,
        );
        expect(mine.totalSalary, closeTo(c.totalSalary, 0.005));
      }
      print(
        'Приёмка: ${before.length} записей, '
        '${export.payroll.length} проверок расчёта',
      );
    }, skip: acceptanceDb == null ? 'нет KFH_ACCEPTANCE_DB' : null);
  });
}

/// Версии записей для сравнения: таблица, uuid, время, удаление, данные.
Set<String> _versions(List<SyncChange> rows) => {
  for (final r in rows)
    jsonEncode([
      r.table,
      r.uuid,
      formatSyncTimestamp(r.updatedAt),
      r.deleted,
      r.data,
    ]),
};
