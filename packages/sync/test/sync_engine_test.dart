import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:test/test.dart';

import 'support/fake_server.dart';

/// ПК с локальной базой и движком синхронизации.
class Pc {
  final String name;
  DateTime now;
  late final LocalDatabase db;
  late final DriftRepositories repo;
  late final LocalSyncStore store;
  late final SyncEngine engine;
  final journal = MemorySyncJournal();
  final sleeps = <Duration>[];

  Pc(this.name, FakeSyncServer server, this.now, {int pullLimit = 500}) {
    db = LocalDatabase.memory(clock: () => now);
    repo = DriftRepositories(db);
    store = LocalSyncStore(db);
    engine = SyncEngine(
      store: store,
      transport: server.client(db.deviceId),
      journal: journal,
      pullLimit: pullLimit,
      sleep: (d) async => sleeps.add(d),
      now: () => now,
    );
  }

  void tick([Duration by = const Duration(minutes: 1)]) => now = now.add(by);

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

  Future<TimesheetRecord?> dayOf(String employee, DateTime day) =>
      repo.timesheet.on(employee, day);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeSyncServer server;
  late Pc a, b;
  final sep1 = DateTime(2026, 9, 1);

  setUp(() async {
    server = FakeSyncServer();
    a = Pc('pc-a', server, DateTime.utc(2026, 9, 27, 10));
    b = Pc('pc-b', server, DateTime.utc(2026, 9, 27, 10, 0, 7));
    // Первый ПК выгрузил свои данные (настройки хозяйства), второй — пустой:
    // его настройки по умолчанию уступают серверным (как при первом входе).
    await a.sync();
    await b.store.markAllSynced();
  });
  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  test('два ПК: ввод на одном появляется на другом, и наоборот', () async {
    final emp = await a.addEmployee('Иванов Иван');
    await a.addWork(emp, sep1);
    final ra = await a.sync();
    expect(ra.pushed, 2);
    expect(ra.pendingLeft, 0);

    final rb = await b.sync();
    expect(rb.received, 3, reason: 'настройки хозяйства, сотрудник, день');
    expect(rb.changedLocalData, isTrue);
    expect((await b.dayOf(emp, sep1))!.days, 1);

    b.tick();
    final rec = (await b.dayOf(emp, sep1))!;
    await b.repo.timesheet.update(rec.copyWith(days: 0.5));
    await b.sync();
    await a.sync();
    expect((await a.dayOf(emp, sep1))!.days, 0.5);
    expect(a.journal.entries, isEmpty);
    expect(b.journal.entries, isEmpty);
  });

  test('собственные изменения, пришедшие обратно, ничего не меняют', () async {
    final emp = await a.addEmployee('Иванов Иван');
    await a.sync();
    final again = await a.sync();
    expect(again.pushed, 0);
    expect(again.lost, 0);
    expect(again.pendingLeft, 0);
    expect((await a.repo.employees.byId(emp))!.fullName, 'Иванов Иван');
  });

  test(
    'офлайн: ввод без сети уходит после подключения, без дубликатов',
    () async {
      server.offline = true;
      final emp = await a.addEmployee('Иванов Иван');
      await a.addWork(emp, sep1);
      await expectLater(a.sync(), throwsA(isA<NetworkFailure>()));
      expect(a.sleeps, const [Duration(seconds: 2), Duration(seconds: 5)]);
      expect(await a.store.pendingCount(), 2);

      // Ещё и ещё правки офлайн.
      a.tick();
      await a.addWork(emp, DateTime(2026, 9, 2), days: 0.5);
      await expectLater(a.sync(), throwsA(isA<NetworkFailure>()));

      server.offline = false;
      final report = await a.sync();
      expect(report.pushed, 3);
      expect(report.pendingLeft, 0);
      expect(server.rows('timesheet'), hasLength(2));
      expect(server.rows('employees'), hasLength(1));
    },
  );

