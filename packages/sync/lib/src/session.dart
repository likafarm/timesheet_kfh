/// Пользователь сервера, как его отдаёт `/auth/me` и `/auth/login`.
class SessionUser {
  final String uuid;
  final String login;
  final String fullName;

  /// `admin` | `accountant` | `operator`.
  final String role;
  final bool mustChangePassword;

  const SessionUser({
    required this.uuid,
    required this.login,
    required this.fullName,
    required this.role,
    this.mustChangePassword = false,
  });

  bool get isAdmin => role == 'admin';

  /// Может ли роль работать в полном клиенте Windows (решение владельца
  /// 2026-09-27: только админ и бухгалтер; оператор — с этапа 4).
  bool get canUseDesktop => role == 'admin' || role == 'accountant';

  String get roleTitle => switch (role) {
    'admin' => 'администратор',
    'accountant' => 'бухгалтер',
    'operator' => 'оператор',
    _ => role,
  };

  factory SessionUser.fromJson(Map<String, Object?> json) => SessionUser(
    uuid: json['uuid'] as String,
    login: json['login'] as String,
    fullName: json['full_name'] as String? ?? '',
    role: json['role'] as String,
    mustChangePassword: json['must_change_password'] == true,
  );

  Map<String, Object?> toJson() => {
    'uuid': uuid,
    'login': login,
    'full_name': fullName,
    'role': role,
    'must_change_password': mustChangePassword,
  };
}

/// Пара токенов входа и пользователь.
class AuthTokens {
  final String accessToken;
  final DateTime accessExpiresAt;
  final String refreshToken;
  final DateTime refreshExpiresAt;
  final SessionUser user;

  AuthTokens({
    required this.accessToken,
    required DateTime accessExpiresAt,
    required this.refreshToken,
    required DateTime refreshExpiresAt,
    required this.user,
  }) : accessExpiresAt = accessExpiresAt.toUtc(),
       refreshExpiresAt = refreshExpiresAt.toUtc();

  factory AuthTokens.fromJson(Map<String, Object?> json) => AuthTokens(
    accessToken: json['access_token'] as String,
    accessExpiresAt: DateTime.parse(json['access_expires_at'] as String),
    refreshToken: json['refresh_token'] as String,
    refreshExpiresAt: DateTime.parse(json['refresh_expires_at'] as String),
    user: SessionUser.fromJson(json['user'] as Map<String, Object?>),
  );

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'access_expires_at': accessExpiresAt.toIso8601String(),
    'refresh_token': refreshToken,
    'refresh_expires_at': refreshExpiresAt.toIso8601String(),
    'user': user.toJson(),
  };

  AuthTokens withUser(SessionUser user) => AuthTokens(
    accessToken: accessToken,
    accessExpiresAt: accessExpiresAt,
    refreshToken: refreshToken,
    refreshExpiresAt: refreshExpiresAt,
    user: user,
  );
}

/// Где лежат токены. В приложении — защищённое хранилище ОС.
abstract class TokenStore {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

/// Токены в памяти — для тестов.
class MemoryTokenStore implements TokenStore {
  AuthTokens? tokens;

  MemoryTokenStore([this.tokens]);

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> write(AuthTokens tokens) async => this.tokens = tokens;

  @override
  Future<void> clear() async => tokens = null;
}
