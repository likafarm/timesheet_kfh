@Tags(['mysql'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart' as local;
import 'package:kfh_server/kfh_server.dart';
import 'package:test/test.dart';

import 'support/mysql.dart';

/// Сверка схемы MySQL после миграций со схемой клиента (снимок drift в
/// `packages/local_db/drift_schemas`) и проверка ограничений на данных.
void main() {
  late TestDatabase testDb;

  setUpAll(() async {
    if (!mysqlEnabled) return;
    testDb = await TestDatabase.create();
    await MigrationRunner(testDb.db, Logger(write: (_) {}))
        .migrate(projectMigrations());
  });

  tearDownAll(() async {
    if (mysqlEnabled) await testDb.dispose();
  });

  Future<void> exec(String sql, [Map<String, dynamic>? params]) =>
      testDb.db.execute(sql, params);

  group('совпадение с клиентом', () {
    /// Колонки клиента: имя → (тип drift, nullable).
    Map<String, Map<String, (String, bool)>> clientSchema() {
      final dir = Directory('../packages/local_db/drift_schemas');
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      final json = jsonDecode(files.last.readAsStringSync());
      return {
        for (final e in json['entities'] as List)
          if (e['type'] == 'table')
            e['data']['name'] as String: {
              for (final c in e['data']['columns'] as List)
                c['name'] as String: (
                  c['moor_type'] as String,
                  c['nullable'] as bool
                ),
            },
      };
    }

    Future<Map<String, (String, bool)>> serverColumns(String table) async {
      final result = await testDb.db.execute(
          // information_schema в MySQL 8 отдаёт двоичные строки — драйвер
          // вернул бы байты, поэтому CAST.
          'SELECT CAST(column_name AS CHAR) AS name, '
          'CAST(data_type AS CHAR) AS type, '
          "is_nullable = 'YES' AS nullable, CAST(extra AS CHAR) AS extra "
          'FROM information_schema.columns '
          'WHERE table_schema = DATABASE() AND table_name = :t',
          {'t': table});
      return {
        for (final row in result.rows)
          // Служебный столбец для частичной уникальности — только сервер.
          if (!row.textOf('extra').contains('GENERATED'))
            row.textOf('name'): (
              row.textOf('type'),
              row.text('nullable') == '1'
            ),
      };
    }

    /// Тип MySQL, которым сервер хранит колонку клиента.
    bool typeMatches(String table, String column, String drift, String mysql) {
      if (local.dateColumnsOf(table).contains(column)) return mysql == 'date';
      return switch (drift) {
        'string' => const {'char', 'varchar', 'text'}.contains(mysql),
        'int' => const {'int', 'smallint', 'tinyint', 'bigint'}.contains(mysql),
        'double' => mysql == 'double',
        'bool' => mysql == 'tinyint',
        'dateTime' => mysql == 'datetime',
        _ => false,
      };
    }

    test('описание обмена (kfh_domain) совпадает с MySQL, длины влезают',
        () async {
      for (final table in syncTables) {
        final r = await testDb.db.execute(
            'SELECT CAST(column_name AS CHAR) AS name, '
            'CAST(data_type AS CHAR) AS type, '
            "is_nullable = 'YES' AS nullable, "
            'character_maximum_length AS len, CAST(extra AS CHAR) AS extra '
            'FROM information_schema.columns '
            'WHERE table_schema = DATABASE() AND table_name = :t',
            {'t': table.name});
        final server = {
          for (final row in r.rows)
            if (!row.textOf('extra').contains('GENERATED'))
              row.textOf('name'): row,
        };
        const envelope = {'uuid', 'updated_at', 'deleted', 'edited_by'};
        expect(server.keys.toSet(), {...table.columnNames, ...envelope},
            reason: table.name);
        for (final column in table.columns) {
          final row = server[column.name]!;
          final type = row.textOf('type');
          final where = '${table.name}.${column.name}';
          final ok = switch (column.type) {
            SyncType.text => const {'varchar', 'text', 'char'}.contains(type),
            SyncType.uuid => type == 'char' && row.text('len') == '36',
            SyncType.date => type == 'date',
            SyncType.real => type == 'double',
            SyncType.integer =>
              const {'int', 'smallint', 'tinyint', 'bigint'}.contains(type),
            SyncType.boolean => type == 'tinyint',
          };
          expect(ok, isTrue, reason: '$where: $type');
          expect(row.text('nullable') == '1', column.nullable, reason: where);
          final max = column.maxLength;
          final len = int.tryParse(row.text('len') ?? '');
          if (max != null && len != null) {
            expect(max, lessThanOrEqualTo(len), reason: '$where: длина');
          }
        }
      }
    }, skip: mysqlSkip);

    test('все бизнес-таблицы клиента есть на сервере с теми же полями',
        () async {
      final client = clientSchema();
      expect(client.keys, containsAll(local.businessTables));
      for (final table in local.businessTables) {
        final clientColumns = {...client[table]!}..remove('remote_updated_at');
        final server = await serverColumns(table);
        expect(server.keys.toSet(), clientColumns.keys.toSet(),
            reason: 'состав полей $table');
        for (final MapEntry(key: name, value: (driftType, nullable))
            in clientColumns.entries) {
          final (mysqlType, serverNullable) = server[name]!;
          expect(typeMatches(table, name, driftType, mysqlType), isTrue,
              reason: '$table.$name: drift $driftType, MySQL $mysqlType');
          expect(serverNullable, nullable, reason: '$table.$name: NULL');
        }
      }
    }, skip: mysqlSkip);
  });

  group('ограничения', () {
    const employee = '01900000-0000-7000-8000-000000000001';
    var n = 0;
    String uuid() =>
        '01900000-0000-7000-8000-${(++n).toString().padLeft(12, '0')}';

    setUpAll(() async {
      if (!mysqlEnabled) return;
      await exec(
          'INSERT INTO employees (uuid, updated_at, full_name, position, '
          "hire_date) VALUES (:u, UTC_TIMESTAMP(6), 'Иванов Иван 🌾', "
          "'Тракторист', '2026-01-15')",
          {'u': employee});
    });

    Future<void> day(String date,
            {int deleted = 0, String dayType = 'work', double days = 1}) =>
        exec(
            'INSERT INTO timesheet (uuid, updated_at, deleted, employee_uuid, '
            'date, day_type, days, work_place, created_at) VALUES (:u, '
            "UTC_TIMESTAMP(6), :deleted, :e, :date, :type, :days, 'field', "
            "'2026-09-01T10:00:00')",
            {
              'u': uuid(),
              'deleted': deleted,
              'e': employee,
              'date': date,
              'type': dayType,
              'days': days,
            });

    test('кириллица и эмодзи сохраняются', () async {
      final r = await testDb.db.execute(
          'SELECT full_name FROM employees WHERE uuid = :u', {'u': employee});
      expect(r.rows.single.text('full_name'), 'Иванов Иван 🌾');
    }, skip: mysqlSkip);

    test('день табеля: второй живой — отказ, удалённые не мешают', () async {
      await day('2026-09-01', deleted: 1);
      await day('2026-09-01', deleted: 1);
      await day('2026-09-01');
      await expectLater(day('2026-09-01'), throwsA(anything));
    }, skip: mysqlSkip);

    test('неизвестный сотрудник — отказ внешнего ключа', () async {
      await expectLater(
        exec(
            'INSERT INTO payments (uuid, updated_at, employee_uuid, '
            "payment_date, amount, created_at) VALUES (:u, UTC_TIMESTAMP(6), "
            ":e, '2026-09-10', 1000, 'x')",
            {'u': uuid(), 'e': '01900000-0000-7000-8000-999999999999'}),
        throwsA(anything),
      );
    }, skip: mysqlSkip);

    test('проверки значений табеля', () async {
      await expectLater(day('2026-09-02', dayType: 'holiday'), throwsA(anything));
      await expectLater(day('2026-09-03', days: 2), throwsA(anything));
      await expectLater(
        exec(
            'INSERT INTO timesheet (uuid, updated_at, employee_uuid, date, '
            "work_place, created_at) VALUES (:u, UTC_TIMESTAMP(6), :e, "
            "'2026-09-04', 'office', 'x')",
            {'u': uuid(), 'e': employee}),
        throwsA(anything),
      );
      // Выходной с местом «поле» — так бывает в реальных данных.
      await day('2026-09-05', dayType: 'dayoff');
    }, skip: mysqlSkip);

    test('updated_at хранит микросекунды', () async {
      final u = uuid();
      await exec(
          'INSERT INTO employee_rates (uuid, updated_at, employee_uuid, '
          "base_rate, field_rate, start_date) VALUES (:u, "
          "'2026-09-26 04:54:54.502936', :e, 1000, 1500, '2026-01-01')",
          {'u': u, 'e': employee});
      final r = await testDb.db.execute(
          'SELECT updated_at FROM employee_rates WHERE uuid = :u', {'u': u});
      expect(r.rows.single.text('updated_at'),
          '2026-09-26 04:54:54.502936');
    }, skip: mysqlSkip);

    test('расчёт месяца: один живой на сотрудника и месяц', () async {
      Future<void> payroll({int deleted = 0, int month = 9}) => exec(
          'INSERT INTO payroll_results (uuid, updated_at, deleted, '
          'employee_uuid, year, month, calculated_at) VALUES (:u, '
          "UTC_TIMESTAMP(6), :d, :e, 2026, :m, 'x')",
          {'u': uuid(), 'd': deleted, 'e': employee, 'm': month});
      await payroll(deleted: 1);
      await payroll();
      await expectLater(payroll(), throwsA(anything));
      await expectLater(payroll(month: 13), throwsA(anything));
    }, skip: mysqlSkip);

    test('логин уникален без учёта регистра, роль проверяется', () async {
      Future<void> user(String login, {String role = 'operator'}) => exec(
          'INSERT INTO users (uuid, login, password_hash, role, full_name) '
          "VALUES (:u, :l, 'hash', :r, 'Тест')",
          {'u': uuid(), 'l': login, 'r': role});
      await user('Operator');
      await expectLater(user('operator'), throwsA(anything));
      await expectLater(user('boss', role: 'root'), throwsA(anything));
    }, skip: mysqlSkip);

    test('закрытый месяц — один на год и месяц', () async {
      final admin = uuid();
      await exec(
          'INSERT INTO users (uuid, login, password_hash, role, full_name) '
          "VALUES (:u, 'admin_lock', 'hash', 'admin', 'Админ')",
          {'u': admin});
      Future<void> lock(int month) => exec(
          'INSERT INTO period_locks (year, month, locked_by) '
          'VALUES (2026, :m, :u)',
          {'m': month, 'u': admin});
      await lock(8);
      await expectLater(lock(8), throwsA(anything));
      await expectLater(lock(0), throwsA(anything));
    }, skip: mysqlSkip);
  });
}
