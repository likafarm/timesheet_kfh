import 'package:mysql_client_plus/mysql_client_plus.dart';

import 'config.dart';
import 'pool.dart';

/// Доступ сервера к базе, нужный `/health`.
abstract interface class Database {
  /// Проверка, что база отвечает. Бросает исключение, если нет.
  Future<void> ping();

  Future<void> close();
}

/// Режим SQL каждого соединения: строгий (ошибка вместо молчаливой порчи
/// данных) и без NO_BACKSLASH_ESCAPES — драйвер экранирует параметры
/// обратной косой чертой, без неё экранирование было бы небезопасным.
const _sqlMode = 'STRICT_TRANS_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,'
    'NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

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
            await connection.execute(
                "SET time_zone = '+00:00', sql_mode = '$_sqlMode'");
            return connection;
          },
          isAlive: (connection) => connection.connected,
          close: (connection) => connection.close(),
        ),
      );

  /// Запрос на любом свободном соединении пула.
  Future<IResultSet> execute(String sql, [Map<String, dynamic>? params]) =>
      pool.withConnection((connection) => connection.execute(sql, params));

  /// Транзакция на одном соединении: COMMIT, если [action] завершилось,
  /// иначе ROLLBACK и исключение дальше. Если не удался и ROLLBACK,
  /// соединение закрывается — пул его выбросит, незавершённая транзакция
  /// не достанется следующему запросу.
  Future<T> transaction<T>(
          Future<T> Function(MySQLConnection connection) action) =>
      pool.withConnection((connection) async {
        await connection.execute('START TRANSACTION');
        final T result;
        try {
          result = await action(connection);
        } catch (_) {
          try {
            await connection.execute('ROLLBACK');
          } catch (_) {
            await connection.close();
          }
          rethrow;
        }
        await connection.execute('COMMIT');
        return result;
      });

  @override
  Future<void> ping() async {
    await execute('SELECT 1');
  }

  @override
  Future<void> close() => pool.close();
}
