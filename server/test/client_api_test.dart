import 'dart:convert';
import 'dart:io';

import 'package:kfh_server/kfh_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'app_test.dart' show FakeDatabase;

void main() {
  late Directory dir;
  late File file;
  late List<Map<String, dynamic>> log;
  late Handler handler;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kfh_versions');
    file = File('${dir.path}/versions.json');
    log = [];
    final logger = Logger(write: (line) => log.add(jsonDecode(line)));
    handler = buildHandler(
      db: FakeDatabase(),
      logger: logger,
      clientApi: ClientApi(versionsFile: file.path, logger: logger),
    );
  });
  tearDown(() => dir.delete(recursive: true));

  Future<Response> get() => Future.sync(
      () => handler(Request('GET', Uri.parse('http://localhost/client/version'))));

  test('файла нет — пустой список, вход не нужен', () async {
    final r = await get();
    expect(r.statusCode, 200);
    expect(jsonDecode(await r.readAsString()), {'platforms': {}});
  });

  test('список из файла; новая версия видна без перезапуска', () async {
    const v1 = {
      'platforms': {
        'android': {
          'latest': '1.3.0',
          'min': '1.3.0',
          'url': 'https://tab.example.ru/download/kfh-1.3.0.apk',
          'sha256': 'ab12',
        },
      },
    };
    await file.writeAsString(jsonEncode(v1));
    expect(jsonDecode(await (await get()).readAsString()), v1);

    await file.writeAsString(jsonEncode({
      'platforms': {
        'android': {'latest': '1.3.1', 'min': '1.3.0'},
      },
    }));
    final body = jsonDecode(await (await get()).readAsString());
    expect(body['platforms']['android']['latest'], '1.3.1');
  });

  test('испорченный файл — 500 и запись в журнал', () async {
    await file.writeAsString('{"platforms": {"android": {"latest": "1.3"}}}');
    final r = await get();
    expect(r.statusCode, 500);
    expect(jsonDecode(await r.readAsString())['error']['code'],
        'client_versions');
    expect(log.any((l) => l['level'] == 'error'), isTrue);
  });
}
