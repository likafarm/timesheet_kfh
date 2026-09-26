// lib/services/app_database.dart
//
// Открытие локальной базы приложения (drift, схема v2).
//
// При первом запуске версии с drift старая база (sqflite, v8) переносится
// в новый файл конвертером из kfh_local_db: сначала копия старой базы в
// резервные, затем перенос со сверкой. Старый файл не меняется. Если
// перенос не прошёл — программа не открывает ни одну базу и показывает
// причину; при следующем запуске перенос повторяется.

import 'dart:io';
import 'dart:isolate';

import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:path/path.dart' as p;

import 'db_location.dart';

/// Открытая база и репозитории над ней.
class AppDatabase {
  final LocalDatabase db;
  final DriftRepositories repos;

  /// Путь к файлу базы v2.
  final String path;

  AppDatabase(this.db, this.path) : repos = DriftRepositories(db);

  Future<void> close() => db.close();
}

/// База не открыта; [message] показывается пользователю.
class DatabaseOpenException implements Exception {
  final String message;
  const DatabaseOpenException(this.message);

  @override
  String toString() => message;
}

/// Открывает базу v2 в [dataDir], при необходимости перенося в неё старую
/// базу v8 (из [dataDir] или, раньше, из [legacyDirs]).
///
/// [backupLegacy] делает копию старой базы перед переносом и возвращает
/// путь к копии; без копии перенос не начинается.
Future<AppDatabase> openAppDatabase({
  required String dataDir,
  required List<String> legacyDirs,
  required Future<String> Function(String v8Path) backupLegacy,
  Future<void> Function(String message)? log,
}) async {
  final write = log ?? (_) async {};
  final v2Path = p.join(dataDir, dbV2FileName);

  if (!File(v2Path).existsSync()) {
    final location = await resolveDatabasePath(
      dataDir: dataDir,
      legacyDirs: legacyDirs,
    );
    if (location.migratedFrom != null) {
      await write(
        'База перенесена: ${location.migratedFrom} -> ${location.path}',
      );
    }
    if (location.error != null) await write(location.error!);

    final v8Path = location.path;
    if (File(v8Path).existsSync()) {
      await _convert(v8Path, v2Path, backupLegacy, write);
    }
  }

  try {
    final db = LocalDatabase.file(File(v2Path));
    // Открываем сразу: ошибка открытия — здесь, а не на первом экране.
    await db.deviceId();
    return AppDatabase(db, v2Path);
  } catch (e) {
    await write('Не удалось открыть базу $v2Path: $e');
    throw DatabaseOpenException(
      'Не удалось открыть базу данных:\n$v2Path\n\n$e',
    );
  }
}

Future<void> _convert(
  String v8Path,
  String v2Path,
  Future<String> Function(String v8Path) backupLegacy,
  Future<void> Function(String message) write,
) async {
  final String backup;
  try {
    backup = await backupLegacy(v8Path);
  } catch (e) {
    await write('Нет резервной копии перед переносом базы: $e');
    throw DatabaseOpenException(
      'Не удалось сделать резервную копию базы перед переходом '
      'на новый формат:\n$e\n\nБаза не изменена: $v8Path',
    );
  }
  await write('Копия старой базы перед переносом: $backup');

  try {
    // Перенос с построчной сверкой — в отдельном изоляте, чтобы не
    // подвешивать окно.
    final report = await Isolate.run(
      () => convertV8ToV2(sourcePath: v8Path, targetPath: v2Path),
    );
    await write('База перенесена в формат v2: $v8Path -> $v2Path\n$report');
  } catch (e) {
    await write('Перенос базы в формат v2 не выполнен: $e');
    throw DatabaseOpenException(
      'Не удалось перенести базу в новый формат.\n\n$e\n\n'
      'Старая база не изменена: $v8Path\n'
      'Копия: $backup',
    );
  }
}
