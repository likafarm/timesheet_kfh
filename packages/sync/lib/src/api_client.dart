import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kfh_domain/kfh_domain.dart';

import 'failures.dart';
import 'period_snapshots.dart';
import 'session.dart';

/// Клиент API сервера: вход, токены, JSON-запросы.
///
/// Access-токен живёт 15 минут: клиент обновляет его заранее и ещё раз,
/// если сервер всё же ответил `token_invalid`. Refresh-токен одноразовый
/// (сервер выдаёт новую пару), поэтому обновление идёт строго по одному.
/// Закрытый на сервере месяц.
class PeriodLockInfo {
  final int year;
  final int month;

  /// Кто закрыл (ФИО пользователя; null — пользователь удалён).
  final String? lockedByName;
  final DateTime? lockedAt;
  final String? note;

  const PeriodLockInfo({
    required this.year,
    required this.month,
    this.lockedByName,
    this.lockedAt,
    this.note,
  });
}

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

  /// Закрытые на сервере месяцы `(год, месяц)`.
  Future<List<(int, int)>> lockedMonths() async => [
    for (final l in await periodLocks()) (l.year, l.month),
  ];

  /// Закрытые месяцы со сведениями, кто и когда закрыл (новые сверху).
  Future<List<PeriodLockInfo>> periodLocks() async {
    final json = await getJson('/periods/locks');
    final locks = json['locks'];
    if (locks is! List) throw ServerFailure('нет списка закрытых месяцев');
    return [
      for (final l in locks)
        if (l is Map && l['year'] is int && l['month'] is int)
          PeriodLockInfo(
            year: l['year'] as int,
            month: l['month'] as int,
            lockedByName: l['locked_by_name'] as String?,
            lockedAt: DateTime.tryParse('${l['locked_at']}'),
            note: l['note'] as String?,
          ),
    ];
  }

  /// Закрыть месяц (бухгалтер и админ). Сервер до закрытия пересчитывает
  /// его расчёт; уже закрыт — [ApiFailure] `already_locked`.
  Future<void> lockMonth(int year, int month, {String? note}) =>
      postJson('/periods/locks', {'year': year, 'month': month, 'note': ?note});

  /// Открыть закрытый месяц (только админ). Сервер сохраняет снимок
  /// остатков до открытия и пересчитывает расчёты; возвращает id снимка.
  Future<int?> unlockMonth(int year, int month) async {
    final json = await _authorized('DELETE', '/periods/locks/$year/$month');
    return json['snapshot_id'] as int?;
  }

  /// Что изменит открытие месяца — без изменений на сервере (только админ).
  Future<UnlockPreview> unlockPreview(int year, int month) async =>
      UnlockPreview.fromJson(
        await getJson('/periods/locks/$year/$month/unlock-preview'),
      );

  /// Снимки остатков перед открытием месяцев, новые сверху (без данных).
  Future<List<PeriodSnapshot>> periodSnapshots() async {
    final list = (await getJson('/periods/snapshots'))['snapshots'];
    if (list is! List) throw ServerFailure('нет списка снимков');
    return [for (final s in list) PeriodSnapshot.fromJson(s)];
  }

  /// Снимок целиком.
  Future<PeriodSnapshot> periodSnapshot(int id) async =>
      PeriodSnapshot.fromJson(await getJson('/periods/snapshots/$id'));

  /// Что изменилось со времени снимка (только изменившиеся строки).
  Future<SnapshotChanges> periodSnapshotChanges(int id) async =>
      SnapshotChanges.fromJson(await getJson('/periods/snapshots/$id/changes'));

  /// Версии программ (`GET /client/version`, без входа). Старый сервер без
  /// этого адреса — пустой список (обновлений не требуется).
  Future<ClientVersions> clientVersions() async {
    try {
      return ClientVersions.fromJson(await _send('GET', '/client/version'));
    } on ApiFailure catch (e) {
      if (e.code == 'not_found') return ClientVersions.empty;
      rethrow;
    } on ClientVersionsFormatException catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  /// Версия сервера (`GET /health`, без входа); null — не сообщает.
  Future<String?> serverVersion() async =>
      (await _send('GET', '/health'))['version'] as String?;

  // ------------------------------------------------------------- запросы

  Future<Map<String, Object?>> getJson(
    String path, {
    Map<String, String>? query,
  }) => _authorized('GET', path, query: query);

  /// [timeout] — свой срок ожидания (долгие операции вроде импорта).
  Future<Map<String, Object?>> postJson(
    String path,
    Object? body, {
    Duration? timeout,
  }) => _authorized('POST', path, body: body, timeout: timeout);

  Future<Map<String, Object?>> _authorized(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Duration? timeout,
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
        timeout: timeout,
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
      timeout: timeout,
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
    Duration? timeout,
  }) async {
    final wait = timeout ?? this.timeout;
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
        await _http.send(request).timeout(wait),
      ).timeout(wait);
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
      final details = error['details'];
      if (code is String && message is String) {
        throw ApiFailure(status, code, message, [
          if (details is List)
            for (final d in details) '$d',
        ]);
      }
    }
    throw ServerFailure('HTTP $status', status: status);
  }
}
