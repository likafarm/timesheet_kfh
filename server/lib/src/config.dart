import 'dart:convert';
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
///   `false`: на VPS их применяет `server migrate` после резервной копии);
/// - `JWT_SECRET` или `JWT_SECRET_FILE` — ключ подписи access-токенов, не
///   короче 32 байт (нужен только самому серверу, не командам);
/// - `TRUST_PROXY` — сервер за своим прокси (Caddy): адрес клиента брать из
///   `X-Forwarded-For` (по умолчанию `false`);
/// - `CLIENT_VERSIONS_FILE` — файл версий программ для `GET /client/version`
///   (не задан — обновлений не требуется).
class ServerConfig {
  final int port;
  final DbConfig db;
  final String migrationsDir;
  final bool migrateOnStart;
  final String? jwtSecret;
  final bool trustProxy;
  final String? clientVersionsFile;

  /// Адреса страниц, которым браузер разрешит обращаться к API (CORS):
  /// только отладка веб-версии на localhost. На VPS — пусто.
  final Set<String> corsOrigins;

  const ServerConfig({
    required this.port,
    required this.db,
    this.migrationsDir = 'migrations',
    this.migrateOnStart = false,
    this.jwtSecret,
    this.trustProxy = false,
    this.clientVersionsFile,
    this.corsOrigins = const {},
  });

  /// Ключ подписи токенов: без него сервер не запускается.
  String requireJwtSecret() =>
      jwtSecret ??
      (throw ConfigException('не задан ключ токенов: JWT_SECRET '
          'или JWT_SECRET_FILE'));

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

    /// Секрет из переменной NAME или из файла NAME_FILE (Docker secrets).
    String? secret(String name) {
      final direct = env[name] ?? '';
      final file = env['${name}_FILE']?.trim() ?? '';
      if (direct.isNotEmpty && file.isNotEmpty) {
        throw ConfigException('заданы и $name, и ${name}_FILE — оставьте одну');
      }
      if (file.isNotEmpty) {
        final String content;
        try {
          content = read(file);
        } on FileSystemException catch (e) {
          throw ConfigException('не прочитан ${name}_FILE ($file): '
              '${e.osError?.message ?? e.message}');
        }
        // Файлы секретов обычно кончаются переводом строки.
        final value = content.trimRight();
        if (value.isEmpty) {
          throw ConfigException('файл ${name}_FILE ($file) пуст');
        }
        return value;
      }
      return direct.isEmpty ? null : direct;
    }

    final password = secret('DB_PASSWORD');
    if (password == null) {
      throw ConfigException('не задан пароль MySQL: DB_PASSWORD '
          'или DB_PASSWORD_FILE');
    }
    final jwtSecret = secret('JWT_SECRET');
    if (jwtSecret != null && utf8.encode(jwtSecret).length < 32) {
      throw ConfigException('JWT_SECRET короче 32 байт — возьмите, например, '
          '«openssl rand -base64 48»');
    }
    final corsOrigins = <String>{};
    for (final raw in (env['CORS_ORIGINS'] ?? '').split(',')) {
      final origin = raw.trim();
      if (origin.isEmpty) continue;
      final uri = Uri.tryParse(origin);
      if (origin == '*' ||
          uri == null ||
          !(uri.scheme == 'http' || uri.scheme == 'https') ||
          uri.host.isEmpty ||
          uri.path.isNotEmpty ||
          uri.hasQuery) {
        throw ConfigException('CORS_ORIGINS: «$origin» — нужен адрес вида '
            'http://localhost:5080, без «*» и пути');
      }
      corsOrigins.add(origin);
    }
    return ServerConfig(
      port: intValue('PORT', 8080),
      db: DbConfig(
        host: required('DB_HOST'),
        port: intValue('DB_PORT', 3306),
        database: required('DB_NAME'),
        user: required('DB_USER'),
        password: password,
        secure: boolValue('DB_SECURE', true),
        maxConnections: intValue('DB_MAX_CONNECTIONS', 10, max: 100),
      ),
      migrationsDir: (env['MIGRATIONS_DIR']?.trim() ?? '').isEmpty
          ? 'migrations'
          : env['MIGRATIONS_DIR']!.trim(),
      migrateOnStart: boolValue('MIGRATE_ON_START', false),
      jwtSecret: jwtSecret,
      trustProxy: boolValue('TRUST_PROXY', false),
      clientVersionsFile: (env['CLIENT_VERSIONS_FILE']?.trim() ?? '').isEmpty
          ? null
          : env['CLIENT_VERSIONS_FILE']!.trim(),
      corsOrigins: corsOrigins,
    );
  }
}
