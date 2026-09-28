// Восстановление из резервных копий.
//
// Копии бывают двух форматов: v8 (sqflite, до перехода на drift) и v2.
// - Полное восстановление готовит новый файл базы из копии любого
//   формата (v8 — через конвертер со сверкой); подмену файла делает
//   приложение, закрыв базу.
// - Восстановление таблиц и строк — только из копий v2: строки
//   совпадают по uuid. Восстановленные строки получают новое updated_at,
//   чтобы при синхронизации они считались свежим изменением.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'backup_format.dart';
import 'database.dart';
import 'migration/v8_converter.dart';
import 'schema_info.dart';

/// Формат копии; неизвестный или повреждённый файл — [RestoreException].
BackupFormat detectBackupFormat(String path) {
  if (!File(path).existsSync()) {
    throw RestoreException('Нет файла копии: $path');
  }
  final sql.Database db;
  try {
    db = sql.sqlite3.open(path, mode: sql.OpenMode.readOnly);
  } catch (e) {
    throw RestoreException('Файл копии не открывается: $e');
  }
  try {
    final version = db.select('PRAGMA user_version').first.values.first;
    final tables = db
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((r) => r['name'] as String)
        .toSet();
    if (tables.contains('sync_state')) {
      if (version != schemaVersionV2) {
        throw RestoreException(
          'Копия схемы версии $version, программа понимает версию '
          '$schemaVersionV2',
        );
      }
      return BackupFormat.v2;
    }
    if (version == legacySchemaVersion && tables.contains('employees')) {
      return BackupFormat.v8;
    }
    throw RestoreException('Файл не похож на копию базы программы');
  } on sql.SqliteException catch (e) {
    throw RestoreException('Файл копии повреждён: $e');
  } finally {
    db.close();
  }
}

/// Версия drift-схемы v2 (`LocalDatabase.schemaVersion`).
const schemaVersionV2 = 1;

/// Готовит из копии [backupPath] файл базы v2 [targetPath] для полной
/// замены текущей. [deviceId] — id этого устройства: восстановленная база
/// остаётся «тем же устройством» для синхронизации.
///
/// Возвращает отчёт конвертера для копии v8 (null — копия v2).
Future<ConversionReport?> prepareFullRestore({
  required String backupPath,
  required String targetPath,
  required String deviceId,
  DateTime Function()? clock,
}) async {
  final format = detectBackupFormat(backupPath);
  for (final suffix in ['', '-journal', '-wal', '-shm']) {
    final file = File('$targetPath$suffix');
    if (file.existsSync()) file.deleteSync();
  }

  ConversionReport? report;
  try {
    if (format == BackupFormat.v8) {
      report = await convertV8ToV2(
        sourcePath: backupPath,
        targetPath: targetPath,
        clock: clock,
      );
    } else {
      File(backupPath).copySync(targetPath);
    }

    final db = sql.sqlite3.open(targetPath);
    try {
      final check = db.select('PRAGMA integrity_check').first.values.first;
      if (check != 'ok') {
        throw RestoreException('integrity_check копии: $check');
      }
      final now = (clock ?? DateTime.now)().toUtc().toIso8601String();
      db.execute(
        'INSERT OR REPLACE INTO sync_state (key, value) VALUES (?, ?)',
        [deviceIdKey, deviceId],
      );
      db.execute(
        'INSERT OR REPLACE INTO sync_state (key, value) VALUES (?, ?)',
        [
          restoredFromKey,
          jsonEncode({'source': backupPath, 'at': now}),
        ],
      );
    } finally {
      db.close();
    }
    return report;
  } catch (_) {
    final file = File(targetPath);
    if (file.existsSync()) file.deleteSync();
    rethrow;
  }
}

/// Восстановление таблиц и отдельных строк из копии v2 в открытую базу.
class BackupRestorer {
  final LocalDatabase db;

  BackupRestorer(this.db);

  /// Таблицы копии, которые можно восстановить.
  static List<String> restorableTables(String backupPath) {
    if (detectBackupFormat(backupPath) != BackupFormat.v2) return const [];
    return _read(backupPath, (b) {
      final present = b
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toSet();
      return businessTables.where(present.contains).toList();
    });
  }

  /// Возвращает строки [uuids] таблицы [table] из копии; удалённые в копии
  /// строки восстанавливаются удалёнными. Строка текущей базы, занимающая
  /// тот же день табеля или месяц расчёта, помечается удалённой.
  /// Возвращает число восстановленных строк.
  Future<int> restoreRows(
    String backupPath,
    String table,
    List<String> uuids,
  ) async {
    if (uuids.isEmpty) return 0;
    final rows = _backupRows(
      backupPath,
      table,
    ).where((r) => uuids.contains(r['uuid'])).toList();
    await db.transaction(() => _upsert(table, rows));
    return rows.length;
  }

