import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_local_db/native.dart';
import 'package:kfx_time_tracking/services/app_database.dart';
import 'package:kfx_time_tracking/services/database_files.dart';
import 'package:kfx_time_tracking/services/db_location.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory root;
  late String dataDir;
  late String legacyDir;
  late List<String> backups;
  late List<String> log;
  AppDatabase? opened;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('app_database_test');
    dataDir = p.join(root.path, 'AppData', 'KFH Time Tracking');
    legacyDir = p.join(root.path, 'Programs', '.dart_tool');
    backups = [];
    log = [];
    opened = null;
  });

  tearDown(() async {
    await opened?.close();
    await root.delete(recursive: true);
  });

  /// Старая база v8 с одним сотрудником.
  String makeV8(String dir, {int version = 8}) {
    Directory(dir).createSync(recursive: true);
    final path = p.join(dir, dbFileName);
    final db = sql.sqlite3.open(path);
    for (final statement in legacyV8Schema) {
      db.execute(statement);
    }
    db.execute('PRAGMA user_version = $version');
    db.execute("INSERT INTO company_settings (id) VALUES (1)");
    db.execute(
      "INSERT INTO employees (full_name, position, hire_date) "
      "VALUES ('Иванов Иван', 'Рабочий', '2025-01-01')",
    );
    db.close();
    return path;
  }

  Future<String> fakeBackup(String v8Path) async {
    final copy = p.join(root.path, 'backup_${backups.length}.db');
    await File(v8Path).copy(copy);
    backups.add(copy);
    return copy;
  }

  Future<AppDatabase> open({Future<String> Function(String)? backup}) async {
    final db = await openAppDatabase(
      dataDir: dataDir,
      legacyDirs: [legacyDir],
      backupLegacy: backup ?? fakeBackup,
      log: (m) async => log.add(m),
    );
    opened = db;
    return db;
  }

  String v2Path() => p.join(dataDir, dbV2FileName);

  test('новая установка: пустая база v2, без копий и переноса', () async {
    final db = await open();
    expect(db.path, v2Path());
    expect(File(v2Path()).existsSync(), isTrue);
    expect(await db.repos.employees.all(), isEmpty);
    expect(backups, isEmpty);
  });

  test(
    'первый запуск со старой базой: копия, перенос, данные на месте',
    () async {
      final v8 = makeV8(dataDir);
      final before = File(v8).readAsBytesSync();

      final db = await open();

      expect(backups, hasLength(1));
      expect(File(backups.single).readAsBytesSync(), before);
      expect(File(v8).readAsBytesSync(), before);
      final employees = await db.repos.employees.all();
      expect(employees.single.fullName, 'Иванов Иван');
      expect(log.any((m) => m.contains('перенесена в формат v2')), isTrue);
    },
  );

  test('повторный запуск: база v2 уже есть — переноса нет', () async {
    makeV8(dataDir);
    await (await open()).close();
    opened = null;
    backups.clear();

    final db = await open();
    expect(backups, isEmpty);
    expect(await db.repos.employees.all(), hasLength(1));
  });

  test('старая база в папке программы: переезд в AppData и перенос', () async {
    makeV8(legacyDir);
    final db = await open();
    expect(File(p.join(dataDir, dbFileName)).existsSync(), isTrue);
    expect(await db.repos.employees.all(), hasLength(1));
  });

  test('перенос не прошёл — база не открыта, старая не тронута', () async {
    final v8 = makeV8(dataDir, version: 7);
    final before = File(v8).readAsBytesSync();

    await expectLater(
      open(),
      throwsA(
        isA<DatabaseOpenException>().having(
          (e) => e.message,
          'message',
          allOf(contains('версии 7'), contains('Старая база не изменена')),
        ),
      ),
    );
    expect(File(v2Path()).existsSync(), isFalse);
    expect(File(v8).readAsBytesSync(), before);
    expect(log.any((m) => m.contains('не выполнен')), isTrue);
  });

  test('без резервной копии перенос не начинается', () async {
    makeV8(dataDir);
    await expectLater(
      open(backup: (_) async => throw const FileSystemException('нет места')),
      throwsA(
        isA<DatabaseOpenException>().having(
          (e) => e.message,
          'message',
          contains('резервную копию'),
        ),
      ),
    );
    expect(File(v2Path()).existsSync(), isFalse);
  });

  /// База схемы 1 (до финансов): текущая база без таблиц финансов.
  Future<void> makeSchema1() async {
    final db = await open();
    await db.repos.employees.all();
    await db.close();
    opened = null;
    final raw = sql.sqlite3.open(v2Path());
    // Схема 1 — без таблиц финансов (схема 2) и корректировок (схема 3).
    for (final table in [
      'payroll_adjustments',
      ...financeTables.keys.toList().reversed,
    ]) {
      raw.execute('DROP TABLE $table');
    }
    raw.execute('PRAGMA user_version = 1');
    raw.execute(
      "INSERT INTO employees (uuid, full_name, position, hire_date, "
      "base_rate, field_rate, updated_at, deleted) VALUES ('e1', "
      "'Петров Пётр', 'Рабочий', '2025-01-01', 0, 0, "
      "'2026-09-26T10:00:00.000Z', 0)",
    );
    raw.close();
  }

  List<String> upgradeCopies() => [
    for (final f in Directory(dataDir).listSync().whereType<File>())
      if (p.basename(f.path).startsWith(upgradeBackupPrefix)) f.path,
  ];

  test('база схемы 1: копия рядом, обновление до последней, данные на месте', () async {
    await makeSchema1();
    final db = await open();
    expect(upgradeCopies(), hasLength(1));
    final copy = sql.sqlite3.open(
      upgradeCopies().single,
      mode: sql.OpenMode.readOnly,
    );
    expect(copy.select('PRAGMA user_version').single.values.single, 1);
    copy.close();
    expect(databaseFileVersion(v2Path()), currentSchemaVersion);
    expect((await db.repos.employees.all()).single.fullName, 'Петров Пётр');
    expect(await db.repos.finance.accounts(), isEmpty);
    expect(
      log.any(
        (m) => m.contains('обновлением схемы 1 -> $currentSchemaVersion'),
      ),
      isTrue,
    );

    // Следующий запуск — копий больше не делается.
    await db.close();
    opened = null;
    await open();
    expect(upgradeCopies(), hasLength(1));
  });

  test('база от более новой версии программы не открывается', () async {
    await (await open()).close();
    opened = null;
    final raw = sql.sqlite3.open(v2Path());
    raw.execute('PRAGMA user_version = ${currentSchemaVersion + 1}');
    raw.close();
    await expectLater(
      open(),
      throwsA(
        isA<DatabaseOpenException>().having(
          (e) => e.message,
          'message',
          contains('более новой версией'),
        ),
      ),
    );
    expect(databaseFileVersion(v2Path()), currentSchemaVersion + 1);
    expect(upgradeCopies(), isEmpty);
  });
}
