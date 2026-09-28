import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/native.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:test/test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory dir;
  late LocalDatabase db;
  late DriftRepositories repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kfh_restore_');
    db = openLocalDatabaseFile(File('${dir.path}/current.db'));
    repo = DriftRepositories(db);
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

  Future<String> addDay(String emp, DateTime date, {double days = 1}) =>
      repo.timesheet.add(
        TimesheetRecord(
          employeeId: emp,
          date: date,
          dayType: 'work',
          days: days,
          workPlace: 'field',
        ),
      );

  /// Снимок текущей базы, как делает BackupService.
  Future<String> snapshot(String name) async {
    final path = '${dir.path}/$name.db';
    await db.customStatement('VACUUM INTO ?', [path]);
    return path;
  }

  String makeV8(String name) {
    final path = '${dir.path}/$name.db';
    final b = sql.sqlite3.open(path);
    for (final statement in legacyV8Schema) {
      b.execute(statement);
    }
    b.execute('PRAGMA user_version = 8');
    b.execute(
      "INSERT INTO company_settings (id, company_name) VALUES (1, 'КФХ из копии')",
    );
    b.execute(
      "INSERT INTO employees (full_name, position, hire_date) "
      "VALUES ('Сидоров Сидор', 'Рабочий', '2025-01-01')",
    );
    b.close();
    return path;
  }

  test('версия схемы для копий совпадает с LocalDatabase', () {
    expect(db.schemaVersion, schemaVersionV2);
  });

  group('формат копии', () {
    test('v2, v8 и чужой файл', () async {
      await addEmployee('Иванов Иван');
      expect(detectBackupFormat(await snapshot('v2')), BackupFormat.v2);
      expect(detectBackupFormat(makeV8('v8')), BackupFormat.v8);

      final junk = File('${dir.path}/junk.db')..writeAsStringSync('не база');
      expect(
        () => detectBackupFormat(junk.path),
        throwsA(isA<RestoreException>()),
      );
      expect(
        () => detectBackupFormat('${dir.path}/нет.db'),
        throwsA(isA<RestoreException>()),
      );
    });
  });

  group('полное восстановление', () {
    test('из копии v2: данные копии, id устройства — текущий', () async {
      await addEmployee('Иванов Иван');
      final backup = await snapshot('v2');
      await addEmployee('Петров Пётр');
      final device = await db.deviceId();

      final target = '${dir.path}/restored.db';
      final report = await prepareFullRestore(
        backupPath: backup,
        targetPath: target,
        deviceId: device,
      );
      expect(report, isNull);

      final restored = openLocalDatabaseFile(File(target));
      addTearDown(restored.close);
      final names = (await DriftRepositories(
        restored,
      ).employees.all()).map((e) => e.fullName);
      expect(names, ['Иванов Иван']);
      expect(await restored.deviceId(), device);
      expect(
        await restored.syncStateDao.getValue(restoredFromKey),
        contains('v2.db'),
      );
    });

    test('из копии v8: перенос конвертером, id устройства — текущий', () async {
      final device = await db.deviceId();
      final target = '${dir.path}/restored.db';
      final report = await prepareFullRestore(
        backupPath: makeV8('v8'),
        targetPath: target,
        deviceId: device,
      );
      expect(report!.rowCounts['employees'], 1);

      final restored = openLocalDatabaseFile(File(target));
      addTearDown(restored.close);
      final r = DriftRepositories(restored);
      expect((await r.employees.all()).single.fullName, 'Сидоров Сидор');
      expect((await r.settings.get()).companyName, 'КФХ из копии');
      expect(await restored.deviceId(), device);
    });

    test('испорченная копия — ошибка, файл не создан', () async {
      final junk = File('${dir.path}/junk.db')..writeAsStringSync('не база');
      final target = '${dir.path}/restored.db';
      await expectLater(
        prepareFullRestore(
          backupPath: junk.path,
          targetPath: target,
          deviceId: 'x',
        ),
        throwsA(isA<RestoreException>()),
      );
      expect(File(target).existsSync(), isFalse);
    });
  });

  group('таблицы и строки из копии v2', () {
    test('строка возвращается как в копии, с новой отметкой', () async {
      final emp = await addEmployee('Иванов Иван');
      final day = await addDay(emp, DateTime(2026, 9, 1));
      final backup = await snapshot('v2');

      await repo.timesheet.update(
        (await repo.timesheet.on(
          emp,
          DateTime(2026, 9, 1),
        ))!.copyWith(days: 0.5),
      );
      final restorer = BackupRestorer(db);
      expect(await restorer.restoreRows(backup, 'timesheet', [day]), 1);

      final row = (await db.timesheetDao.recordOn(emp, DateTime(2026, 9, 1)))!;
      expect(row.days, 1);
      expect(row.editedBy, await db.deviceId());
    });

    test('удалённая строка возвращается', () async {
      final emp = await addEmployee('Иванов Иван');
      final day = await addDay(emp, DateTime(2026, 9, 1));
      final backup = await snapshot('v2');
      await repo.timesheet.delete(day);

      await BackupRestorer(db).restoreRows(backup, 'timesheet', [day]);
      expect((await repo.timesheet.on(emp, DateTime(2026, 9, 1)))!.id, day);
    });

    test('день, занятый новой записью, освобождается', () async {
      final emp = await addEmployee('Иванов Иван');
      final old = await addDay(emp, DateTime(2026, 9, 1));
      final backup = await snapshot('v2');
      await repo.timesheet.delete(old);
      final newer = await addDay(emp, DateTime(2026, 9, 1), days: 0.5);

      await BackupRestorer(db).restoreRows(backup, 'timesheet', [old]);
      final current = (await repo.timesheet.on(emp, DateTime(2026, 9, 1)))!;
      expect(current.id, old);
      final replaced = await (db.select(
        db.timesheet,
      )..where((t) => t.uuid.equals(newer))).getSingle();
      expect(replaced.deleted, isTrue);
    });

    test('таблица целиком: лишние строки помечаются удалёнными', () async {
      final emp = await addEmployee('Иванов Иван');
      await addDay(emp, DateTime(2026, 9, 1));
      final backup = await snapshot('v2');
      await addDay(emp, DateTime(2026, 9, 2));

      final count = await BackupRestorer(db).restoreTable(backup, 'timesheet');
      expect(count, 1);
      final days = await repo.timesheet.inPeriod(
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 30),
      );
      expect(days.map((d) => d.date), [DateTime(2026, 9, 1)]);
    });

    test('из копии v8 — только вся база', () async {
      expect(
        () => BackupRestorer(db).restoreTable(makeV8('v8'), 'employees'),
        throwsA(isA<RestoreException>()),
      );
      expect(BackupRestorer.restorableTables(makeV8('v8b')), isEmpty);
    });

    test('список восстанавливаемых таблиц копии v2', () async {
      final tables = BackupRestorer.restorableTables(await snapshot('v2'));
      expect(tables, containsAll(['employees', 'timesheet', 'payments']));
      expect(tables, isNot(contains('sync_state')));
    });
  });

  group('просмотр базы', () {
    late RawTables raw;
    setUp(() => raw = RawTables(db));

    test('колонки: даты и служебные поля отмечены', () async {
      final cols = {for (final c in await raw.columns('timesheet')) c.name: c};
      expect(cols['date']!.isDate, isTrue);
      expect(cols['updated_at']!.isSync, isTrue);
      expect(cols['days']!.type, 'REAL');
      expect(cols['notes']!.notNull, isFalse);
    });

    test('правка ставит отметку, служебные поля не правятся', () async {
      final emp = await addEmployee('Иванов Иван');
      await raw.updateRow('employees', emp, {'position': 'Бригадир'});
      final row = (await db.employeesDao.employeeByUuid(emp))!;
      expect(row.position, 'Бригадир');
      expect(row.editedBy, await db.deviceId());

      expect(
        () => raw.updateRow('employees', emp, {'uuid': 'x'}),
        throwsArgumentError,
      );
      expect(
        () => raw.updateRow('employees', emp, {'full_name': null}),
        throwsArgumentError,
      );
      expect(
        () => raw.updateRow('sync_state', emp, {'value': 'x'}),
        throwsArgumentError,
      );
      expect(
        () => raw.updateRow('employees', 'нет', {'position': 'x'}),
        throwsStateError,
      );
    });

    test('удаление мягкое и обратимое; настройки не удаляются', () async {
      final emp = await addEmployee('Иванов Иван');
      await raw.setDeleted('employees', emp, true);
      expect(await db.employeesDao.employeeByUuid(emp), isNull);
      await raw.setDeleted('employees', emp, false);
      expect(await db.employeesDao.employeeByUuid(emp), isNotNull);

      expect(
        () => raw.setDeleted('company_settings', companySettingsUuid, true),
        throwsArgumentError,
      );
    });

    test('строки таблицы и список таблиц', () async {
      await addEmployee('Иванов Иван');
      expect(await raw.tableNames(), containsAll(['employees', 'sync_state']));
      final rows = await raw.rows('employees');
      expect(rows.single['full_name'], 'Иванов Иван');
      expect(() => raw.rows('employees; DROP'), throwsArgumentError);
    });
  });
}
