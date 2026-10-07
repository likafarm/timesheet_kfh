// Обновление схемы файла базы на месте (Windows, Android): перед первой
// миграцией drift — копия файла рядом с базой. Без копии обновление не
// начинается.

import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sql;

import '../backup_restore.dart';

/// Версия схемы файла (`PRAGMA user_version`); null — файла нет, 0 — файл
/// пуст или не база программы.
int? databaseFileVersion(String path) {
  if (!File(path).existsSync()) return null;
  final db = sql.sqlite3.open(path, mode: sql.OpenMode.readOnly);
  try {
    return db.select('PRAGMA user_version').first.values.first as int;
  } finally {
    db.close();
  }
}

/// Префикс копий перед обновлением схемы.
const upgradeBackupPrefix = 'backup_before_migration_';

/// Если схема файла [path] старше [targetVersion] (и файл — база
/// программы), делает его копию `backup_before_migration_v<цель>_<время>.db`
/// рядом с ним и возвращает путь к копии; иначе — null. Хранятся [keep]
/// последних копий. Копия — `VACUUM INTO`: целая, даже если рядом
/// остался журнал.
String? backupBeforeUpgrade(
  String path, {
  int targetVersion = currentSchemaVersion,
  DateTime Function()? clock,
  int keep = 3,
}) {
  final version = databaseFileVersion(path);
  if (version == null || version == 0 || version >= targetVersion) return null;

  final now = (clock ?? DateTime.now)();
  String two(int v) => v.toString().padLeft(2, '0');
  final stamp =
      '${now.year}${two(now.month)}${two(now.day)}-'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  final dir = File(path).parent;
  final target =
      '${dir.path}${Platform.pathSeparator}'
      '${upgradeBackupPrefix}v${targetVersion}_$stamp.db';
  final db = sql.sqlite3.open(path);
  try {
    db.execute('VACUUM INTO ?', [target]);
  } finally {
    db.close();
  }

  final copies =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.uri.pathSegments.last.startsWith(upgradeBackupPrefix))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
  for (final old in copies.skip(keep)) {
    old.deleteSync();
  }
  return target;
}
