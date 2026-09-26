import 'dart:io';

import 'package:kfh_server/kfh_server.dart';
import 'package:test/test.dart';

void main() {
  const minimal = {
    'DB_HOST': 'mysql',
    'DB_NAME': 'kfh',
    'DB_USER': 'kfh_api',
    'DB_PASSWORD': 'secret',
  };

  test('минимальные настройки и значения по умолчанию', () {
    final config = ServerConfig.fromEnvironment(minimal);
    expect(config.port, 8080);
    expect(config.db.host, 'mysql');
    expect(config.db.port, 3306);
    expect(config.db.database, 'kfh');
    expect(config.db.user, 'kfh_api');
    expect(config.db.password, 'secret');
    expect(config.db.secure, isTrue);
    expect(config.db.maxConnections, 10);
    expect(config.migrationsDir, 'migrations');
    expect(config.migrateOnStart, isFalse);
  });

  test('все настройки заданы явно', () {
    final config = ServerConfig.fromEnvironment({
      ...minimal,
      'PORT': '9000',
      'DB_PORT': '3307',
      'DB_SECURE': 'false',
      'DB_MAX_CONNECTIONS': '4',
      'MIGRATIONS_DIR': '/app/migrations',
      'MIGRATE_ON_START': 'true',
    });
    expect(config.migrationsDir, '/app/migrations');
    expect(config.migrateOnStart, isTrue);
    expect(config.port, 9000);
    expect(config.db.port, 3307);
    expect(config.db.secure, isFalse);
    expect(config.db.maxConnections, 4);
  });

  for (final name in ['DB_HOST', 'DB_NAME', 'DB_USER']) {
    test('без $name — ошибка с именем переменной', () {
      final env = {...minimal}..remove(name);
      expect(
        () => ServerConfig.fromEnvironment(env),
        throwsA(isA<ConfigException>()
            .having((e) => e.message, 'message', contains(name))),
      );
    });

    test('$name из пробелов считается пустой', () {
      expect(() => ServerConfig.fromEnvironment({...minimal, name: '  '}),
          throwsA(isA<ConfigException>()));
    });
  }

  test('неверные числа и флаги отклоняются', () {
    for (final bad in [
      {'PORT': 'abc'},
      {'PORT': '0'},
      {'PORT': '70000'},
      {'DB_PORT': '-1'},
      {'DB_MAX_CONNECTIONS': '1000'},
      {'DB_SECURE': 'yes'},
    ]) {
      expect(() => ServerConfig.fromEnvironment({...minimal, ...bad}),
          throwsA(isA<ConfigException>()),
          reason: bad.toString());
    }
  });

  group('пароль', () {
    final withoutPassword = {...minimal}..remove('DB_PASSWORD');

    test('не задан — ошибка', () {
      expect(() => ServerConfig.fromEnvironment(withoutPassword),
          throwsA(isA<ConfigException>()));
    });

    test('из файла, перевод строки в конце отрезается', () {
      final config = ServerConfig.fromEnvironment(
        {...withoutPassword, 'DB_PASSWORD_FILE': '/run/secrets/db'},
        readFile: (path) {
          expect(path, '/run/secrets/db');
          return 'from-file\n';
        },
      );
      expect(config.db.password, 'from-file');
    });

    test('пробелы в начале пароля сохраняются', () {
      final config = ServerConfig.fromEnvironment(
          {...minimal, 'DB_PASSWORD': ' pass '});
      expect(config.db.password, ' pass ');
    });

    test('заданы оба способа — ошибка', () {
      expect(
        () => ServerConfig.fromEnvironment(
            {...minimal, 'DB_PASSWORD_FILE': '/run/secrets/db'},
            readFile: (_) => 'x'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('файл пуст или не читается — ошибка', () {
      final env = {...withoutPassword, 'DB_PASSWORD_FILE': '/nope'};
      expect(() => ServerConfig.fromEnvironment(env, readFile: (_) => '\n'),
          throwsA(isA<ConfigException>()));
      expect(
        () => ServerConfig.fromEnvironment(env,
            readFile: (path) => throw FileSystemException('нет файла', path)),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
