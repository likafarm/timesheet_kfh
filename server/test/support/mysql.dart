import 'dart:io';
import 'dart:math';

import 'package:kfh_server/kfh_server.dart';

/// Настройки тестов на MySQL стенда `docker-compose.dev.yml`.
///
/// Включаются `KFH_TEST_MYSQL=1`; хост, порт и учётки — `KFH_TEST_DB_*`.
final _env = Platform.environment;

final bool mysqlEnabled = _env['KFH_TEST_MYSQL'] == '1';

/// Причина пропуска для `skip:` (null — тесты идут).
final String? mysqlSkip = mysqlEnabled ? null : 'нет KFH_TEST_MYSQL=1';

DbConfig testDbConfig({
  String? database,
  String? user,
  String? password,
  int maxConnections = 2,
}) =>
    DbConfig(
      host: _env['KFH_TEST_DB_HOST'] ?? '127.0.0.1',
      port: int.parse(_env['KFH_TEST_DB_PORT'] ?? '3307'),
      database: database ?? _env['KFH_TEST_DB_NAME'] ?? 'kfh',
      user: user ?? _env['KFH_TEST_DB_USER'] ?? 'kfh_api',
      password: password ?? _env['KFH_TEST_DB_PASSWORD'] ?? 'dev-api',
      maxConnections: maxConnections,
    );

/// Отдельная пустая база на время теста (создаёт и удаляет root).
class TestDatabase {
  final String name;
  final MySqlDatabase db;
  final MySqlDatabase _admin;

  TestDatabase._(this.name, this.db, this._admin);

  static Future<TestDatabase> create({int maxConnections = 2}) async {
    final rootPassword = _env['KFH_TEST_DB_ROOT_PASSWORD'] ?? 'dev-root';
    final admin = MySqlDatabase.connect(testDbConfig(
        database: 'mysql', user: 'root', password: rootPassword));
    final suffix = Random().nextInt(1 << 32).toRadixString(16);
    final name = 'kfh_test_$suffix';
    await admin.execute('CREATE DATABASE `$name` '
        'CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci');
    final db = MySqlDatabase.connect(testDbConfig(
        database: name,
        user: 'root',
        password: rootPassword,
        maxConnections: maxConnections));
    return TestDatabase._(name, db, admin);
  }

  Future<void> dispose() async {
    await db.close();
    await _admin.execute('DROP DATABASE IF EXISTS `$name`');
    await _admin.close();
  }
}

/// Миграции из папки `server/migrations` (тесты запускаются из `server/`).
List<Migration> projectMigrations() => loadMigrations(Directory('migrations'));
