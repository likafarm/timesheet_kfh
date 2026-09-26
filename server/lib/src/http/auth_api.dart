import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_service.dart';
import '../auth/users.dart';
import 'middleware.dart';
import 'request_utils.dart';
import 'responses.dart';

/// Маршруты входа и пользователей.
///
/// - `POST /auth/login` `{login, password}` → пара токенов и пользователь;
/// - `POST /auth/refresh` `{refresh_token}` → новая пара (старый гасится);
/// - `POST /auth/logout` `{refresh_token}` → 204;
/// - `GET /auth/me` → пользователь;
/// - `POST /auth/change-password` `{old_password, new_password}` → новая пара;
/// - `GET /users`, `POST /users`, `PATCH /users/<uuid>`,
///   `POST /users/<uuid>/reset-password` — только админ.
///
/// Остальные запросы требуют `Authorization: Bearer <access_token>`.
/// Пока пользователь не сменил выданный админом пароль, ему доступны
/// только `me`, `change-password`, `refresh` и `logout`.
class AuthApi {
  final AuthService auth;
  final bool trustProxy;

  AuthApi(this.auth, {this.trustProxy = false});

  void addRoutes(Router router) {
    router
      ..post('/auth/login', _login)
      ..post('/auth/refresh', _refresh)
      ..post('/auth/logout', _logout)
      ..get('/auth/me', _me)
      ..post('/auth/change-password', _changePassword)
      ..get('/users', _listUsers)
      ..post('/users', _createUser)
      ..patch('/users/<uuid>', _updateUser)
      ..post('/users/<uuid>/reset-password', _resetPassword);
  }

  /// Пользователь запроса. Для всех будущих защищённых маршрутов.
  Future<User> requireUser(Request request,
      {bool allowPasswordChange = false}) async {
    final token = bearerToken(request);
    if (token == null) throw tokenInvalid;
    final user = await auth.authenticate(token);
    if (user.mustChangePassword && !allowPasswordChange) {
      throw passwordChangeRequired;
    }
    return user;
  }

  RequestInfo info(Request request) => RequestInfo(
        requestId: requestIdOf(request),
        deviceId: deviceIdOf(request),
        ip: clientIp(request, trustProxy: trustProxy),
      );

  Future<Response> _login(Request request) async {
    final body = await readJsonObject(request);
    final pair = await auth.login(requireString(body, 'login'),
        requireString(body, 'password'), info(request));
    return jsonResponse(pair.toJson());
  }

  Future<Response> _refresh(Request request) async {
    final body = await readJsonObject(request);
    final pair =
        await auth.refresh(requireString(body, 'refresh_token'), info(request));
    return jsonResponse(pair.toJson());
  }

  Future<Response> _logout(Request request) async {
    final body = await readJsonObject(request);
    await auth.logout(requireString(body, 'refresh_token'), info(request));
    return Response(204);
  }

  Future<Response> _me(Request request) async {
    final user = await requireUser(request, allowPasswordChange: true);
    return jsonResponse(user.toJson());
  }

  Future<Response> _changePassword(Request request) async {
    final user = await requireUser(request, allowPasswordChange: true);
    final body = await readJsonObject(request);
    final pair = await auth.changePassword(
        user,
        requireString(body, 'old_password'),
        requireString(body, 'new_password'),
        info(request));
    return jsonResponse(pair.toJson());
  }

  Future<Response> _listUsers(Request request) async {
    final actor = await requireUser(request);
    final users = await auth.listUsers(actor);
    return jsonResponse({'users': users.map((u) => u.toJson()).toList()});
  }

  Future<Response> _createUser(Request request) async {
    final actor = await requireUser(request);
    final body = await readJsonObject(request);
    final user = await auth.createUser(actor,
        login: body['login'],
        fullName: body['full_name'],
        role: body['role'],
        password: body['password'],
        info: info(request));
    return jsonResponse(user.toJson(), status: 201);
  }

  Future<Response> _updateUser(Request request, String uuid) async {
    final actor = await requireUser(request);
    final body = await readJsonObject(request);
    final unknown = body.keys.toSet().difference({'full_name', 'role', 'is_active'});
    if (unknown.isNotEmpty) {
      throw ApiException.badRequest('Эти поля не меняются здесь: '
          '${unknown.join(', ')}');
    }
    final user = await auth.updateUser(actor, uuid,
        fullName: body['full_name'],
        role: body['role'],
        isActive: body['is_active'],
        info: info(request));
    return jsonResponse(user.toJson());
  }

  Future<Response> _resetPassword(Request request, String uuid) async {
    final actor = await requireUser(request);
    final body = await readJsonObject(request);
    await auth.resetPassword(actor, uuid, body['password'], info(request));
    return Response(204);
  }
}
