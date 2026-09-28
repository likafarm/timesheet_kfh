// База в браузере (drift WASM): открытие, запись, повторное открытие,
// стирание. Запуск — tool/web_test.ps1 из корня репозитория: он кладёт
// sqlite3.wasm и drift_worker.js из web/ в test/browser/assets/ (сервер
// тестов отдаёт только папку пакета).
@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/web.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

// Адрес страницы теста — <корень пакета>/test/browser/*.html.
final _sqlite3 = Uri.base.resolve('assets/sqlite3.wasm');
final _worker = Uri.base.resolve('assets/drift_worker.js');

Future<bool> _assetsPresent() async {
  final r = await web.window.fetch(_sqlite3.toString().toJS).toDart;
  return r.status == 200;
}

void main() {
  late String name;

  setUp(() async {
    if (!await _assetsPresent()) {
      fail('Нет test/browser/assets — запускайте через tool/web_test.ps1');
    }
    name = 'test_${DateTime.now().microsecondsSinceEpoch}';
  });

  Future<WebDatabase> open() =>
      openWebDatabase(name: name, sqlite3Uri: _sqlite3, driftWorkerUri: _worker);

  test('данные переживают повторное открытие, стирание — нет', () async {
    final first = await open();
    expect(first.storage, isNot('inMemory'));
    final repos = DriftRepositories(first.db);
    final id = await repos.employees.add(
      Employee(
        fullName: 'Иванов Иван Иванович',
        position: 'Тракторист',
        hireDate: DateTime(2026, 3, 1),
        baseRate: 1000,
        fieldRate: 1500,
      ),
    );
    final device = await first.db.deviceId();
    await first.db.close();

    final second = await open();
    expect(second.storage, first.storage);
    final again = await DriftRepositories(second.db).employees.byId(id);
    expect(again?.fullName, 'Иванов Иван Иванович');
    // Id устройства браузера тоже сохраняется.
    expect(await second.db.deviceId(), device);
    await second.db.close();

    await deleteWebDatabase(
      name: name,
      sqlite3Uri: _sqlite3,
      driftWorkerUri: _worker,
    );
    final third = await open();
    expect(await DriftRepositories(third.db).employees.all(), isEmpty);
    expect(await third.db.deviceId(), isNot(device));
    await third.db.close();
    await deleteWebDatabase(
      name: name,
      sqlite3Uri: _sqlite3,
      driftWorkerUri: _worker,
    );
  });
}
