@Tags(['mysql'])
library;

import 'dart:io';

import 'package:kfh_server/kfh_server.dart';
import 'package:test/test.dart';

/// Проверки на настоящей MySQL. Запуск — при поднятом стенде
/// `docker-compose.dev.yml`:
///
///   $env:KFH_TEST_MYSQL="1"; dart test -t mysql
///
/// Без `KFH_TEST_MYSQL` тесты пропускаются.
void main() {
  final enabled = Platform.environment['KFH_TEST_MYSQL'] == '1';
  final env = Platform.environment;

  DbConfig config({String? password}) => DbConfig(
        host: env['KFH_TEST_DB_HOST'] ?? '127.0.0.1',
        port: int.parse(env['KFH_TEST_DB_PORT'] ?? '3307'),
        database: env['KFH_TEST_DB_NAME'] ?? 'kfh',
        user: env['KFH_TEST_DB_USER'] ?? 'kfh_api',
        password: password ?? env['KFH_TEST_DB_PASSWORD'] ?? 'dev-api',
        maxConnections: 2,
      );

  test('подключение по TLS, кодировка utf8mb4', () async {
    final db = MySqlDatabase.connect(config());
    addTearDown(db.close);
    await db.ping();
    final result = await db.execute(
        "SELECT @@character_set_connection AS cs, "
        "CONVERT('Иванов 🌾' USING utf8mb4) AS text, "
        "(SELECT VARIABLE_VALUE FROM performance_schema.session_status "
        " WHERE VARIABLE_NAME = 'Ssl_cipher') AS cipher");
    final row = result.rows.single;
    expect(row.colByName('cs'), 'utf8mb4');
    expect(row.colByName('text'), 'Иванов 🌾');
    expect(row.colByName('cipher'), isNotEmpty);
  }, skip: enabled ? false : 'нет KFH_TEST_MYSQL=1');

  test('соединение убито на стороне MySQL — пул восстанавливается сам',
      () async {
    final db = MySqlDatabase.connect(config());
    addTearDown(db.close);
    final id = (await db.execute('SELECT CONNECTION_ID() AS id'))
        .rows
        .single
        .colByName('id');
    final killer = MySqlDatabase.connect(config());
    addTearDown(killer.close);
    await killer.execute('KILL $id');

    // Клиент узнаёт о закрытии сокета не мгновенно: один запрос может
    // упасть, но дальше пул должен открыть новое соединение.
    Object? lastError;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final newId = (await db.execute('SELECT CONNECTION_ID() AS id'))
            .rows
            .single
            .colByName('id');
        expect(newId, isNot(id));
        return;
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    fail('пул не восстановился: $lastError');
  }, skip: enabled ? false : 'нет KFH_TEST_MYSQL=1');

  test('неверный пароль — ping бросает ошибку', () async {
    final db = MySqlDatabase.connect(config(password: 'wrong'));
    addTearDown(db.close);
    await expectLater(db.ping(), throwsA(anything));
  }, skip: enabled ? false : 'нет KFH_TEST_MYSQL=1');
}
