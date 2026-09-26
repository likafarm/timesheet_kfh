import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:kfh_server/kfh_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

const _usage = '''
Команды:
  (без аргументов)             сервер API
  migrate                      применить миграции и выйти
  create-admin <логин> <ФИО>   первый администратор (пока админов нет)
  set-password <логин>         задать пароль пользователю из консоли
  healthcheck                  проверка для Docker (код 0 — всё в порядке)
Пароль команды спрашивают в консоли (или читают первую строку stdin).''';

/// Запуск: `dart run bin/server.dart [команда]` (настройки — из переменных
/// окружения, см. `ServerConfig`).
///
/// - сервер без применённых миграций не стартует (или применяет их при
///   `MIGRATE_ON_START=true`);
/// - `migrate` — на VPS после резервной копии, из `deploy.sh`;
/// - `create-admin`, `set-password` — из консоли сервера:
///   `docker compose run --rm api create-admin ivan "Иванов Иван"`;
/// - `healthcheck` — запрос к `/health` на своём порту (в образе нет curl).
Future<void> main(List<String> args) async {
  final command = args.isEmpty ? 'serve' : args.first;
  if (command == 'healthcheck') exit(await _healthcheck());
  final known = {'serve', 'migrate', 'create-admin', 'set-password'};
  if (!known.contains(command) ||
      (command == 'create-admin' && args.length < 3) ||
      (command == 'set-password' && args.length != 2)) {
    stderr.writeln(_usage);
    exit(64); // EX_USAGE
  }

  final logger = Logger();
  final ServerConfig config;
  final List<Migration> migrations;
  try {
    config = ServerConfig.fromEnvironment(Platform.environment);
    if (command == 'serve') config.requireJwtSecret();
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
      if (command != 'serve' || !config.migrateOnStart) {
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

  if (command == 'create-admin' || command == 'set-password') {
    exit(await _consoleCommand(command, args, db, logger));
  }

  final auth = AuthService(
    db: db,
    accessTokens: AccessTokens(utf8.encode(config.requireJwtSecret())),
    logger: logger,
  );
  final authApi = AuthApi(auth, trustProxy: config.trustProxy);
  final handler = buildHandler(
    db: db,
    logger: logger,
    authApi: authApi,
    syncApi: SyncApi(SyncService(db: db, logger: logger), authApi),
  );
  final server =
      await shelf_io.serve(handler, InternetAddress.anyIPv4, config.port);
  server.autoCompress = true;
  logger.info('сервер запущен', {
    'version': serverVersion,
    'port': server.port,
    'db_host': config.db.host,
    'db_name': config.db.database,
    'trust_proxy': config.trustProxy,
  });

  // Уборка давно истёкших refresh-токенов: при старте и раз в сутки.
  Future<void> cleanup() async {
    try {
      await const RefreshTokenStore()
          .deleteExpired(db.execute, DateTime.now().toUtc());
    } catch (e) {
      logger.warning('уборка токенов не удалась', {'error': e.toString()});
    }
  }

  unawaited(cleanup());
  final cleanupTimer =
      Timer.periodic(const Duration(days: 1), (_) => unawaited(cleanup()));

  // Docker останавливает контейнер сигналом SIGTERM: даём закончить
  // текущие запросы и закрываем соединения с базой.
  var stopping = false;
  Future<void> stop(ProcessSignal signal) async {
    if (stopping) return;
    stopping = true;
    logger.info('остановка', {'signal': signal.toString()});
    cleanupTimer.cancel();
    await server.close();
    await db.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(stop);
  if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(stop);
}

Future<int> _consoleCommand(
    String command, List<String> args, MySqlDatabase db, Logger logger) async {
  // Токены консоль не выдаёт — ключ подписи ей не нужен.
  final random = Random.secure();
  final auth = AuthService(
    db: db,
    accessTokens: AccessTokens(List.generate(32, (_) => random.nextInt(256))),
    logger: logger,
  );
  try {
    final login = args[1];
    final password = _readPassword();
    if (command == 'create-admin') {
      final user = await auth.createFirstAdmin(
          login: login, fullName: args.sublist(2).join(' '), password: password);
      stdout.writeln('Администратор создан: ${user.login} (${user.fullName})');
    } else {
      await auth.setPasswordFromConsole(login, password);
      stdout.writeln('Пароль пользователя $login изменён, все его входы '
          'завершены');
    }
    return 0;
  } on ApiException catch (e) {
    stderr.writeln(e.message);
    return 1;
  } on StateError catch (e) {
    stderr.writeln(e.message);
    return 1;
  } finally {
    await db.close();
  }
}

/// Пароль из консоли без эха и с повтором; если stdin не консоль (пароль
/// подан через конвейер) — первая строка.
String _readPassword() {
  String? readLine() => stdin.readLineSync(encoding: utf8);
  if (!stdin.hasTerminal) {
    final line = readLine();
    if (line == null || line.isEmpty) throw StateError('Пароль не передан');
    return line;
  }
  stdin.echoMode = false;
  try {
    stderr.write('Пароль: ');
    final first = readLine() ?? '';
    stderr.write('\nПовторите пароль: ');
    final second = readLine() ?? '';
    stderr.writeln();
    if (first != second) throw StateError('Пароли не совпадают');
    return first;
  } finally {
    stdin.echoMode = true;
  }
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
