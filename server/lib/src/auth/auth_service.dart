import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

import '../audit.dart';
import '../database.dart';
import '../http/responses.dart';
import '../logger.dart';
import 'access_token.dart';
import 'login_throttle.dart';
import 'password_hasher.dart';
import 'refresh_tokens.dart';
import 'users.dart';

/// Пара токенов после входа или обмена.
class TokenPair {
  final String accessToken;
  final DateTime accessExpiresAt;
  final String refreshToken;
  final DateTime refreshExpiresAt;
  final User user;

  TokenPair(this.accessToken, this.accessExpiresAt, this.refreshToken,
      this.refreshExpiresAt, this.user);

  Map<String, Object?> toJson() => {
        'access_token': accessToken,
        'access_expires_at': accessExpiresAt.toIso8601String(),
        'refresh_token': refreshToken,
        'refresh_expires_at': refreshExpiresAt.toIso8601String(),
        'user': user.toJson(),
      };
}

/// Кто и откуда выполняет действие — для аудита.
class RequestInfo {
  final String? requestId;
  final String? deviceId;
  final String? ip;

  const RequestInfo({this.requestId, this.deviceId, this.ip});
}

// Ошибки входа. Коды — для программы клиента, сообщения — для человека.
const invalidCredentials =
    ApiException(401, 'invalid_credentials', 'Неверный логин или пароль');

/// Access-токен не принят: клиент пробует обменять refresh-токен.
const tokenInvalid =
    ApiException(401, 'token_invalid', 'Требуется вход в систему');

/// Refresh-токен не принят: нужно войти заново логином и паролем.
const sessionExpired = ApiException(
    401, 'session_expired', 'Сеанс завершён, войдите заново');

const userDisabled =
    ApiException(403, 'user_disabled', 'Учётная запись отключена');

const forbidden =
    ApiException(403, 'forbidden', 'Недостаточно прав для этого действия');

const passwordChangeRequired = ApiException(403, 'password_change_required',
    'Нужно сменить пароль, выданный администратором');

/// Слишком много неудачных входов.
class TooManyAttempts extends ApiException {
  final Duration retryAfter;

  TooManyAttempts(this.retryAfter)
      : super(429, 'too_many_attempts',
            'Слишком много неудачных попыток входа. Повторите через '
            '${(retryAfter.inSeconds / 60).ceil()} мин.');

  @override
  Response toResponse() => super.toResponse().change(
      headers: {'retry-after': '${retryAfter.inSeconds.clamp(1, 86400)}'});
}

final _loginPattern = RegExp(r'^[\p{L}\p{N}._-]{3,64}$', unicode: true);

/// Вход, токены и пользователи.
class AuthService {
  final MySqlDatabase db;
  final PasswordHasher hasher;
  final AccessTokens accessTokens;
  final Logger logger;
  final Duration refreshLifetime;
  final LoginThrottle loginThrottle;
  final LoginThrottle ipThrottle;
  final DateTime Function() _now;

  final _users = const UserStore();
  final _refresh = const RefreshTokenStore();
  static const _uuid = Uuid();

  /// Хэш для входа с несуществующим логином: проверка идёт столько же,
  /// сколько с настоящим, — по времени ответа не узнать, есть ли логин.
  late final Future<String> _dummyHash = hasher.hash(newRefreshToken());

  AuthService({
    required this.db,
    required this.accessTokens,
    required this.logger,
    this.hasher = const PasswordHasher(),
    this.refreshLifetime = const Duration(days: 30),
    LoginThrottle? loginThrottle,
    LoginThrottle? ipThrottle,
    DateTime Function()? now,
  })  : loginThrottle = loginThrottle ?? LoginThrottle(maxFailures: 5),
        ipThrottle = ipThrottle ?? LoginThrottle(maxFailures: 30),
        _now = now ?? DateTime.now;

  DateTime _utcNow() => _now().toUtc();

  // ---------------------------------------------------------------- вход

