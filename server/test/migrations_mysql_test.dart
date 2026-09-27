@Tags(['mysql'])
library;

import 'package:kfh_server/kfh_server.dart';
import 'package:test/test.dart';

import 'support/mysql.dart';

void main() {
  late TestDatabase testDb;
  late List<String> log;
  late MigrationRunner runner;

  setUp(() async {
    if (!mysqlEnabled) return;
    testDb = await TestDatabase.create(maxConnections: 4);
    log = [];
    runner = MigrationRunner(testDb.db, Logger(write: log.add));
  });

  tearDown(() async {
    if (mysqlEnabled) await testDb.dispose();
  });

  Future<List<String>> tables() async => [
        for (final row in (await testDb.db.execute(
                // information_schema в MySQL 8 отдаёт двоичные строки —
                // драйвер вернул бы байты.
                'SELECT CAST(table_name AS CHAR) AS t '
                'FROM information_schema.tables '
                'WHERE table_schema = DATABASE() ORDER BY table_name'))
            .rows)
          row.textOf('t'),
      ];

  test('миграции проекта применяются на пустую базу, повтор — пустой',
      () async {
    final migrations = projectMigrations();
    final applied = await runner.migrate(migrations);
    expect(applied, hasLength(migrations.length));
    expect(await tables(), containsAll([
      'schema_migrations', 'company_settings', 'employees', 'employee_rates',
      'timesheet', 'payments', 'sick_leave', 'vacation', 'payroll_results',
      'users', 'refresh_tokens', 'audit_log', 'period_locks', 'change_log',
    ]));

    expect(await runner.migrate(migrations), isEmpty);
    final status = await runner.status(migrations);
    expect(status.isUpToDate, isTrue);
    expect(status.applied.map((a) => a.checksum),
        migrations.map((m) => m.checksum));
    expect(status.applied.first.appliedAt.isUtc, isTrue);
    expect(
        DateTime.now().toUtc().difference(status.applied.first.appliedAt).abs(),
        lessThan(const Duration(minutes: 5)));
  }, skip: mysqlSkip);

  test('новая миграция применяется поверх старых', () async {
    final first = [Migration(1, 'a', 'CREATE TABLE a (id INT);')];
    await runner.migrate(first);
    final both = [
      ...first,
      Migration(2, 'b', 'CREATE TABLE b (id INT); INSERT INTO b VALUES (1);'),
    ];
    final status = await runner.status(both);
    expect(status.pending.map((m) => m.version), [2]);
    expect((await runner.migrate(both)).map((m) => m.version), [2]);
    expect(await tables(), containsAll(['a', 'b']));
  }, skip: mysqlSkip);

  test('изменённая после применения миграция — отказ', () async {
    await runner.migrate([Migration(1, 'a', 'CREATE TABLE a (id INT);')]);
    final changed = [Migration(1, 'a', 'CREATE TABLE a (id BIGINT);')];
    final status = await runner.status(changed);
    expect(status.problems.single, contains('изменена'));
    await expectLater(
        runner.migrate(changed), throwsA(isA<MigrationException>()));
  }, skip: mysqlSkip);

  test('база новее программы — отказ', () async {
    await runner.migrate([
      Migration(1, 'a', 'CREATE TABLE a (id INT);'),
      Migration(2, 'b', 'CREATE TABLE b (id INT);'),
    ]);
    final status =
        await runner.status([Migration(1, 'a', 'CREATE TABLE a (id INT);')]);
    expect(status.problems.single, contains('новее'));
  }, skip: mysqlSkip);

  test('упавшая миграция не отмечается применённой, причина понятна',
      () async {
    final broken = [
      Migration(1, 'broken',
          'CREATE TABLE ok_part (id INT); CREATE TABLE bad (id NOPE);'),
    ];
    await expectLater(
      runner.migrate(broken),
      throwsA(isA<MigrationException>()
          .having((e) => e.message, 'message', contains('команда 2 из 2'))),
    );
    final status = await runner.status(broken);
    expect(status.applied, isEmpty);
    expect(status.pending, hasLength(1));
  }, skip: mysqlSkip);

  test('два запуска одновременно — миграция применяется один раз', () async {
    final other = MigrationRunner(testDb.db, Logger(write: log.add));
    final migrations = projectMigrations();
    final results = await Future.wait(
        [runner.migrate(migrations), other.migrate(migrations)]);
    expect(results.map((r) => r.length).toList()..sort(),
        [0, migrations.length]);
    expect((await runner.status(migrations)).isUpToDate, isTrue);
  }, skip: mysqlSkip);
}
