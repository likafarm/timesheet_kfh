// Правила веб-версии в SyncProvider (этап 5.3): «Чужой компьютер», выход со
// стиранием базы браузера, конец входа по сроку refresh-токена, свой сервер.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/providers/sync_provider.dart';

import '../support/sync_test_server.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestServer server;
  late LocalDatabase db;
  late MemoryTokenStore tokens;
  late List<bool> remembered;
  late int erased;
  final providers = <SyncProvider>[];

  SyncProvider provider({
    ClientKind client = ClientKind.web,
    bool debugBuild = false,
    bool erase = true,
  }) {
    final p = SyncProvider(
      client: client,
      appVersion: () async => '1.4.0',
      database: db,
      onDataChanged: () async {},
      backup: () async {},
      tokenStore: (_) => tokens,
      httpClient: () => MockClient(server.handle),
      journal: MemorySyncJournal(),
      autoSync: false,
      debugBuild: debugBuild,
      rememberSignIn: client == ClientKind.web ? remembered.add : null,
      eraseAfterSignOut: client == ClientKind.web && erase
          ? () async => erased++
          : null,
    );
    providers.add(p);
    return p;
  }

  setUp(() {
    server = SyncTestServer();
    db = LocalDatabase.memory();
    tokens = MemoryTokenStore();
    remembered = [];
    erased = 0;
  });
  tearDown(() async {
    for (final p in providers) {
      p.dispose();
    }
    providers.clear();
    await db.close();
  });

  AuthTokens savedTokens({required Duration refreshLeft}) => AuthTokens(
    accessToken: 'a',
    accessExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
    refreshToken: 'r',
    refreshExpiresAt: DateTime.now().add(refreshLeft),
    user: const SessionUser(
      uuid: '01900000-0000-7000-8000-000000000001',
      login: 'ivan',
      fullName: 'Иван Иванов',
      role: 'admin',
    ),
  );

  test('веб-версия: адрес сервера не меняется (кроме отладки)', () {
    expect(provider().canChangeServer, isFalse);
    expect(provider(debugBuild: true).canChangeServer, isTrue);
    expect(provider(client: ClientKind.desktop).canChangeServer, isTrue);
  });

  test('«Чужой компьютер» — вход не запоминается', () async {
    final sync = provider();
    await sync.init();
    expect(sync.offersPublicComputer, isTrue);
    await sync.signIn(
      'localhost:8080',
      'ivan',
      'secret-pass',
      publicComputer: true,
    );
    expect(remembered, [false]);
    await sync.signOut();
    await sync.signIn('localhost:8080', 'ivan', 'secret-pass');
    expect(remembered, [false, true]);
  });

  test('на Windows отметки «Чужой компьютер» нет', () async {
    final sync = provider(client: ClientKind.desktop);
    expect(sync.offersPublicComputer, isFalse);
    expect(sync.erasesOnSignOut, isFalse);
  });

  test('оператору вход в веб-версию закрыт', () async {
    server.role = 'operator';
    final sync = provider();
    await sync.init();
    await expectLater(
      sync.signIn('localhost:8080', 'op', 'secret-pass'),
      throwsA(
        isA<SyncUserException>().having(
          (e) => e.message,
          'message',
          contains('веб-версии'),
        ),
      ),
    );
    expect(await tokens.read(), isNull);
  });

  test('выход стирает данные браузера, токены удалены', () async {
    final sync = provider();
    await sync.init();
    await sync.signIn('localhost:8080', 'ivan', 'secret-pass');
    expect(sync.erasesOnSignOut, isTrue);
    await sync.signOut();
    expect(erased, 1);
    expect(await tokens.read(), isNull);
  });

  test(
    'срок refresh-токена истёк — сразу экран входа, даже без сети',
    () async {
      server.online = false;
      tokens.tokens = savedTokens(refreshLeft: const Duration(minutes: -1));
      final sync = provider();
      await sync.init();
      expect(sync.phase, SyncPhase.signedOut);
      expect(sync.problem, contains('Срок входа истёк'));
      expect(await tokens.read(), isNull);
      // Данные браузера при этом не стираются: тот же вход продолжит работу.
      expect(erased, 0);
    },
  );

  test('вход ещё действует — программа работает и без сети', () async {
    server.online = false;
    tokens.tokens = savedTokens(refreshLeft: const Duration(days: 3));
    final sync = provider();
    await sync.init();
    expect(sync.user?.login, 'ivan');
    expect(sync.problem, isNull);
  });

  test('на Windows истёкший вход без сети не прерывает работу', () async {
    server.online = false;
    tokens.tokens = savedTokens(refreshLeft: const Duration(minutes: -1));
    final sync = provider(client: ClientKind.desktop);
    await sync.init();
    expect(sync.user?.login, 'ivan');
  });

  test('версии: веб-версия смотрит на свою запись web', () async {
    server.versions = {
      'platforms': {
        'windows': {'latest': '1.3.2', 'min': '1.3.2'},
        'web': {
          'latest': '1.4.1',
          'min': '1.4.1',
          'url': 'https://tab.korovatech.ru/app/',
        },
      },
    };
    final sync = provider();
    await sync.init();
    await sync.checkVersion();
    expect(sync.serverVersion?.latest, '1.4.1');
    expect(sync.updateRequired, isTrue);

    final desktop = provider(client: ClientKind.desktop);
    await desktop.init();
    await desktop.checkVersion();
    expect(desktop.serverVersion?.latest, '1.3.2');
  });
}