  test('обрыв после приёма пачки сервером: повтор — duplicate', () async {
    final emp = await a.addEmployee('Иванов Иван');
    await a.addWork(emp, sep1);
    server.loseNextPushResponse = true;
    final report = await a.sync();
    expect(a.sleeps, const [Duration(seconds: 2)]);
    expect(report.duplicates, 2);
    expect(report.pendingLeft, 0);
    expect(server.rows('timesheet'), hasLength(1));
  });

  test('временный сбой при pull повторяется', () async {
    final emp = await b.addEmployee('Петров Пётр');
    await b.sync();
    server.failNext = 1;
    final report = await a.sync();
    expect(report.received, 1);
    expect(await a.repo.employees.byId(emp), isNotNull);
  });

  test('одна запись на двух ПК: побеждает последняя правка', () async {
    final emp = await a.addEmployee('Иванов Иван');
    await a.sync();
    await b.sync();

    // Сначала правит B, позже A; A синхронизируется первым.
    b.tick(const Duration(minutes: 1));
    final eb = (await b.repo.employees.byId(emp))!;
    await b.repo.employees.update(eb.copyWith(position: 'Тракторист'));
    a.tick(const Duration(minutes: 5));
    final ea = (await a.repo.employees.byId(emp))!;
    await a.repo.employees.update(ea.copyWith(position: 'Бригадир'));
    await a.sync();

    final report = await b.sync();
    expect(report.stale, 1);
    expect(report.lost, 1);
    expect(report.pendingLeft, 0);
    expect((await b.repo.employees.byId(emp))!.position, 'Бригадир');
    final entry = b.journal.entries.single;
    expect(entry.kind, JournalKind.lost);
    expect(entry.local!['position'], 'Тракторист');
    expect(entry.remote!['position'], 'Бригадир');
    expect(entry.message, contains('Сотрудник'));

    // Более поздняя правка B, отправленная позже, побеждает.
    b.tick(const Duration(minutes: 10));
    final eb2 = (await b.repo.employees.byId(emp))!;
    await b.repo.employees.update(eb2.copyWith(position: 'Механик'));
    await b.sync();
    await a.sync();
    expect((await a.repo.employees.byId(emp))!.position, 'Механик');
  });

  test(
    'один день введён на двух ПК офлайн: побеждает пришедший первым',
    () async {
      final emp = await a.addEmployee('Иванов Иван');
      await a.sync();
      await b.sync();

      final mine = await a.addWork(emp, sep1);
      b.tick();
      final theirs = await b.addWork(emp, sep1, days: 0.5);
      await b.sync(); // B первым
      final report = await a.sync();

      expect(report.lost, 1);
      expect(report.pendingLeft, 0);
      final rec = (await a.dayOf(emp, sep1))!;
      expect(rec.id, theirs);
      expect(rec.days, 0.5);
      final entry = a.journal.entries.single;
      expect(entry.kind, JournalKind.lostUnique);
      expect(entry.uuid, mine);
      expect(entry.remote, {'uuid': theirs});
      expect(server.rows('timesheet').single.uuid, theirs);

      // Следующий прогон спокоен.
      final next = await a.sync();
      expect(next.lost + next.pushed + next.rejected, 0);
    },
  );

  test('расчёт ЗП за тот же месяц с двух ПК — без журнала', () async {
    final emp = await a.addEmployee('Иванов Иван');
    await a.addWork(emp, sep1);
    await a.sync();
    await b.sync();
    await a.repo.payrollService.saveMonth(2026, 9);
    b.tick();
    await b.repo.payrollService.saveMonth(2026, 9);
    await b.sync();
    final report = await a.sync();
    expect(report.lost, 1);
    expect(a.journal.entries, isEmpty);
    expect(server.rows('payroll_results'), hasLength(1));
    expect(await a.repo.payroll.forMonth(2026, 9), hasLength(1));
  });

