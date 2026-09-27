import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfh_sync/kfh_sync.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/providers/sync_provider.dart';
import 'package:kfx_time_tracking/services/database_files.dart';
import 'package:kfx_time_tracking/services/backup_service.dart';
import 'package:path/path.dart' as p;

import '../support/sync_test_server.dart';

/// Защита боевых данных (шаг 3.7).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SyncTestServer server;

  setUp(() => server = SyncTestServer());

  group('отладочная сборка', () {
    late LocalDatabase db;
    late SyncProvider sync;

    setUp(() async {
      db = LocalDatabase.memory();
      sync = SyncProvider(
        appVersion: () async => '1.3.0',
        database: db,
        onDataChanged: () async {},
        backup: () async {},
        tokenStore: (_) => MemoryTokenStore(),
        httpClient: () => MockClient(server.handle),
        journal: MemorySyncJournal(),
        autoSync: false,
        debugBuild: true,
      );
      await sync.init();
    });
    tearDown(() async {
      sync.dispose();
      await db.close();
    });

    test('по умолчанию — только стенд на этом компьютере', () {
      expect(SyncProvider.isLocalServer(sync.server), isTrue);
      expect(SyncProvider.isLocalServer('http://127.0.0.1:8080'), isTrue);
      expect(SyncProvider.isLocalServer('https://tab.korovatech.ru'), isFalse);
    });

    test('рабочий сервер — только с явного согласия', () async {
      await expectLater(
        sync.signIn('tab.korovatech.ru', 'ivan', 'secret-pass'),
        throwsA(
          isA<SyncUserException>().having(
            (e) => e.message,
            'message',
            contains('отладочная сборка'),
          ),
        ),
      );
      expect(sync.phase, SyncPhase.signedOut);

      await sync.signIn(
        'tab.korovatech.ru',
        'ivan',
        'secret-pass',
        allowRemoteInDebug: true,
      );
      expect(sync.phase, SyncPhase.needsLink);
    });

    test('стенд — без лишних вопросов', () async {
      await sync.signIn('http://localhost:8080', 'ivan', 'secret-pass');
      expect(sync.phase, SyncPhase.needsLink);
    });
  });

  group('полное восстановление на связанном ПК', () {
    late Directory root;
    late AppProvider app;
    late SyncProvider sync;
    late MemorySyncJournal journal;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kfh_restore_sync');
      final appDb = await openAppDatabaseFile(
        p.join(root.path, 'kfx_time_tracking_v2.db'),
      );
      app = AppProvider(
        appDb,
        backupService: BackupService(
          backupDirectory: p.join(root.path, 'backups'),
        ),
      );
      journal = MemorySyncJournal();
      final tokens = MemoryTokenStore();
      sync = SyncProvider(
        appVersion: () async => '1.3.0',
        database: app.localDatabase,
        onDataChanged: app.reloadAfterSync,
        backup: app.createSyncSafetyBackup,
        onLocksChanged: app.loadLockedMonths,
        tokenStore: (_) => tokens,
        httpClient: () => MockClient(server.handle),
        journal: journal,
        autoSync: false,
        debugBuild: false,
      );
      // Как в main.dart.
      app.beforeDatabaseReplaced = sync.suspend;
      var generation = app.databaseGeneration;
      app.addListener(() {
        if (app.databaseGeneration != generation) {
          generation = app.databaseGeneration;
          sync.rebind(app.localDatabase);
        }
      });
      await app.loadAllData();
      await sync.init();
      await sync.signIn('https://tab.example.ru', 'ivan', 'secret-pass');
      await sync.link(await sync.analyzeLink());
    });
    tearDown(() async {
      sync.dispose();
      await app.closeDatabase();
      await root.delete(recursive: true);
    });

    Employee employee(String name) => Employee(
      fullName: name,
      position: 'Рабочий',
      hireDate: DateTime(2025, 3, 1),
      baseRate: 1000,
      fieldRate: 1500,
    );

    Future<Employee?> byName(String name) async => (await DriftRepositories(
      app.localDatabase,
    ).employees.all()).where((e) => e.fullName == name).firstOrNull;

    test('в окне восстановления — предупреждение о сервере', () {
      expect(sync.restoreWarning(full: true), contains('заново сверена'));
      expect(sync.restoreWarning(full: false), contains('отправлены'));
    });

    test(
      'после восстановления база сверяется с сервером: серверное новее '
      'побеждает, записи копии, которых на сервере нет, уходят туда',
      () async {
        final repo = DriftRepositories(app.localDatabase);
        final a = await repo.employees.add(employee('Иванов Иван'));
        await sync.syncNow();

        // На сервере сотрудника позже изменили с другого ПК.
        final key = 'employees/$a';
        server.rows[key] = {
          ...server.rows[key]!,
          'updated_at': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 1))
              .toIso8601String(),
          'edited_by': 'other-pc',
          'data': {
            ...(server.rows[key]!['data'] as Map<String, Object?>),
            'position': 'Бригадир',
          },
        };
        server.log.add(key);

        // Без сети добавили сотрудника и сделали копию (он есть только в ней).
        server.online = false;
        final b = await repo.employees.add(employee('Петров Пётр'));
        final backup = await app.createBackup();
        expect(backup, isNotNull);

        expect(await app.restoreFullBackup(backup!), isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(
          sync.phase,
          SyncPhase.ready,
          reason: 'связь с сервером осталась',
        );
        expect(
          await app.localDatabase.syncStateDao.getValue(SyncProvider.relinkKey),
          '1',
        );
        // Сети нет — сверка ждёт; флаг переживёт и перезапуск программы.
        expect(await sync.syncNow(), isNull);

        server.online = true;
        final report = await sync.syncNow();
        expect(report, isNotNull);
        expect((await byName('Иванов Иван'))!.position, 'Бригадир');
        expect(await byName('Петров Пётр'), isNotNull);
        expect(server.rows.containsKey('employees/$b'), isTrue);
        expect(sync.pending, 0);
        expect(
          await app.localDatabase.syncStateDao.getValue(SyncProvider.relinkKey),
          isNull,
        );
        final entry = journal.entries.single;
        expect(entry.kind, JournalKind.lost);
        expect(entry.message, contains('при привязке'));

        // Дальше — обычная синхронизация.
        final quiet = await sync.syncNow();
        expect(quiet!.pushed + quiet.lost, 0);
      },
    );
  });
}
