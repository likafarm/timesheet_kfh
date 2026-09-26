import 'package:mysql_client_plus/mysql_client_plus.dart';

import 'config.dart';
import 'pool.dart';

/// Доступ сервера к MySQL. Пока — только проверка связи; запросы
/// появятся вместе со схемой (шаг 2.2).
abstract interface class Database {
  /// Проверка, что база отвечает. Бросает исключение, если нет.
  Future<void> ping();

  Future<void> close();
}

class MySqlDatabase implements Database {
  final ConnectionPool<MySQLConnection> pool;

  MySqlDatabase(this.pool);

  factory MySqlDatabase.connect(DbConfig config) => MySqlDatabase(
        ConnectionPool<MySQLConnection>(
          maxConnections: config.maxConnections,
          open: () async {
            final connection = await MySQLConnection.createConnection(
              host: config.host,
              port: config.port,
              userName: config.user,
              password: config.password,
              databaseName: config.database,
              secure: config.secure,
              // По умолчанию пакет берёт utf8mb4_general_ci; берём
              // сравнение MySQL 8 по умолчанию.
              collation: 'utf8mb4_0900_ai_ci',
            );
            await connection.connect(timeoutMs: 5000);
            // Все моменты времени в базе — UTC (CURRENT_TIMESTAMP, NOW()).
            await connection.execute("SET time_zone = '+00:00'");
            return connection;
          },
          isAlive: (connection) => connection.connected,
          close: (connection) => connection.close(),
        ),
      );

  /// Запрос на любом свободном соединении пула.
  Future<IResultSet> execute(String sql, [Map<String, dynamic>? params]) =>
      pool.withConnection((connection) => connection.execute(sql, params));

  @override
  Future<void> ping() async {
    await execute('SELECT 1');
  }

  @override
  Future<void> close() => pool.close();
}
