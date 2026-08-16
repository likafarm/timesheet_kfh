// lib/services/backup_service.dart

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

class BackupInfo {
  final String path;
  final String fileName;
  final DateTime created;

  BackupInfo({
    required this.path,
    required this.fileName,
    required this.created,
  });

  @override
  String toString() => fileName;
}

class BackupService {
  static const _maxBackups = 10;
  static const _backupDirName = 'backups';

  Future<Directory> _getBackupDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(appDocDir.path, _backupDirName));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<String?> createBackup(Database db) async {
    try {
      final dbPath = db.path;
      final backupDir = await _getBackupDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final backupFileName = 'backup_$timestamp.db';
      final backupPath = p.join(backupDir.path, backupFileName);

      final sourceFile = File(dbPath);
      if (!await sourceFile.exists()) {
        throw Exception('Файл базы данных не найден');
      }
      await sourceFile.copy(backupPath);
      await _cleanupOldBackups(backupDir);
      return backupPath;
    } catch (e) {
      debugPrint('Ошибка создания бэкапа: $e');
      return null;
    }
  }

  Future<void> _cleanupOldBackups(Directory backupDir) async {
    final files = await _listBackupFiles(backupDir);
    if (files.length <= _maxBackups) return;
    files.sort((a, b) => b.created.compareTo(a.created));
    final toDelete = files.skip(_maxBackups);
    for (var info in toDelete) {
      try {
        final file = File(info.path);
        if (await file.exists()) await file.delete();
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
    final files = await backupDir
        .list()
        .where((entity) => entity is File)
        .toList();
    final backups = <BackupInfo>[];
    for (var entity in files) {
      final file = entity as File;
      final fileName = p.basename(file.path);
      if (!fileName.startsWith('backup_') || !fileName.endsWith('.db')) {
        continue;
      }
      final datePart = fileName.substring(7, fileName.length - 3);
      DateTime created;
      try {
        final normalized = datePart.replaceAll('-', ':');
        created = DateTime.parse(normalized);
      } catch (_) {
        final stat = await file.stat();
        created = stat.modified;
      }
      backups.add(
        BackupInfo(path: file.path, fileName: fileName, created: created),
      );
    }
    backups.sort((a, b) => b.created.compareTo(a.created));
    return backups;
  }

  Future<void> deleteBackup(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<bool> restoreFullBackup(String backupPath, Database currentDb) async {
    try {
      await currentDb.close();
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

  /// Замена таблицы целиком (как было)
  Future<int> restoreTables(
    String backupPath,
    Database currentDb,
    List<String> tableNames,
  ) async {
    final backupDb = await openDatabase(backupPath);
    try {
      int totalInserted = 0;
      for (var table in tableNames) {
        final rows = await backupDb.query(table);
        if (rows.isEmpty) continue;
        await currentDb.delete(table);
        for (var row in rows) {
          row.remove('id');
          final id = await currentDb.insert(table, row);
          if (id > 0) totalInserted++;
        }
      }
      return totalInserted;
    } finally {
      await backupDb.close();
    }
  }

  // ---- НОВЫЕ МЕТОДЫ ДЛЯ ВЫБОРОЧНОГО ВОССТАНОВЛЕНИЯ ЗАПИСЕЙ ----

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

  /// Восстановить выбранные записи из бэкапа в текущую таблицу
  /// Если запись с таким же id существует, она обновляется, иначе вставляется
  /// Возвращает количество обработанных записей
  Future<int> restoreSelectedRows(
    String backupPath,
    Database currentDb,
    String tableName,
    List<int> rowIds, // список id записей, которые нужно восстановить
  ) async {
    if (rowIds.isEmpty) return 0;

    final backupDb = await openDatabase(backupPath);
    try {
      // Получаем структуру таблицы, чтобы понять, есть ли поле id
      final tableInfo = await currentDb.rawQuery(
        "PRAGMA table_info($tableName)",
      );
      final hasIdColumn = tableInfo.any((col) => col['name'] == 'id');

      // Загружаем записи из бэкапа с указанными id
      final placeholders = rowIds.map((_) => '?').join(',');
      final rows = await backupDb.query(
        tableName,
        where: 'id IN ($placeholders)',
        whereArgs: rowIds,
      );

      if (rows.isEmpty) return 0;

      int processed = 0;
      for (var row in rows) {
        final id = row['id'];
        if (hasIdColumn && id != null) {
          // Проверяем, существует ли запись с таким id в текущей БД
          final existing = await currentDb.query(
            tableName,
            where: 'id = ?',
            whereArgs: [id],
          );
          if (existing.isNotEmpty) {
            // Обновляем
            row.remove('id');
            await currentDb.update(
              tableName,
              row,
              where: 'id = ?',
              whereArgs: [id],
            );
          } else {
            // Вставляем с сохранением id (если разрешено автоинкремент, то id будет проигнорирован)
            // В SQLite при вставке с указанным id автоинкремент не сработает, если явно задать
            // Поэтому мы просто вставляем, удалив id, чтобы генерировался новый
            row.remove('id');
            await currentDb.insert(tableName, row);
          }
        } else {
          // Таблица без id – вставляем как есть
          row.remove('id');
          await currentDb.insert(tableName, row);
        }
        processed++;
      }
      return processed;
    } finally {
      await backupDb.close();
    }
  }

  /// Получить список id для всех записей в таблице бэкапа (для выбора)
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