  /// Таблица целиком как в копии: строки копии возвращаются, строки,
  /// которых в копии нет, помечаются удалёнными.
  Future<int> restoreTable(String backupPath, String table) async {
    final rows = _backupRows(backupPath, table);
    await db.transaction(() async {
      await _upsert(table, rows);
      if (table != 'company_settings') {
        final keep = rows.map((r) => r['uuid'] as String).toSet();
        final current = await db
            .customSelect('SELECT uuid FROM $table WHERE deleted = 0')
            .get();
        for (final r in current) {
          final uuid = r.read<String>('uuid');
          if (!keep.contains(uuid)) await _softDelete(table, uuid);
        }
      }
    });
    return rows.length;
  }

  List<Map<String, Object?>> _backupRows(String backupPath, String table) {
    if (!businessTables.contains(table)) {
      throw RestoreException('Таблица $table не восстанавливается');
    }
    if (detectBackupFormat(backupPath) != BackupFormat.v2) {
      throw const RestoreException(
        'Таблицы и строки восстанавливаются только из копий нового формата; '
        'из старой копии — только вся база',
      );
    }
    return _read(
      backupPath,
      (b) => b
          .select('SELECT * FROM ${checkIdentifier(table)}')
          .map((r) => Map<String, Object?>.of(r))
          .toList(),
    );
  }

  Future<void> _upsert(String table, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    final current = (await db.customSelect('PRAGMA table_info($table)').get())
        .map((r) => r.read<String>('name'))
        .toSet();
    final columns = rows.first.keys.toList();
    if (!current.containsAll(columns) || columns.length != current.length) {
      throw RestoreException(
        'Колонки таблицы $table в копии не совпадают с текущими',
      );
    }

    final editor = await db.deviceId();
    final now = db.nowUtc();
    // Поля, которые при восстановлении берутся не из копии.
    const stamped = {'updated_at', 'edited_by'};
    final data = columns.where((c) => !stamped.contains(c)).toList();
    final names = [...data, 'updated_at', 'edited_by'];
    final updates = names
        .where((c) => c != 'uuid' && c != 'remote_updated_at')
        .map((c) => '$c = excluded.$c')
        .join(', ');
    final sqlText =
        'INSERT INTO $table (${names.join(', ')}) '
        'VALUES (${List.filled(names.length, '?').join(', ')}) '
        'ON CONFLICT (uuid) DO UPDATE SET $updates';

    for (final row in rows) {
      if (row['deleted'] == 0) await _freeUniqueKey(table, row);
      await db.customInsert(
        sqlText,
        variables: [
          for (final c in data) Variable(row[c]),
          Variable<DateTime>(now),
          Variable<String>(editor),
        ],
        updates: _tableInfo(table),
      );
    }
  }

  /// Помечает удалённой строку, которая занимает уникальный ключ
  /// восстанавливаемой строки (тот же день табеля, тот же месяц расчёта).
  Future<void> _freeUniqueKey(String table, Map<String, Object?> row) async {
    final key = uniqueKeys[table];
    if (key == null) return;
    final taken = await db
        .customSelect(
          'SELECT uuid FROM $table WHERE deleted = 0 AND uuid <> ? AND '
          '${key.map((c) => '$c = ?').join(' AND ')}',
          variables: [
            Variable<String>(row['uuid'] as String),
            for (final c in key) Variable(row[c]),
          ],
        )
        .get();
    for (final r in taken) {
      await _softDelete(table, r.read<String>('uuid'));
    }
  }

  Future<void> _softDelete(String table, String uuid) async {
    await db.customUpdate(
      'UPDATE $table SET deleted = 1, updated_at = ?, edited_by = ? '
      'WHERE uuid = ?',
      variables: [
        Variable<DateTime>(db.nowUtc()),
        Variable<String>(await db.deviceId()),
        Variable<String>(uuid),
      ],
      updates: _tableInfo(table),
      updateKind: UpdateKind.update,
    );
  }

  Set<TableInfo> _tableInfo(String table) => {
    for (final t in db.allTables)
      if (t.actualTableName == table) t,
  };

  static T _read<T>(String path, T Function(sql.Database) body) {
    final b = sql.sqlite3.open(path, mode: sql.OpenMode.readOnly);
    try {
      return body(b);
    } finally {
      b.close();
    }
  }
}
