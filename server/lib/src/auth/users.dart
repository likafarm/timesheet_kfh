import 'package:mysql_client_plus/mysql_client_plus.dart';

import '../sql.dart';

/// Выполнение SQL: и `MySqlDatabase.execute`, и `MySQLConnection.execute`
/// (внутри транзакции).
typedef SqlExecutor = Future<IResultSet> Function(String sql,
    [Map<String, dynamic>? params]);

enum Role {
  admin,
  accountant,
  operator;

  static Role? tryParse(Object? value) {
    for (final role in values) {
      if (role.name == value) return role;
    }
    return null;
  }
}

class User {
  final String uuid;
  final String login;
  final String fullName;
  final Role role;
  final bool isActive;
  final bool mustChangePassword;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? passwordChangedAt;

  /// Только для проверки пароля; наружу не отдаётся.
  final String passwordHash;

  const User({
    required this.uuid,
    required this.login,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.mustChangePassword,
    required this.createdAt,
    required this.updatedAt,
    required this.passwordChangedAt,
    required this.passwordHash,
  });

  /// Представление для API и аудита — без хэша пароля.
  Map<String, Object?> toJson() => {
        'uuid': uuid,
        'login': login,
        'full_name': fullName,
        'role': role.name,
        'is_active': isActive,
        'must_change_password': mustChangePassword,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'password_changed_at': passwordChangedAt?.toIso8601String(),
      };

  static User fromRow(ResultSetRow row) => User(
        uuid: row.textOf('uuid'),
        login: row.textOf('login'),
        fullName: row.textOf('full_name'),
        role: Role.tryParse(row.text('role'))!,
        isActive: parseSqlBool(row.text('is_active')),
        mustChangePassword: parseSqlBool(row.text('must_change_password')),
        createdAt: parseSqlDateTime(row.textOf('created_at')),
        updatedAt: parseSqlDateTime(row.textOf('updated_at')),
        passwordChangedAt:
            parseSqlDateTimeOrNull(row.text('password_changed_at')),
        passwordHash: row.textOf('password_hash'),
      );
}

const _columns = 'uuid, login, full_name, role, is_active, '
    'must_change_password, created_at, updated_at, password_changed_at, '
    'password_hash';

/// Запросы к таблице `users`.
class UserStore {
  const UserStore();

  Future<User?> byUuid(SqlExecutor sql, String uuid,
      {bool forUpdate = false}) async {
    final r = await sql('SELECT $_columns FROM users WHERE uuid = :u'
        '${forUpdate ? ' FOR UPDATE' : ''}', {'u': uuid});
    return r.rows.isEmpty ? null : User.fromRow(r.rows.first);
  }

  /// Логин сравнивается без учёта регистра (сравнение столбца _ai_ci).
  Future<User?> byLogin(SqlExecutor sql, String login) async {
    final r = await sql(
        'SELECT $_columns FROM users WHERE login = :l', {'l': login});
    return r.rows.isEmpty ? null : User.fromRow(r.rows.first);
  }

  Future<List<User>> all(SqlExecutor sql) async {
    final r = await sql('SELECT $_columns FROM users ORDER BY full_name, login');
    return [for (final row in r.rows) User.fromRow(row)];
  }

  Future<bool> anyAdmin(SqlExecutor sql) async {
    final r = await sql("SELECT 1 FROM users WHERE role = 'admin' LIMIT 1");
    return r.rows.isNotEmpty;
  }

  /// Активные админы, с блокировкой строк до конца транзакции: два
  /// одновременных отключения не оставят систему без админа.
  Future<int> countActiveAdminsForUpdate(SqlExecutor sql) async {
    final r = await sql("SELECT uuid FROM users WHERE role = 'admin' "
        'AND is_active = 1 FOR UPDATE');
    return r.rows.length;
  }

  Future<void> insert(
    SqlExecutor sql, {
    required String uuid,
    required String login,
    required String fullName,
    required Role role,
    required String passwordHash,
    required bool mustChangePassword,
    required DateTime now,
  }) =>
      sql(
          'INSERT INTO users (uuid, login, password_hash, role, full_name, '
          'is_active, must_change_password, created_at, updated_at, '
          'password_changed_at) VALUES (:u, :l, :h, :r, :n, 1, :m, :now, '
          ':now, :now)',
          {
            'u': uuid,
            'l': login,
            'h': passwordHash,
            'r': role.name,
            'n': fullName,
            'm': mustChangePassword ? 1 : 0,
            'now': sqlDateTime(now),
          });

  Future<void> update(
    SqlExecutor sql,
    String uuid, {
    required String fullName,
    required Role role,
    required bool isActive,
    required DateTime now,
  }) =>
      sql(
          'UPDATE users SET full_name = :n, role = :r, is_active = :a, '
          'updated_at = :now WHERE uuid = :u',
          {
            'u': uuid,
            'n': fullName,
            'r': role.name,
            'a': isActive ? 1 : 0,
            'now': sqlDateTime(now),
          });

  Future<void> setPassword(
    SqlExecutor sql,
    String uuid, {
    required String passwordHash,
    required bool mustChangePassword,
    required DateTime now,
  }) =>
      sql(
          'UPDATE users SET password_hash = :h, must_change_password = :m, '
          'password_changed_at = :now, updated_at = :now WHERE uuid = :u',
          {
            'u': uuid,
            'h': passwordHash,
            'm': mustChangePassword ? 1 : 0,
            'now': sqlDateTime(now),
          });

  /// Пересчёт хэша при входе (параметры Argon2 подняли) — пароль тот же,
  /// поэтому `password_changed_at` не трогаем: токены остаются в силе.
  Future<void> rehash(SqlExecutor sql, String uuid, String passwordHash) =>
      sql('UPDATE users SET password_hash = :h WHERE uuid = :u',
          {'u': uuid, 'h': passwordHash});
}
