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
      appVersion: () async => '1.3.0',
      database: db,
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

  test('телефон (6.9): бухгалтер входит, первый вход — только приём', () async {
    server.role = 'accountant';
    final sync = provider(client: ClientKind.phone);
    await sync.init();
    await sync.signIn('https://localhost', 'buh', 'secret-pass');
    expect(sync.phase, SyncPhase.needsLink);
    final plan = await sync.analyzeLink();
    expect(plan.kind, BootstrapKind.download);
    await sync.link(plan);
    expect(sync.phase, SyncPhase.ready);
  });

  group('телефон: вход человека другой роли (6.9, 6.10)', () {
    Future<(SyncProvider, String)> operatorWithEdit() async {
      server.role = 'operator';
      final sync = provider(client: ClientKind.phone);
      await sync.init();
      await sync.signIn('https://localhost', 'oper', 'secret-pass');
      await sync.link(await sync.analyzeLink());
      final id = await DriftRepositories(db).employees.add(
        Employee(
          fullName: 'Петров Пётр',
          position: 'Рабочий',
          hireDate: DateTime(2025, 3, 1),
          baseRate: 0,
          fieldRate: 0,
        ),
      );
      await sync.refreshPending();
      expect(sync.pending, 1);
      await sync.signOut();
      return (sync, id);
    }

    test(
      'неотправленное уходит; база не стирается, закрытое догружается',
      () async {
        final (sync, id) = await operatorWithEdit();
        final repos = DriftRepositories(db);
        server.role = 'operator';
        await sync.signIn('https://localhost', 'oper', 'secret-pass');
        await sync.syncNow();
        // Пока телефон был у оператора, бухгалтер на другом ПК поменял
        // сотруднику ставку — оператору она приходит нулём.
        final rows = Map.of(server.rows['employees/$id']!);
        server.rows['employees/$id'] = {
          ...rows,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'data': {
            ...(rows['data'] as Map<String, Object?>),
            'base_rate': 1500.0,
            'field_rate': 2000.0,
          },
        };
        server.log.add('employees/$id');
        await sync.syncNow();
        // Оператору ставка пришла нулём — так и должно быть.
        expect((await repos.employees.byId(id))!.baseRate, 0);
        await sync.signOut();

        server.role = 'accountant';
        reloads = 0;
        await sync.signIn('https://localhost', 'buh', 'secret-pass');
        expect(server.rows.keys, contains('employees/$id'));
        // Приёма заново нет: сразу работа, данные на месте, ставка догружена.
        expect(sync.phase, SyncPhase.ready);
        final e = await repos.employees.byId(id);
        expect(e, isNotNull);
        expect(e!.baseRate, 1500.0);
        expect(e.fieldRate, 2000.0);
        expect(reloads, greaterThan(0));

        // Снова оператор — ничего не стирается и не догружается.
        await sync.signOut();
        server.role = 'operator';
        await sync.signIn('https://localhost', 'oper', 'secret-pass');
        expect(sync.phase, SyncPhase.ready);
        expect((await repos.employees.byId(id))!.baseRate, 1500.0);

        // Тот же бухгалтер дважды подряд — без догрузки.
        await sync.signOut();
        server.role = 'accountant';
        await sync.signIn('https://localhost', 'buh', 'secret-pass');
        final pulls = server.pulls;
        await sync.signOut();
        await sync.signIn('https://localhost', 'buh', 'secret-pass');
        expect(server.pulls, pulls);
        expect(sync.phase, SyncPhase.ready);
      },
    );

    test('нет связи для догрузки — отказ во входе, данные на месте', () async {
      final (sync, id) = await operatorWithEdit();
      server.role = 'operator';
      await sync.signIn('https://localhost', 'oper', 'secret-pass');
      await sync.syncNow();
      await sync.signOut();
      server.role = 'accountant';
      server.failPull = true;
      await expectLater(
        sync.signIn('https://localhost', 'buh', 'secret-pass'),
        throwsA(
          isA<SyncUserException>().having(
            (e) => e.message,
            'message',
            contains('Не удалось принять с сервера ставки и выплаты'),
          ),
        ),
      );
      expect(sync.phase, SyncPhase.signedOut);
      expect(await DriftRepositories(db).employees.byId(id), isNotNull);
      // Связь появилась — догрузка при следующем входе.
      server.failPull = false;
      await sync.signIn('https://localhost', 'buh', 'secret-pass');
      expect(sync.phase, SyncPhase.ready);
    });

    test(
      'сервер не принял правки от новой роли — отказ, данные на месте',
      () async {
        final (sync, id) = await operatorWithEdit();
        server.role = 'accountant';
        server.rejectTables.add('employees');
        await expectLater(
          sync.signIn('https://localhost', 'buh', 'secret-pass'),
          throwsA(
            isA<SyncUserException>().having(
              (e) => e.message,
              'message',
              contains('неотправленные правки прошлого пользователя (1)'),
            ),
          ),
        );
        expect(sync.phase, SyncPhase.signedOut);
        expect(tokens.tokens, isNull);
        expect(await DriftRepositories(db).employees.byId(id), isNotNull);
        // Правка снова ждёт отправки, а не числится отклонённой.
        expect((sync.pending, sync.rejected), (1, 0));
      },
    );
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

  test('версия старее минимальной — синхронизация на паузе', () async {
    server.versions = {
      'platforms': {
        'windows': {'latest': '1.4.0', 'min': '1.4.0'},
        'android': {'latest': '1.3.0', 'min': '1.3.0'},
      },
    };
    final sync = await signedIn();
    await sync.link(await sync.analyzeLink());
    await sync.checkVersion();
    expect(sync.updateRequired, isTrue);
    expect(sync.serverVersion!.latest, '1.4.0');

    final pushes = server.pushes;
    expect(await sync.syncNow(), isNull);
    expect(server.pushes, pushes);
    expect(sync.problem, contains('Нужна новая версия программы (1.4.0)'));

    // Минимальную снизили — снова работает.
    server.versions = {
      'platforms': {
        'windows': {'latest': '1.4.0', 'min': '1.3.0'},
      },
    };
    await sync.checkVersion();
    expect(sync.updateRequired, isFalse);
    expect(sync.updateAvailable, isTrue);
    expect(await sync.syncNow(), isNotNull);
  });

  test(
    'телефон смотрит версию android; старый сервер — без требований',
    () async {
      server.role = 'operator';
      server.versions = {
        'platforms': {
          'android': {'latest': '1.3.1', 'min': '1.3.1'},
        },
      };
      final phone = provider(client: ClientKind.phone);
      await phone.init();
      await phone.checkVersion();
      expect(phone.updateRequired, isTrue);

      server.versions = null;
      final desktop = provider();
      await desktop.init();
      await desktop.checkVersion();
      expect(desktop.updateRequired, isFalse);
      expect(desktop.serverVersion, isNull);
    },
  );

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

  group('закрытие месяцев (6.2)', () {
    Future<SyncProvider> linked({String role = 'accountant'}) async {
      server.role = role;
      final sync = await signedIn();
      await sync.link(await sync.analyzeLink());
      return sync;
    }

    Future<String> addDay(DateTime day) async {
      final repo = DriftRepositories(db);
      final emp = await repo.employees.add(
        Employee(
          fullName: 'Петров Пётр',
          position: 'Рабочий',
          hireDate: DateTime(2025, 3, 1),
          baseRate: 1000,
          fieldRate: 1500,
        ),
      );
      return repo.timesheet.add(
        TimesheetRecord(
          employeeId: emp,
          date: day,
          dayType: 'work',
          days: 1,
          workPlace: 'field',
        ),
      );
    }

    test('права: бухгалтер закрывает, открывает только админ', () async {
      final sync = await linked();
      expect((sync.canLockMonths, sync.canUnlockMonths), (true, false));
      server.role = 'admin';
      await sync.signIn('localhost:8080', 'ivan', 'secret-pass');
      expect((sync.canLockMonths, sync.canUnlockMonths), (true, true));
      await sync.signOut();
      expect(sync.canLockMonths, isFalse, reason: 'без входа');
    });

    test('закрытие: сначала правки уходят, потом месяц закрыт и известен '
        'здесь', () async {
      final sync = await linked();
      await addDay(DateTime(2026, 9, 3));
      await sync.lockMonth(2026, 9, note: '  ведомость сдана ');
      expect(
        server.rows.keys.where((k) => k.startsWith('timesheet/')),
        hasLength(1),
        reason: 'день ушёл до закрытия',
      );
      expect(server.locks, [(2026, 9)]);
      expect(server.lockNotes, ['ведомость сдана']);
      expect(await LocalSyncStore(db).lockedMonths(), {
        PeriodGuard.monthKey(2026, 9),
      });
      final info = (await sync.periodLocks()).single;
      expect((info.lockedByName, info.lockedAt!.isUtc), ('Иван Иванов', true));

      await expectLater(
        sync.lockMonth(2026, 9),
        throwsA(
          isA<SyncUserException>().having(
            (e) => e.message,
            'message',
            contains('уже закрыт'),
          ),
        ),
      );
      await expectLater(
        sync.unlockMonth(2026, 9),
        throwsA(isA<SyncUserException>()),
        reason: 'бухгалтер не открывает',
      );
      await expectLater(
        sync.unlockPreview(2026, 9),
        throwsA(isA<SyncUserException>()),
      );
    });

    test('неотправленная правка в месяце — месяц не закрывается', () async {
      final sync = await linked();
      server.rejectTables.add('timesheet');
      await addDay(DateTime(2026, 9, 3));
      await expectLater(
        sync.lockMonth(2026, 9),
        throwsA(
          isA<SyncUserException>().having(
            (e) => e.message,
            'message',
            contains('1 неотправл.'),
          ),
        ),
      );
      expect(server.locks, isEmpty);
      // Другой месяц правка не задевает.
      await sync.lockMonth(2026, 8);
      expect(server.locks, [(2026, 8)]);
    });

    test('старый сервер — закрывать и открывать нельзя', () async {
      final sync = await linked(role: 'admin');
      server.serverVersion = '0.3.0';
      for (final action in [
        () => sync.lockMonth(2026, 9),
        () => sync.unlockPreview(2026, 9),
        () => sync.unlockMonth(2026, 9),
      ]) {
        await expectLater(
          action(),
          throwsA(
            isA<SyncUserException>().having(
              (e) => e.message,
              'message',
              contains('0.4.0'),
            ),
          ),
        );
      }
      expect(server.locks, isEmpty);
    });

    test('нет связи — месяц не закрывается, понятная причина', () async {
      final sync = await linked();
      server.online = false;
      await expectLater(
        sync.lockMonth(2026, 9),
        throwsA(
          isA<SyncUserException>().having(
            (e) => e.message,
            'message',
            contains('Нет связи'),
          ),
        ),
      );
    });

    test('админ открывает месяц — отклонённые правки уходят снова', () async {
      final sync = await linked(role: 'admin');
      await sync.lockMonth(2026, 9);
      server.rejectTables.add('timesheet');
      await addDay(DateTime(2026, 9, 3));
      await sync.syncNow();
      expect(sync.rejected, 1);
      server.rejectTables.clear();
      final preview = await sync.unlockPreview(2026, 9);
      final change = preview.changes.single.rows.single;
      expect((change.before.accrued, change.after.accrued), (1000.0, 1500.0));
      expect(server.locks, [(2026, 9)], reason: 'предпросмотр не открывает');
      expect(await sync.unlockMonth(2026, 9), 1, reason: 'id снимка');
      final snapshot = (await sync.periodSnapshots()).single;
      expect((snapshot.year, snapshot.month), (2026, 9));
      final changed = await sync.periodSnapshotChanges(snapshot.id);
      expect(changed.snapshot.month, 9);
      expect(changed.changes, isEmpty);
      expect(server.locks, isEmpty);
      expect(await LocalSyncStore(db).lockedMonths(), isEmpty);
      expect(sync.pending, 0, reason: 'отклонённая правка ушла');
    });
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
