import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:test/test.dart';

/// Описание обмена (`syncTables` в kfh_domain) должно совпадать с
/// локальной схемой: иначе клиент будет слать поля, которых нет, или
/// терять поля при синхронизации.
void main() {
  late LocalDatabase db;

  setUp(() => db = LocalDatabase.memory());
  tearDown(() => db.close());

  /// Служебные поля синхронизации, которые передаются вне `data`.
  const envelope = {'uuid', 'updated_at', 'deleted', 'edited_by'};

  test('таблицы обмена = бизнес-таблицы клиента', () {
    expect(syncTables.map((t) => t.name).toSet(), businessTables.toSet());
    expect(syncTables.map((t) => t.name).where((n) => n != 'company_settings'),
        employeeTablesOrder);
  });

  test('состав полей, типы и NULL совпадают со схемой drift', () async {
    for (final table in syncTables) {
      final info = await db
          .customSelect('PRAGMA table_info(${table.name})')
          .get();
      final local = {
        for (final row in info)
          row.read<String>('name'): (
            row.read<String>('type'),
            row.read<int>('notnull') == 0,
          ),
      };
      // remote_updated_at — только у клиента.
      final expected = {...table.columnNames, ...envelope, 'remote_updated_at'};
      expect(local.keys.toSet(), expected, reason: table.name);

      for (final column in table.columns) {
        final (sqlType, nullable) = local[column.name]!;
        final wanted = switch (column.type) {
          SyncType.text || SyncType.uuid || SyncType.date => 'TEXT',
          SyncType.real => 'REAL',
          SyncType.integer || SyncType.boolean => 'INTEGER',
        };
        expect(sqlType, wanted, reason: '${table.name}.${column.name}');
        expect(nullable, column.nullable,
            reason: '${table.name}.${column.name}: NULL');
      }
      final dates = table.columns
          .where((c) => c.type == SyncType.date)
          .map((c) => c.name)
          .toList();
      expect(dates, dateColumnsOf(table.name), reason: '${table.name}: даты');
    }
  });
}
