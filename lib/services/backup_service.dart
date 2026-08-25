// lib/services/backup_service.dart

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';

/// Тип резервной копии.
enum BackupType {
  /// Ежедневная копия — имя файла `daily_YYYY-MM-DD.db`
  daily,

  /// Ежемесячная копия — имя файла `monthly_YYYY-MM.db`
  monthly,

  /// Устаревший формат `backup_<timestamp>.db`
  legacy,
}

class BackupInfo {
  final String path;
  final String fileName;
  final DateTime created;
  final BackupType type;

  BackupInfo({
    required this.path,
    required this.fileName,
    required this.created,
    required this.type,
  });

  @override
  String toString() => fileName;
}

class BackupService {
  static const _maxDailyBackups = 5;
  static const _backupDirName = 'backups';

  Future<Directory> _getBackupDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(appDocDir.path, _backupDirName));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Создаёт резервную копию заданного типа.
  ///
  /// - [BackupType.daily]: имя `daily_YYYY-MM-DD.db`.
  ///   Если файл за сегодня уже есть — перезаписывает (актуальнее).
  /// - [BackupType.monthly]: имя `monthly_YYYY-MM.db`.
  ///   Если файл за этот месяц уже есть — пропускает (первая копия месяца важнее).
  Future<String?> createBackup(
    Database db, {
    BackupType type = BackupType.daily,
  }) async {
    try {
      final dbPath = db.path;
      final sourceFile = File(dbPath);
      if (!await sourceFile.exists()) {
        throw Exception('Файл базы данных не найден');
      }

      final backupDir = await _getBackupDirectory();
      final now = DateTime.now();

      String backupFileName;
      bool skipIfExists = false;

      if (type == BackupType.monthly) {
        final yearMonth =
            '${now.year}-${now.month.toString().padLeft(2, '0')}';
        backupFileName = 'monthly_$yearMonth.db';
        skipIfExists = true; // первая копия месяца сохраняется
      } else {
        final date =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        backupFileName = 'daily_$date.db';
        skipIfExists = false; // перезаписываем: актуальнее
      }

      final backupPath = p.join(backupDir.path, backupFileName);

      if (skipIfExists && await File(backupPath).exists()) {
        debugPrint('Ежемесячная копия за этот месяц уже существует: $backupPath');
        return backupPath;
      }

      // Сбрасываем WAL в основной файл БД, чтобы копия была согласованной.
      try {
        await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      } catch (e) {
        debugPrint('WAL checkpoint failed (non-fatal): $e');
      }

      await sourceFile.copy(backupPath);
      await _cleanupOldBackups(backupDir);
      return backupPath;
    } catch (e) {
      debugPrint('Ошибка создания бэкапа: $e');
      return null;
    }
  }

  /// Очищает старые ежедневные копии, оставляя только последние [_maxDailyBackups].
  /// Ежемесячные и legacy-копии не трогает.
  Future<void> _cleanupOldBackups(Directory backupDir) async {
    final all = await _listBackupFiles(backupDir);

    final dailies = all.where((b) => b.type == BackupType.daily).toList();
    if (dailies.length <= _maxDailyBackups) return;

    // Сортируем по дате (новые вперёд), удаляем лишние
    dailies.sort((a, b) => b.created.compareTo(a.created));
    final toDelete = dailies.skip(_maxDailyBackups);
    for (final info in toDelete) {
      try {
        final file = File(info.path);
        if (await file.exists()) await file.delete();
        debugPrint('Удалена старая ежедневная копия: ${info.fileName}');
      } catch (e) {
        debugPrint('Ошибка удаления старого бэкапа: $e');
      }
    }
  }

  Future<List<BackupInfo>> getBackups() async {
    final backupDir = await _getBackupDirectory();
    return await _listBackupFiles(backupDir);
  }

  Future<List<BackupInfo>> _listBackupFiles(Directory backupDir) async {
    final entities = await backupDir
        .list()
        .where((e) => e is File)
        .toList();

    final backups = <BackupInfo>[];

    for (final entity in entities) {
      final file = entity as File;
      final fileName = p.basename(file.path);

      BackupType type;
      DateTime created;

      if (fileName.startsWith('daily_') && fileName.endsWith('.db')) {
        // daily_YYYY-MM-DD.db
        type = BackupType.daily;
        final datePart = fileName.substring(6, fileName.length - 3);
        try {
          created = DateTime.parse(datePart);
        } catch (_) {
          final stat = await file.stat();
          created = stat.modified;
        }
      } else if (fileName.startsWith('monthly_') && fileName.endsWith('.db')) {
        // monthly_YYYY-MM.db
        type = BackupType.monthly;
        final datePart = fileName.substring(8, fileName.length - 3);
        try {
          created = DateTime.parse('$datePart-01');
        } catch (_) {
          final stat = await file.stat();
          created = stat.modified;
        }
      } else if (fileName.startsWith('backup_') && fileName.endsWith('.db')) {
        // legacy: backup_<timestamp>.db
        type = BackupType.legacy;
        final datePart = fileName.substring(7, fileName.length - 3);
        try {
          final normalized = datePart.replaceAll('-', ':');
          created = DateTime.parse(normalized);
        } catch (_) {
          final stat = await file.stat();
          created = stat.modified;
        }
      } else {
        continue; // не наш файл
      }

      backups.add(
        BackupInfo(
          path: file.path,
          fileName: fileName,
          created: created,
          type: type,
        ),
      );
    }

    backups.sort((a, b) => b.created.compareTo(a.created));
    return backups;
  }

  Future<void> deleteBackup(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Восстанавливает БД из бэкапа.
  /// Не закрывает [currentDb] — это обязанность вызывающего кода (провайдера).
  /// Вызывающий должен закрыть БД ДО вызова этого метода и переоткрыть ПОСЛЕ.
  Future<bool> restoreFullBackup(String backupPath, Database currentDb) async {
    try {
      final currentDbPath = currentDb.path;
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) throw Exception('Файл бэкапа не найден');
      await backupFile.copy(currentDbPath);
      return true;
    } catch (e) {
      debugPrint('Ошибка восстановления БД: $e');
      return false;
    }
  }

  /// Замена таблицы целиком.
  /// Каждая таблица восстанавливается в отдельной транзакции,
  /// чтобы crash не оставлял таблицу пустой.
  Future<int> restoreTables(
    String backupPath,
    Database currentDb,
    List<String> tableNames,
  ) async {
    final backupDb = await openDatabase(backupPath);
    try {
      int totalInserted = 0;
      for (final table in tableNames) {
        final rows = await backupDb.query(table);
        if (rows.isEmpty) continue;
        await currentDb.transaction((txn) async {
          await txn.delete(table);
          for (final row in rows) {
            final mutableRow = Map<String, Object?>.from(row);
            mutableRow.remove('id');
            final id = await txn.insert(table, mutableRow);
            if (id > 0) totalInserted++;
          }
        });
      }
      return totalInserted;
    } finally {
      await backupDb.close();
    }
  }

  /// Получить список всех таблиц (кроме системных)
  Future<List<String>> getTableNames(Database currentDb) async {
    final result = await currentDb.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    return result.map((row) => row['name'] as String).toList();
  }

  /// Получить записи из указанной таблицы из бэкапа
  Future<List<Map<String, dynamic>>> getBackupTableData(
    String backupPath,
    String tableName,
  ) async {
    final backupDb = await openDatabase(backupPath);
    try {
      return await backupDb.query(tableName);
    } finally {
      await backupDb.close();
    }
  }

  /// Восстановить выбранные записи из бэкапа в текущую таблицу.
  /// Если запись с таким же id существует — обновляется, иначе вставляется.
  Future<int> restoreSelectedRows(
    String backupPath,
    Database currentDb,
    String tableName,
    List<int> rowIds,
  ) async {
    if (rowIds.isEmpty) return 0;

    final backupDb = await openDatabase(backupPath);
    try {
      final tableInfo = await currentDb.rawQuery(
        'PRAGMA table_info($tableName)',
      );
      final hasIdColumn = tableInfo.any((col) => col['name'] == 'id');

      final placeholders = rowIds.map((_) => '?').join(',');
      final rows = await backupDb.query(
        tableName,
        where: 'id IN ($placeholders)',
        whereArgs: rowIds,
      );

      if (rows.isEmpty) return 0;

      int processed = 0;
      for (final row in rows) {
        final mutableRow = Map<String, Object?>.from(row);
        final id = mutableRow['id'];
        if (hasIdColumn && id != null) {
          final existing = await currentDb.query(
            tableName,
            where: 'id = ?',
            whereArgs: [id],
          );
          mutableRow.remove('id');
          if (existing.isNotEmpty) {
            await currentDb.update(
              tableName,
              mutableRow,
              where: 'id = ?',
              whereArgs: [id],
            );
          } else {
            await currentDb.insert(tableName, mutableRow);
          }
        } else {
          mutableRow.remove('id');
          await currentDb.insert(tableName, mutableRow);
        }
        processed++;
      }
      return processed;
    } finally {
      await backupDb.close();
    }
  }

  /// Получить список id для всех записей в таблице бэкапа
  Future<List<int>> getBackupRowIds(String backupPath, String tableName) async {
    final backupDb = await openDatabase(backupPath);
    try {
      final result = await backupDb.query(tableName, columns: ['id']);
      return result.map((row) => row['id'] as int).toList();
    } finally {
      await backupDb.close();
    }
  }
}
