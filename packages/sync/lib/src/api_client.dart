import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'failures.dart';
import 'session.dart';

/// Клиент API сервера: вход, токены, JSON-запросы.
///
/// Access-токен живёт 15 минут: клиент обновляет его заранее и ещё раз,
/// если сервер всё же ответил `token_invalid`. Refresh-токен одноразовый
/// (сервер выдаёт новую пару), поэтому обновление идёт строго по одному.
class KfhApiClient {
  final Uri baseUrl;
  final String deviceId;
  final TokenStore tokens;
  final http.Client _http;
  final Duration timeout;
  final DateTime Function() _now;

  /// Обновлять access-токен, если до конца его жизни меньше этого.
  static const refreshMargin = Duration(seconds: 60);

  Future<AuthTokens>? _refreshing;

  KfhApiClient({
    required this.baseUrl,
    required this.deviceId,
    required this.tokens,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _http = client ?? http.Client(),
       _now = now ?? DateTime.now;

  void close() => _http.close();

  // ------------------------------------------------------------- вход

  /// Вход логином и паролем. Токены сохраняются в [tokens].
  Future<SessionUser> login(String login, String password) async {
    final json = await _send(
      'POST',
      '/auth/login',
      body: {'login': login, 'password': password},
    );
    final pair = AuthTokens.fromJson(json);
    await tokens.write(pair);
    return pair.user;
  }

  /// Выход: сервер гасит refresh-токен; локально токены удаляются в любом
  /// случае (даже без связи).
  Future<void> logout() async {
    final current = await tokens.read();
    await tokens.clear();
    if (current == null) return;
    try {
      await _send(
        'POST',
        '/auth/logout',
        body: {'refresh_token': current.refreshToken},
      );
    } on SyncFailure {
      // Токен истечёт сам.
    }
  }

  /// Пользователь, под которым выполнен вход (из сохранённых токенов).
  Future<SessionUser?> currentUser() async => (await tokens.read())?.user;

  /// Пользователь по данным сервера; сохранённый обновляется.
  Future<SessionUser> me() async {
    final json = await getJson('/auth/me');
    final user = SessionUser.fromJson(json);
    final current = await tokens.read();
    if (current != null) await tokens.write(current.withUser(user));
    return user;
  }

  /// Смена пароля; сервер выдаёт новую пару токенов.
  Future<SessionUser> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    final json = await postJson('/auth/change-password', {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
    final pair = AuthTokens.fromJson(json);
    await tokens.write(pair);
    return pair.user;
  }

  // ------------------------------------------------------------- запросы

  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, String>? query,
  }) => _authorized('GET', path, query: query);

  Future<Map<String, Object?>> postJson(String path, Object? body) =>
      _authorized('POST', path, body: body);

  Future<Map<String, Object?>> _authorized(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    var pair = await tokens.read();
    if (pair == null) throw NotSignedIn();
    if (!pair.accessExpiresAt.isAfter(_now().toUtc().add(refreshMargin))) {
      pair = await _refresh(pair);
    }
    try {
      return await _send(
        method,
        path,
        query: query,
        body: body,
        access: pair.accessToken,
      );
    } on ApiFailure catch (e) {
      if (e.status != 401 || e.code != 'token_invalid') rethrow;
    }
    // Токен не принят раньше срока (например, сервер сменил ключ) — ещё
    // одна попытка с новой парой.
    pair = await _refresh(pair);
    return _send(
      method,
      path,
      query: query,
      body: body,
      access: pair.accessToken,
    );
  }

  /// Обмен refresh-токена на новую пару. Параллельные вызовы ждут один
  /// запрос: второй обмен того же токена сервер отверг бы.
  Future<AuthTokens> _refresh(AuthTokens stale) {
    return _refreshing ??= () async {
      try {
        // Пока ждали, пару могли уже обновить.
        final current = await tokens.read();
        if (current == null) throw NotSignedIn();
        if (current.refreshToken != stale.refreshToken) return current;
        try {
          final json = await _send(
            'POST',
            '/auth/refresh',
            body: {'refresh_token': current.refreshToken},
          );
          final pair = AuthTokens.fromJson(json);
          await tokens.write(pair);
          return pair;
        } on ApiFailure catch (e) {
          if (e.status == 401) {
            await tokens.clear();
            throw ApiFailure(
              401,
              'session_expired',
              'Сеанс завершён, войдите заново',
            );
          }
          rethrow;
        }
      } finally {
        _refreshing = null;
      }
    }();
  }

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? access,
  }) async {
    final base = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    final uri = baseUrl.replace(
      path: '$base$path',
      queryParameters: query?.isEmpty ?? true ? null : query,
    );
    final request = http.Request(method, uri)
      ..headers.addAll({
        'accept': 'application/json',
        'x-device-id': deviceId,
        if (access != null) 'authorization': 'Bearer $access',
      });
    if (body != null) {
      request.headers['content-type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      ).timeout(timeout);
    } on http.ClientException catch (e) {
      throw NetworkFailure(e);
    } on TimeoutException catch (e) {
      throw NetworkFailure(e);
    }
    return _decode(response);
  }

  static Map<String, Object?> _decode(http.Response response) {
    Object? json;
    if (response.bodyBytes.isNotEmpty) {
      try {
        json = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        json = null;
      }
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (status == 204 || response.bodyBytes.isEmpty) return const {};
      if (json is Map<String, Object?>) return json;
      throw ServerFailure('ответ не JSON-объект', status: status);
    }
    if (json is Map<String, Object?> && json['error'] is Map) {
      final error = json['error'] as Map;
      final code = error['code'], message = error['message'];
      if (code is String && message is String) {
        throw ApiFailure(status, code, message);
      }
    }
    throw ServerFailure('HTTP $status', status: status);
  }
}
