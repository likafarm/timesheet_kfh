import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:test/test.dart';

import 'support/fake_server.dart';

// Сквозные сценарии первого входа с настоящим сервером (импорт со сверкой,
// привязка, приём) — server/test/client_sync_test.dart. Здесь — решения.

const _admin = SessionUser(
  uuid: '01900000-0000-7000-8000-000000000001',
  login: 'ivan',
  fullName: 'Иван',
  role: 'admin',
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeSyncServer server;
  late LocalDatabase db;
  late LocalSyncStore store;
  late int imports;

  SyncBootstrap bootstrap(
    String address, {
    ClientKind client = ClientKind.desktop,
  }) {
    final transport = server.client(db.deviceId);
    // /admin/import поддельного сервера: записи кладутся как есть.
    final api = KfhApiClient(
      baseUrl: Uri.parse(address),
      deviceId: 'device',
      tokens: MemoryTokenStore(
        AuthTokens(
          accessToken: 'a',
          accessExpiresAt: DateTime.now().add(const Duration(hours: 1)),
          refreshToken: 'r',
          refreshExpiresAt: DateTime.now().add(const Duration(days: 1)),
          user: _admin,
        ),
      ),
      client: MockClient((r) async {
        imports++;
        final export = SyncExport.fromJson(jsonDecode(r.body));
        export.rows.forEach(server.put);
        return http.Response(
          '{"ok": true}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    return SyncBootstrap(
      store: store,
      api: api,
      transport: transport,
      engine: SyncEngine(store: store, transport: transport),
      server: address,
      client: client,
    );
  }

  setUp(() {
    server = FakeSyncServer();
    db = LocalDatabase.memory();
    store = LocalSyncStore(db);
    imports = 0;
  });
  tearDown(() => db.close());

  Future<String> addEmployee() => DriftRepositories(db).employees.add(
    Employee(
      fullName: 'Иванов Иван',
      position: 'Рабочий',
      hireDate: DateTime(2025, 3, 1),
      baseRate: 1000,
      fieldRate: 1500,
    ),
  );

  const operator = SessionUser(
    uuid: '01900000-0000-7000-8000-000000000002',
    login: 'op',
    fullName: 'Оператор',
    role: 'operator',
  );

  test('на Windows оператору — отказ', () async {
    final plan = await bootstrap('https://a').analyze(operator);
    expect(plan.allowed, isFalse);
    expect(plan.refusal, contains('оператор'));
  });

  test('на телефоне — только оператор', () async {
    final b = bootstrap('https://a', client: ClientKind.phone);
    final plan = await b.analyze(_admin);
    expect(plan.allowed, isFalse);
    expect(plan.refusal, contains('только для оператора'));
  });

  test('оператор на телефоне: пустая база — приём, ничего не уходит', () async {
    // На сервере — данные хозяйства (сотрудник пришёл с другого устройства).
    final other = LocalDatabase.memory();
    addTearDown(other.close);
    final emp = await DriftRepositories(other).employees.add(
      Employee(
        fullName: 'Петров Пётр',
        position: 'Рабочий',
        hireDate: DateTime(2025, 3, 1),
        baseRate: 1000,
        fieldRate: 1500,
      ),
    );
    await SyncEngine(
      store: LocalSyncStore(other),
      transport: server.client(other.deviceId),
    ).run();
    final settings = server.rows('company_settings').single;

    final b = bootstrap('https://a', client: ClientKind.phone);
    final plan = await b.analyze(operator);
    expect(plan.kind, BootstrapKind.download);
    expect(plan.allowed, isTrue);
    await b.execute(plan, backup: () async {});
    expect(await b.isLinked(), isTrue);
    expect(await DriftRepositories(db).employees.byId(emp), isNotNull);
    // Своя строка настроек хозяйства на сервер не ушла.
    expect(server.rows('company_settings').single.uuid, settings.uuid);
    expect(await store.pendingCount(), 0);
    expect(imports, 0);
  });

  test('оператор на телефоне: пустой сервер — тоже приём', () async {
    final b = bootstrap('https://a', client: ClientKind.phone);
    final plan = await b.analyze(operator);
    expect(plan.kind, BootstrapKind.download);
    await b.execute(plan, backup: () async {});
    expect(server.rows('company_settings'), isEmpty);
    expect(await store.pendingCount(), 0);
  });

  test('оператор на телефоне: здесь свои данные — отказ', () async {
    await addEmployee();
    final plan = await bootstrap(
      'https://a',
      client: ClientKind.phone,
    ).analyze(operator);
    expect(plan.allowed, isFalse);
    expect(plan.refusal, contains('пустую базу'));
  });

  test('в веб-версии оператору — отказ', () async {
    final plan = await bootstrap(
      'https://a',
      client: ClientKind.web,
    ).analyze(operator);
    expect(plan.allowed, isFalse);
    expect(plan.refusal, contains('веб-версии'));
  });

  test('веб-версия: пустая база — приём, ничего не уходит', () async {
    final other = LocalDatabase.memory();
    addTearDown(other.close);
    final emp = await DriftRepositories(other).employees.add(
      Employee(
        fullName: 'Петров Пётр',
        position: 'Рабочий',
        hireDate: DateTime(2025, 3, 1),
        baseRate: 1000,
        fieldRate: 1500,
      ),
    );
    await SyncEngine(
      store: LocalSyncStore(other),
      transport: server.client(other.deviceId),
    ).run();
    final settings = server.rows('company_settings').single;

    final b = bootstrap('https://a', client: ClientKind.web);
    final plan = await b.analyze(_admin);
    expect(plan.kind, BootstrapKind.download);
    expect(plan.allowed, isTrue);
    await b.execute(plan, backup: () async {});
    expect(await DriftRepositories(db).employees.byId(emp), isNotNull);
    expect(server.rows('company_settings').single.uuid, settings.uuid);
    expect(await store.pendingCount(), 0);
    expect(imports, 0);
  });

  test(
    'веб-версия: пустой сервер — тоже приём, ничего не выгружается',
    () async {
      final b = bootstrap('https://a', client: ClientKind.web);
      final plan = await b.analyze(_admin);
      expect(plan.kind, BootstrapKind.download);
      await b.execute(plan, backup: () async {});
      expect(server.rows('company_settings'), isEmpty);
      expect(imports, 0);
    },
  );

  test('веб-версия: в браузере уже есть данные — отказ', () async {
    await addEmployee();
    final plan = await bootstrap(
      'https://a',
      client: ClientKind.web,
    ).analyze(_admin);
    expect(plan.allowed, isFalse);
    expect(plan.refusal, contains('браузере'));
  });

  test('пусто и там, и здесь — просто начать', () async {
    final b = bootstrap('https://a');
    final plan = await b.analyze(_admin);
    expect(plan.kind, BootstrapKind.fresh);
    expect(plan.allowed, isTrue);
    var backups = 0;
    await b.execute(plan, backup: () async => backups++);
    expect(backups, 1);
    expect(await b.isLinked(), isTrue);
    expect(server.rows('company_settings'), hasLength(1));
  });

  test('без резервной копии ничего не начинается', () async {
    await addEmployee();
    final b = bootstrap('https://a');
    final plan = await b.analyze(_admin);
    expect(plan.kind, BootstrapKind.upload);
    await expectLater(
      b.execute(plan, backup: () async => throw StateError('диск полон')),
      throwsStateError,
    );
    expect(imports, 0);
    expect(server.rows('employees'), isEmpty);
    expect(await b.isLinked(), isFalse);
  });

  test('выгрузка, затем привязка к другому серверу — с нуля', () async {
    final emp = await addEmployee();
    final first = bootstrap('https://a');
    await first.execute(await first.analyze(_admin), backup: () async {});
    expect(imports, 1);
    expect(await store.pendingCount(), 0);

    // Другой сервер (пустой): прежние отметки «отправлено» к нему не
    // относятся — база выгружается туда целиком.
    server = FakeSyncServer();
    final second = bootstrap('https://b');
    expect(await second.isLinked(), isFalse);
    final plan = await second.analyze(_admin);
    expect(plan.kind, BootstrapKind.upload);
    await second.execute(plan, backup: () async {});
    expect(server.row('employees', emp), isNotNull);
    expect(await store.linkedServer(), 'https://b');
  });
}
