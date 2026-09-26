@Tags(['mysql'])
library;

import 'dart:convert';

import 'package:kfh_server/kfh_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support/mysql.dart';

/// Вход, токены и пользователи через HTTP-обработчик на настоящей MySQL.
void main() {
  late TestDatabase testDb;
  late Handler handler;
  late AuthService auth;
  late DateTime now;

  const adminPassword = 'admin-pass-1';

  setUp(() async {
    if (!mysqlEnabled) return;
    testDb = await TestDatabase.create(maxConnections: 4);
    final logger = Logger(write: (_) {});
    await MigrationRunner(testDb.db, logger).migrate(projectMigrations());
    now = DateTime.utc(2026, 9, 26, 10);
    DateTime clock() => now;
    auth = AuthService(
      db: testDb.db,
      accessTokens: AccessTokens(utf8.encode('k' * 32), now: clock),
      logger: logger,
      // Лёгкий Argon2 — тесты быстрые; правильность — password_hasher_test.
      hasher: const PasswordHasher(memoryKiB: 1024, iterations: 1),
      loginThrottle: LoginThrottle(maxFailures: 5, now: clock),
      ipThrottle: LoginThrottle(maxFailures: 30, now: clock),
      now: clock,
    );
    handler = buildHandler(
      db: testDb.db,
      logger: logger,
      authApi: AuthApi(auth, trustProxy: true),
    );
    await auth.createFirstAdmin(
        login: 'admin', fullName: 'Главный Админ', password: adminPassword);
  });

  tearDown(() async {
    if (mysqlEnabled) await testDb.dispose();
  });

  /// Запрос к обработчику; тело ответа — JSON или null.
  Future<(int, dynamic, Map<String, String>)> call(
    String method,
    String path, {
    Object? body,
    String? token,
    Map<String, String> headers = const {},
  }) async {
    final response = await handler(Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : (body is String ? body : jsonEncode(body)),
      headers: {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
        ...headers,
      },
    ));
    final text = await response.readAsString();
    return (
      response.statusCode,
      text.isEmpty ? null : jsonDecode(text),
      response.headers,
    );
  }

  Future<Map<String, dynamic>> login(String login, String password,
      {String ip = '10.0.0.1'}) async {
    final (status, json, _) = await call('POST', '/auth/login',
        body: {'login': login, 'password': password},
        headers: {'x-forwarded-for': ip, 'x-device-id': 'test-device'});
    expect(status, 200, reason: '$json');
    return json;
  }

  String errorCode(dynamic json) => json['error']['code'];

  Future<List<Map<String, String?>>> audit(String action) async {
    const columns = [
      'user_uuid', 'entity_uuid', 'device_id', 'old_value', 'new_value',
    ];
    final r = await testDb.db.execute(
        'SELECT ${columns.join(', ')} FROM audit_log WHERE action = :a '
        'ORDER BY id',
        {'a': action});
    return [
      for (final row in r.rows) {for (final c in columns) c: row.text(c)},
    ];
  }

  Future<Map<String, dynamic>> createUser(String adminToken,
      {String login = 'operator1',
      String role = 'operator',
      String password = 'first-pass-1'}) async {
    final (status, json, _) = await call('POST', '/users',
        token: adminToken,
        body: {
          'login': login,
          'full_name': '  Петров   Пётр ',
          'role': role,
          'password': password,
        });
    expect(status, 201, reason: '$json');
    return json;
  }

  group('вход', () {
    test('логин и пароль верны — токены, пользователь без хэша', () async {
      final json = await login('admin', adminPassword);
      expect(json['access_token'], isNotEmpty);
      expect(json['refresh_token'], isNotEmpty);
      expect(json['access_expires_at'], '2026-09-26T10:15:00.000Z');
      expect(json['refresh_expires_at'], startsWith('2026-10-26T10:00:00'));
      expect(json['user']['login'], 'admin');
      expect(json['user']['role'], 'admin');
      expect(json['user'], isNot(contains('password_hash')));

      final (status, me, headers) =
          await call('GET', '/auth/me', token: json['access_token']);
      expect(status, 200);
      expect(me['full_name'], 'Главный Админ');
      expect(headers['cache-control'], 'no-store');

      final logins = await audit('login');
      expect(logins.single['device_id'], 'test-device');
    }, skip: mysqlSkip);

    test('логин без учёта регистра и пробелов по краям', () async {
      await login('  ADMIN ', adminPassword);
    }, skip: mysqlSkip);

    test('неверный пароль и неизвестный логин — одинаковый ответ', () async {
      final (s1, j1, _) = await call('POST', '/auth/login',
          body: {'login': 'admin', 'password': 'wrong-pass'});
      final (s2, j2, _) = await call('POST', '/auth/login',
          body: {'login': 'nobody', 'password': 'wrong-pass'});
      expect(s1, 401);
      expect(s2, 401);
      expect(j1, j2);
      expect(errorCode(j1), 'invalid_credentials');
      expect(await audit('login_failed'), hasLength(2));
    }, skip: mysqlSkip);

    test('5 неудач по логину — блок на 15 минут даже с верным паролем',
        () async {
      for (var i = 0; i < 5; i++) {
        final (s, _, _) = await call('POST', '/auth/login',
            body: {'login': 'admin', 'password': 'wrong-$i'},
            headers: {'x-forwarded-for': '10.0.0.$i'});
        expect(s, 401);
      }
      final (status, json, headers) = await call('POST', '/auth/login',
          body: {'login': 'admin', 'password': adminPassword});
      expect(status, 429);
      expect(errorCode(json), 'too_many_attempts');
      expect(headers['retry-after'], '900');

      now = now.add(const Duration(minutes: 15));
      await login('admin', adminPassword);
    }, skip: mysqlSkip);

    test('30 неудач с одного адреса — блок адреса для любых логинов',
        () async {
      for (var i = 0; i < 30; i++) {
        await call('POST', '/auth/login',
            body: {'login': 'user$i', 'password': 'wrong-pass'},
            headers: {'x-forwarded-for': '1.2.3.4'});
      }
      final (status, _, _) = await call('POST', '/auth/login',
          body: {'login': 'admin', 'password': adminPassword},
          headers: {'x-forwarded-for': '9.9.9.9, 1.2.3.4'});
      expect(status, 429);
      // Другой адрес — входит.
      await login('admin', adminPassword, ip: '5.6.7.8');
    }, skip: mysqlSkip);

    test('неполный или испорченный запрос — 400, огромный — 413', () async {
      var (s, j, _) = await call('POST', '/auth/login', body: {'login': 'a'});
      expect(s, 400);
      (s, j, _) = await call('POST', '/auth/login', body: 'не json');
      expect(s, 400);
      (s, j, _) = await call('POST', '/auth/login', body: [1, 2]);
      expect(s, 400);
      (s, j, _) = await call('POST', '/auth/login',
          body: {'login': 'admin', 'password': 'x' * 70000});
      expect(s, 413);
      expect(errorCode(j), 'too_large');
    }, skip: mysqlSkip);
  });

  group('токены', () {
    test('без токена, с мусором, просроченный — 401 token_invalid', () async {
      final tokens = await login('admin', adminPassword);
      var (s, j, _) = await call('GET', '/auth/me');
      expect((s, errorCode(j)), (401, 'token_invalid'));
      (s, j, _) = await call('GET', '/auth/me', token: 'garbage');
      expect((s, errorCode(j)), (401, 'token_invalid'));

      now = now.add(const Duration(minutes: 15));
      (s, j, _) = await call('GET', '/auth/me', token: tokens['access_token']);
      expect((s, errorCode(j)), (401, 'token_invalid'));
    }, skip: mysqlSkip);

    test('refresh выдаёт новую пару, старый refresh больше не годится',
        () async {
      final first = await login('admin', adminPassword);
      now = now.add(const Duration(minutes: 20));
      final (s, second, _) = await call('POST', '/auth/refresh',
          body: {'refresh_token': first['refresh_token']});
      expect(s, 200);
      expect(second['refresh_token'], isNot(first['refresh_token']));
      final (meStatus, _, _) =
          await call('GET', '/auth/me', token: second['access_token']);
      expect(meStatus, 200);
    }, skip: mysqlSkip);

    test('повторное использование refresh — гасится вся цепочка входа',
        () async {
      final first = await login('admin', adminPassword);
      final other = await login('admin', adminPassword); // другой вход
      final (_, second, _) = await call('POST', '/auth/refresh',
          body: {'refresh_token': first['refresh_token']});

      // Украденный старый токен предъявили ещё раз.
      final (s, j, _) = await call('POST', '/auth/refresh',
          body: {'refresh_token': first['refresh_token']});
      expect((s, errorCode(j)), (401, 'session_expired'));
      // Гаснет и выданный взамен…
      final (s2, _, _) = await call('POST', '/auth/refresh',
          body: {'refresh_token': second['refresh_token']});
      expect(s2, 401);
      // …но не другой вход того же пользователя.
      final (s3, _, _) = await call('POST', '/auth/refresh',
          body: {'refresh_token': other['refresh_token']});
      expect(s3, 200);
      expect(await audit('token_reuse'), hasLength(1));
    }, skip: mysqlSkip);

    test('refresh истекает через 30 дней', () async {
      final tokens = await login('admin', adminPassword);
      now = now.add(const Duration(days: 30));
      final (s, _, _) = await call('POST', '/auth/refresh',
          body: {'refresh_token': tokens['refresh_token']});
      expect(s, 401);
    }, skip: mysqlSkip);

    test('два одновременных обмена одного refresh — удаётся только один',
        () async {
      final tokens = await login('admin', adminPassword);
      final results = await Future.wait([
        for (var i = 0; i < 2; i++)
          call('POST', '/auth/refresh',
              body: {'refresh_token': tokens['refresh_token']}),
      ]);
      expect(results.map((r) => r.$1).toList()..sort(), [200, 401]);
    }, skip: mysqlSkip);

    test('выход гасит refresh; неизвестный токен — тоже 204', () async {
      final tokens = await login('admin', adminPassword);
      var (s, _, _) = await call('POST', '/auth/logout',
          body: {'refresh_token': tokens['refresh_token']});
      expect(s, 204);
      (s, _, _) = await call('POST', '/auth/refresh',
          body: {'refresh_token': tokens['refresh_token']});
      expect(s, 401);
      (s, _, _) = await call('POST', '/auth/logout',
          body: {'refresh_token': 'unknown'});
      expect(s, 204);
    }, skip: mysqlSkip);
  });

  group('пользователи', () {
    test('админ заводит оператора; тот обязан сменить пароль', () async {
      final admin = await login('admin', adminPassword);
      final created = await createUser(admin['access_token']);
      expect(created['full_name'], 'Петров Пётр');
      expect(created['must_change_password'], isTrue);

      final op = await login('operator1', 'first-pass-1');
      expect(op['user']['must_change_password'], isTrue);
      var (s, j, _) = await call('GET', '/users', token: op['access_token']);
      expect((s, errorCode(j)), (403, 'password_change_required'));
      (s, j, _) = await call('GET', '/auth/me', token: op['access_token']);
      expect(s, 200);

      now = now.add(const Duration(seconds: 2));
      (s, j, _) = await call('POST', '/auth/change-password',
          token: op['access_token'],
          body: {'old_password': 'first-pass-1', 'new_password': 'my-own-pass'});
      expect(s, 200, reason: '$j');
      expect(j['user']['must_change_password'], isFalse);

      // Старые access и refresh после смены пароля не годятся.
      final (oldAccess, _, _) =
          await call('GET', '/auth/me', token: op['access_token']);
      expect(oldAccess, 401);
      final (oldRefresh, _, _) = await call('POST', '/auth/refresh',
          body: {'refresh_token': op['refresh_token']});
      expect(oldRefresh, 401);
      // Новые — годятся, но прав админа у оператора нет.
      (s, j, _) = await call('GET', '/users', token: j['access_token']);
      expect((s, errorCode(j)), (403, 'forbidden'));
      await login('operator1', 'my-own-pass');

      final creates = await audit('user_create');
      expect(creates.last['new_value'], isNot(contains('password_hash')));
      expect(creates.last['new_value'], isNot(contains('argon2')));
    }, skip: mysqlSkip);

    test('смена пароля: неверный текущий, слабый новый, тот же — отказ',
        () async {
      final admin = await login('admin', adminPassword);
      final t = admin['access_token'];
      for (final (body, code) in [
        ({'old_password': 'wrong-pass', 'new_password': 'new-pass-1'},
            'wrong_password'),
        ({'old_password': adminPassword, 'new_password': 'short'},
            'validation'),
        ({'old_password': adminPassword, 'new_password': adminPassword},
            'validation'),
      ]) {
        final (s, j, _) =
            await call('POST', '/auth/change-password', token: t, body: body);
        expect((s, errorCode(j)), (400, code), reason: '$body');
      }
    }, skip: mysqlSkip);

    test('проверка полей при создании, логин занят без учёта регистра',
        () async {
      final t = (await login('admin', adminPassword))['access_token'];
      for (final body in [
        {'login': 'ab', 'full_name': 'X', 'role': 'operator', 'password': 'pass-1234'},
        {'login': 'with space', 'full_name': 'X', 'role': 'operator', 'password': 'pass-1234'},
        {'login': 'okay', 'full_name': '  ', 'role': 'operator', 'password': 'pass-1234'},
        {'login': 'okay', 'full_name': 'X', 'role': 'root', 'password': 'pass-1234'},
        {'login': 'okay', 'full_name': 'X', 'role': 'operator', 'password': '123'},
        {'login': 'okay', 'full_name': 'X', 'role': 'operator'},
      ]) {
        final (s, j, _) = await call('POST', '/users', token: t, body: body);
        expect((s, errorCode(j)), (400, 'validation'), reason: '$body');
      }
      final (s, j, _) = await call('POST', '/users', token: t, body: {
        'login': 'ADMIN', 'full_name': 'X', 'role': 'operator',
        'password': 'pass-1234',
      });
      expect((s, errorCode(j)), (409, 'login_taken'));
      // Кириллический логин допустим.
      await createUser(t, login: 'бухгалтер.1', role: 'accountant');
    }, skip: mysqlSkip);

    test('отключение: токены пользователя перестают работать сразу',
        () async {
      final t = (await login('admin', adminPassword))['access_token'];
      final user = await createUser(t);
      final op = await login('operator1', 'first-pass-1');

      var (s, j, _) = await call('PATCH', '/users/${user['uuid']}',
          token: t, body: {'is_active': false});
      expect(s, 200);
      expect(j['is_active'], isFalse);

      (s, j, _) = await call('GET', '/auth/me', token: op['access_token']);
      expect((s, errorCode(j)), (403, 'user_disabled'));
      (s, j, _) = await call('POST', '/auth/refresh',
          body: {'refresh_token': op['refresh_token']});
      expect(s, 401);
      (s, j, _) = await call('POST', '/auth/login',
          body: {'login': 'operator1', 'password': 'first-pass-1'});
      expect((s, errorCode(j)), (403, 'user_disabled'));

      final updates = await audit('user_update');
      final change = updates.single;
      expect(jsonDecode(change['old_value']!)['is_active'], isTrue);
      expect(jsonDecode(change['new_value']!)['is_active'], isFalse);
      expect(change['new_value'], isNot(contains('password_hash')));
    }, skip: mysqlSkip);

    test('смена роли действует на уже выданный токен', () async {
      final t = (await login('admin', adminPassword))['access_token'];
      final user = await createUser(t, role: 'accountant');
      now = now.add(const Duration(seconds: 2));
      var op = await login('operator1', 'first-pass-1');
      final (_, changed, _) = await call('POST', '/auth/change-password',
          token: op['access_token'],
          body: {'old_password': 'first-pass-1', 'new_password': 'my-own-pass'});
      await call('PATCH', '/users/${user['uuid']}',
          token: t, body: {'role': 'admin'});
      final (s, _, _) =
          await call('GET', '/users', token: changed['access_token']);
      expect(s, 200);
    }, skip: mysqlSkip);

    test('себя не отключить и не понизить; другого админа — можно',
        () async {
      final t = (await login('admin', adminPassword))['access_token'];
      final me = (await call('GET', '/auth/me', token: t)).$2;
      for (final body in [
        {'is_active': false},
        {'role': 'operator'},
      ]) {
        final (s, j, _) =
            await call('PATCH', '/users/${me['uuid']}', token: t, body: body);
        expect((s, errorCode(j)), (409, 'self_change'));
      }
      final second = await createUser(t, login: 'admin2', role: 'admin');
      final (s, _, _) = await call('PATCH', '/users/${second['uuid']}',
          token: t, body: {'role': 'accountant'});
      expect(s, 200);
    }, skip: mysqlSkip);

    test('PATCH: неизвестные поля и неверные значения — 400, нет — 404',
        () async {
      final t = (await login('admin', adminPassword))['access_token'];
      final user = await createUser(t);
      var (s, _, _) = await call('PATCH', '/users/${user['uuid']}',
          token: t, body: {'password_hash': 'x'});
      expect(s, 400);
      (s, _, _) = await call('PATCH', '/users/${user['uuid']}',
          token: t, body: {'is_active': 'no'});
      expect(s, 400);
      (s, _, _) = await call('PATCH', '/users/01900000-0000-7000-8000-000000000000',
          token: t, body: {'full_name': 'X'});
      expect(s, 404);
    }, skip: mysqlSkip);

    test('сброс пароля админом: входы гаснут, нужна смена пароля', () async {
      final t = (await login('admin', adminPassword))['access_token'];
      final user = await createUser(t);
      final op = await login('operator1', 'first-pass-1');
      now = now.add(const Duration(seconds: 2));
      final (s, _, _) = await call(
          'POST', '/users/${user['uuid']}/reset-password',
          token: t, body: {'password': 'reset-pass-1'});
      expect(s, 204);
      final (r, _, _) = await call('POST', '/auth/refresh',
          body: {'refresh_token': op['refresh_token']});
      expect(r, 401);
      final (a, _, _) = await call('GET', '/auth/me', token: op['access_token']);
      expect(a, 401);
      final again = await login('operator1', 'reset-pass-1');
      expect(again['user']['must_change_password'], isTrue);
    }, skip: mysqlSkip);

    test('второго «первого админа» не создать', () async {
      await expectLater(
        auth.createFirstAdmin(
            login: 'other', fullName: 'Другой', password: 'other-pass-1'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'admin_exists')),
      );
    }, skip: mysqlSkip);

    test('пароль из консоли гасит входы и не требует смены', () async {
      final tokens = await login('admin', adminPassword);
      await auth.setPasswordFromConsole('admin', 'console-pass-1');
      final (s, _, _) = await call('POST', '/auth/refresh',
          body: {'refresh_token': tokens['refresh_token']});
      expect(s, 401);
      final fresh = await login('admin', 'console-pass-1');
      expect(fresh['user']['must_change_password'], isFalse);
    }, skip: mysqlSkip);
  });
}
