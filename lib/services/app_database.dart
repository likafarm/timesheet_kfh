// lib/services/app_database.dart
//
// Открытая локальная база приложения (drift, схема v2) — на всех
// платформах. Открыть файл базы и перенести старую базу v8 —
// database_files.dart (Windows, Android), базу в браузере —
// web_database.dart.

import 'package:kfh_local_db/kfh_local_db.dart';

/// Открытая база и репозитории над ней.
class AppDatabase {
  final LocalDatabase db;
  final DriftRepositories repos;

  /// Путь к файлу базы v2 (в браузере — имя базы).
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
