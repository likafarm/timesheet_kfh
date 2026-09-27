import 'dart:async';
import 'dart:convert';

import 'package:kfh_server/kfh_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class FakeDatabase implements Database {
  Future<void> Function() onPing = () async {};

  @override
  Future<void> ping() => onPing();

  @override
  Future<void> close() async {}
}

void main() {
  late FakeDatabase db;
  late List<Map<String, dynamic>> log;
  late Handler handler;

  setUp(() {
    db = FakeDatabase();
    log = [];
    handler = buildHandler(
      db: db,
      logger: Logger(write: (line) => log.add(jsonDecode(line))),
    );
  });

  Future<Response> get(String path, {Map<String, String>? headers}) =>
      Future.sync(() => handler(
          Request('GET', Uri.parse('http://localhost$path'), headers: headers)));

  Future<Map<String, dynamic>> body(Response r) async =>
      jsonDecode(await r.readAsString()) as Map<String, dynamic>;

  test('/health: база отвечает — 200 и версия', () async {
    final r = await get('/health');
    expect(r.statusCode, 200);
    expect(r.headers['content-type'], startsWith('application/json'));
    expect(await body(r),
        {'status': 'ok', 'version': serverVersion, 'db': 'ok'});
  });

  test('/health: база упала — 503 без подробностей наружу', () async {
    db.onPing = () async => throw Exception('Access denied for user kfh_api');
    final r = await get('/health');
    expect(r.statusCode, 503);
    final text = await r.readAsString();
    expect(jsonDecode(text)['db'], 'error');
    expect(text, isNot(contains('Access denied')));
    // Причина — в журнале.
    expect(log.any((e) => '${e['error']}'.contains('Access denied')), isTrue);
  });

  test('/health: база молчит — 503 по таймауту', () async {
    db.onPing = () => Completer<void>().future;
    final r = await get('/health');
    expect(r.statusCode, 503);
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('неизвестный адрес — 404 в формате ошибки API', () async {
    final r = await get('/nope');
    expect(r.statusCode, 404);
    expect((await body(r))['error']['code'], 'not_found');
  });

  test('id запроса: создаётся, возвращается и попадает в журнал', () async {
    final r = await get('/health');
    final id = r.headers[requestIdHeader];
    expect(id, matches(RegExp(r'^[0-9a-f]{16}$')));
    final entry = log.singleWhere((e) => e['msg'] == 'request');
    expect(entry['request_id'], id);
    expect(entry['method'], 'GET');
    expect(entry['path'], '/health');
    expect(entry['status'], 200);
    expect(entry['time'], endsWith('Z'));
  });

  test('id запроса от прокси берётся, мусорный — заменяется', () async {
    final ok = await get('/health', headers: {'X-Request-Id': 'abc-123'});
    expect(ok.headers[requestIdHeader], 'abc-123');
    final bad =
        await get('/health', headers: {'X-Request-Id': 'a b\n{"x":1}'});
    expect(bad.headers[requestIdHeader], matches(RegExp(r'^[0-9a-f]{16}$')));
  });

  test('в журнал не попадает строка запроса', () async {
    await get('/health?token=secret');
    expect(log.map(jsonEncode).join(), isNot(contains('secret')));
  });

  group('обработка ошибок', () {
    Handler wrap(Handler inner) => const Pipeline()
        .addMiddleware(handleErrors(
            Logger(write: (line) => log.add(jsonDecode(line)))))
        .addHandler(inner);

    Request req() => Request('GET', Uri.parse('http://localhost/x'));

    test('ApiException уходит клиенту как есть', () async {
      final h = wrap((_) =>
          throw const ApiException(409, 'conflict', 'Запись уже изменена'));
      final r = await h(req());
      expect(r.statusCode, 409);
      expect(await body(r), {
        'error': {'code': 'conflict', 'message': 'Запись уже изменена'},
      });
    });

    test('прочие ошибки — 500 без подробностей, подробности в журнал',
        () async {
      final h = wrap((_) => throw StateError('секретная деталь'));
      final r = await h(req());
      expect(r.statusCode, 500);
      final text = await r.readAsString();
      expect(jsonDecode(text)['error']['code'], 'internal');
      expect(text, isNot(contains('секретная')));
      expect(log.single['level'], 'error');
      expect(log.single['error'], contains('секретная деталь'));
      expect(log.single['stack'], isNotEmpty);
    });
  });
}
