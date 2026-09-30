// lib/services/backup_service.dart
//
// Файловые копии базы и восстановление из них (Windows, Android).

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:kfh_domain/kfh_domain.dart' show DataSnapshot;
import 'package:kfh_local_db/native.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'app_database.dart';
import 'database_files.dart';
import 'local_backups.dart';
import 'platform.dart';

export 'local_backups.dart' show BackupInfo, BackupType, LocalBackups;

class BackupService implements LocalBackups {
  static const _maxDailyBackups = 5;

  /// Папка копий; по умолчанию — [backupsDirectory] (у отладочной сборки
  /// своя, чтобы `flutter run` не перезаписал копию рабочей базы); другая —
  /// для тестов.
  final String? backupDirectory;

  BackupService({this.backupDirectory});

  Future<Directory> _getBackupDirectory() async {
    final backupDir = Directory(backupDirectory ?? await backupsDirectory());
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
  @override
  Future<String?> createBackup(
    LocalDatabase db, {
    BackupType type = BackupType.daily,
  }) async {
    try {
      final backupDir = await _getBackupDirectory();
      final now = DateTime.now();

      String backupFileName;
      bool skipIfExists = false;

      if (type == BackupType.monthly) {
        final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
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
        debugPrint(
          'Ежемесячная копия за этот месяц уже существует: $backupPath',
        );
        return backupPath;
      }

      // VACUUM INTO — согласованный снимок открытой базы. Пишем во
      // временный файл: VACUUM INTO не перезаписывает существующий.
      final tmp = File('$backupPath.tmp');
      if (await tmp.exists()) await tmp.delete();
      await db.customStatement('VACUUM INTO ?', [tmp.path]);
      final target = File(backupPath);
      if (await target.exists()) await target.delete();
      await tmp.rename(backupPath);

      await _cleanupOldBackups(backupDir);
      return backupPath;
    } catch (e) {
      debugPrint('Ошибка создания бэкапа: $e');
      return null;
    }
  }

  /// Копия текущей базы перед рискованной операцией:
  /// `<prefix>_<дата-время>.db` (по умолчанию — перед восстановлением из
  /// другой копии), автоматически не удаляется. Бросает исключение, если
  /// копию сделать не удалось.
  @override
  Future<String> createSafetyBackup(
    LocalDatabase db, {
    String prefix = 'backup_before_restore',
  }) async {
    final backupDir = await _getBackupDirectory();
    final path = p.join(
      backupDir.path,
      '${prefix}_${_stamp(DateTime.now())}.db',
    );
    await db.customStatement('VACUUM INTO ?', [path]);
    return path;
  }

  static String _stamp(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}_'
        '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';
  }

  /// Копия старой базы (v8) перед переносом в формат v2.
  /// Имя `backup_v8_<дата-время>.db`; такие копии не удаляются автоматически.
  /// Бросает исключение, если копию сделать не удалось.
  Future<String> backupLegacyDatabase(String v8Path) async {
    final backupDir = await _getBackupDirectory();
    final now = DateTime.now();
    final backupPath = p.join(backupDir.path, 'backup_v8_${_stamp(now)}.db');
    await File(v8Path).copy(backupPath);
    // Копия сохраняет дату изменения оригинала — ставим текущую,
    // чтобы в списке копий было видно, когда она сделана.
    await File(backupPath).setLastModified(now);
    return backupPath;
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

  @override
  Future<List<BackupInfo>> getBackups() async {
    final backupDir = await _getBackupDirectory();
    return await _listBackupFiles(backupDir);
  }

  Future<List<BackupInfo>> _listBackupFiles(Directory backupDir) async {
    final entities = await backupDir.list().where((e) => e is File).toList();

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
          modified: (await file.stat()).modified,
        ),
      );
    }

    backups.sort((a, b) => b.created.compareTo(a.created));
    return backups;
  }

  @override
  Future<void> deleteBackup(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<String> folderPath() async => (await _getBackupDirectory()).path;

  @override
  Future<void> openFolder() async {
    final path = await folderPath();
    if (Platform.isWindows) {
      await Process.start('explorer.exe', [path]);
    }
  }

  @override
  Future<DataSnapshot> readSnapshot(String backupPath) async {
    detectBackupFormat(backupPath); // понятная ошибка до изолята
    final temp = Directory.systemTemp.path;
    return Isolate.run(
      () => readSnapshotFile(backupPath, tempDir: Directory(temp)),
    );
  }

  /// Таблицы копии (без служебных sqlite_*). Копия открывается только
  /// на чтение.
  @override
  Future<List<String>> getBackupTableNames(String backupPath) async {
    final db = sql.sqlite3.open(backupPath, mode: sql.OpenMode.readOnly);
    try {
      return db
          .select(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%' ORDER BY name",
          )
          .map((r) => r['name'] as String)
          .toList();
    } finally {
      db.close();
    }
  }

  /// Записи таблицы копии. Копия открывается только на чтение.
  @override
  Future<List<Map<String, dynamic>>> getBackupTableData(
    String backupPath,
    String tableName,
  ) async {
    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(tableName)) {
      throw ArgumentError('Недопустимое имя таблицы: $tableName');
    }
    final db = sql.sqlite3.open(backupPath, mode: sql.OpenMode.readOnly);
    try {
      return db
          .select('SELECT * FROM $tableName')
          .map((r) => Map<String, dynamic>.of(r))
          .toList();
    } finally {
      db.close();
    }
  }

  @override
  int backupSize(String path) => File(path).lengthSync();

  @override
  BackupFormat detectFormat(String backupPath) =>
      detectBackupFormat(backupPath);

  @override
  List<String> restorableTables(String backupPath) =>
      BackupRestorer.restorableTables(backupPath);

  @override
  Future<void> restoreFull(
    AppDatabase current,
    String backupPath, {
    required Future<void> Function() beforeReplace,
    required void Function(AppDatabase reopened) onReopened,
  }) async {
    final deviceId = await current.db.deviceId();
    final path = current.path;
    final prepared = '$path.restore';
    // Перенос v8 и сверка — в отдельном изоляте, чтобы не подвешивать окно.
    await Isolate.run(
      () => prepareFullRestore(
        backupPath: backupPath,
        targetPath: prepared,
        deviceId: deviceId,
      ),
    );
    await beforeReplace();
    await current.close();
    try {
      replaceDatabaseFile(prepared, path);
    } finally {
      onReopened(await openAppDatabaseFile(path));
    }
  }

  @override
  Future<int> restoreTable(LocalDatabase db, String backupPath, String table) =>
      BackupRestorer(db).restoreTable(backupPath, table);

  @override
  Future<int> restoreRows(
    LocalDatabase db,
    String backupPath,
    String table,
    List<String> uuids,
  ) => BackupRestorer(db).restoreRows(backupPath, table, uuids);
}
