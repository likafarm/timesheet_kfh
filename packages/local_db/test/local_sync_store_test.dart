import 'package:drift/drift.dart' show Value, Variable, driftRuntimeOptions;
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:test/test.dart';

/// Устройство — своя база, свои часы.
class Device {
  DateTime now;
  late final LocalDatabase db;
  late final DriftRepositories repo;
  late final LocalSyncStore store;

  Device(this.now) {
    db = LocalDatabase.memory(clock: () => now);
    repo = DriftRepositories(db);
    store = LocalSyncStore(db);
  }

  void tick([Duration by = const Duration(minutes: 1)]) => now = now.add(by);

  Future<String> addEmployee(String name) => repo.employees.add(
    Employee(
      fullName: name,
      position: 'Рабочий',
      hireDate: DateTime(2025, 3, 1),
      baseRate: 1000,
      fieldRate: 1500,
    ),
  );

  Future<String> addWork(String employee, DateTime day, {double days = 1}) =>
      repo.timesheet.add(
        TimesheetRecord(
          employeeId: employee,
          date: day,
          dayType: 'work',
          days: days,
          workPlace: 'field',
        ),
      );

  /// Отметить всё как отправленное — «сервер всё принял».
  Future<void> pushAll() async {
    for (final c in await store.pendingChanges(includeRejected: true)) {
      await store.markPushed(c);
    }
  }

  Future<List<String>> pendingUuids() async => [
    for (final c in await store.pendingChanges()) c.uuid,
  ];

  /// Записи этого устройства в формате обмена — как их отдал бы сервер.
  Future<List<SyncChange>> rows(String table) async => [
    for (final r in await readAllSyncRows(db))
      if (r.table == table) r,
  ];

  Future<SyncChange> row(String table, String uuid) async =>
      (await rows(table)).singleWhere((r) => r.uuid == uuid);

  Future<Map<String, Object?>> raw(String table, String uuid) async =>
      (await db
              .customSelect(
                'SELECT * FROM $table WHERE uuid = ?',
                variables: [Variable<String>(uuid)],
              )
              .getSingle())
          .data;
}

SyncChange edited(
  SyncChange c,
  DateTime at,
  Map<String, Object?> data, {
  bool? deleted,
}) => SyncChange(
  table: c.table,
  uuid: c.uuid,
  updatedAt: at,
  deleted: deleted ?? c.deleted,
  editedBy: 'other-device',
  data: {...c.data, ...data},
);

