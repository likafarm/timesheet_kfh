import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:kfh_domain/kfh_domain.dart';

import 'audit_log.dart';
import 'failures.dart';
import 'period_snapshots.dart';
import 'server_backups.dart';
import 'session.dart';
import 'timesheet_day.dart';

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

  /// Табель дня с авторами отметок (6.10, сервер 0.6.0+).
  Future<TimesheetDayInfo> timesheetDay(DateTime day) async =>
      TimesheetDayInfo.fromJson(
        await getJson('/timesheet/day', query: {'date': formatDateIso(day)}),
      );

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

  /// Пользователи сервера (только админ).
  Future<List<SessionUser>> users() async {
    final list = (await getJson('/users'))['users'];
    if (list is! List) throw ServerFailure('нет списка пользователей');
    return [
      for (final u in list)
        if (u is Map) SessionUser.fromJson(u.cast<String, Object?>()),
    ];
  }

  /// Журнал действий сервера (6.7, только админ): [since]/[until] — моменты
  /// (переводятся в UTC), [kind] — `timesheet`, `payments`, `rates`,
  /// `employees`, `payroll`, `settings`, `periods`, `access`; [before] —
  /// курсор предыдущей страницы.
  Future<AuditPage> auditLog({
    DateTime? since,
    DateTime? until,
    String? userUuid,
    String? employeeUuid,
    String? kind,
    int? before,
    int limit = 100,
  }) async => AuditPage.fromJson(
    await getJson(
      '/audit',
      query: {
        if (since != null) 'since': since.toUtc().toIso8601String(),
        if (until != null) 'until': until.toUtc().toIso8601String(),
        'user_uuid': ?userUuid,
        'employee_uuid': ?employeeUuid,
        'kind': ?kind,
        if (before != null) 'before': '$before',
        'limit': '$limit',
      },
    ),
  );

  /// Ежедневные выгрузки сервера для модуля «Резервные копии» (только
  /// админ, сервер 0.8.0+), новые первыми.
  Future<List<ServerBackup>> serverBackups() async {
    final list = (await getJson('/admin/backups'))['backups'];
    if (list is! List) throw ServerFailure('нет списка копий');
    return [for (final b in list) ServerBackup.fromJson(b)];
  }

  /// Выгрузка сервера как есть — зашифрованная (age).
  Future<Uint8List> downloadServerBackup(String name) => getBytes(
    '/admin/backups/${Uri.encodeComponent(name)}',
    timeout: const Duration(minutes: 2),
  );

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

  /// Файл с сервера как есть (не JSON) — например, зашифрованная копия.
  Future<Uint8List> getBytes(String path, {Duration? timeout}) =>
      _withToken((access) async {
        final response = await _sendRaw(
          'GET',
          path,
          access: access,
          timeout: timeout,
          accept: 'application/octet-stream',
        );
        if (response.statusCode == 200) return response.bodyBytes;
        _decode(response); // бросает ошибку API
        throw ServerFailure('нет файла', status: response.statusCode);
      });

  Future<Map<String, Object?>> _authorized(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Duration? timeout,
  }) => _withToken(
    (access) => _send(
      method,
      path,
      query: query,
      body: body,
      access: access,
      timeout: timeout,
    ),
  );

  /// Запрос [call] с действующим access-токеном: токен обновляется заранее
  /// и ещё раз — если сервер его не принял.
  Future<T> _withToken<T>(Future<T> Function(String access) call) async {
    var pair = await tokens.read();
    if (pair == null) throw NotSignedIn();
    if (!pair.accessExpiresAt.isAfter(_now().toUtc().add(refreshMargin))) {
      pair = await _refresh(pair);
    }
    try {
      return await call(pair.accessToken);
    } on ApiFailure catch (e) {
      if (e.status != 401 || e.code != 'token_invalid') rethrow;
    }
    // Токен не принят раньше срока (например, сервер сменил ключ) — ещё
    // одна попытка с новой парой.
    pair = await _refresh(pair);
    return call(pair.accessToken);
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
  }) async => _decode(
    await _sendRaw(
      method,
      path,
      query: query,
      body: body,
      access: access,
      timeout: timeout,
    ),
  );

  Future<http.Response> _sendRaw(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? access,
    Duration? timeout,
    String accept = 'application/json',
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
        'accept': accept,
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
    return response;
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
