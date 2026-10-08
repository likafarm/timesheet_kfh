// Миграции drift на снимках схем (drift_schemas/, test/generated_migrations/
// — `drift_dev schema generate`). Каждая новая версия схемы — новый тест
// «N → N+1» здесь.

import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/native.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:test/test.dart';

import 'generated_migrations/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('версия схемы LocalDatabase — последняя из снимков', () {
    expect(GeneratedHelper.versions.last, currentSchemaVersion);
    expect(LocalDatabase.memory().schemaVersion, currentSchemaVersion);
  });

  test('1 → 2: схема совпадает со свежей схемой 2', () async {
    final connection = await verifier.startAt(1);
    final db = LocalDatabase(connection);
    await verifier.migrateAndValidate(db, 2);
    await db.close();
  });

  test('1 → 2: данные табеля на месте, финансы работают', () async {
    final schema = await verifier.schemaAt(1);
    final raw = schema.rawDatabase;
    const now = '2026-09-26T10:00:00.000Z';
    raw.execute(
      "INSERT INTO sync_state (key, value) VALUES ('device_id', 'dev-1')",
    );
    raw.execute(
      'INSERT INTO company_settings (uuid, updated_at, deleted) '
      "VALUES ('00000000-0000-0000-0000-000000000001', '$now', 0)",
    );
    raw.execute(
      'INSERT INTO employees (uuid, full_name, position, hire_date, '
      'base_rate, field_rate, updated_at, deleted) '
      "VALUES ('e1', 'Иванов Иван', 'Механизатор', '2025-01-01', 2000, "
      "3000, '$now', 0)",
    );
    raw.execute(
      'INSERT INTO timesheet (uuid, employee_uuid, date, day_type, days, '
      'work_place, created_at, updated_at, deleted) '
      "VALUES ('t1', 'e1', '2026-09-01', 'work', 1, 'field', '$now', "
      "'$now', 0)",
    );
    raw.execute(
      'INSERT INTO payments (uuid, employee_uuid, payment_date, amount, '
      'payment_method, created_at, updated_at, deleted) '
      "VALUES ('p1', 'e1', '2026-09-30', 17000.5, 'cash', '$now', '$now', 0)",
    );

    final db = LocalDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);

    final repos = DriftRepositories(db);
    expect(await db.deviceId(), 'dev-1', reason: 'id устройства сохранён');
    final employees = await repos.employees.all();
    expect(employees.single.fullName, 'Иванов Иван');
    expect((await repos.payments.list()).single.amount, 17000.5);
    expect(await repos.timesheet.on('e1', DateTime(2026, 9, 1)), isNotNull);

    for (final check in ['integrity_check', 'foreign_key_check']) {
      final rows = await db.customSelect('PRAGMA $check').get();
      if (check == 'integrity_check') {
        expect(rows.single.data.values.single, 'ok');
      } else {
        expect(rows, isEmpty);
      }
    }

    await repos.finance.saveAccount(
      const FinAccount(id: 'a1', name: 'Касса', kind: AccountKind.cash),
    );
    expect((await repos.finance.accounts()).single.name, 'Касса');
    await db.close();
  });

  test('2 → 3: схема совпадает со свежей схемой 3', () async {
    final connection = await verifier.startAt(2);
    final db = LocalDatabase(connection);
    await verifier.migrateAndValidate(db, 3);
    await db.close();
  });

  test('2 → 3: данные на месте, корректировки работают', () async {
    final schema = await verifier.schemaAt(2);
    final raw = schema.rawDatabase;
    const now = '2026-10-08T10:00:00.000Z';
    raw.execute(
      "INSERT INTO sync_state (key, value) VALUES ('device_id', 'dev-1')",
    );
    raw.execute(
      'INSERT INTO company_settings (uuid, updated_at, deleted) '
      "VALUES ('00000000-0000-0000-0000-000000000001', '$now', 0)",
    );
    raw.execute(
      'INSERT INTO employees (uuid, full_name, position, hire_date, '
      'base_rate, field_rate, updated_at, deleted) '
      "VALUES ('e1', 'Иванов Иван', 'Механизатор', '2025-01-01', 2000, "
      "3000, '$now', 0)",
    );
    raw.execute(
      'INSERT INTO fin_accounts (uuid, name, kind, opening_balance, closed, '
      "sort_order, updated_at, deleted) VALUES ('a1', 'Касса', 'cash', 0, 0, "
      "0, '$now', 0)",
    );

    final db = LocalDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 3);
    final repos = DriftRepositories(db);
    expect(await db.deviceId(), 'dev-1');
    expect((await repos.employees.all()).single.fullName, 'Иванов Иван');
    expect((await repos.finance.accounts()).single.name, 'Касса');

    await repos.adjustments.save(
      const PayrollAdjustment(
        employeeId: 'e1',
        year: 2025,
        month: 3,
        amount: 13000,
        notes: 'надбавка',
      ),
    );
    final calc = await repos.payrollService.calculateMonth('e1', 2025, 3);
    expect(calc.totalSalary, 13000);
    final fk = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(fk, isEmpty);
    await db.close();
  });

  test('3 → 4: схема совпадает со свежей схемой 4', () async {
    final connection = await verifier.startAt(3);
    final db = LocalDatabase(connection);
    await verifier.migrateAndValidate(db, 4);
    await db.close();
  });

  test('3 → 4: статьи на месте, группа — по названию, затем ссылкой', () async {
    final schema = await verifier.schemaAt(3);
    final raw = schema.rawDatabase;
    const now = '2026-10-08T10:00:00.000Z';
    raw.execute(
      "INSERT INTO sync_state (key, value) VALUES ('device_id', 'dev-1')",
    );
    raw.execute(
      'INSERT INTO company_settings (uuid, updated_at, deleted) '
      "VALUES ('00000000-0000-0000-0000-000000000001', '$now', 0)",
    );
    raw.execute(
      'INSERT INTO fin_categories (uuid, type, group_name, name, kind, '
      'in_tax_book, hidden, sort_order, updated_at, deleted) '
      "VALUES ('c1', 'expense', '01. Скот', 'Коровы', 'current', 1, 0, 0, "
      "'$now', 0)",
    );

    final db = LocalDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 4);
    final f = DriftRepositories(db).finance;
    final before = (await f.categories()).single;
    expect(before.groupId, isNull);
    expect(before.group, '01. Скот');

    // Группа с тем же названием — статья находит её по названию.
    const cattle = FinCategoryGroup(
      id: 'g1',
      type: CategoryType.expense,
      name: '01. Скот',
    );
    await f.saveCategoryGroup(cattle);
    final catalog = FinanceCatalog(
      categories: await f.categories(),
      groups: await f.categoryGroups(),
    );
    expect(catalog.groupOf(catalog.categories['c1']!)?.id, 'g1');

    // Переименование — копия названия и ссылка у статьи.
    await f.saveCategoryGroup(
      const FinCategoryGroup(
        id: 'g1',
        type: CategoryType.expense,
        name: '01. Скот и молодняк',
      ),
    );
    final after = (await f.categories()).single;
    expect(after.groupId, 'g1');
    expect(after.group, '01. Скот и молодняк');
    final fk = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(fk, isEmpty);
    await db.close();
  });

  test('4 → 5: схема совпадает со свежей схемой 5', () async {
    final connection = await verifier.startAt(4);
    final db = LocalDatabase(connection);
    await verifier.migrateAndValidate(db, 5);
    await db.close();
  });

  test('4 → 5: данные на месте, платёжный календарь работает', () async {
    final schema = await verifier.schemaAt(4);
    final raw = schema.rawDatabase;
    const now = '2026-10-08T10:00:00.000Z';
    raw.execute(
      "INSERT INTO sync_state (key, value) VALUES ('device_id', 'dev-1')",
    );
    raw.execute(
      'INSERT INTO company_settings (uuid, updated_at, deleted) '
      "VALUES ('00000000-0000-0000-0000-000000000001', '$now', 0)",
    );
    raw.execute(
      'INSERT INTO fin_accounts (uuid, name, kind, opening_balance, closed, '
      "sort_order, updated_at, deleted) VALUES ('a1', 'Касса', 'cash', 500, "
      "0, 0, '$now', 0)",
    );

    final db = LocalDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 5);
    final f = DriftRepositories(db).finance;
    expect((await f.accounts()).single.openingBalance, 500);

    final plan = FinPlan(
      id: 'p1',
      type: OperationType.expense,
      amount: 1000000,
      startDate: DateTime(2026, 1, 31),
      repeat: PlanRepeat.monthly,
      accountId: 'a1',
      description: 'Аренда земли',
      skipped: {DateTime(2026, 3, 31), DateTime(2026, 2, 28)},
    );
    await f.savePlan(plan);
    final saved = (await f.plans()).single;
    expect(saved.repeat, PlanRepeat.monthly);
    expect(saved.startDate, DateTime(2026, 1, 31));
    expect(saved.skipped, {DateTime(2026, 2, 28), DateTime(2026, 3, 31)});
    expect(saved.accountId, 'a1');
    await f.deletePlan('p1');
    expect(await f.plans(), isEmpty);
    final fk = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(fk, isEmpty);
    await db.close();
  });

  group('копия перед обновлением схемы', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('kfh_upgrade_'));
    tearDown(() => dir.deleteSync(recursive: true));

    String fileAt(int version, [String name = 'base']) {
      final path = '${dir.path}${Platform.pathSeparator}$name.db';
      final db = sql.sqlite3.open(path);
      db.execute('CREATE TABLE t (x INTEGER)');
      db.execute('INSERT INTO t VALUES (42)');
      db.execute('PRAGMA user_version = $version');
      db.close();
      return path;
    }

    List<String> copies() => [
      for (final f in dir.listSync().whereType<File>())
        if (f.uri.pathSegments.last.startsWith(upgradeBackupPrefix))
          f.uri.pathSegments.last,
    ]..sort();

    test('схема старше — копия с данными, файл не тронут', () {
      final path = fileAt(1);
      final copy = backupBeforeUpgrade(
        path,
        targetVersion: 2,
        clock: () => DateTime(2026, 10, 8, 9, 5, 7),
      )!;
      expect(copies(), ['backup_before_migration_v2_20261008-090507.db']);
      final c = sql.sqlite3.open(copy, mode: sql.OpenMode.readOnly);
      expect(c.select('SELECT x FROM t').single['x'], 42);
      expect(c.select('PRAGMA user_version').single.values.single, 1);
      c.close();
      expect(databaseFileVersion(path), 1);
    });

    test('схема та же, новее, файла нет или пустой — без копии', () {
      expect(backupBeforeUpgrade(fileAt(2, 'same'), targetVersion: 2), isNull);
      expect(backupBeforeUpgrade(fileAt(3, 'newer'), targetVersion: 2), isNull);
      expect(backupBeforeUpgrade(fileAt(0, 'empty'), targetVersion: 2), isNull);
      expect(
        backupBeforeUpgrade('${dir.path}/нет.db', targetVersion: 2),
        isNull,
      );
      expect(copies(), isEmpty);
    });

    test('хранятся три последние копии', () {
      final path = fileAt(1);
      for (var minute = 0; minute < 5; minute++) {
        backupBeforeUpgrade(
          path,
          targetVersion: 2,
          clock: () => DateTime(2026, 10, 8, 9, minute),
        );
      }
      expect(copies(), [
        'backup_before_migration_v2_20261008-090200.db',
        'backup_before_migration_v2_20261008-090300.db',
        'backup_before_migration_v2_20261008-090400.db',
      ]);
    });

    test('файл схемы 1 открывается программой и обновляется до 2', () async {
      final path = '${dir.path}${Platform.pathSeparator}v1.db';
      final schema = await verifier.schemaAt(1);
      schema.rawDatabase.execute('VACUUM INTO ?', [path]);
      expect(backupBeforeUpgrade(path), isNotNull);
      final db = openLocalDatabaseFile(File(path));
      await db.deviceId();
      await db.close();
      expect(databaseFileVersion(path), currentSchemaVersion);
    });
  });
}
