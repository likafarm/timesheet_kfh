import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/native.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:test/test.dart';

/// Модуль «Резервные копии»: снимок из файла копии, сравнение с текущей
/// базой и возврат записей обычными правками.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;
  late LocalDatabase db;
  late DriftRepositories repo;
  late LocalSyncStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kfh_snapshot_');
    db = openLocalDatabaseFile(File('${dir.path}/current.db'));
    repo = DriftRepositories(db);
    store = LocalSyncStore(db);
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<String> addEmployee(String name) => repo.employees.add(
    Employee(
      fullName: name,
      position: 'Рабочий',
      hireDate: DateTime(2025, 1, 1),
      baseRate: 1000,
      fieldRate: 1500,
    ),
  );

  Future<String> addDay(String emp, DateTime date, {String place = 'field'}) =>
      repo.timesheet.add(
        TimesheetRecord(
          employeeId: emp,
          date: date,
          dayType: 'work',
          days: 1,
          workPlace: place,
        ),
      );

  /// Копия текущей базы, как делает BackupService.
  Future<String> copy(String name) async {
    final path = '${dir.path}/$name.db';
    await db.customStatement('VACUUM INTO ?', [path]);
    return path;
  }

  Future<DataSnapshot> fromCopy(String path) =>
      readSnapshotFile(path, tempDir: dir);

  Future<RestorePlan> planFrom(
    String path, {
    Set<int> locked = const {},
    bool Function(RecordChange)? only,
  }) async {
    final now = await readSnapshot(db);
    final diff = diffSnapshots(await fromCopy(path), now);
    return planRestore(
      only == null ? diff : diff.where(only),
      now: now,
      lockedMonths: locked,
    );
  }

  test('вернуть всю базу на дату: правки обычные, уходят в очередь', () async {
    final ivan = await addEmployee('Иванов Иван');
    final kept = await addDay(ivan, DateTime(2026, 9, 1));
    final edited = await addDay(ivan, DateTime(2026, 9, 2));
    final removed = await addDay(ivan, DateTime(2026, 9, 3));
    final backup = await copy('copy');
    await store.markAllSynced();

    final record = (await repo.timesheet.on(ivan, DateTime(2026, 9, 2)))!;
    await repo.timesheet.update(record.copyWith(workPlace: 'base', days: 0.5));
    await repo.timesheet.delete(removed);
    final added = await addDay(ivan, DateTime(2026, 9, 4));
    await repo.payments.add(
      Payment(employeeId: ivan, paymentDate: DateTime(2026, 9, 10), amount: 5),
    );
    await store.markAllSynced();

    final plan = await planFrom(backup);
    expect(plan.skipped, isEmpty);
    expect(plan.edits, hasLength(4));
    expect(await SnapshotRestorer(db).apply(plan.edits), 4);

    expect(
      diffSnapshots(await fromCopy(backup), await readSnapshot(db)),
      isEmpty,
    );
    final back = (await repo.timesheet.on(ivan, DateTime(2026, 9, 2)))!;
    expect((back.id, back.workPlace, back.days), (edited, 'field', 1.0));
    expect(await repo.timesheet.on(ivan, DateTime(2026, 9, 3)), isNotNull);
    expect(await repo.timesheet.on(ivan, DateTime(2026, 9, 4)), isNull);
    expect(await repo.payments.list(), isEmpty);

    // Возвращённые записи не отправлены — уйдут на сервер синхронизацией;
    // нетронутая запись в очередь не попала.
    final pending = await store.pendingChanges();
    expect(pending.map((p) => p.change.table).toSet(), {
      'timesheet',
      'payments',
    });
    expect(pending, hasLength(4));
    expect(pending.map((p) => p.change.uuid), isNot(contains(kept)));
    expect(
      pending.firstWhere((p) => p.change.uuid == added).change.deleted,
      isTrue,
    );
    final device = await db.deviceId();
    expect(pending.every((p) => p.change.editedBy == device), isTrue);
  });

  test(
    'возврат удалённого дня освобождает день, занятый другой записью',
    () async {
      final ivan = await addEmployee('Иванов Иван');
      final first = await addDay(ivan, DateTime(2026, 9, 1));
      final backup = await copy('copy');
      await repo.timesheet.delete(first);
      final second = await addDay(ivan, DateTime(2026, 9, 1), place: 'base');

      final plan = await planFrom(
        backup,
        only: (c) => c.kind == RecordChangeKind.removed,
      );
      expect(plan.edits.map((e) => e.implied), [true, false]);
      await SnapshotRestorer(db).apply(plan.edits);
      final day = (await repo.timesheet.on(ivan, DateTime(2026, 9, 1)))!;
      expect((day.id, day.workPlace), (first, 'field'));
      expect(
        (await readSnapshot(db)).row('timesheet', second)!.deleted,
        isTrue,
      );
    },
  );

  test('записи, поменявшиеся днями, возвращаются без конфликта', () async {
    final ivan = await addEmployee('Иванов Иван');
    final a = await addDay(ivan, DateTime(2026, 9, 1));
    final b = await addDay(ivan, DateTime(2026, 9, 2), place: 'base');
    final backup = await copy('copy');
    // Меняем дни местами в обход репозитория (через третий день).
    Future<void> move(String uuid, String date) => db.customUpdate(
      'UPDATE timesheet SET date = ?, updated_at = ? WHERE uuid = ?',
      variables: [
        Variable<String>(date),
        Variable<DateTime>(db.nowUtc()),
        Variable<String>(uuid),
      ],
    );
    await move(a, '2026-09-09');
    await move(b, '2026-09-01');
    await move(a, '2026-09-02');

    final plan = await planFrom(backup);
    expect(plan.skipped, isEmpty);
    await SnapshotRestorer(db).apply(plan.edits);
    expect((await repo.timesheet.on(ivan, DateTime(2026, 9, 1)))!.id, a);
    expect((await repo.timesheet.on(ivan, DateTime(2026, 9, 2)))!.id, b);
  });

  test('закрытый месяц не трогается', () async {
    final ivan = await addEmployee('Иванов Иван');
    await addDay(ivan, DateTime(2026, 8, 20));
    await addDay(ivan, DateTime(2026, 9, 2));
    final backup = await copy('copy');
    for (final d in [DateTime(2026, 8, 20), DateTime(2026, 9, 2)]) {
      final r = (await repo.timesheet.on(ivan, d))!;
      await repo.timesheet.update(r.copyWith(workPlace: 'base'));
    }
    final plan = await planFrom(
      backup,
      locked: {PeriodGuard.monthKey(2026, 8)},
    );
    expect(plan.skipped.single.reason, contains('закрыт'));
    await SnapshotRestorer(db).apply(plan.edits);
    expect(
      (await repo.timesheet.on(ivan, DateTime(2026, 8, 20)))!.workPlace,
      'base',
    );
    expect(
      (await repo.timesheet.on(ivan, DateTime(2026, 9, 2)))!.workPlace,
      'field',
    );
  });

  test(
    'данные изменились после построения плана — ничего не пишется',
    () async {
      final ivan = await addEmployee('Иванов Иван');
      await addDay(ivan, DateTime(2026, 9, 1));
      await addDay(ivan, DateTime(2026, 9, 2));
      final backup = await copy('copy');
      for (final d in [DateTime(2026, 9, 1), DateTime(2026, 9, 2)]) {
        final r = (await repo.timesheet.on(ivan, d))!;
        await repo.timesheet.update(r.copyWith(workPlace: 'base'));
      }
      final plan = await planFrom(backup);
      final later = (await repo.timesheet.on(ivan, DateTime(2026, 9, 2)))!;
      await repo.timesheet.update(later.copyWith(days: 0.5));

      await expectLater(
        SnapshotRestorer(db).apply(plan.edits),
        throwsA(
          isA<RestoreException>().having(
            (e) => e.message,
            'message',
            contains('заново'),
          ),
        ),
      );
      expect(
        (await repo.timesheet.on(ivan, DateTime(2026, 9, 1)))!.workPlace,
        'base',
      );
    },
  );

  test('копия старого формата v8 читается через конвертер', () async {
    final path = '${dir.path}/old.db';
    final b = sql.sqlite3.open(path);
    for (final statement in legacyV8Schema) {
      b.execute(statement);
    }
    b.execute('PRAGMA user_version = 8');
    b.execute(
      "INSERT INTO company_settings (id, company_name) VALUES (1, 'КФХ')",
    );
    b.execute(
      "INSERT INTO employees (full_name, position, hire_date) "
      "VALUES ('Сидоров Сидор', 'Рабочий', '2025-01-01')",
    );
    b.close();

    final snapshot = await fromCopy(path);
    expect(
      snapshot.liveRows('employees').single.data['full_name'],
      'Сидоров Сидор',
    );
    // Временный файл конвертера убран, копия не изменилась.
    expect(dir.listSync().map((f) => f.uri.pathSegments.last).toList(), [
      'old.db',
    ]);
    expect(detectBackupFormat(path), BackupFormat.v8);
  });
}
