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
    }
    if (sessionExpired) {
      return _error(401, 'token_invalid', 'Требуется вход в систему');
    }
    switch (r.url.path) {
      case '/sync/push':
        final changes =
            (jsonDecode(r.body) as Map<String, Object?>)['changes'] as List;
        return _json({
          'results': [
            for (final c in changes.cast<Map<String, Object?>>())
              () {
                final key = '${c['table']}/${c['uuid']}';
                rows[key] = {...c, 'edited_by': r.headers['x-device-id']}
                  ..remove('change_id');
                log.add(key);
                return {'change_id': c['change_id'], 'status': 'applied'};
              }(),
          ],
        });
      case '/sync/pull':
        final cursor = int.parse(r.url.queryParameters['cursor'] ?? '0');
        final keys = log.skip(cursor).toSet();
        return _json({
          'epoch': 'e1',
          'cursor': log.length,
          'has_more': false,
          'changes': [for (final k in keys) rows[k]],
        });
    }
    return _error(404, 'not_found', 'Не найдено');
  }
}
