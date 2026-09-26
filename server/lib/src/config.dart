import 'dart:io';

/// Ошибка настройки сервера: не хватает переменной окружения или значение
/// неверное. Сервер с такой ошибкой не стартует.
class ConfigException implements Exception {
  final String message;
  ConfigException(this.message);

  @override
  String toString() => 'Ошибка настройки: $message';
}

/// Настройки подключения к MySQL.
class DbConfig {
  final String host;
  final int port;
  final String database;
  final String user;
  final String password;

  /// TLS до MySQL. MySQL 8 с `caching_sha2_password` без TLS не пускает
  /// при первом входе пользователя, поэтому по умолчанию включено.
  final bool secure;
  final int maxConnections;

  const DbConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.user,
    required this.password,
    this.secure = true,
    this.maxConnections = 10,
  });
}

/// Настройки сервера. Читаются только из переменных окружения:
///
/// - `PORT` — порт HTTP (по умолчанию 8080);
/// - `DB_HOST`, `DB_PORT` (3306), `DB_NAME`, `DB_USER` — MySQL;
/// - `DB_PASSWORD` или `DB_PASSWORD_FILE` (путь к файлу, для Docker secrets);
/// - `DB_SECURE` (`true`/`false`, по умолчанию `true`);
/// - `DB_MAX_CONNECTIONS` (по умолчанию 10);
/// - `MIGRATIONS_DIR` — папка SQL-миграций (по умолчанию `migrations`
///   в рабочей папке);
/// - `MIGRATE_ON_START` — применять миграции при старте (по умолчанию
///   `false`: на VPS их применяет `server migrate` после резервной копии).
class ServerConfig {
  final int port;
  final DbConfig db;
  final String migrationsDir;
  final bool migrateOnStart;

  const ServerConfig({
    required this.port,
    required this.db,
    this.migrationsDir = 'migrations',
    this.migrateOnStart = false,
  });

  factory ServerConfig.fromEnvironment(
    Map<String, String> env, {
    String Function(String path)? readFile,
  }) {
    final read = readFile ?? (path) => File(path).readAsStringSync();

    String required(String name) {
      final value = env[name]?.trim() ?? '';
      if (value.isEmpty) {
        throw ConfigException('не задана переменная $name');
      }
      return value;
    }

    int intValue(String name, int defaultValue, {int min = 1, int max = 65535}) {
      final raw = env[name]?.trim() ?? '';
      if (raw.isEmpty) return defaultValue;
      final value = int.tryParse(raw);
      if (value == null || value < min || value > max) {
        throw ConfigException('$name должна быть целым числом от $min до $max, '
            'получено «$raw»');
      }
      return value;
    }

    bool boolValue(String name, bool defaultValue) {
      final raw = env[name]?.trim().toLowerCase() ?? '';
      if (raw.isEmpty) return defaultValue;
      if (raw == 'true' || raw == '1') return true;
      if (raw == 'false' || raw == '0') return false;
      throw ConfigException('$name должна быть true или false, получено «$raw»');
    }

    String password() {
      final direct = env['DB_PASSWORD'] ?? '';
      final file = env['DB_PASSWORD_FILE']?.trim() ?? '';
      if (direct.isNotEmpty && file.isNotEmpty) {
        throw ConfigException('заданы и DB_PASSWORD, и DB_PASSWORD_FILE — '
            'оставьте одну');
      }
      if (file.isNotEmpty) {
        final String content;
        try {
          content = read(file);
        } on FileSystemException catch (e) {
          throw ConfigException('не прочитан DB_PASSWORD_FILE ($file): '
              '${e.osError?.message ?? e.message}');
        }
        // Файлы секретов обычно кончаются переводом строки.
        final value = content.trimRight();
        if (value.isEmpty) {
          throw ConfigException('файл DB_PASSWORD_FILE ($file) пуст');
        }
        return value;
      }
      if (direct.isEmpty) {
        throw ConfigException('не задан пароль MySQL: DB_PASSWORD '
            'или DB_PASSWORD_FILE');
      }
      return direct;
    }

    return ServerConfig(
      port: intValue('PORT', 8080),
      db: DbConfig(
        host: required('DB_HOST'),
        port: intValue('DB_PORT', 3306),
        database: required('DB_NAME'),
        user: required('DB_USER'),
        password: password(),
        secure: boolValue('DB_SECURE', true),
        maxConnections: intValue('DB_MAX_CONNECTIONS', 10, max: 100),
      ),
      migrationsDir: (env['MIGRATIONS_DIR']?.trim() ?? '').isEmpty
          ? 'migrations'
          : env['MIGRATIONS_DIR']!.trim(),
      migrateOnStart: boolValue('MIGRATE_ON_START', false),
    );
  }
}
