import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kfh_domain/kfh_domain.dart' show SyncChange;
import 'package:kfh_local_db/kfh_local_db.dart' show SyncCursor;
import 'package:kfh_sync/kfh_sync.dart';
import 'package:test/test.dart';

final _now = DateTime.utc(2026, 9, 27, 10);

Map<String, Object?> _user({String role = 'admin', bool mustChange = false}) =>
    {
      'uuid': '01900000-0000-7000-8000-000000000001',
      'login': 'ivan',
      'full_name': 'Иван',
      'role': role,
      'is_active': true,
      'must_change_password': mustChange,
    };

Map<String, Object?> _pair(
  String n, {
  Duration accessLeft = const Duration(minutes: 15),
}) => {
  'access_token': 'access-$n',
  'access_expires_at': _now.add(accessLeft).toIso8601String(),
  'refresh_token': 'refresh-$n',
  'refresh_expires_at': _now.add(const Duration(days: 30)).toIso8601String(),
  'user': _user(),
};

http.Response _json(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _error(int status, String code, String message) => _json({
  'error': {'code': code, 'message': message},
}, status);

void main() {
  late List<http.Request> requests;
  late MemoryTokenStore tokens;

  KfhApiClient client(
    FutureOr<http.Response> Function(http.Request) handler, {
    String base = 'https://tab.example.ru',
  }) => KfhApiClient(
    baseUrl: Uri.parse(base),
    deviceId: 'device-1',
    tokens: tokens,
    now: () => _now,
    client: MockClient((r) async {
      requests.add(r);
      return handler(r);
    }),
  );

  setUp(() {
    requests = [];
    tokens = MemoryTokenStore();
  });

  test('вход сохраняет токены; заголовки устройства и JSON', () async {
    final api = client((r) => _json(_pair('1')));
    final user = await api.login('ivan', 'secret-pass');
    expect(user.login, 'ivan');
    expect(user.canUseOn(ClientKind.desktop), isTrue);
    expect(user.canUseOn(ClientKind.phone), isFalse);
    expect(tokens.tokens!.accessToken, 'access-1');
    final r = requests.single;
    expect(r.method, 'POST');
    expect(r.url.toString(), 'https://tab.example.ru/auth/login');
    expect(r.headers['x-device-id'], 'device-1');
    expect(jsonDecode(r.body), {'login': 'ivan', 'password': 'secret-pass'});
  });

  test('версии программ — без входа; старый сервер — пустой список', () async {
    final api = client(
      (r) => _json({
        'platforms': {
          'android': {'latest': '1.3.0', 'min': '1.3.0'},
        },
      }),
    );
    final v = await api.clientVersions();
    expect(v.platforms['android']!.requiresUpdate('1.2.0'), isTrue);
    expect(requests.single.headers['authorization'], isNull);
    expect(requests.single.url.path, '/client/version');

    final old = client((r) => _error(404, 'not_found', 'Нет такого адреса'));
    expect((await old.clientVersions()).platforms, isEmpty);

    final broken = client((r) => _json({'platforms': 1}));
    await expectLater(broken.clientVersions(), throwsA(isA<ServerFailure>()));
  });

  test('неверный пароль — ApiFailure с сообщением сервера', () async {
    final api = client(
      (r) => _error(401, 'invalid_credentials', 'Неверный логин или пароль'),
    );
    await expectLater(
      api.login('ivan', 'x'),
      throwsA(
        isA<ApiFailure>()
            .having((e) => e.code, 'code', 'invalid_credentials')
            .having((e) => e.message, 'message', 'Неверный логин или пароль')
            .having((e) => e.needsLogin, 'needsLogin', false),
      ),
    );
    expect(tokens.tokens, isNull);
  });

  test('запрос с токеном; адрес сервера с путём', () async {
    tokens.tokens = AuthTokens.fromJson(_pair('1'));
    final api = client(
      (r) => _json({'ok': true}),
      base: 'https://example.ru/api/',
    );
    expect(await api.getJson('/sync/pull', query: {'cursor': '0'}), {
      'ok': true,
    });
    final r = requests.single;
    expect(r.url.toString(), 'https://example.ru/api/sync/pull?cursor=0');
    expect(r.headers['authorization'], 'Bearer access-1');
  });

  test('без входа — NotSignedIn, запросов нет', () async {
    final api = client((r) => _json({}));
    await expectLater(api.getJson('/auth/me'), throwsA(isA<NotSignedIn>()));
    expect(requests, isEmpty);
  });

  test('access-токен на исходе — сначала обновление', () async {
    tokens.tokens = AuthTokens.fromJson(
      _pair('1', accessLeft: const Duration(seconds: 30)),
    );
    final api = client(
      (r) => r.url.path == '/auth/refresh'
          ? _json(_pair('2'))
          : _json({'ok': r.headers['authorization']}),
    );
    expect(await api.getJson('/x'), {'ok': 'Bearer access-2'});
    expect(requests.map((r) => r.url.path), ['/auth/refresh', '/x']);
    expect(jsonDecode(requests.first.body), {'refresh_token': 'refresh-1'});
    expect(tokens.tokens!.refreshToken, 'refresh-2');
  });

  test('token_invalid — обновление и одна повторная попытка', () async {
    tokens.tokens = AuthTokens.fromJson(_pair('1'));
    final api = client((r) {
      if (r.url.path == '/auth/refresh') return _json(_pair('2'));
      return r.headers['authorization'] == 'Bearer access-1'
          ? _error(401, 'token_invalid', 'Требуется вход в систему')
          : _json({'ok': true});
    });
    expect(await api.getJson('/x'), {'ok': true});
    expect(requests.map((r) => r.url.path), ['/x', '/auth/refresh', '/x']);
  });

  test('refresh отвергнут — токены удалены, нужен вход', () async {
    tokens.tokens = AuthTokens.fromJson(_pair('1', accessLeft: Duration.zero));
    final api = client(
      (r) => _error(401, 'session_expired', 'Сеанс завершён, войдите заново'),
    );
    await expectLater(
      api.getJson('/x'),
      throwsA(
        isA<ApiFailure>().having((e) => e.needsLogin, 'needsLogin', true),
      ),
    );
    expect(tokens.tokens, isNull);
  });

  test('refresh без сети — токены сохраняются', () async {
    tokens.tokens = AuthTokens.fromJson(_pair('1', accessLeft: Duration.zero));
    final api = client((r) => throw http.ClientException('нет сети'));
    await expectLater(api.getJson('/x'), throwsA(isA<NetworkFailure>()));
    expect(tokens.tokens, isNotNull);
  });

  test('параллельные запросы обновляют токен один раз', () async {
    tokens.tokens = AuthTokens.fromJson(_pair('1', accessLeft: Duration.zero));
    final api = client((r) async {
      if (r.url.path == '/auth/refresh') {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _json(_pair('2'));
      }
      return _json({'ok': true});
    });
    await Future.wait([
      api.getJson('/a'),
      api.getJson('/b'),
      api.getJson('/c'),
    ]);
    expect(requests.where((r) => r.url.path == '/auth/refresh'), hasLength(1));
  });

  test('ответы без понятной ошибки', () async {
    tokens.tokens = AuthTokens.fromJson(_pair('1'));
    final html = client((r) => http.Response('<html>502</html>', 502));
    await expectLater(
      html.getJson('/x'),
      throwsA(
        isA<ServerFailure>().having((e) => e.isTransient, 'transient', true),
      ),
    );
    final notJson = client((r) => http.Response('ok', 200));
    await expectLater(
      notJson.getJson('/x'),
      throwsA(
        isA<ServerFailure>().having((e) => e.isTransient, 'transient', false),
      ),
    );
  });

  test('выход без сети всё равно удаляет токены', () async {
    tokens.tokens = AuthTokens.fromJson(_pair('1'));
    final api = client((r) => throw http.ClientException('нет сети'));
    await api.logout();
    expect(tokens.tokens, isNull);
  });

  test('смена пароля сохраняет новую пару', () async {
    tokens.tokens = AuthTokens.fromJson(_pair('1'));
    final api = client((r) => _json(_pair('2')));
    await api.changePassword('old-pass-1', 'new-pass-1');
    expect(tokens.tokens!.accessToken, 'access-2');
    expect(jsonDecode(requests.single.body), {
      'old_password': 'old-pass-1',
      'new_password': 'new-pass-1',
    });
  });

  test('закрытые месяцы', () async {
    tokens.tokens = AuthTokens.fromJson(_pair('1'));
    final api = client(
      (r) => _json({
        'locks': [
          {'year': 2026, 'month': 8, 'locked_at': '2026-09-27T10:00:00Z'},
          {'year': 2026, 'month': 7, 'note': null},
        ],
      }),
    );
    expect(await api.lockedMonths(), [(2026, 8), (2026, 7)]);
    expect(requests.single.url.path, '/periods/locks');
  });

  test('закрытые месяцы: кто закрыл, закрыть и открыть', () async {
    tokens.tokens = AuthTokens.fromJson(_pair('1'));
    final api = client(
      (r) => r.method == 'GET'
          ? _json({
              'locks': [
                {
                  'year': 2026,
                  'month': 8,
                  'locked_by_name': 'Бухгалтер',
                  'locked_at': '2026-09-27T10:00:00.000Z',
                  'note': 'сдан',
                },
              ],
            })
          : r.method == 'POST'
          ? _json({'year': 2026, 'month': 9}, 201)
          : http.Response('', 204),
    );
    final lock = (await api.periodLocks()).single;
    expect(
      (lock.year, lock.month, lock.lockedByName, lock.note),
      (2026, 8, 'Бухгалтер', 'сдан'),
    );
    expect(lock.lockedAt, DateTime.utc(2026, 9, 27, 10));

    await api.lockMonth(2026, 9, note: 'ведомость');
    expect(requests[1].url.path, '/periods/locks');
    expect(jsonDecode(requests[1].body), {
      'year': 2026,
      'month': 9,
      'note': 'ведомость',
    });
    await api.unlockMonth(2026, 8);
    expect(
      (requests[2].method, requests[2].url.path),
      ('DELETE', '/periods/locks/2026/8'),
    );
  });

  test('открытие месяца: предпросмотр, снимок, id снимка', () async {
    tokens.tokens = AuthTokens.fromJson(_pair('1'));
    Map<String, Object?> row(double accrued, double starting) => {
      'employee_uuid': 'e1',
      'full_name': 'Иванов Иван',
      'starting': starting,
      'accrued': accrued,
      'paid': 1000,
      'closing': starting + accrued - 1000,
    };
    final api = client((r) {
      if (r.method == 'DELETE') return _json({'snapshot_id': 7});
      if (r.url.path.endsWith('/unlock-preview')) {
        return _json({
          'year': 2026,
          'month': 9,
          'lock': {'year': 2026, 'month': 9, 'locked_by_name': 'Бухгалтер'},
          'changes': [
            {
              'year': 2026,
              'month': 9,
              'employees': [
                {'before': row(0, 0), 'after': row(5650, 0)},
              ],
            },
          ],
        });
      }
      if (r.url.path.endsWith('/changes')) {
        return _json({
          'id': 7,
          'year': 2026,
          'month': 9,
          'compared_at': '2026-09-29T08:00:00.000Z',
          'changes': [
            {
              'year': 2026,
              'month': 9,
              'employees': [
                {'before': row(2000, 0), 'after': row(2500, 0)},
              ],
            },
          ],
        });
      }
      if (r.url.path == '/periods/snapshots') {
        return _json({
          'snapshots': [
            {
              'id': 7,
              'year': 2026,
              'month': 9,
              'created_at': '2026-09-28T10:00:00.000Z',
              'created_by_name': 'Админ',
              'lock': null,
            },
          ],
        });
      }
      return _json({
        'id': 7,
        'year': 2026,
        'month': 9,
        'months': [
          {
            'year': 2026,
            'month': 9,
            'employees': [row(0, 0)],
          },
        ],
      });
    });
    final preview = await api.unlockPreview(2026, 9);
    expect(requests.last.url.path, '/periods/locks/2026/9/unlock-preview');
    expect(preview.lock!.lockedByName, 'Бухгалтер');
    final change = preview.changes.single.rows.single;
    expect(
      (change.fullName, change.before.accrued, change.after.accrued),
      ('Иванов Иван', 0.0, 5650.0),
    );
    expect(change.after.closing, 4650.0);

    expect(await api.unlockMonth(2026, 9), 7);
    final listed = (await api.periodSnapshots()).single;
    expect((listed.id, listed.createdByName), (7, 'Админ'));
    expect(listed.months, isEmpty);
    final full = await api.periodSnapshot(7);
    expect(requests.last.url.path, '/periods/snapshots/7');
    expect(full.months.single.rows.single.closing, -1000.0);
    final changes = await api.periodSnapshotChanges(7);
    expect(requests.last.url.path, '/periods/snapshots/7/changes');
    expect(changes.snapshot.id, 7);
    expect(changes.comparedAt, DateTime.utc(2026, 9, 29, 8));
    final c = changes.changes.single.rows.single;
    expect((c.before.accrued, c.after.accrued), (2000.0, 2500.0));
  });

  group('HttpSyncTransport', () {
    setUp(() => tokens.tokens = AuthTokens.fromJson(_pair('1')));

    test('pull: параметры и разбор', () async {
      final api = client(
        (r) => _json({
          'epoch': 'e1',
          'cursor': 12,
          'has_more': false,
          'changes': [
            {
              'table': 'employees',
              'uuid': '01900000-0000-7000-8000-00000000000a',
              'updated_at': '2026-09-27T10:00:00.123456Z',
              'deleted': false,
              'edited_by': 'device-2',
              'data': {
                'legacy_id': null,
                'full_name': 'Петров Пётр',
                'position': 'Рабочий',
                'hire_date': '2025-03-01',
                'dismissal_date': null,
                'base_rate': 1000,
                'field_rate': 1500,
              },
            },
          ],
        }),
      );
      final page = await HttpSyncTransport(
        api,
      ).pull(const SyncCursor(5, 'e1'), limit: 100);
      expect(requests.single.url.queryParameters, {
        'cursor': '5',
        'epoch': 'e1',
        'limit': '100',
      });
      expect(page.cursor, 12);
      expect(page.changes.single.data['base_rate'], 1000.0);
    });

    test('pull с нуля — без эпохи', () async {
      final api = client(
        (r) => _json({
          'epoch': 'e1',
          'cursor': 0,
          'has_more': false,
          'changes': [],
        }),
      );
      await HttpSyncTransport(api).pull(SyncCursor.start);
      expect(requests.single.url.queryParameters.containsKey('epoch'), isFalse);
    });

    test('409 resync_required — ApiFailure', () async {
      final api = client(
        (r) => _error(409, 'resync_required', 'Нужна полная синхронизация'),
      );
      await expectLater(
        HttpSyncTransport(api).pull(const SyncCursor(3, 'old')),
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'resync_required'),
        ),
      );
    });

    test('push: итоги по порядку; неполный ответ — сбой сервера', () async {
      final change = SyncChange(
        table: 'employees',
        uuid: '01900000-0000-7000-8000-00000000000a',
        updatedAt: _now,
        deleted: false,
        changeId: '01900000-0000-7000-8000-00000000000a',
        data: const {
          'legacy_id': null,
          'full_name': 'Петров Пётр',
          'position': 'Рабочий',
          'hire_date': '2025-03-01',
          'dismissal_date': null,
          'base_rate': 1000.0,
          'field_rate': 1500.0,
        },
      );
      final ok = client(
        (r) => _json({
          'results': [
            {
              'change_id': change.changeId,
              'uuid': change.uuid,
              'status': 'rejected',
              'code': 'period_locked',
              'message': 'Месяц закрыт',
            },
          ],
        }),
      );
      final outcome = (await HttpSyncTransport(ok).push([change])).single;
      expect(outcome.status, 'rejected');
      expect(outcome.code, 'period_locked');
      expect(jsonDecode(requests.last.body), {
        'changes': [change.toJson()],
      });

      final short = client((r) => _json({'results': []}));
      await expectLater(
        HttpSyncTransport(short).push([change]),
        throwsA(isA<ServerFailure>()),
      );
    });
  });
}
