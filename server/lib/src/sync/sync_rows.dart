import 'package:kfh_domain/kfh_domain.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

import '../auth/users.dart';
import '../sql.dart';

/// Чтение и запись бизнес-строк в MySQL в формате обмена ([SyncChange]).
///
/// Имена таблиц и колонок берутся только из описания `syncTables`, не из
/// запроса клиента, — подстановка их в SQL безопасна.
class SyncRows {
  const SyncRows();

  static String _select(SyncTable table) =>
      'SELECT uuid, updated_at, deleted, edited_by, '
      '${table.columnNames.join(', ')} FROM ${table.name}';

  /// Текущая версия записи; [forUpdate] — с блокировкой до конца
  /// транзакции.
  Future<SyncChange?> read(SqlExecutor sql, SyncTable table, String uuid,
      {bool forUpdate = false}) async {
    final r = await sql(
        '${_select(table)} WHERE uuid = :u${forUpdate ? ' FOR UPDATE' : ''}',
        {'u': uuid});
    return r.rows.isEmpty ? null : fromRow(table, r.rows.first);
  }

  /// Несколько записей одной таблицы.
  Future<List<SyncChange>> readMany(
      SqlExecutor sql, SyncTable table, List<String> uuids) async {
    if (uuids.isEmpty) return const [];
    final params = <String, dynamic>{
      for (var i = 0; i < uuids.length; i++) 'u$i': uuids[i],
    };
    final r = await sql(
        '${_select(table)} WHERE uuid IN '
        '(${[for (var i = 0; i < uuids.length; i++) ':u$i'].join(', ')})',
        params);
    return [for (final row in r.rows) fromRow(table, row)];
  }

  static SyncChange fromRow(SyncTable table, ResultSetRow row) => SyncChange(
        table: table.name,
        uuid: row.textOf('uuid'),
        updatedAt: parseSqlDateTime(row.textOf('updated_at')),
        deleted: parseSqlBool(row.text('deleted')),
        editedBy: row.text('edited_by'),
        data: {
          for (final c in table.columns) c.name: _fromSql(c, row.text(c.name)),
        },
      );

  static Object? _fromSql(SyncColumn column, String? value) {
    if (value == null) return null;
    return switch (column.type) {
      SyncType.text || SyncType.uuid || SyncType.date => value,
      SyncType.real => double.parse(value),
      SyncType.integer => int.parse(value),
      SyncType.boolean => value == '1',
    };
  }

  static Object? _toSql(Object? value) => switch (value) {
        bool b => b ? 1 : 0,
        _ => value,
      };

  Map<String, dynamic> _params(SyncChange change, String editedBy) => {
        'uuid': change.uuid,
        'updated_at': sqlDateTime(change.updatedAt),
        'deleted': change.deleted ? 1 : 0,
        'edited_by': editedBy,
        for (final entry in change.data.entries)
          'c_${entry.key}': _toSql(entry.value),
      };

  Future<void> insert(
      SqlExecutor sql, SyncTable table, SyncChange change, String editedBy) {
    final columns = table.columnNames.toList();
    return sql(
        'INSERT INTO ${table.name} (uuid, updated_at, deleted, edited_by, '
        '${columns.join(', ')}) VALUES (:uuid, :updated_at, :deleted, '
        ':edited_by, ${columns.map((c) => ':c_$c').join(', ')})',
        _params(change, editedBy));
  }

  Future<void> update(
      SqlExecutor sql, SyncTable table, SyncChange change, String editedBy) {
    final sets = table.columnNames.map((c) => '$c = :c_$c').join(', ');
    return sql(
        'UPDATE ${table.name} SET updated_at = :updated_at, '
        'deleted = :deleted, edited_by = :edited_by, $sets WHERE uuid = :uuid',
        _params(change, editedBy));
  }
}