  Future<TokenPair> login(String login, String password, RequestInfo info) async {
    final loginKey = 'login:${login.trim().toLowerCase()}';
    final ipKey = 'ip:${info.ip ?? '-'}';
    for (final key in [loginKey, ipKey]) {
      final wait = (key == loginKey ? loginThrottle : ipThrottle).retryAfter(key);
      if (wait != null) throw TooManyAttempts(wait);
    }

    final user = await _users.byLogin(db.execute, login.trim());
    final bool ok;
    if (user == null) {
      await hasher.verify(password, await _dummyHash);
      ok = false;
    } else {
      ok = await hasher.verify(password, user.passwordHash);
    }

    if (!ok) {
      loginThrottle.recordFailure(loginKey);
      ipThrottle.recordFailure(ipKey);
      await writeAudit(db.execute,
          action: 'login_failed',
          entity: 'users',
          entityUuid: user?.uuid,
          deviceId: info.deviceId,
          requestId: info.requestId,
          newValue: {'login': login.trim(), 'ip': info.ip});
      throw invalidCredentials;
    }
    loginThrottle.reset(loginKey);
    if (!user!.isActive) throw userDisabled;

    if (hasher.needsRehash(user.passwordHash)) {
      await _users.rehash(db.execute, user.uuid, await hasher.hash(password));
    }

    return db.transaction((conn) async {
      final pair = await _issue(conn.execute, user,
          family: _uuid.v7(), deviceId: info.deviceId);
      await writeAudit(conn.execute,
          action: 'login',
          userUuid: user.uuid,
          entity: 'users',
          entityUuid: user.uuid,
          deviceId: info.deviceId,
          requestId: info.requestId,
          newValue: {'ip': info.ip});
      return pair;
    });
  }

  /// Обмен refresh-токена на новую пару (старый гасится). Повторное
  /// использование уже погашенного токена значит, что его украли: гасится
  /// вся цепочка этого входа, обоим владельцам придётся войти заново.
  Future<TokenPair> refresh(String token, RequestInfo info) async {
    final result = await db.transaction((conn) async {
      final now = _utcNow();
      final stored = await _refresh.findForUpdate(conn.execute, token);
      if (stored == null) return null;
      if (stored.revokedAt != null) {
        // В журнал — только если было что гасить: повторные попытки с уже
        // погашенной цепочкой его не засоряют.
        final revoked =
            await _refresh.revokeFamily(conn.execute, stored.family, now);
        if (revoked == 0) return null;
        await writeAudit(conn.execute,
            action: 'token_reuse',
            userUuid: stored.userUuid,
            entity: 'users',
            entityUuid: stored.userUuid,
            deviceId: info.deviceId ?? stored.deviceId,
            requestId: info.requestId,
            newValue: {'family': stored.family, 'ip': info.ip});
        return null;
      }
      if (!stored.expiresAt.isAfter(now)) return null;
      final user = await _users.byUuid(conn.execute, stored.userUuid);
      if (user == null || !user.isActive) {
        await _refresh.revokeFamily(conn.execute, stored.family, now);
        return null;
      }
      await _refresh.revoke(conn.execute, token, now);
      return _issue(conn.execute, user,
          family: stored.family, deviceId: stored.deviceId);
    });
    if (result == null) {
      logger.warning('refresh отклонён', {'request_id': info.requestId});
      throw sessionExpired;
    }
    return result;
  }

  /// Выход: гасится вся цепочка этого входа. Неизвестный токен — не
  /// ошибка (выход должен удаваться всегда).
  Future<void> logout(String token, RequestInfo info) =>
      db.transaction((conn) async {
        final stored = await _refresh.findForUpdate(conn.execute, token);
        if (stored == null) return;
        await _refresh.revokeFamily(conn.execute, stored.family, _utcNow());
        await writeAudit(conn.execute,
            action: 'logout',
            userUuid: stored.userUuid,
            entity: 'users',
            entityUuid: stored.userUuid,
            deviceId: info.deviceId ?? stored.deviceId,
            requestId: info.requestId);
      });

  /// Пользователь по access-токену. Каждый запрос читает пользователя из
  /// базы: отключение и смена роли действуют сразу, а смена пароля
  /// гасит выданные до неё access-токены.
  Future<User> authenticate(String accessToken) async {
    final AccessClaims claims;
    try {
      claims = accessTokens.verify(accessToken);
    } on InvalidTokenException {
      throw tokenInvalid;
    }
    final user = await _users.byUuid(db.execute, claims.userUuid);
    if (user == null) throw tokenInvalid;
    if (!user.isActive) throw userDisabled;
    final changed = user.passwordChangedAt;
    if (changed != null &&
        claims.issuedAt.isBefore(DateTime.fromMillisecondsSinceEpoch(
            changed.millisecondsSinceEpoch ~/ 1000 * 1000,
            isUtc: true))) {
      throw tokenInvalid;
    }
    return user;
  }