  test(
    'закрытый месяц: отказ в журнал, без повторов; после открытия — уходит',
    () async {
      final emp = await a.addEmployee('Иванов Иван');
      await a.sync();
      server.lockedMonths.add(202608);
      final day = await a.addWork(emp, DateTime(2026, 8, 3));
      final report = await a.sync();
      expect(report.rejected, 1);
      expect(report.pendingLeft, 1);
      final entry = a.journal.entries.single;
      expect(entry.kind, JournalKind.rejected);
      expect(entry.code, 'period_locked');
      expect(entry.uuid, day);
      expect((await a.store.rejectedChanges()).single.code, 'period_locked');

      final calls = server.pushCalls;
      await a.sync();
      expect(server.pushCalls, calls, reason: 'отклонённое повторно не уходит');

      server.lockedMonths.clear();
      final retry = await a.sync(retryRejected: true);
      expect(retry.pushed, 1);
      expect(retry.pendingLeft, 0);
    },
  );

  test('частичный отказ пачки: остальное принято', () async {
    server.forbiddenTables.add('payments');
    final emp = await a.addEmployee('Иванов Иван');
    await a.addWork(emp, sep1);
    await a.repo.payments.add(
      Payment(
        employeeId: emp,
        paymentDate: sep1,
        amount: 500,
        paymentType: 'advance',
      ),
    );
    final report = await a.sync();
    expect(report.pushed, 2);
    expect(report.rejected, 1);
    expect(a.journal.entries.single.table, 'payments');
    expect(server.rows('timesheet'), hasLength(1));
  });

  test('сервер восстановлен из копии: приём с нуля, данные на месте', () async {
    final emp = await a.addEmployee('Иванов Иван');
    await a.addWork(emp, sep1);
    await a.sync();
    await b.sync();
    server.restoreFromBackup();

    final report = await b.sync();
    expect(report.resynced, isTrue);
    expect(report.lost, 0);
    expect(b.journal.entries.single.kind, JournalKind.resync);
    expect((await b.dayOf(emp, sep1))!.days, 1);
    expect((await b.store.cursor()).epoch, server.epoch);
  });

  test('приём постранично', () async {
    final c = Pc('pc-c', server, DateTime.utc(2026, 9, 27, 10), pullLimit: 2);
    addTearDown(c.db.close);
    final emp = await a.addEmployee('Иванов Иван');
    for (var d = 1; d <= 5; d++) {
      await a.addWork(emp, DateTime(2026, 9, d));
    }
    await a.sync();
    await c.store.markAllSynced();
    final report = await c.sync();
    expect(report.received, greaterThanOrEqualTo(6));
    expect(
      await c.repo.timesheet.inPeriod(sep1, DateTime(2026, 9, 30)),
      hasLength(5),
    );
    expect(server.pullCalls, greaterThan(3));
  });

  test('одновременные вызовы — один прогон', () async {
    await a.addEmployee('Иванов Иван');
    final calls = server.pushCalls;
    final first = a.sync();
    expect(a.engine.isRunning, isTrue);
    final second = a.sync();
    expect(identical(await first, await second), isTrue);
    expect(server.pushCalls, calls + 1);
    expect(a.engine.isRunning, isFalse);
  });

  test('ошибка без временного характера не повторяется', () async {
    final failing = SyncEngine(
      store: a.store,
      transport: _Failing(ApiFailure(401, 'session_expired', 'Сеанс завершён')),
      sleep: (d) async => a.sleeps.add(d),
    );
    await a.addEmployee('Иванов Иван');
    await expectLater(
      failing.run(),
      throwsA(
        isA<ApiFailure>().having((e) => e.needsLogin, 'needsLogin', true),
      ),
    );
    expect(a.sleeps, isEmpty);
    expect(await a.store.pendingCount(), 1);
  });
}

class _Failing implements SyncTransport {
  final SyncFailure failure;

  _Failing(this.failure);

  @override
  Future<List<PushOutcome>> push(List<SyncChange> changes) => throw failure;

  @override
  Future<PullPage> pull(SyncCursor cursor, {int limit = 500}) => throw failure;
}
