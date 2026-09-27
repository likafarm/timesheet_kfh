import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/providers/sync_provider.dart';

import '../support/sync_test_server.dart';

/// Автоматическая синхронизация (шаг 3.5) — на настоящих таймерах с
/// короткими паузами. Само расписание подробно — в packages/sync
/// (sync_scheduler_test.dart, поддельное время).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestServer server;
  late LocalDatabase db;
  late MemoryTokenStore tokens;
  final providers = <SyncProvider>[];

  SyncProvider provider({
    bool autoSync = true,
    Duration interval = const Duration(minutes: 5),
  }) {
    final p = SyncProvider(
      appVersion: () async => '1.3.0',
      database: db,
      dataDirectory: '.',
      onDataChanged: () async {},
      backup: () async {},
      tokenStore: (_) => tokens,
      httpClient: () => MockClient(server.handle),
      journal: MemorySyncJournal(),
      autoSync: autoSync,
      debugBuild: false,
      syncInterval: interval,
      changeDelay: const Duration(milliseconds: 150),
    );
    providers.add(p);
    return p;
  }

  Future<void> wait([int ms = 500]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> addEmployee(String name) => DriftRepositories(db).employees.add(
    Employee(
      fullName: name,
      position: 'Рабочий',
      hireDate: DateTime(2025, 3, 1),
      baseRate: 1000,
      fieldRate: 1500,
    ),
  );

  /// База привязана и вход сохранён (как после первого входа).
  Future<void> linked() async {
    final setup = provider(autoSync: false);
    await setup.init();
    await setup.signIn('localhost:8080', 'ivan', 'secret-pass');
    await setup.link(await setup.analyzeLink());
    setup.dispose();
    providers.remove(setup);
  }

  setUp(() {
    server = SyncTestServer();
    db = LocalDatabase.memory();
    tokens = MemoryTokenStore();
  });
  tearDown(() async {
    for (final p in providers) {
      p.dispose();
    }
    providers.clear();
    await db.close();
  });

  test('при запуске программы — сразу синхронизация', () async {
    await linked();
    final pulls = server.pulls;
    final sync = provider();
    await sync.init();
    await wait();
    expect(server.pulls, pulls + 1);
    expect(sync.problem, isNull);
    expect(sync.nextAttemptAt, isNotNull, reason: 'следующая — по расписанию');
  });

  test('правка уходит сама вскоре после ввода', () async {
    await linked();
    final sync = provider();
    await sync.init();
    await wait();
    await addEmployee('Петров Пётр');
    await addEmployee('Сидоров Сидор');
    await wait(1200);
    expect(
      server.rows.keys.where((k) => k.startsWith('employees/')),
      hasLength(2),
    );
    expect(sync.pending, 0);
  });

  test('записи самой синхронизации не запускают её снова', () async {
    await linked();
    final sync = provider();
    await sync.init();
    await addEmployee('Петров Пётр');
    await wait(1200);
    final pushes = server.pushes, pulls = server.pulls;
    await wait(1200);
    expect(server.pushes, pushes);
    expect(server.pulls, pulls);
    expect(sync.pending, 0);
  });

  test('раз в интервал — приём чужих изменений', () async {
    await linked();
    final sync = provider(interval: const Duration(milliseconds: 400));
    await sync.init();
    await wait(1500);
    expect(server.pulls, greaterThanOrEqualTo(3));
  });

  test(
    'нет сети — понятно и с паузой; правки не дёргают сервер',
    () async {
      await linked();
      server.online = false;
      final sync = provider();
      await sync.init();
      await wait(9000); // первая попытка + повторы движка (2 и 5 с)
      expect(sync.isOffline, isTrue);
      final next = sync.nextAttemptAt!;
      final delay = next.difference(DateTime.now());
      expect(
        delay.inSeconds,
        inInclusiveRange(1, 6),
        reason: 'пауза 5 с ±20 %',
      );
      final pushes = server.pushes;
      await addEmployee('Петров Пётр');
      await wait(300);
      expect(server.pushes, pushes, reason: 'правка не ускоряет повтор');
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('сеанс истёк — автоматика останавливается до входа', () async {
    await linked();
    final sync = provider(interval: const Duration(milliseconds: 300));
    server.sessionExpired = true;
    await sync.init();
    await wait();
    expect(sync.phase, SyncPhase.signedOut);
    expect(sync.nextAttemptAt, isNull);
    final pulls = server.pulls;
    await wait(1000);
    expect(server.pulls, pulls);

    server.sessionExpired = false;
    await sync.signIn('localhost:8080', 'ivan', 'secret-pass');
    await wait();
    expect(sync.phase, SyncPhase.ready);
    expect(server.pulls, greaterThan(pulls));
  });
}
