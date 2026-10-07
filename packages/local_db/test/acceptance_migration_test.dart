// Приёмка миграции схемы на КОПИИ реальной базы: путь — в KFH_MIGRATION_DB
// (без переменной тест пропускается). Файл копируется во временную папку,
// исходник не открывается на запись.
//
//   $env:KFH_MIGRATION_DB="<копия v2.db>"; dart test test/acceptance_migration_test.dart

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:kfh_local_db/native.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:test/test.dart';

void main() {
  final source = Platform.environment['KFH_MIGRATION_DB'];
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'миграция копии реальной базы: копия перед обновлением, все записи на месте',
    () async {
      final dir = Directory.systemTemp.createTempSync('kfh_acceptance_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}${Platform.pathSeparator}base.db';
      File(source!).copySync(path);

      Map<String, int> counts(String file) {
        final db = sql.sqlite3.open(file, mode: sql.OpenMode.readOnly);
        try {
          final tables = db
              .select(
                "SELECT name FROM sqlite_master WHERE type = 'table' "
                "AND name NOT LIKE 'sqlite_%'",
              )
              .map((r) => r['name'] as String);
          return {
            for (final t in tables)
              t: db.select('SELECT COUNT(*) AS n FROM "$t"').single['n'] as int,
          };
        } finally {
          db.close();
        }
      }

      final versionBefore = databaseFileVersion(path)!;
      final before = counts(path);
      print('Схема до: $versionBefore; записей: $before');

      final backup = backupBeforeUpgrade(path);
      if (versionBefore < currentSchemaVersion) {
        expect(backup, isNotNull);
        expect(counts(backup!), before, reason: 'копия полная');
      }

      final db = openLocalDatabaseFile(File(path));
      final deviceBefore = sql.sqlite3
          .open(source, mode: sql.OpenMode.readOnly)
          .select("SELECT value FROM sync_state WHERE key = 'device_id'")
          .single['value'];
      expect(await db.deviceId(), deviceBefore, reason: 'id устройства');
      final integrity = await db.customSelect('PRAGMA integrity_check').get();
      expect(integrity.single.data.values.single, 'ok');
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      await db.close();

      expect(databaseFileVersion(path), currentSchemaVersion);
      final after = counts(path);
      print('Схема после: $currentSchemaVersion; записей: $after');
      for (final MapEntry(key: table, value: n) in before.entries) {
        expect(after[table], n, reason: table);
      }
      for (final table in financeTables.keys) {
        expect(after[table], 0, reason: '$table — новая и пустая');
      }
    },
    skip: source == null ? 'нет KFH_MIGRATION_DB' : null,
  );
}