  /// Смена своего пароля. Все прежние входы гасятся, этому устройству
  /// выдаётся новая пара токенов.
  Future<TokenPair> changePassword(User user, String oldPassword,
      String newPassword, RequestInfo info) async {
    if (!await hasher.verify(oldPassword, user.passwordHash)) {
      throw const ApiException(
          400, 'wrong_password', 'Текущий пароль указан неверно');
    }
    _checkPassword(newPassword);
    if (oldPassword == newPassword) {
      throw const ApiException(400, 'validation',
          'Новый пароль должен отличаться от текущего');
    }
    final hash = await hasher.hash(newPassword);
    return db.transaction((conn) async {
      final now = _utcNow();
      await _users.setPassword(conn.execute, user.uuid,
          passwordHash: hash, mustChangePassword: false, now: now);
      await _refresh.revokeAllForUser(conn.execute, user.uuid, now);
      await writeAudit(conn.execute,
          action: 'password_change',
          userUuid: user.uuid,
          entity: 'users',
          entityUuid: user.uuid,
          deviceId: info.deviceId,
          requestId: info.requestId);
      final fresh = (await _users.byUuid(conn.execute, user.uuid))!;
      return _issue(conn.execute, fresh,
          family: _uuid.v7(), deviceId: info.deviceId);
    });
  }

  // ------------------------------------------------------- пользователи

  Future<List<User>> listUsers(User actor) async {
    _requireAdmin(actor);
    return _users.all(db.execute);
  }

  /// Новый пользователь с паролем от админа — при первом входе он обязан
  /// сменить пароль.
  Future<User> createUser(
    User actor, {
    required Object? login,
    required Object? fullName,
    required Object? role,
    required Object? password,
    required RequestInfo info,
  }) async {
    _requireAdmin(actor);
    final l = _checkLogin(login);
    final n = _checkFullName(fullName);
    final r = _checkRole(role);
    final p = _checkPassword(password);
    final hash = await hasher.hash(p);
    return db.transaction((conn) async {
      if (await _users.byLogin(conn.execute, l) != null) throw _loginTaken;
      final uuid = _uuid.v7();
      await _users.insert(conn.execute,
          uuid: uuid,
          login: l,
          fullName: n,
          role: r,
          passwordHash: hash,
          mustChangePassword: true,
          now: _utcNow());
      final user = (await _users.byUuid(conn.execute, uuid))!;
      await writeAudit(conn.execute,
          action: 'user_create',
          userUuid: actor.uuid,
          entity: 'users',
          entityUuid: uuid,
          deviceId: info.deviceId,
          requestId: info.requestId,
          newValue: user.toJson());
      return user;
    });
  }

  /// Правка ФИО, роли, активности. Себя отключить или понизить нельзя,
  /// последнего активного админа — тоже.
  Future<User> updateUser(
    User actor,
    String uuid, {
    Object? fullName,
    Object? role,
    Object? isActive,
    required RequestInfo info,
  }) async {
    _requireAdmin(actor);
    final n = fullName == null ? null : _checkFullName(fullName);
    final r = role == null ? null : _checkRole(role);
    if (isActive != null && isActive is! bool) {
      throw const ApiException.badRequest('is_active должен быть true или false');
    }
    final a = isActive as bool?;
    return db.transaction((conn) async {
      final old = await _users.byUuid(conn.execute, uuid, forUpdate: true);
      if (old == null) throw const ApiException.notFound('Нет такого пользователя');
      final newRole = r ?? old.role;
      final newActive = a ?? old.isActive;
      final losesAdmin = old.role == Role.admin &&
          old.isActive &&
          (newRole != Role.admin || !newActive);
      if (losesAdmin && old.uuid == actor.uuid) {
        throw const ApiException(409, 'self_change',
            'Нельзя отключить себя или снять с себя роль администратора');
      }
      if (losesAdmin &&
          await _users.countActiveAdminsForUpdate(conn.execute) <= 1) {
        throw const ApiException(409, 'last_admin',
            'Нельзя отключить или понизить последнего администратора');
      }
      final now = _utcNow();
      await _users.update(conn.execute, uuid,
          fullName: n ?? old.fullName,
          role: newRole,
          isActive: newActive,
          now: now);
      if (!newActive && old.isActive) {
        await _refresh.revokeAllForUser(conn.execute, uuid, now);
      }
      final updated = (await _users.byUuid(conn.execute, uuid))!;
      await writeAudit(conn.execute,
          action: 'user_update',
          userUuid: actor.uuid,
          entity: 'users',
          entityUuid: uuid,
          deviceId: info.deviceId,
          requestId: info.requestId,
          oldValue: old.toJson(),
          newValue: updated.toJson());
      return updated;
    });
  }

  /// Сброс пароля админом: все входы пользователя гасятся, при следующем
  /// входе он обязан сменить пароль.
  Future<void> resetPassword(User actor, String uuid, Object? password,
      RequestInfo info) async {
    _requireAdmin(actor);
    final p = _checkPassword(password);
    final hash = await hasher.hash(p);
    await db.transaction((conn) async {
      final user = await _users.byUuid(conn.execute, uuid, forUpdate: true);
      if (user == null) throw const ApiException.notFound('Нет такого пользователя');
      final now = _utcNow();
      await _users.setPassword(conn.execute, uuid,
          passwordHash: hash, mustChangePassword: true, now: now);
      await _refresh.revokeAllForUser(conn.execute, uuid, now);
      await writeAudit(conn.execute,
          action: 'password_reset',
          userUuid: actor.uuid,
          entity: 'users',
          entityUuid: uuid,
          deviceId: info.deviceId,
          requestId: info.requestId);
    });
  }

