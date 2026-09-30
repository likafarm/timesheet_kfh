@Tags(['mysql'])
library;

import 'dart:async';
import 'dart:convert';

import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_server/kfh_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support/mysql.dart';

/// Синхронизация через HTTP-обработчик на настоящей MySQL.
void main() {
  late TestDatabase testDb;
  late Handler handler;
  late AuthService auth;
  late Map<Role, String> tokens;
  late String adminUuid;

  /// Сейчас по часам сервера (обычные часы — проверка сдвига часов).
  DateTime at(int minutesAgo) =>
      DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo));

  setUp(() async {
    if (!mysqlEnabled) return;
    testDb = await TestDatabase.create(maxConnections: 6);
    final logger = Logger(write: (_) {});
    await MigrationRunner(testDb.db, logger).migrate(projectMigrations());
    auth = AuthService(
      db: testDb.db,
      accessTokens: AccessTokens(utf8.encode('k' * 32)),
      logger: logger,
      hasher: const PasswordHasher(memoryKiB: 1024, iterations: 1),
    );
    final authApi = AuthApi(auth);
    handler = buildHandler(
      db: testDb.db,
      logger: logger,
      authApi: authApi,
      syncApi: SyncApi(SyncService(db: testDb.db, logger: logger), authApi),
    );
    final admin = await auth.createFirstAdmin(
        login: 'admin', fullName: 'Админ', password: 'admin-pass-1');
    adminUuid = admin.uuid;
    tokens = {Role.admin: (await auth.login('admin', 'admin-pass-1',
            const RequestInfo()))
        .accessToken};
    for (final role in [Role.accountant, Role.operator]) {
      await auth.createUser(admin,
          login: role.name,
          fullName: role.name,
          role: role.name,
          password: 'temp-pass-1',
          info: const RequestInfo());
      await auth.setPasswordFromConsole(role.name, 'real-pass-1');
      tokens[role] = (await auth.login(role.name, 'real-pass-1',
              const RequestInfo()))
          .accessToken;
    }
  });

  tearDown(() async {
    if (mysqlEnabled) await testDb.dispose();
  });

  Future<(int, dynamic)> call(String method, String path,
      {Object? body, Role role = Role.accountant, String? device = 'pc-1'}) async {
    final response = await handler(Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {
        'authorization': 'Bearer ${tokens[role]}',
        'x-device-id': ?device,
      },
    ));
    final text = await response.readAsString();
    return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
  }

  /// push; результат — список итогов.
  Future<List<Map<String, dynamic>>> push(List<Object?> changes,
      {Role role = Role.accountant, String device = 'pc-1'}) async {
    final (status, json) = await call('POST', '/sync/push',
        body: {'changes': changes}, role: role, device: device);
    expect(status, 200, reason: '$json');
    return (json['results'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> pull(
      {int cursor = 0, String? epoch, int? limit, Role role = Role.accountant}) async {
    final query = [
      'cursor=$cursor',
      if (epoch != null) 'epoch=$epoch',
      if (limit != null) 'limit=$limit',
    ].join('&');
    final (status, json) =
        await call('GET', '/sync/pull?$query', role: role);
    expect(status, 200, reason: '$json');
    return json;
  }

  var n = 0;
  String uuid() => '01900000-0000-7000-8000-${(++n).toString().padLeft(12, '0')}';

  Map<String, Object?> employee(String id,
          {DateTime? updatedAt, String name = 'Иванов Иван', bool deleted = false}) =>
      SyncChange(
        table: 'employees',
        uuid: id,
        updatedAt: updatedAt ?? at(10),
        deleted: deleted,
        changeId: 'e-$id',
        data: {
          'legacy_id': null,
          'full_name': name,
          'position': 'Тракторист',
          'hire_date': '2026-01-15',
          'dismissal_date': null,
          'base_rate': 1500.5,
          'field_rate': 2000.0,
        },
      ).toJson();

  Map<String, Object?> day(String id, String employeeId, String date,
          {DateTime? updatedAt,
          bool deleted = false,
          String? notes,
          double days = 1}) =>
      SyncChange(
        table: 'timesheet',
        uuid: id,
        updatedAt: updatedAt ?? at(10),
        deleted: deleted,
        changeId: 't-$id',
        data: {
          'legacy_id': null,
          'employee_uuid': employeeId,
          'date': date,
          'day_type': 'work',
          'days': days,
          'work_place': 'field',
          'notes': notes,
          'created_at': '2026-09-01T10:00:00.123456',
        },
      ).toJson();

  List<String> statuses(List<Map<String, dynamic>> results) =>
      [for (final r in results) r['status'] as String];

  group('push и pull', () {
    test('полный круг без потерь: числа, время до микросекунд, кириллица',
        () async {
      final emp = uuid(), d = uuid();
      final stamp = DateTime.utc(2026, 9, 26, 4, 54, 54, 502, 936);
      final payment = SyncChange(
        table: 'payments',
        uuid: uuid(),
        updatedAt: stamp,
        deleted: false,
        data: {
          'legacy_id': 7,
          'employee_uuid': emp,
          'payment_date': '2026-09-10',
          'amount': 0.1 + 0.2,
          'payment_type': 'advance',
          'period_start': null,
          'period_end': null,
          'payment_method': 'cash',
          'document_number': '№ 12/а',
          'notes': 'Аванс «за сентябрь» \\ \' 🌾',
          'created_at': '2026-09-10T08:00:00',
        },
      );
      // Порядок в пачке — ребёнок раньше сотрудника: сервер разберётся.
      final results = await push([
        day(d, emp, '2026-09-01', notes: 'поле', days: 0.5),
        payment.toJson(),
        employee(emp, updatedAt: stamp),
      ]);
      expect(statuses(results), ['applied', 'applied', 'applied']);
      expect(results.first['change_id'], 't-$d');

      final pulled = await pull(role: Role.admin);
      final changes = [
        for (final c in pulled['changes'] as List) SyncChange.fromJson(c),
      ];
      expect(changes.map((c) => c.table),
          ['employees', 'timesheet', 'payments'], reason: 'сотрудники первыми');
      final gotPayment = changes.firstWhere((c) => c.table == 'payments');
      expect(gotPayment.data, payment.data);
      expect(gotPayment.updatedAt, stamp);
      expect(gotPayment.editedBy, 'pc-1');
      expect(changes.first.updatedAt, stamp);
      expect(pulled['has_more'], isFalse);
      expect(pulled['cursor'], greaterThan(0));
      expect(pulled['epoch'], isNotEmpty);
    }, skip: mysqlSkip);

    test('повтор — duplicate, старее — stale, новее — applied', () async {
      final emp = uuid();
      final t10 = at(10);
      final first = employee(emp, updatedAt: t10);
      expect(statuses(await push([first])), ['applied']);
      expect(statuses(await push([first])), ['duplicate']);
      expect(statuses(await push([employee(emp, updatedAt: at(20), name: 'Старое')])),
          ['stale']);
      // То же время, другие данные — выигрывает сервер.
      expect(statuses(await push([employee(emp, updatedAt: t10, name: 'Другое')])),
          ['stale']);
      expect(statuses(await push([employee(emp, updatedAt: at(5), name: 'Новое')])),
          ['applied']);
      final pulled = await pull();
      final changes = pulled['changes'] as List;
      expect(changes, hasLength(1), reason: 'одна запись, хоть и менялась дважды');
      expect(changes.single['data']['full_name'], 'Новое');
    }, skip: mysqlSkip);

    test('pull с курсора отдаёт только новое', () async {
      final e1 = uuid(), e2 = uuid();
      await push([employee(e1)]);
      final first = await pull();
      await push([employee(e2)]);
      final second = await pull(cursor: first['cursor'], epoch: first['epoch']);
      expect([for (final c in second['changes']) c['uuid']], [e2]);
      final empty = await pull(cursor: second['cursor'], epoch: second['epoch']);
      expect(empty['changes'], isEmpty);
      expect(empty['cursor'], second['cursor']);
    }, skip: mysqlSkip);

    test('постранично: limit и has_more', () async {
      await push([for (var i = 0; i < 5; i++) employee(uuid())]);
      var page = await pull(limit: 2);
      final seen = <String>[];
      while (true) {
        seen.addAll([for (final c in page['changes']) c['uuid'] as String]);
        if (page['has_more'] != true) break;
        page = await pull(cursor: page['cursor'], epoch: page['epoch'], limit: 2);
      }
      expect(seen, hasLength(5));
      expect(seen.toSet(), hasLength(5));
    }, skip: mysqlSkip);

    test('мягкое удаление приходит как deleted, пишется в журнал и аудит',
        () async {
      final emp = uuid(), d = uuid();
      await push([employee(emp), day(d, emp, '2026-09-02')]);
      final before = await pull();
      expect(statuses(await push([day(d, emp, '2026-09-02', updatedAt: at(1), deleted: true)])),
          ['applied']);
      final after = await pull(cursor: before['cursor'], epoch: before['epoch']);
      expect(after['changes'].single['deleted'], isTrue);
      final log = await testDb.db.execute(
          "SELECT operation FROM change_log WHERE entity_uuid = :u ORDER BY seq",
          {'u': d});
      expect([for (final r in log.rows) r.textOf('operation')], ['upsert', 'delete']);
      final audit = await testDb.db.execute(
          'SELECT action, user_uuid, device_id FROM audit_log '
          "WHERE entity_uuid = :u ORDER BY id", {'u': d});
      expect([for (final r in audit.rows) r.textOf('action')],
          ['sync_insert', 'sync_delete']);
      expect(audit.rows.last.text('device_id'), 'pc-1');
    }, skip: mysqlSkip);
  });

  group('отказы по одному, остальное проходит', () {
    test('неверное изменение, неизвестный сотрудник, занятый день', () async {
      final emp = uuid(), d1 = uuid(), d2 = uuid();
      await push([employee(emp)]);
      final bad = day(uuid(), emp, '2026-02-30');
      final results = await push([
        bad,
        day(uuid(), uuid(), '2026-09-03'),
        day(d1, emp, '2026-09-04'),
        day(d2, emp, '2026-09-04'),
        {'change_id': 'x', 'table': 'users'},
      ]);
      expect(statuses(results),
          ['rejected', 'rejected', 'applied', 'rejected', 'rejected']);
      expect(results[0]['code'], 'invalid');
      expect(results[0]['message'], contains('timesheet.date'));
      expect(results[1]['code'], 'unknown_employee');
      expect(results[3]['code'], 'unique_conflict');
      expect(results[3]['conflict_uuid'], d1);
      expect(results[4]['change_id'], 'x');
      // Удалённая запись день не занимает.
      await push([day(d1, emp, '2026-09-04', updatedAt: at(1), deleted: true)]);
      expect(statuses(await push([day(d2, emp, '2026-09-04')])), ['applied']);
    }, skip: mysqlSkip);

    test('время из будущего — clock_skew', () async {
      final results = await push([
        employee(uuid(), updatedAt: DateTime.now().toUtc().add(const Duration(hours: 1))),
      ]);
      expect(results.single['code'], 'clock_skew');
    }, skip: mysqlSkip);

    test('без X-Device-Id — 400; больше 500 — 413', () async {
      var (s, j) = await call('POST', '/sync/push',
          body: {'changes': []}, device: null);
      expect((s, j['error']['code']), (400, 'device_id_required'));
      (s, j) = await call('POST', '/sync/push',
          body: {'changes': List.filled(501, 1)});
      expect(s, 413);
    }, skip: mysqlSkip);
  });

  group('роли', () {
    test('оператор пишет только табель', () async {
      final emp = uuid();
      await push([employee(emp)]);
      final results = await push([
        day(uuid(), emp, '2026-09-05'),
        employee(uuid()),
        employee(emp, updatedAt: at(1), name: 'Взлом'),
      ], role: Role.operator, device: 'phone-1');
      expect(statuses(results), ['applied', 'rejected', 'rejected']);
      expect(results[1]['code'], 'forbidden');
    }, skip: mysqlSkip);

    test('оператор видит сотрудников без ставок и табель, но не выплаты',
        () async {
      final emp = uuid();
      await push([
        employee(emp),
        day(uuid(), emp, '2026-09-06'),
        SyncChange(
          table: 'employee_rates',
          uuid: uuid(),
          updatedAt: at(10),
          deleted: false,
          data: {
            'legacy_id': null,
            'employee_uuid': emp,
            'base_rate': 1500.0,
            'field_rate': 2000.0,
            'start_date': '2026-01-01',
            'end_date': null,
          },
        ).toJson(),
      ]);
      final pulled = await pull(role: Role.operator);
      final changes = pulled['changes'] as List;
      expect(changes.map((c) => c['table']), ['employees', 'timesheet']);
      expect(changes.first['data']['base_rate'], 0.0);
      expect(changes.first['data']['field_rate'], 0.0);
      expect(changes.first['data']['full_name'], 'Иванов Иван');
      // Курсор всё равно дошёл до конца журнала.
      expect(pulled['cursor'], (await pull())['cursor']);
    }, skip: mysqlSkip);

    test('только нужные таблицы (6.10): бухгалтер догружает с нуля',
        () async {
      final emp = uuid();
      await push([employee(emp), day(uuid(), emp, '2026-09-06')]);
      var (s, j) = await call('GET',
          '/sync/pull?cursor=0&tables=employees,employee_rates,payments');
      expect(s, 200);
      expect((j['changes'] as List).map((c) => c['table']), ['employees']);
      expect(j['changes'].first['data']['base_rate'], 1500.5);
      // Оператору отбор не открывает закрытого.
      (s, j) = await call('GET', '/sync/pull?cursor=0&tables=payments',
          role: Role.operator);
      expect(j['changes'], isEmpty);
      (s, j) = await call('GET', '/sync/pull?cursor=0&tables=users');
      expect(s, 400);
    }, skip: mysqlSkip);
  });

  group('закрытые месяцы', () {
    setUp(() async {
      if (!mysqlEnabled) return;
      await testDb.db.execute(
          'INSERT INTO period_locks (year, month, locked_by) VALUES '
          '(2026, 8, :u)',
          {'u': adminUuid});
    });

    test('табель закрытого месяца — period_locked, открытого — проходит',
        () async {
      final emp = uuid();
      await push([employee(emp)]);
      final results = await push([
        day(uuid(), emp, '2026-08-31'),
        day(uuid(), emp, '2026-09-01'),
      ]);
      expect(statuses(results), ['rejected', 'applied']);
      expect(results.first['code'], 'period_locked');
      expect(results.first['message'], contains('08.2026'));
    }, skip: mysqlSkip);

    test('ставка: новая с сентября и закрытие прежней августа нельзя, '
        'с октября — можно', () async {
      final emp = uuid(), old = uuid();
      Map<String, Object?> rate(String id, String start, String? end,
              {DateTime? updatedAt}) =>
          SyncChange(
            table: 'employee_rates',
            uuid: id,
            updatedAt: updatedAt ?? at(10),
            deleted: false,
            data: {
              'legacy_id': null,
              'employee_uuid': emp,
              'base_rate': 1000.0,
              'field_rate': 1500.0,
              'start_date': start,
              'end_date': end,
            },
          ).toJson();
      // Старая ставка заведена до закрытия (сразу пишем в базу мимо
      // проверки — как если бы месяц закрыли потом).
      await testDb.db.execute('DELETE FROM period_locks');
      await push([employee(emp), rate(old, '2026-01-01', null)]);
      await testDb.db.execute('INSERT INTO period_locks (year, month, '
          'locked_by) VALUES (2026, 8, :u)', {'u': adminUuid});

      // Закрыть прежнюю 31.07 — задевает закрытый август.
      var results = await push([
        rate(old, '2026-01-01', '2026-07-31', updatedAt: at(5)),
        rate(uuid(), '2026-08-01', null),
      ]);
      expect(statuses(results), ['rejected', 'rejected']);
      // Закрыть 30.09 и начать новую с 01.10 — август не тронут.
      results = await push([
        rate(old, '2026-01-01', '2026-09-30', updatedAt: at(5)),
        rate(uuid(), '2026-10-01', null),
      ]);
      expect(statuses(results), ['applied', 'applied']);
    }, skip: mysqlSkip);
  });

  group('эпоха и курсор', () {
    test('чужая эпоха или курсор за концом журнала — 409 resync_required',
        () async {
      await push([employee(uuid())]);
      final first = await pull();
      var (s, j) = await call('GET',
          '/sync/pull?cursor=${first['cursor']}&epoch=other');
      expect((s, j['error']['code']), (409, 'resync_required'));
      (s, j) = await call('GET',
          '/sync/pull?cursor=${first['cursor'] + 100}&epoch=${first['epoch']}');
      expect(s, 409);

      // Восстановление из копии: эпоху меняют — клиенты начинают с нуля.
      await testDb.db.execute('UPDATE sync_serial SET epoch = UUID()');
      (s, j) = await call('GET',
          '/sync/pull?cursor=${first['cursor']}&epoch=${first['epoch']}');
      expect(s, 409);
      final fresh = await pull();
      expect(fresh['epoch'], isNot(first['epoch']));
      expect(fresh['changes'], hasLength(1));
    }, skip: mysqlSkip);

    test('неверные параметры — 400', () async {
      var (s, _) = await call('GET', '/sync/pull?cursor=abc');
      expect(s, 400);
      (s, _) = await call('GET', '/sync/pull?cursor=-1');
      expect(s, 400);
    }, skip: mysqlSkip);
  });

  group('очередь записи', () {
    test('push ждёт открытую транзакцию журнала, seq идут по фиксации',
        () async {
      final emp = uuid();
      await push([employee(emp)]);
      final release = Completer<void>();
      final locked = Completer<void>();
      late int heldSeq;
      final holder = testDb.db.transaction((conn) async {
        await const ChangeLog().lock(conn.execute);
        heldSeq = await const ChangeLog()
            .append(conn.execute, 'employees', emp, deleted: false);
        locked.complete();
        await release.future;
      });
      await locked.future;

      var pushed = false;
      final pushing = push([employee(uuid())]).then((r) {
        pushed = true;
        return r;
      });
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(pushed, isFalse, reason: 'push должен ждать очередь');
      release.complete();
      await holder;
      expect(statuses(await pushing), ['applied']);

      final seqs = await testDb.db.execute(
          'SELECT seq FROM change_log ORDER BY seq');
      final all = [for (final r in seqs.rows) r.intOf('seq')];
      expect(all.last, greaterThan(heldSeq));
    }, skip: mysqlSkip);

    test('параллельные push от разных устройств — ничего не теряется',
        () async {
      final devices = [for (var i = 0; i < 8; i++) 'pc-$i'];
      await Future.wait([
        for (final device in devices)
          push([for (var i = 0; i < 5; i++) employee(uuid())], device: device),
      ]);
      final seen = <String>{};
      var page = await pull(limit: 7);
      while (true) {
        seen.addAll([for (final c in page['changes']) c['uuid'] as String]);
        if (page['has_more'] != true) break;
        page = await pull(cursor: page['cursor'], epoch: page['epoch'], limit: 7);
      }
      expect(seen, hasLength(40));
    }, skip: mysqlSkip);
  });
}
