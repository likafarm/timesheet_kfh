import 'dart:async';
import 'dart:io';

import 'package:kfh_server/kfh_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Запуск: `dart run bin/server.dart` (настройки — из переменных окружения,
/// см. `ServerConfig`).
///
/// `server healthcheck` — проверка для Docker: запрос к `/health` на своём
/// порту, код выхода 0 — сервер и база в порядке. В образе нет curl.
Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == 'healthcheck') {
    exit(await _healthcheck());
  }

  final logger = Logger();
  final ServerConfig config;
  try {
    config = ServerConfig.fromEnvironment(Platform.environment);
  } on ConfigException catch (e) {
    logger.error(e.toString());
    exit(78); // EX_CONFIG
  }

  final db = MySqlDatabase.connect(config.db);
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
