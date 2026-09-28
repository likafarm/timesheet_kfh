import 'dart:convert';

import 'package:http/http.dart' as http;

/// Сервер для тестов интерфейса синхронизации (через `MockClient`): вход,
/// смена пароля, push (всё принимает) и pull. Правила синхронизации
/// проверяются в packages/sync и server — здесь только поведение
/// интерфейса.
class SyncTestServer {
  String role = 'admin';
  bool mustChange = false;
  bool online = true;
  bool sessionExpired = false;
  final rows = <String, Map<String, Object?>>{};
  final log = <String>[];

  /// Ответ `GET /client/version` (null — старый сервер без этого адреса).
  Map<String, Object?>? versions;

  /// Закрытые месяцы `(год, месяц)`.
  final locks = <(int, int)>[];

  /// Открытые месяцы, по которым сохранён снимок (id = номер + 1).
  final snapshots = <(int, int)>[];

  /// Версия сервера в `/health`.
  String serverVersion = '0.4.0';

  /// Правки этих таблиц сервер отклоняет.
  final rejectTables = <String>{};

  /// Примечания, с которыми закрывали месяцы (по порядку).
  final lockNotes = <String?>[];

  /// Сколько было запросов push и pull.
  int pushes = 0;
  int pulls = 0;

  http.Response _json(Object? body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  http.Response _error(int status, String code, String message) => _json({
    'error': {'code': code, 'message': message},
  }, status);

  Map<String, Object?> _pair() => {
    'access_token': 'a',
    'access_expires_at': DateTime.now()
        .add(const Duration(minutes: 15))
        .toUtc()
        .toIso8601String(),
    'refresh_token': 'r',
    'refresh_expires_at': DateTime.now()
        .add(const Duration(days: 30))
        .toUtc()
        .toIso8601String(),
    'user': {
      'uuid': '01900000-0000-7000-8000-000000000001',
      'login': 'ivan',
      'full_name': 'Иван Иванов',
      'role': role,
      'must_change_password': mustChange,
    },
  };

  Future<http.Response> handle(http.Request r) async {
    if (!online) throw http.ClientException('нет сети', r.url);
    switch (r.url.path) {
      case '/health':
        return _json({'status': 'ok', 'version': serverVersion});
      case '/auth/login':
        final body = jsonDecode(r.body) as Map<String, Object?>;
        if (body['password'] != 'secret-pass') {
          return _error(
            401,
            'invalid_credentials',
            'Неверный логин или пароль',
          );
        }
        return _json(_pair());
      case '/auth/change-password':
        mustChange = false;
        return _json(_pair());
      case '/auth/logout':
        return http.Response('', 204);
      case '/auth/refresh':
        return _error(401, 'session_expired', 'Сеанс завершён, войдите заново');
      case '/client/version':
        final v = versions;
        return v == null ? _error(404, 'not_found', 'Нет адреса') : _json(v);
    }
    if (sessionExpired) {
      return _error(401, 'token_invalid', 'Требуется вход в систему');
    }
    switch (r.url.path) {
      case '/sync/push':
        pushes++;
        final changes =
            (jsonDecode(r.body) as Map<String, Object?>)['changes'] as List;
        return _json({
          'results': [
            for (final c in changes.cast<Map<String, Object?>>())
              () {
                final key = '${c['table']}/${c['uuid']}';
                if (rejectTables.contains(c['table'])) {
                  return {
                    'change_id': c['change_id'],
                    'status': 'rejected',
                    'code': 'invalid',
                    'message': 'Не принято',
                  };
                }
                // Как на сервере: побеждает более поздняя правка.
                final existing = rows[key];
                if (existing != null) {
                  final mine = DateTime.parse(existing['updated_at'] as String);
                  final theirs = DateTime.parse(c['updated_at'] as String);
                  if (!theirs.isAfter(mine)) {
                    final same =
                        theirs == mine &&
                        jsonEncode(existing['data']) == jsonEncode(c['data']) &&
                        existing['deleted'] == c['deleted'];
                    return {
                      'change_id': c['change_id'],
                      'status': same ? 'duplicate' : 'stale',
                    };
                  }
                }
                rows[key] = {...c, 'edited_by': r.headers['x-device-id']}
                  ..remove('change_id');
                log.add(key);
                return {'change_id': c['change_id'], 'status': 'applied'};
              }(),
          ],
        });
      case '/periods/locks' when r.method == 'POST':
        if (role == 'operator') return _error(403, 'forbidden', 'Нельзя');
        final body = jsonDecode(r.body) as Map<String, Object?>;
        final month = (body['year'] as int, body['month'] as int);
        if (locks.contains(month)) {
          return _error(409, 'already_locked', 'Месяц уже закрыт');
        }
        locks.add(month);
        lockNotes.add(body['note'] as String?);
        return _json({'year': month.$1, 'month': month.$2}, 201);
      case '/periods/locks':
        return _json({
          'locks': [
            for (final (y, m) in locks)
              {
                'year': y,
                'month': m,
                'locked_by_name': 'Иван Иванов',
                'locked_at': '2026-09-28T10:00:00.000Z',
              },
          ],
        });
      case '/sync/pull':
        pulls++;
        final cursor = int.parse(r.url.queryParameters['cursor'] ?? '0');
        final keys = log.skip(cursor).toSet();
        return _json({
          'epoch': 'e1',
          'cursor': log.length,
          'has_more': false,
          'changes': [for (final k in keys) rows[k]],
        });
    }
    final unlock = RegExp(
      r'^/periods/locks/(\d+)/(\d+)$',
    ).firstMatch(r.url.path);
    if (unlock != null && r.method == 'DELETE') {
      if (role != 'admin') {
        return _error(
          403,
          'forbidden',
          'Открыть месяц может только администратор',
        );
      }
      final month = (int.parse(unlock[1]!), int.parse(unlock[2]!));
      if (!locks.remove(month)) {
        return _error(404, 'not_found', 'Месяц не закрыт');
      }
      snapshots.add(month);
      return _json({'snapshot_id': snapshots.length});
    }
    final preview = RegExp(
      r'^/periods/locks/(\d+)/(\d+)/unlock-preview$',
    ).firstMatch(r.url.path);
    if (preview != null) {
      if (role != 'admin') return _error(403, 'forbidden', 'Только админ');
      final month = (int.parse(preview[1]!), int.parse(preview[2]!));
      if (!locks.contains(month)) {
        return _error(404, 'not_found', 'Месяц не закрыт');
      }
      Map<String, Object?> row(double accrued) => {
        'employee_uuid': 'e1',
        'full_name': 'Иванов Иван',
        'starting': 0,
        'accrued': accrued,
        'paid': 0,
        'closing': accrued,
      };
      return _json({
        'year': month.$1,
        'month': month.$2,
        'lock': {'year': month.$1, 'month': month.$2},
        'changes': [
          {
            'year': month.$1,
            'month': month.$2,
            'employees': [
              {'before': row(1000), 'after': row(1500)},
            ],
          },
        ],
      });
    }
    final changes = RegExp(
      r'^/periods/snapshots/(\d+)/changes$',
    ).firstMatch(r.url.path);
    if (changes != null) {
      final id = int.parse(changes[1]!);
      if (id < 1 || id > snapshots.length) {
        return _error(404, 'not_found', 'Нет такого снимка');
      }
      final (y, m) = snapshots[id - 1];
      return _json({
        'id': id,
        'year': y,
        'month': m,
        'compared_at': '2026-09-29T08:00:00.000Z',
        'changes': <Object?>[],
      });
    }
    if (r.url.path == '/periods/snapshots') {
      return _json({
        'snapshots': [
          for (final (i, (y, m)) in snapshots.indexed.toList().reversed)
            {'id': i + 1, 'year': y, 'month': m},
        ],
      });
    }
    return _error(404, 'not_found', 'Не найдено');
  }
}
