import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/services/browser_storage.dart';

AuthTokens _tokens(String n) => AuthTokens(
  accessToken: 'access-$n',
  accessExpiresAt: DateTime.utc(2026, 9, 27, 10),
  refreshToken: 'refresh-$n',
  refreshExpiresAt: DateTime.utc(2026, 10, 27),
  user: const SessionUser(
    uuid: '01900000-0000-7000-8000-000000000001',
    login: 'ivan',
    fullName: 'Иван',
    role: 'admin',
  ),
);

void main() {
  late MemoryStringStorage persistent;
  late MemoryStringStorage session;
  late bool remember;

  BrowserTokenStore store([String server = 'https://tab.korovatech.ru']) =>
      BrowserTokenStore(
        server,
        persistent: persistent,
        session: session,
        remember: () => remember,
      );

  setUp(() {
    persistent = MemoryStringStorage();
    session = MemoryStringStorage();
    remember = true;
  });

  test('свой компьютер: вход — в постоянном хранилище', () async {
    await store().write(_tokens('1'));
    expect(hasBrowserTokens(persistent), isTrue);
    expect(hasBrowserTokens(session), isFalse);
    expect((await store().read())?.accessToken, 'access-1');
  });

  test('чужой компьютер: вход — до закрытия вкладки', () async {
    remember = false;
    await store().write(_tokens('1'));
    expect(hasBrowserTokens(persistent), isFalse);
    expect(hasBrowserTokens(session), isTrue);
  });

  test('обновлённые токены остаются там же, где были', () async {
    remember = false;
    await store().write(_tokens('1'));
    // Отметка сменилась (например, открыто окно входа), но токены — те же.
    remember = true;
    await store().write(_tokens('2'));
    expect(hasBrowserTokens(persistent), isFalse);
    expect((await store().read())?.accessToken, 'access-2');
  });

  test('выход удаляет вход отовсюду, другие серверы не трогает', () async {
    await store().write(_tokens('1'));
    await store('http://localhost:8080').write(_tokens('2'));
    await store().clear();
    expect(await store().read(), isNull);
    expect(await store('http://localhost:8080').read(), isNotNull);
  });

  test('испорченная запись — как будто входа не было', () async {
    persistent.write('${browserTokenPrefix}https://tab.korovatech.ru', '{');
    expect(await store().read(), isNull);
  });

  test('журнал хранит последние записи, новые сверху', () async {
    final storage = MemoryStringStorage();
    final journal = StoredSyncJournal(storage, maxEntries: 3);
    for (var i = 1; i <= 5; i++) {
      await journal.add([
        JournalEntry(
          at: DateTime.utc(2026, 9, 27, 10, i),
          kind: JournalKind.rejected,
          message: 'запись $i',
        ),
      ]);
    }
    final recent = await journal.recent();
    expect(recent.map((e) => e.message), ['запись 5', 'запись 4', 'запись 3']);
    expect((await journal.recent(limit: 1)).single.message, 'запись 5');
    journal.clear();
    expect(await journal.recent(), isEmpty);
  });
}
