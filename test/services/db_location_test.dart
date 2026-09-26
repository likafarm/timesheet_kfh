import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kfx_time_tracking/services/db_location.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  late Directory root;
  late String dataDir;
  late String exeDir;
  late String cwdDir;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('db_location_test');
    dataDir = p.join(root.path, 'AppData', 'KFH Time Tracking');
    exeDir = p.join(root.path, 'Programs', 'db');
    cwdDir = p.join(root.path, 'cwd', 'db');
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  /// Создаёт настоящую базу с таблицей employees и одной записью [name].
  Future<String> makeDb(String dir, String name) async {
    await Directory(dir).create(recursive: true);
    final path = p.join(dir, dbFileName);
    final db = sql.sqlite3.open(path);
    db.execute(
      'CREATE TABLE employees (id INTEGER PRIMARY KEY, full_name TEXT)',
    );
    db.execute('INSERT INTO employees (full_name) VALUES (?)', [name]);
    db.close();
    return path;
  }

  Future<String> readName(String path) async {
    final db = sql.sqlite3.open(path, mode: sql.OpenMode.readOnly);
    try {
      return db.select('SELECT full_name FROM employees').single['full_name']
          as String;
    } finally {
      db.close();
    }
  }

  Future<DbLocation> resolve() =>
      resolveDatabasePath(dataDir: dataDir, legacyDirs: [exeDir, cwdDir]);

  test('старой базы нет — новый путь, ничего не создаётся', () async {
    final loc = await resolve();
    expect(loc.path, p.join(dataDir, dbFileName));
    expect(loc.migratedFrom, isNull);
    expect(loc.error, isNull);
    expect(await File(loc.path).exists(), isFalse);
  });

  test('старая база копируется, оригинал остаётся', () async {
    final old = await makeDb(exeDir, 'Иванов');
    final loc = await resolve();

    expect(loc.path, p.join(dataDir, dbFileName));
    expect(loc.migratedFrom, old);
    expect(loc.error, isNull);
    expect(await readName(loc.path), 'Иванов');
    expect(await File(old).exists(), isTrue);
    expect(await File('${loc.path}.tmp').exists(), isFalse);
  });

  test('соседний -wal копируется вместе с базой', () async {
    final old = await makeDb(exeDir, 'Иванов');
    await File('$old-wal').writeAsString('');
    final loc = await resolve();
    expect(loc.migratedFrom, old);
    expect(await File('$old-wal').exists(), isTrue);
  });

  test('новая база уже есть — старая игнорируется', () async {
    await makeDb(dataDir, 'Новая');
    await makeDb(exeDir, 'Старая');
    final loc = await resolve();

    expect(loc.migratedFrom, isNull);
    expect(await readName(loc.path), 'Новая');
  });

  test('старые базы в обеих папках — берётся из папки программы', () async {
    await makeDb(cwdDir, 'Из рабочей папки');
    final fromExe = await makeDb(exeDir, 'Из папки программы');
    final loc = await resolve();

    expect(loc.migratedFrom, fromExe);
    expect(await readName(loc.path), 'Из папки программы');
  });

  test('база только в рабочей папке — переносится она', () async {
    final fromCwd = await makeDb(cwdDir, 'Из рабочей папки');
    final loc = await resolve();
    expect(loc.migratedFrom, fromCwd);
  });

  test('одновременные вызовы не мешают друг другу', () async {
    final old = await makeDb(exeDir, 'Иванов');
    final results = await Future.wait([resolve(), resolve(), resolve()]);

    for (final loc in results) {
      expect(loc.error, isNull);
      expect(loc.path, p.join(dataDir, dbFileName));
      expect(loc.migratedFrom, old);
    }
    expect(await readName(results.first.path), 'Иванов');
  });

  test('повреждённая старая база — перенос отменён, путь к старой', () async {
    await Directory(exeDir).create(recursive: true);
    final old = p.join(exeDir, dbFileName);
    await File(old).writeAsString('это не база данных');
    final loc = await resolve();

    expect(loc.path, old);
    expect(loc.error, isNotNull);
    expect(await File(p.join(dataDir, dbFileName)).exists(), isFalse);
    expect(await File(p.join(dataDir, '$dbFileName.tmp')).exists(), isFalse);
  });

  test('чужая база без таблиц программы не переносится', () async {
    await Directory(exeDir).create(recursive: true);
    final old = p.join(exeDir, dbFileName);
    final db = sql.sqlite3.open(old);
    db.execute('CREATE TABLE other (id INTEGER)');
    db.close();

    final loc = await resolve();
    expect(loc.path, old);
    expect(loc.error, contains('employees'));
  });
}