  // ------------------------------------------- команды сервера (консоль)

  /// Первый админ — только пока админов нет вовсе. Пароль задаёт он сам
  /// в консоли сервера, поэтому менять его при входе не требуется.
  Future<User> createFirstAdmin(
      {required String login,
      required String fullName,
      required String password}) async {
    final l = _checkLogin(login);
    final n = _checkFullName(fullName);
    final p = _checkPassword(password);
    final hash = await hasher.hash(p);
    return db.transaction((conn) async {
      // Блокировка на время проверки: два запуска не создадут двух.
      await conn.execute("SELECT GET_LOCK('kfh_create_admin', 10)");
      try {
        if (await _users.anyAdmin(conn.execute)) {
          throw const ApiException(409, 'admin_exists',
              'Администратор уже есть — новых пользователей заводит он');
        }
        if (await _users.byLogin(conn.execute, l) != null) throw _loginTaken;
        final uuid = _uuid.v7();
        await _users.insert(conn.execute,
            uuid: uuid,
            login: l,
            fullName: n,
            role: Role.admin,
            passwordHash: hash,
            mustChangePassword: false,
            now: _utcNow());
        await writeAudit(conn.execute,
            action: 'user_create',
            entity: 'users',
            entityUuid: uuid,
            newValue: {'login': l, 'role': 'admin', 'source': 'console'});
        return (await _users.byUuid(conn.execute, uuid))!;
      } finally {
        await conn.execute("SELECT RELEASE_LOCK('kfh_create_admin')");
      }
    });
  }

  /// Пароль из консоли сервера (у кого есть доступ к серверу, тот и так
  /// может всё). Гасит все входы пользователя.
  Future<void> setPasswordFromConsole(String login, String password) async {
    final p = _checkPassword(password);
    final hash = await hasher.hash(p);
    await db.transaction((conn) async {
      final user = await _users.byLogin(conn.execute, login.trim());
      if (user == null) {
        throw const ApiException.notFound('Нет пользователя с таким логином');
      }
      final now = _utcNow();
      await _users.setPassword(conn.execute, user.uuid,
          passwordHash: hash, mustChangePassword: false, now: now);
      await _refresh.revokeAllForUser(conn.execute, user.uuid, now);
      await writeAudit(conn.execute,
          action: 'password_reset',
          entity: 'users',
          entityUuid: user.uuid,
          newValue: {'source': 'console'});
    });
  }

  // ---------------------------------------------------------- служебное

  Future<TokenPair> _issue(SqlExecutor sql, User user,
      {required String family, required String? deviceId}) async {
    final now = _utcNow();
    final access = accessTokens.issue(user.uuid);
    final refresh = newRefreshToken();
    final refreshExpiresAt = now.add(refreshLifetime);
    await _refresh.insert(sql,
        token: refresh,
        userUuid: user.uuid,
        family: family,
        deviceId: deviceId,
        now: now,
        expiresAt: refreshExpiresAt);
    return TokenPair(
        access.token, access.expiresAt, refresh, refreshExpiresAt, user);
  }

  static void _requireAdmin(User actor) {
    if (actor.role != Role.admin) throw forbidden;
  }

  static const _loginTaken =
      ApiException(409, 'login_taken', 'Такой логин уже занят');

  static String _checkLogin(Object? value) {
    final login = value is String ? value.trim() : '';
    if (!_loginPattern.hasMatch(login)) {
      throw const ApiException(400, 'validation',
          'Логин — от 3 до 64 символов: буквы, цифры, точка, дефис, _');
    }
    return login;
  }

  static String _checkFullName(Object? value) {
    final name = value is String ? value.trim().replaceAll(RegExp(r'\s+'), ' ') : '';
    if (name.isEmpty || name.length > 255) {
      throw const ApiException(400, 'validation', 'Укажите ФИО (до 255 символов)');
    }
    return name;
  }

  static Role _checkRole(Object? value) {
    final role = Role.tryParse(value);
    if (role == null) {
      throw const ApiException(400, 'validation',
          'Роль — admin, accountant или operator');
    }
    return role;
  }

  static String _checkPassword(Object? value) {
    if (value is! String) {
      throw const ApiException(400, 'validation', 'Укажите пароль');
    }
    final problem = PasswordHasher.validate(value);
    if (problem != null) throw ApiException(400, 'validation', problem);
    return value;
  }
}
