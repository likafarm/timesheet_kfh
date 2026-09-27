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

  test('файл версий программ — необязателен', () {
    expect(ServerConfig.fromEnvironment(minimal).clientVersionsFile, isNull);
    expect(
        ServerConfig.fromEnvironment(
                {...minimal, 'CLIENT_VERSIONS_FILE': ' /downloads/versions.json '})
            .clientVersionsFile,
        '/downloads/versions.json');
  });

  test('CORS: по умолчанию выключен, адреса — только точные', () {
    expect(ServerConfig.fromEnvironment(minimal).corsOrigins, isEmpty);
    expect(
        ServerConfig.fromEnvironment({
          ...minimal,
          'CORS_ORIGINS': 'http://localhost:5080, http://127.0.0.1:5080',
        }).corsOrigins,
        {'http://localhost:5080', 'http://127.0.0.1:5080'});
    for (final bad in ['*', 'localhost:5080', 'http://localhost:5080/app']) {
      expect(
          () => ServerConfig.fromEnvironment(
              {...minimal, 'CORS_ORIGINS': bad}),
          throwsA(isA<ConfigException>()),
          reason: bad);
    }
  });

  group('ключ токенов и прокси', () {
    test('по умолчанию ключа нет, прокси не доверяем', () {
      final config = ServerConfig.fromEnvironment(minimal);
      expect(config.jwtSecret, isNull);
      expect(config.trustProxy, isFalse);
      expect(config.requireJwtSecret, throwsA(isA<ConfigException>()));
    });

    test('ключ из переменной и из файла', () {
      final key = 'k' * 32;
      expect(
          ServerConfig.fromEnvironment({...minimal, 'JWT_SECRET': key})
              .requireJwtSecret(),
          key);
      expect(
          ServerConfig.fromEnvironment(
                  {...minimal, 'JWT_SECRET_FILE': '/run/secrets/jwt'},
                  readFile: (_) => '$key\n')
              .jwtSecret,
          key);
    });

    test('короткий ключ — ошибка (считаются байты UTF-8)', () {
      expect(
          () => ServerConfig.fromEnvironment(
              {...minimal, 'JWT_SECRET': 'k' * 31}),
          throwsA(isA<ConfigException>()));
      // 16 кириллических букв = 32 байта.
      expect(
          ServerConfig.fromEnvironment({...minimal, 'JWT_SECRET': 'ж' * 16})
              .jwtSecret,
          'ж' * 16);
    });

    test('TRUST_PROXY', () {
      expect(
          ServerConfig.fromEnvironment({...minimal, 'TRUST_PROXY': 'true'})
              .trustProxy,
          isTrue);
    });
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
