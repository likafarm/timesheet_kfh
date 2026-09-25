// lib/services/db_location.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Имя файла базы данных.
const dbFileName = 'kfx_time_tracking.db';

/// Соседние файлы SQLite, которые переносятся вместе с базой.
const _sidecarSuffixes = ['-wal', '-shm', '-journal'];

/// Результат выбора пути к базе.
class DbLocation {
  /// Путь, по которому нужно открыть базу.
  final String path;

  /// Откуда скопирована база при переносе (null — переноса не было).
  final String? migratedFrom;

  /// Ошибка переноса (null — ошибок не было). При ошибке [path] указывает
  /// на старую базу, чтобы программа работала как раньше.
  final String? error;

  const DbLocation(this.path, {this.migratedFrom, this.error});
}

/// Определяет путь к базе в [dataDir] и при необходимости переносит туда
/// старую базу из [legacyDirs] (первая найденная по порядку).
///
/// - Если база в [dataDir] уже есть — используется она, старые не трогаются.
/// - Иначе старая база копируется во временный файл, проверяется
///   ([validate], по умолчанию `integrity_check` + наличие таблиц) и только
///   потом получает итоговое имя. Оригинал остаётся на месте.
/// - Если проверка не прошла — возвращается путь к старой базе и [DbLocation.error].
/// - Если старой базы нет — путь к новой (пустой) базе в [dataDir].
///
/// Одновременные вызовы для одной [dataDir] получают общий результат.
Future<DbLocation> resolveDatabasePath({
  required String dataDir,
  required List<String> legacyDirs,
  Future<void> Function(String path)? validate,
}) {
  final key = p.canonicalize(dataDir);
  return _inFlight.putIfAbsent(
    key,
    // Тело в фигурных скобках: `remove` вернул бы этот же Future,
    // и whenComplete ждал бы сам себя.
    () => _resolve(dataDir, legacyDirs, validate).whenComplete(() {
      _inFlight.remove(key);
    }),
  );
}

final _inFlight = <String, Future<DbLocation>>{};

Future<DbLocation> _resolve(
  String dataDir,
  List<String> legacyDirs,
  Future<void> Function(String path)? validate,
) async {
  final target = p.join(dataDir, dbFileName);
  if (await File(target).exists()) return DbLocation(target);

  await Directory(dataDir).create(recursive: true);

  final legacy = await _findLegacy(legacyDirs, target);
  if (legacy == null) return DbLocation(target);

  final tmp = '$target.tmp';
  try {
    await _deleteWithSidecars(tmp);
    await File(legacy).copy(tmp);
    for (final s in _sidecarSuffixes) {
      final side = File('$legacy$s');
      if (await side.exists()) await side.copy('$tmp$s');
    }

    await (validate ?? validateDatabase)(tmp);

    await File(tmp).rename(target);
    for (final s in _sidecarSuffixes) {
      final side = File('$tmp$s');
      if (await side.exists()) await side.rename('$target$s');
    }
    return DbLocation(target, migratedFrom: legacy);
  } catch (e) {
    await _deleteWithSidecars(tmp);
    return DbLocation(legacy, error: 'Не удалось перенести базу: $e');
  }
}

/// Проверяет, что файл — целая база программы. Бросает исключение, если нет.
Future<void> validateDatabase(String path) async {
  final db = await databaseFactoryFfi.openDatabase(path);
  try {
    final check = await db.rawQuery('PRAGMA integrity_check');
    final result = check.isEmpty ? null : check.first.values.first;
    if (result != 'ok') {
      throw StateError('integrity_check: $result');
    }
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'employees'",
    );
    if (tables.isEmpty) {
      throw StateError('в базе нет таблицы employees');
    }
  } finally {
    await db.close();
  }
}

Future<String?> _findLegacy(List<String> dirs, String target) async {
  final seen = <String>{p.canonicalize(target)};
  for (final dir in dirs) {
    final candidate = p.join(dir, dbFileName);
    if (!seen.add(p.canonicalize(candidate))) continue;
    if (await File(candidate).exists()) return candidate;
  }
  return null;
}

Future<void> _deleteWithSidecars(String path) async {
  for (final s in ['', ..._sidecarSuffixes]) {
    final f = File('$path$s');
    if (await f.exists()) await f.delete();
  }
}

/// Дописывает строку в `db_location.log` в папке данных программы.
/// Ошибки записи журнала не мешают запуску.
Future<void> logDbLocation(String message) async {
  debugPrint(message);
  try {
    final file = File(p.join(appDataDirectory(), 'db_location.log'));
    await file.writeAsString('${DateTime.now().toIso8601String()} $message\n',
        mode: FileMode.append, flush: true);
  } catch (_) {}
}

/// Папка данных программы: `%LOCALAPPDATA%\KFH Time Tracking`.
/// Отладочная сборка использует отдельную папку, чтобы `flutter run`
/// не смешивал тестовую базу с рабочей.
String appDataDirectory() {
  final base = Platform.environment['LOCALAPPDATA'];
  if (base == null || base.isEmpty) {
    throw StateError('Не задана переменная окружения LOCALAPPDATA');
  }
  final name = kDebugMode ? 'KFH Time Tracking (debug)' : 'KFH Time Tracking';
  return p.join(base, name);
}

/// Папки, где база лежала до версии с переносом в AppData.
/// `sqflite_common_ffi` строил путь от рабочей папки процесса, поэтому
/// сначала проверяется папка программы, затем текущая рабочая папка.
List<String> legacyDatabaseDirectories() {
  const rel = ['.dart_tool', 'sqflite_common_ffi', 'databases'];
  return [
    p.joinAll([p.dirname(Platform.resolvedExecutable), ...rel]),
    p.joinAll([Directory.current.path, ...rel]),
  ];
}
