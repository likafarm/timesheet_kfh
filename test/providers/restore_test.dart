import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/native.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:kfx_time_tracking/services/database_files.dart';
import 'package:kfx_time_tracking/services/backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory root;
  late String dbPath;
  late String backupDir;
  late AppProvider provider;
  late AppDatabase appDb;

  Employee employee(String name) => Employee(
    fullName: name,
    position: 'Рабочий',
    hireDate: DateTime(2025, 1, 1),
    baseRate: 1000,
    fieldRate: 1500,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('restore_test');
    dbPath = p.join(root.path, 'kfx_time_tracking_v2.db');
    backupDir = p.join(root.path, 'backups');
    appDb = await openAppDatabaseFile(dbPath);
    provider = AppProvider(
      appDb,
      backupService: BackupService(backupDirectory: backupDir),
    );
  });

  tearDown(() async {
    // После полного восстановления провайдер держит новую базу:
    // закрываем её через файл, который он открыл.
    await provider.closeDatabase();
    await root.delete(recursive: true);
  });

  List<String> backupNames() =>
      Directory(backupDir).listSync().map((f) => p.basename(f.path)).toList();

  test(
    'вся база из копии v2: данные копии, устройство то же, копия до',
    () async {
      await provider.addEmployee(employee('Иванов Иван'));
      final backup = await provider.createBackup();
      await provider.addEmployee(employee('Петров Пётр'));
      final device = await appDb.db.deviceId();

      expect(
        await provider.restoreFullBackup(backup!),
        isTrue,
        reason: provider.error,
      );

      expect(provider.employees.map((e) => e.fullName), ['Иванов Иван']);
      expect(
        backupNames().where((n) => n.startsWith('backup_before_restore_')),
        hasLength(1),
      );
      expect(File('$dbPath.restore').existsSync(), isFalse);
      expect(File('$dbPath.old').existsSync(), isFalse);
      expect(provider.databasePath, dbPath);

      // Устройство сохранилось, база рабочая.
      await provider.addEmployee(employee('Сидоров Сидор'));
      expect(provider.employees, hasLength(2));
      final check = sql.sqlite3.open(dbPath, mode: sql.OpenMode.readOnly);
      addTearDown(check.close);
      expect(
        check
            .select("SELECT value FROM sync_state WHERE key = 'device_id'")
            .single['value'],
        device,
      );
    },
  );

  test('вся база из копии v8 — через перенос', () async {
    final v8 = p.join(root.path, 'old.db');
    final b = sql.sqlite3.open(v8);
    for (final statement in legacyV8Schema) {
      b.execute(statement);
    }
    b.execute('PRAGMA user_version = 8');
    b.execute("INSERT INTO company_settings (id) VALUES (1)");
    b.execute(
      "INSERT INTO employees (full_name, position, hire_date) "
      "VALUES ('Из старой копии', 'Рабочий', '2025-01-01')",
    );
    b.close();

    expect(
      await provider.restoreFullBackup(v8),
      isTrue,
      reason: provider.error,
    );
    expect(provider.employees.single.fullName, 'Из старой копии');
  });

  test('испорченная копия: ошибка, текущая база на месте', () async {
    await provider.addEmployee(employee('Иванов Иван'));
    final junk = File(p.join(root.path, 'junk.db'))..writeAsStringSync('x');

    expect(await provider.restoreFullBackup(junk.path), isFalse);
    expect(provider.error, contains('Ошибка восстановления'));
    await provider.loadEmployees();
    expect(provider.employees.single.fullName, 'Иванов Иван');
  });

  test('отдельные строки из копии', () async {
    await provider.addEmployee(employee('Иванов Иван'));
    final backup = await provider.createBackup();
    final id = provider.employees.single.id!;
    await provider.updateEmployee(
      provider.employees.single.copyWith(position: 'Бригадир'),
    );

    final count = await provider.restoreSelectedRows(backup!, 'employees', [
      id,
    ]);
    expect(count, 1);
    expect(provider.employees.single.position, 'Рабочий');
  });

  test('replaceDatabaseFile: при ошибке старый файл возвращается', () {
    final target = p.join(root.path, 'a.db');
    File(target).writeAsStringSync('старый');
    expect(
      () => replaceDatabaseFile(p.join(root.path, 'нет.db'), target),
      throwsA(isA<FileSystemException>()),
    );
    expect(File(target).readAsStringSync(), 'старый');
    expect(File('$target.old').existsSync(), isFalse);
  });
}