void main() {
  // Два устройства — две базы в памяти, это нарочно.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Device a; // это устройство
  late Device b; // другое устройство (его записи «приходят с сервера»)

  setUp(() {
    a = Device(DateTime.utc(2026, 9, 27, 10));
    b = Device(DateTime.utc(2026, 9, 27, 10, 0, 30));
  });
  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  group('очередь', () {
    test('новая база: неотправлены только настройки хозяйства', () async {
      expect(await a.pendingUuids(), [companySettingsUuid]);
      expect(await a.store.pendingCount(), 1);
    });

    test('любая правка ставит запись в очередь, отправка снимает', () async {
      await a.pushAll();
      final emp = await a.addEmployee('Иванов Иван');
      expect(await a.pendingUuids(), [emp]);

      await a.pushAll();
      expect(await a.store.pendingCount(), 0);
      final raw = await a.raw('employees', emp);
      expect(raw['remote_updated_at'], raw['updated_at']);

      a.tick();
      final e = (await a.repo.employees.byId(emp))!;
      await a.repo.employees.update(e.copyWith(position: 'Тракторист'));
      expect(await a.pendingUuids(), [emp]);

      // Мягкое удаление — тоже изменение.
      await a.pushAll();
      a.tick();
      final day = await a.addWork(emp, DateTime(2026, 9, 1));
      await a.pushAll();
      a.tick();
      await a.repo.timesheet.delete(day);
      final pending = await a.store.pendingChanges();
      expect(pending.single.uuid, day);
      expect(pending.single.change.deleted, isTrue);
      expect(pending.single.change.changeId, day);
    });

    test('правка через просмотр базы тоже попадает в очередь', () async {
      final emp = await a.addEmployee('Иванов Иван');
      await a.pushAll();
      a.tick();
      await RawTables(a.db).updateRow('employees', emp, {'position': 'Сторож'});
      expect(await a.pendingUuids(), [emp]);
    });

    test('сотрудники уходят раньше ссылающихся на них записей', () async {
      await a.pushAll();
      final emp = await a.addEmployee('Иванов Иван');
      final day = await a.addWork(emp, DateTime(2026, 9, 1));
      final other = await a.addEmployee('Петров Пётр');
      expect(await a.pendingUuids(), [emp, other, day]);
      expect((await a.store.pendingChanges(limit: 2)).length, 2);
    });

    test('запись, изменённая во время отправки, остаётся в очереди', () async {
      await a.pushAll();
      final emp = await a.addEmployee('Иванов Иван');
      final sent = (await a.store.pendingChanges()).single;
      a.tick();
      final e = (await a.repo.employees.byId(emp))!;
      await a.repo.employees.update(e.copyWith(position: 'Тракторист'));
      await a.store.markPushed(sent);
      final again = (await a.store.pendingChanges()).single;
      expect(again.change.data['position'], 'Тракторист');
    });

    test('отправляемая запись проходит проверку формата обмена', () async {
      final emp = await a.addEmployee('Иванов Иван');
      await a.addWork(emp, DateTime(2026, 9, 1), days: 0.5);
      for (final c in await a.store.pendingChanges()) {
        final back = SyncChange.fromJson(c.change.toJson());
        expect(back.data, c.change.data);
        expect(back.updatedAt, c.change.updatedAt);
      }
    });
  });

  group('отклонённые', () {
    test('не уходят повторно, пока запись не изменят', () async {
      await a.pushAll();
      final emp = await a.addEmployee('Иванов Иван');
      final day = await a.addWork(emp, DateTime(2026, 8, 1));
      await a.store.markPushed(
        (await a.store.pendingChanges()).firstWhere((c) => c.uuid == emp),
      );
      final change = (await a.store.pendingChanges()).single;
      await a.store.markRejected(
        change,
        'period_locked',
        'Месяц 08.2026 закрыт',
      );
      await a.store.markRejected(
        change,
        'period_locked',
        'Месяц 08.2026 закрыт',
      );

      expect(await a.store.pendingChanges(), isEmpty);
      expect(await a.store.pendingCount(), 1);
      expect(
        (await a.store.pendingChanges(includeRejected: true)).single.uuid,
        day,
      );
      final rejected = (await a.store.rejectedChanges()).single;
      expect(rejected.uuid, day);
      expect(rejected.code, 'period_locked');
      expect(rejected.message, 'Месяц 08.2026 закрыт');
      expect(rejected.attempts, 2);

      // Новая правка — новая попытка.
      a.tick();
      final r = (await a.repo.timesheet.on(emp, DateTime(2026, 8, 1)))!;
      await a.repo.timesheet.update(r.copyWith(days: 0.5));
      expect(await a.pendingUuids(), [day]);
      expect(await a.store.rejectedChanges(), isEmpty);
    });

    test('clearRejections возвращает их в очередь', () async {
      await a.pushAll();
      final emp = await a.addEmployee('Иванов Иван');
      final change = (await a.store.pendingChanges()).single;
      await a.store.markRejected(change, 'forbidden', 'нельзя');
      expect(await a.store.pendingChanges(), isEmpty);
      await a.store.clearRejections();
      expect(await a.pendingUuids(), [emp]);
    });

    test('успешная отправка снимает отметку об отказе', () async {
      await a.pushAll();
      await a.addEmployee('Иванов Иван');
      final change = (await a.store.pendingChanges()).single;
      await a.store.markRejected(change, 'forbidden', 'нельзя');
      await a.store.markPushed(change);
      expect(await a.store.rejectedChanges(), isEmpty);
      expect(await a.store.pendingCount(), 0);
    });

    test('discardLocal: запись уступила по ключу', () async {
      await a.pushAll();
      final emp = await a.addEmployee('Иванов Иван');
      final day = await a.addWork(emp, DateTime(2026, 9, 1));
      await a.pushAll();
      a.tick();
      final other = await a.addWork(emp, DateTime(2026, 9, 2));
      final fresh = (await a.store.pendingChanges()).single;
      expect(
        await a.store.discardLocal(fresh),
        isFalse,
        reason: 'на сервере записи не было',
      );
      expect((await a.raw('timesheet', other))['deleted'], 1);
      expect(await a.store.pendingCount(), 0);

      // Запись с версией на сервере — после отказа нужен pull с нуля.
      a.tick();
      final r = (await a.repo.timesheet.on(emp, DateTime(2026, 9, 1)))!;
      await a.repo.timesheet.update(r.copyWith(date: DateTime(2026, 9, 3)));
      final moved = (await a.store.pendingChanges()).single;
      expect(moved.uuid, day);
      expect(await a.store.discardLocal(moved), isTrue);
    });
  });

  group('приём с сервера', () {
    test('новые записи пишутся и не попадают в очередь', () async {
      await a.pushAll();
      final emp = await b.addEmployee('Петров Пётр');
      final day = await b.addWork(emp, DateTime(2026, 9, 1), days: 0.5);
      // Табель раньше сотрудника: внешние ключи отложенные.
      final incoming = [
        await b.row('timesheet', day),
        await b.row('employees', emp),
      ];
      final report = await a.store.applyRemote(incoming);
      expect(report.applied, 2);
      expect(report.lost, isEmpty);
      expect(await a.store.pendingCount(), 0);

      expect(await a.row('employees', emp), _sameAs(incoming[1]));
      expect(await a.row('timesheet', day), _sameAs(incoming[0]));
      final rec = (await a.repo.timesheet.on(emp, DateTime(2026, 9, 1)))!;
      expect(rec.days, 0.5);
    });

    test('время с микросекундами не ломает отметку «отправлено»', () async {
      await a.pushAll();
      b.now = DateTime.utc(2026, 9, 27, 10, 0, 0, 123, 456);
      final emp = await b.addEmployee('Петров Пётр');
      final change = await b.row('employees', emp);
      expect(change.updatedAt.microsecond, 456);
      await a.store.applyRemote([change]);
      expect(await a.store.pendingCount(), 0);
      expect((await a.row('employees', emp)).updatedAt, change.updatedAt);
    });

    test(
      'пустой ПК: серверные настройки заменяют местные по умолчанию',
      () async {
        // На сервере — настройки первого ПК, записанные раньше.
        await a.db.settingsDao.updateSettings(
          const CompanySettingsCompanion(companyName: Value('КФХ Иванова')),
        );
        final server = await a.row('company_settings', companySettingsUuid);
        expect(server.updatedAt.isBefore(b.now), isTrue);

        // Без отметки местная версия новее — осталась бы и ушла бы на сервер.
        await b.store.markAllSynced();
        expect(await b.store.pendingCount(), 0);
        final report = await b.store.applyRemote([server]);
        expect(report.applied, 1);
        expect(
          (await b.row(
            'company_settings',
            companySettingsUuid,
          )).data['company_name'],
          'КФХ Иванова',
        );
      },
    );

    test('синхронизированная запись принимает серверную версию', () async {
      final emp = await a.addEmployee('Иванов Иван');
      await a.pushAll();
      final server = edited(
        await a.row('employees', emp),
        DateTime.utc(2026, 9, 27, 11),
        {'position': 'Бригадир'},
      );
      final report = await a.store.applyRemote([server]);
      expect(report.applied, 1);
      expect((await a.repo.employees.byId(emp))!.position, 'Бригадир');
      expect(await a.store.pendingCount(), 0);
    });

    test('неотправленная правка новее серверной остаётся', () async {
      final emp = await a.addEmployee('Иванов Иван');
      await a.pushAll();
      final old = await a.row('employees', emp);
      a.tick(const Duration(hours: 2));
      final e = (await a.repo.employees.byId(emp))!;
      await a.repo.employees.update(e.copyWith(position: 'Тракторист'));

      final report = await a.store.applyRemote([
        edited(old, DateTime.utc(2026, 9, 27, 11), {'position': 'Бригадир'}),
      ]);
      expect(report.keptLocal, 1);
      expect(report.applied, 0);
      expect((await a.repo.employees.byId(emp))!.position, 'Тракторист');
      expect(await a.pendingUuids(), [emp]);
    });

    test(
      'неотправленная правка старше серверной уступает — в журнал',
      () async {
        final emp = await a.addEmployee('Иванов Иван');
        await a.pushAll();
        a.tick();
        final e = (await a.repo.employees.byId(emp))!;
        await a.repo.employees.update(e.copyWith(position: 'Тракторист'));
        final mine = await a.row('employees', emp);

        final server = edited(mine, DateTime.utc(2026, 9, 27, 12), {
          'position': 'Бригадир',
        });
        final report = await a.store.applyRemote([server]);
        expect(report.applied, 1);
        final lost = report.lost.single;
        expect(lost.reason, LostReason.overwritten);
        expect(lost.local.data['position'], 'Тракторист');
        expect(lost.remote.data['position'], 'Бригадир');
        expect(report.needsResync, isFalse);
        expect((await a.repo.employees.byId(emp))!.position, 'Бригадир');
        expect(await a.store.pendingCount(), 0);
      },
    );

    test('равное время: побеждает сервер', () async {
      final emp = await a.addEmployee('Иванов Иван');
      final mine = await a.row('employees', emp);
      final report = await a.store.applyRemote([
        edited(mine, mine.updatedAt, {'position': 'Бригадир'}),
      ]);
      expect(report.lost.single.reason, LostReason.overwritten);
      expect((await a.repo.employees.byId(emp))!.position, 'Бригадир');
    });

    test('такая же версия с сервера — не конфликт', () async {
      final emp = await a.addEmployee('Иванов Иван');
      final mine = await a.row('employees', emp);
      final report = await a.store.applyRemote([mine]);
      expect(report.lost, isEmpty);
      expect(await a.pendingUuids(), [companySettingsUuid]);
    });

    test(
      'своя отправленная запись, вернувшаяся с сервера, не пишется',
      () async {
        final emp = await a.addEmployee('Иванов Иван');
        await a.pushAll();
        final report = await a.store.applyRemote([
          await a.row('employees', emp),
        ]);
        expect(report.unchanged, 1);
        expect(report.applied, 0);
      },
    );

    test('удаление с сервера', () async {
      final emp = await a.addEmployee('Иванов Иван');
      final day = await a.addWork(emp, DateTime(2026, 9, 1));
      await a.pushAll();
      final server = edited(
        await a.row('timesheet', day),
        DateTime.utc(2026, 9, 27, 11),
        {},
        deleted: true,
      );
      await a.store.applyRemote([server]);
      expect(await a.repo.timesheet.on(emp, DateTime(2026, 9, 1)), isNull);
      expect(await a.store.pendingCount(), 0);
    });

    test('день, введённый на двух устройствах: побеждает серверный', () async {
      final emp = await a.addEmployee('Иванов Иван');
      await a.pushAll();
      await b.store.applyRemote([await a.row('employees', emp)]);

      final mine = await a.addWork(emp, DateTime(2026, 9, 1));
      final theirs = await b.addWork(emp, DateTime(2026, 9, 1), days: 0.5);
      final report = await a.store.applyRemote([
        await b.row('timesheet', theirs),
      ]);

      final lost = report.lost.single;
      expect(lost.reason, LostReason.uniqueKey);
      expect(lost.local.uuid, mine);
      expect(lost.remote.uuid, theirs);
      expect(report.needsResync, isFalse, reason: 'на сервере записи не было');
      expect(
        (await a.repo.timesheet.on(emp, DateTime(2026, 9, 1)))!.id,
        theirs,
      );
      expect((await a.raw('timesheet', mine))['deleted'], 1);
      expect(await a.store.pendingCount(), 0, reason: 'проигравшая не уходит');
    });

    test(
      'уступившая по ключу запись с версией на сервере — pull с нуля',
      () async {
        final emp = await a.addEmployee('Иванов Иван');
        final mine = await a.addWork(emp, DateTime(2026, 9, 2));
        await a.pushAll();
        await b.store.applyRemote([
          await a.row('employees', emp),
          await a.row('timesheet', mine),
        ]);
        // Здесь запись перенесли на 1-е, а там 1-е уже занято другой.
        a.tick();
        final r = (await a.repo.timesheet.on(emp, DateTime(2026, 9, 2)))!;
        await a.repo.timesheet.update(r.copyWith(date: DateTime(2026, 9, 1)));
        final theirs = await b.addWork(emp, DateTime(2026, 9, 1));

        final report = await a.store.applyRemote([
          await b.row('timesheet', theirs),
        ]);
        expect(report.lost.single.reason, LostReason.uniqueKey);
        expect(report.needsResync, isTrue);
      },
    );

    test(
      'синхронизированная запись с тем же ключом снимается без журнала',
      () async {
        final emp = await a.addEmployee('Иванов Иван');
        final old = await a.addWork(emp, DateTime(2026, 9, 1));
        await a.pushAll();
        await b.store.applyRemote([await a.row('employees', emp)]);
        final theirs = await b.addWork(emp, DateTime(2026, 9, 1), days: 0.5);

        final report = await a.store.applyRemote([
          await b.row('timesheet', theirs),
        ]);
        expect(report.lost, isEmpty);
        expect((await a.raw('timesheet', old))['deleted'], 1);
        expect(await a.store.pendingCount(), 0);

        // Удаление старой записи приходит следом — без конфликтов.
        final deletion = edited(
          await a.row('timesheet', old),
          DateTime.utc(2026, 9, 27, 11),
          {},
          deleted: true,
        );
        final second = await a.store.applyRemote([deletion]);
        expect(second.lost, isEmpty);
        expect(await a.store.pendingCount(), 0);
      },
    );

    test('ошибка в пачке откатывает всю пачку', () async {
      await a.pushAll();
      final emp = await b.addEmployee('Петров Пётр');
      final day = await b.addWork(emp, DateTime(2026, 9, 1));
      // Табель без сотрудника — внешний ключ при COMMIT.
      await expectLater(
        a.store.applyRemote([await b.row('timesheet', day)]),
        throwsA(anything),
      );
      expect(await a.rows('timesheet'), isEmpty);
      await expectLater(
        a.store.applyRemote([
          await b.row('timesheet', day),
        ], cursor: const SyncCursor(7, 'e')),
        throwsA(anything),
      );
      expect(
        await a.store.cursor(),
        SyncCursor.start,
        reason: 'курсор — в той же транзакции',
      );
    });
  });

  group('привязка к серверу', () {
    test('по умолчанию база не привязана; адрес сохраняется', () async {
      expect(await a.store.linkedServer(), isNull);
      await a.store.setLinkedServer('https://tab.example.ru');
      expect(await a.store.linkedServer(), 'https://tab.example.ru');
    });

    test('forgetServer: всё снова не отправлено, данные те же', () async {
      final emp = await a.addEmployee('Иванов Иван');
      await a.addWork(emp, DateTime(2026, 9, 1));
      await a.pushAll();
      await a.store.saveCursor(const SyncCursor(9, 'e'));
      await a.store.setLinkedServer('https://old.example.ru');
      final before = await readAllSyncRows(a.db);

      await a.store.forgetServer();
      expect(await a.store.pendingCount(), 3);
      expect(await a.store.cursor(), SyncCursor.start);
      expect(await a.store.linkedServer(), isNull);
      final after = await readAllSyncRows(a.db);
      expect(
        [for (final r in after) r.toJson()],
        [for (final r in before) r.toJson()],
      );
    });

    test('localKeys — все записи, и удалённые', () async {
      final emp = await a.addEmployee('Иванов Иван');
      final day = await a.addWork(emp, DateTime(2026, 9, 1));
      await a.repo.timesheet.delete(day);
      final keys = await a.store.localKeys();
      expect(keys['employees'], {emp});
      expect(keys['timesheet'], {day});
      expect(keys['company_settings'], {companySettingsUuid});
    });

    test(
      'версия, отличающаяся только отметкой «кто менял», — не новые данные',
      () async {
        final emp = await a.addEmployee('Иванов Иван');
        await a.pushAll();
        final mine = await a.row('employees', emp);
        final server = SyncChange(
          table: mine.table,
          uuid: mine.uuid,
          updatedAt: mine.updatedAt,
          deleted: mine.deleted,
          editedBy: 'imported-device',
          data: mine.data,
        );
        final report = await a.store.applyRemote([server]);
        expect(report.unchanged, 1);
        expect(report.applied, 0);
        expect((await a.row('employees', emp)).editedBy, 'imported-device');
        expect(await a.store.pendingCount(), 0);
      },
    );
  });

  group('закрытые месяцы', () {
    test('по умолчанию нет; сохраняются; изменение замечается', () async {
      expect(await a.store.lockedMonths(), isEmpty);
      expect(await a.store.saveLockedMonths([(2026, 8), (2025, 12)]), isTrue);
      expect(await a.store.lockedMonths(), {
        PeriodGuard.monthKey(2026, 8),
        PeriodGuard.monthKey(2025, 12),
      });
      expect(await a.db.syncStateDao.getValue(periodLocksKey),
          '["2025-12","2026-08"]');
      expect(await a.store.saveLockedMonths([(2025, 12), (2026, 8)]), isFalse);
      expect(await a.store.saveLockedMonths([]), isTrue);
      expect(await a.store.lockedMonths(), isEmpty);
    });

    test('неотправленные правки, задевающие месяц', () async {
      final emp = await a.addEmployee('Иванов Иван');
      final sep = await a.addWork(emp, DateTime(2026, 9, 3));
      await a.addWork(emp, DateTime(2026, 10, 1));
      await a.pushAll();
      expect(await a.store.pendingInMonth(2026, 9), isEmpty);

      a.tick();
      await a.repo.timesheet.delete(sep); // удаление — тоже правка сентября
      await a.addWork(emp, DateTime(2026, 10, 2));
      await a.repo.employees.update(
        (await a.repo.employees.byId(emp))!.copyWith(position: 'Тракторист'),
      ); // сотрудник к месяцам не привязан
      expect(
        [for (final p in await a.store.pendingInMonth(2026, 9)) p.uuid],
        [sep],
      );
      expect(await a.store.pendingInMonth(2026, 10), hasLength(1));
    });

    test('смена сервера сбрасывает список', () async {
      await a.store.saveLockedMonths([(2026, 8)]);
      await a.store.forgetServer();
      expect(await a.store.lockedMonths(), isEmpty);
    });
  });

  group('курсор', () {
    test('по умолчанию — с начала', () async {
      expect(await a.store.cursor(), SyncCursor.start);
    });

    test('сохраняется и сбрасывается', () async {
      await a.store.saveCursor(const SyncCursor(42, 'epoch-1'));
      expect(await a.store.cursor(), const SyncCursor(42, 'epoch-1'));
      await a.store.resetCursor();
      expect(await a.store.cursor(), SyncCursor.start);
    });
  });
}

Matcher _sameAs(SyncChange expected) => predicate<SyncChange>(
  (c) =>
      c.uuid == expected.uuid &&
      c.updatedAt == expected.updatedAt &&
      c.deleted == expected.deleted &&
      c.editedBy == expected.editedBy &&
      c.data.keys.every((k) => c.data[k] == expected.data[k]),
  'совпадает с ${expected.toJson()}',
);
