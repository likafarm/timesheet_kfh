import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/providers/sync_provider.dart';

import '../support/sync_test_server.dart';

final _providers = <SyncProvider>[];

SyncProvider _track(SyncProvider p) {
  _providers.add(p);
  return p;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestServer server;
  late LocalDatabase db;
  late MemoryTokenStore tokens;
  late int backups;
  late int reloads;
  late int lockChanges;

  SyncProvider provider({ClientKind client = ClientKind.desktop}) => _track(
    SyncProvider(
      client: client,
      database: db,
      dataDirectory: '.',
      onDataChanged: () async => reloads++,
      backup: () async => backups++,
      onLocksChanged: () async => lockChanges++,
      tokenStore: (_) => tokens,
      httpClient: () => MockClient(server.handle),
      journal: MemorySyncJournal(),
      autoSync: false,
      debugBuild: false,
    ),
  );

  setUp(() {
    server = SyncTestServer();
    db = LocalDatabase.memory();
    tokens = MemoryTokenStore();
    backups = 0;
    reloads = 0;
    lockChanges = 0;
  });
  tearDown(() async {
    for (final p in _providers) {
      p.dispose();
    }
    _providers.clear();
    await db.close();
  });

  Future<SyncProvider> signedIn() async {
    final sync = provider();
    await sync.init();
    await sync.signIn('localhost:8080', 'ivan', 'secret-pass');
    return sync;
  }

  test('адрес сервера приводится к виду https://хост без «/»', () {
    expect(
      SyncProvider.normalizeServer(' tab.korovatech.ru/ '),
      'https://tab.korovatech.ru',
    );
    expect(
      SyncProvider.normalizeServer('http://localhost:8080'),
      'http://localhost:8080',
    );
    expect(
      () => SyncProvider.normalizeServer('ftp://x'),
      throwsA(isA<SyncUserException>()),
    );
  });

  test('без входа — работа только локально', () async {
    final sync = provider();
    await sync.init();
    expect(sync.phase, SyncPhase.signedOut);
    expect(sync.pending, 1, reason: 'строка настроек');
    expect(await sync.syncNow(), isNull);
  });

  test('неверный пароль — понятная ошибка', () async {
    final sync = provider();
    await sync.init();
    await expectLater(
      sync.signIn('https://localhost', 'ivan', 'x'),
      throwsA(
        isA<SyncUserException>().having(
          (e) => e.message,
          'message',
          'Неверный логин или пароль',
        ),
      ),
    );
    expect(sync.phase, SyncPhase.signedOut);
  });

  test('нет связи при входе — понятная ошибка с адресом', () async {
    server.online = false;
    final sync = provider();
    await sync.init();
    await expectLater(
      sync.signIn('tab.example.ru', 'ivan', 'secret-pass'),
      throwsA(
        isA<SyncUserException>().having(
          (e) => e.message,
          'message',
          'Нет связи с сервером https://tab.example.ru',
        ),
      ),
    );
  });

  test('оператору — отказ, вход не сохраняется', () async {
    server.role = 'operator';
    final sync = provider();
    await sync.init();
    await expectLater(
      sync.signIn('https://localhost', 'ivan', 'secret-pass'),
      throwsA(isA<SyncUserException>()),
    );
    expect(sync.phase, SyncPhase.signedOut);
    expect(tokens.tokens, isNull);
  });

  test('телефон: оператор входит, первый вход — только приём', () async {
    server.role = 'operator';
    final sync = provider(client: ClientKind.phone);
    await sync.init();
    await sync.signIn('https://localhost', 'oper', 'secret-pass');
    expect(sync.phase, SyncPhase.needsLink);
    final plan = await sync.analyzeLink();
    expect(plan.kind, BootstrapKind.download);
    final report = await sync.link(plan);
    expect(report.pushed, 0, reason: 'настройки хозяйства не уходят');
    expect(sync.phase, SyncPhase.ready);
    expect(sync.pending, 0);
  });

  test('телефон: администратору — отказ', () async {
    final sync = provider(client: ClientKind.phone);
    await sync.init();
    await expectLater(
      sync.signIn('https://localhost', 'ivan', 'secret-pass'),
      throwsA(
        isA<SyncUserException>().having(
          (e) => e.message,
          'message',
          contains('только для оператора'),
        ),
      ),
    );
    expect(sync.phase, SyncPhase.signedOut);
    expect(tokens.tokens, isNull);
  });

  test('сохранённый вход чужой роли при запуске забывается', () async {
    server.role = 'operator';
    final phone = provider(client: ClientKind.phone);
    await phone.init();
    await phone.signIn('https://localhost', 'oper', 'secret-pass');
    expect(tokens.tokens, isNotNull);
    // Те же токены в программе для Windows.
    final desktop = provider();
    await desktop.init();
    expect(desktop.phase, SyncPhase.signedOut);
    expect(tokens.tokens, isNull);
  });

  test('выданный пароль нужно сменить, затем — первый вход', () async {
    server.mustChange = true;
    final sync = await signedIn();
    expect(sync.phase, SyncPhase.passwordChange);
    await sync.changePassword('secret-pass', 'my-own-pass');
    expect(sync.phase, SyncPhase.needsLink);
  });

  test('первый вход: копия базы, обмен, база привязана', () async {
    final sync = await signedIn();
    expect(sync.phase, SyncPhase.needsLink);
    expect(sync.server, 'https://localhost:8080');
    final plan = await sync.analyzeLink();
    expect(plan.kind, BootstrapKind.fresh);
    final report = await sync.link(plan);
    expect(backups, 1);
    expect(report.pushed, 1);
    expect(sync.phase, SyncPhase.ready);
    expect(sync.pending, 0);
    expect(sync.lastSyncAt, isNotNull);

    // Перезапуск программы: вход и привязка сохранились.
    final again = provider();
    await again.init();
    expect(again.phase, SyncPhase.ready);
    expect(again.server, 'https://localhost:8080');
    expect(again.lastSyncAt, isNotNull);
  });

  test('правки считаются неотправленными и уходят по кнопке', () async {
    final sync = await signedIn();
    await sync.link(await sync.analyzeLink());
    await DriftRepositories(db).employees.add(
      Employee(
        fullName: 'Петров Пётр',
        position: 'Рабочий',
        hireDate: DateTime(2025, 3, 1),
        baseRate: 1000,
        fieldRate: 1500,
      ),
    );
    await sync.refreshPending();
    expect(sync.pending, 1);
    final report = await sync.syncNow();
    expect(report!.pushed, 1);
    expect(sync.pending, 0);
    expect(
      server.rows.keys.where((k) => k.startsWith('employees/')),
      hasLength(1),
    );
  });

  test('данные с сервера — экраны перечитываются', () async {
    final sync = await signedIn();
    await sync.link(await sync.analyzeLink());
    reloads = 0;
    server.rows['employees/01900000-0000-7000-8000-00000000000b'] = {
      'table': 'employees',
      'uuid': '01900000-0000-7000-8000-00000000000b',
      'updated_at': '2026-09-27T10:00:00.000Z',
      'deleted': false,
      'edited_by': 'other-pc',
      'data': {
        'legacy_id': null,
        'full_name': 'Сидоров Сидор',
        'position': 'Рабочий',
        'hire_date': '2025-03-01',
        'dismissal_date': null,
        'base_rate': 1000.0,
        'field_rate': 1500.0,
      },
    };
    server.log.add('employees/01900000-0000-7000-8000-00000000000b');
    final report = await sync.syncNow();
    expect(report!.received, 1);
    expect(reloads, 1);
    expect(
      (await DriftRepositories(db).employees.all()).single.fullName,
      'Сидоров Сидор',
    );
  });

  test('нет сети — понятное состояние, после подключения проходит', () async {
    final sync = await signedIn();
    await sync.link(await sync.analyzeLink());
    server.online = false;
    expect(await sync.syncNow(), isNull);
    expect(sync.isOffline, isTrue);
    expect(sync.problem, contains('Нет связи'));
    expect(sync.phase, SyncPhase.ready);

    server.online = true;
    expect(await sync.syncNow(), isNotNull);
    expect(sync.isOffline, isFalse);
    expect(sync.problem, isNull);
  });

  test('сеанс истёк — снова «вход не выполнен», с объяснением', () async {
    final sync = await signedIn();
    await sync.link(await sync.analyzeLink());
    server.sessionExpired = true;
    expect(await sync.syncNow(), isNull);
    expect(sync.phase, SyncPhase.signedOut);
    expect(sync.problem, contains('Войдите снова'));
    expect(tokens.tokens, isNull);
  });

  test('выход сохраняет привязку базы', () async {
    final sync = await signedIn();
    await sync.link(await sync.analyzeLink());
    await sync.signOut();
    expect(sync.phase, SyncPhase.signedOut);
    await sync.signIn('localhost:8080', 'ivan', 'secret-pass');
    expect(sync.phase, SyncPhase.ready, reason: 'первый вход не повторяется');
  });

  test('закрытые месяцы приходят с каждой синхронизацией', () async {
    final sync = await signedIn();
    server.locks.add((2026, 8));
    await sync.link(await sync.analyzeLink());
    expect(await LocalSyncStore(db).lockedMonths(), {
      PeriodGuard.monthKey(2026, 8),
    });
    expect(lockChanges, 1);

    await sync.syncNow();
    expect(lockChanges, 1, reason: 'список не менялся');

    server.locks.clear();
    await sync.syncNow();
    expect(await LocalSyncStore(db).lockedMonths(), isEmpty);
    expect(lockChanges, 2);
  });
}
