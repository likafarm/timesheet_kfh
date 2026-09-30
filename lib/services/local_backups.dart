// lib/services/local_backups.dart
//
// Резервные копии базы в файлах и восстановление из них — есть в программе
// для Windows и Android ([BackupService]). В веб-версии их нет: база
// браузера — копия данных сервера, а сервер копируется сам (этап 2.8).

import 'package:kfh_domain/kfh_domain.dart' show DataSnapshot;
import 'package:kfh_local_db/kfh_local_db.dart';

import 'app_database.dart';

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

  /// Когда файл записан последний раз (ежедневная копия за день
  /// перезаписывается — это и есть момент снимка).
  final DateTime? modified;

  BackupInfo({
    required this.path,
    required this.fileName,
    required this.created,
    required this.type,
    this.modified,
  });

  /// Момент снимка: время записи файла, если известно.
  DateTime get takenAt => modified ?? created;

  @override
  String toString() => fileName;
}

/// Файловые копии базы и восстановление из них.
abstract interface class LocalBackups {
  /// Копия заданного типа; null — не получилось (причина — в журнале).
  Future<String?> createBackup(
    LocalDatabase db, {
    BackupType type = BackupType.daily,
  });

  /// Копия перед рискованной операцией; бросает исключение, если не вышло.
  Future<String> createSafetyBackup(
    LocalDatabase db, {
    String prefix = 'backup_before_restore',
  });

  Future<List<BackupInfo>> getBackups();

  Future<void> deleteBackup(String path);

  /// Папка копий.
  Future<String> folderPath();

  /// Открыть папку копий в проводнике.
  Future<void> openFolder();

  /// Все записи копии (любого формата) — для просмотра и сравнения;
  /// копия открывается только на чтение. Неизвестный или повреждённый
  /// файл — [RestoreException].
  Future<DataSnapshot> readSnapshot(String backupPath);

  /// Размер файла копии в байтах.
  int backupSize(String path);

  Future<List<String>> getBackupTableNames(String backupPath);

  Future<List<Map<String, dynamic>>> getBackupTableData(
    String backupPath,
    String tableName,
  );

  /// Формат копии; неизвестный или повреждённый файл — [RestoreException].
  BackupFormat detectFormat(String backupPath);

  /// Таблицы копии, которые можно восстановить по отдельности.
  List<String> restorableTables(String backupPath);

  /// Заменяет всю базу [current] копией (любого формата, v8 — через
  /// конвертер): готовит новый файл, вызывает [beforeReplace], закрывает
  /// [current], подменяет файл и открывает базу заново — [onReopened]
  /// вызывается и тогда, когда подмена не удалась (открыта прежняя база, а
  /// исключение пробрасывается).
  Future<void> restoreFull(
    AppDatabase current,
    String backupPath, {
    required Future<void> Function() beforeReplace,
    required void Function(AppDatabase reopened) onReopened,
  });

  Future<int> restoreTable(LocalDatabase db, String backupPath, String table);

  Future<int> restoreRows(
    LocalDatabase db,
    String backupPath,
    String table,
    List<String> uuids,
  );
}
