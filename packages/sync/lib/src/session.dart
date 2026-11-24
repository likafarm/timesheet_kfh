import 'package:kfh_domain/kfh_domain.dart' as domain;

/// Какая программа входит на сервер.
enum ClientKind {
  /// Полная программа для Windows: администратор и бухгалтер.
  desktop,

  /// Программа для телефона (Android): оператор вводит табель, бухгалтер и
  /// админ работают в полной программе (6.9).
  phone,

  /// Веб-версия в браузере (этап 5): запасной вход администратора и
  /// бухгалтера; данные только принимаются с сервера в пустую базу.
  web;

  String get title => switch (this) {
    ClientKind.desktop => 'программе для Windows',
    ClientKind.phone => 'программе для телефона',
    ClientKind.web => 'веб-версии',
  };
}

/// Пользователь сервера, как его отдаёт `/auth/me` и `/auth/login`.
class SessionUser {
  final String uuid;
  final String login;
  final String fullName;

  /// `admin` | `accountant` | `operator` | `sales` (11.2).
  final String role;
  final bool mustChangePassword;

  /// Учётная запись действует (список пользователей у админа).
  final bool isActive;

  const SessionUser({
    required this.uuid,
    required this.login,
    required this.fullName,
    required this.role,
    this.mustChangePassword = false,
    this.isActive = true,
  });

  bool get isAdmin => role == domain.roleAdmin;
  bool get isOperator => role == domain.roleOperator;

  /// Специалист по продажам (11.2): прайс, позже — покупатели и заказы.
  bool get isSales => role == domain.roleSales;

  /// Админ или бухгалтер — вся программа.
  bool get isFull => domain.isFullRole(role);

  /// Может ли роль работать в этой программе (решения владельца
  /// 2026-09-27, 2026-09-29 и 2026-11-24): на Windows и в веб-версии —
  /// админ, бухгалтер и специалист по продажам, на телефоне — все роли
  /// (разделы — по роли). Роли, которых программа не знает, не входят.
  bool canUseOn(ClientKind client) => switch (client) {
    ClientKind.desktop || ClientKind.web => isFull || isSales,
    ClientKind.phone => domain.allRoles.contains(role),
  };

  /// Почему роль не может работать в этой программе (null — может).
  String? refusalOn(ClientKind client) {
    if (canUseOn(client)) return null;
    return switch (client) {
      ClientKind.desktop =>
        'Роль «$roleTitle» не работает в программе для Windows — нужна '
            'учётная запись администратора, бухгалтера или специалиста по '
            'продажам.${domain.allRoles.contains(role) ? '' : _update}',
      ClientKind.phone =>
        'Роль «$roleTitle» не работает в программе для телефона.$_update',
      ClientKind.web =>
        'Роль «$roleTitle» не работает в веб-версии — нужна учётная запись '
            'администратора, бухгалтера или специалиста по продажам. '
            'Оператор работает в программе для телефона.'
            '${domain.allRoles.contains(role) ? '' : _update}',
    };
  }

  static const _update =
      ' Возможно, эта версия программы старше роли — обновите программу.';

  String get roleTitle => domain.roleTitle(role);

  factory SessionUser.fromJson(Map<String, Object?> json) => SessionUser(
    uuid: json['uuid'] as String,
    login: json['login'] as String,
    fullName: json['full_name'] as String? ?? '',
    role: json['role'] as String,
    mustChangePassword: json['must_change_password'] == true,
    isActive: json['is_active'] != false,
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
