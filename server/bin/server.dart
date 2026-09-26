import 'dart:async';
import 'dart:io';

import 'package:kfh_server/kfh_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Запуск: `dart run bin/server.dart` (настройки — из переменных окружения,
/// см. `ServerConfig`).
///
/// Команды:
/// - без аргументов — сервер. Если миграции не применены, не стартует
///   (или применяет их при `MIGRATE_ON_START=true`);
/// - `migrate` — применить миграции и выйти (на VPS — после резервной
///   копии, из `deploy.sh`);
/// - `healthcheck` — проверка для Docker: запрос к `/health` на своём
///   порту, код выхода 0 — сервер и база в порядке. В образе нет curl.
Future<void> main(List<String> args) async {
  final command = args.isEmpty ? 'serve' : args.first;
  if (command == 'healthcheck') exit(await _healthcheck());
  if (command != 'serve' && command != 'migrate') {
    stderr.writeln('Неизвестная команда: $command (есть: migrate, '
        'healthcheck)');
    exit(64); // EX_USAGE
  }

  final logger = Logger();
  final ServerConfig config;
  final List<Migration> migrations;
  try {
    config = ServerConfig.fromEnvironment(Platform.environment);
    migrations = loadMigrations(Directory(config.migrationsDir));
  } on ConfigException catch (e) {
    logger.error(e.toString());
    exit(78); // EX_CONFIG
  } on MigrationException catch (e) {
    logger.error(e.toString());
    exit(78);
  }

  final db = MySqlDatabase.connect(config.db);
  final runner = MigrationRunner(db, logger);
  try {
    if (command == 'migrate') {
      final applied = await runner.migrate(migrations);
      logger.info('миграции применены', {
        'applied': applied.map((m) => m.toString()).toList(),
        'total': migrations.length,
      });
      await db.close();
      exit(0);
    }
    final status = await runner.status(migrations);
    if (status.problems.isNotEmpty) {
      throw MigrationException(status.problems.join('; '));
    }
    if (status.pending.isNotEmpty) {
      if (!config.migrateOnStart) {
        throw MigrationException('не применены миграции '
            '${status.pending.join(', ')} — запустите «server migrate» '
            '(после резервной копии базы)');
      }
      await runner.migrate(migrations);
    }
  } catch (e, st) {
    logger.error(e is MigrationException ? e.toString() : 'нет доступа к базе',
        error: e is MigrationException ? null : e,
        stackTrace: e is MigrationException ? null : st);
    await db.close();
    exit(1);
  }

  final handler = buildHandler(db: db, logger: logger);
  final server =
      await shelf_io.serve(handler, InternetAddress.anyIPv4, config.port);
  server.autoCompress = true;
  logger.info('сервер запущен', {
    'version': serverVersion,
    'port': server.port,
    'db_host': config.db.host,
    'db_name': config.db.database,
  });

  // Docker останавливает контейнер сигналом SIGTERM: даём закончить
  // текущие запросы и закрываем соединения с базой.
  var stopping = false;
  Future<void> stop(ProcessSignal signal) async {
    if (stopping) return;
    stopping = true;
    logger.info('остановка', {'signal': signal.toString()});
    await server.close();
    await db.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(stop);
  if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(stop);
}

Future<int> _healthcheck() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final request = await client
        .get(InternetAddress.loopbackIPv4.address, port, '/health')
        .timeout(const Duration(seconds: 5));
    final response =
        await request.close().timeout(const Duration(seconds: 5));
    await response.drain<void>();
    return response.statusCode == 200 ? 0 : 1;
  } catch (_) {
    return 1;
  } finally {
    client.close(force: true);
  }
}
