import '../auth/users.dart';
import '../sql.dart';

/// Журнал изменений `change_log` — курсор pull-синхронизации.
///
/// Любая транзакция, которая пишет в журнал, сначала вызывает [lock]:
/// записи идут строго по очереди, порядок seq совпадает с порядком
/// фиксации (см. миграцию 0002).
class ChangeLog {
  const ChangeLog();

  /// Блокировка очереди записи до конца транзакции; возвращает эпоху.
  Future<String> lock(SqlExecutor sql) async {
    final r = await sql('SELECT epoch FROM sync_serial WHERE id = 1 FOR UPDATE');
    return r.rows.single.textOf('epoch');
  }

  Future<String> epoch(SqlExecutor sql) async {
    final r = await sql('SELECT epoch FROM sync_serial WHERE id = 1');
    return r.rows.single.textOf('epoch');
  }

  Future<int> append(SqlExecutor sql, String table, String uuid,
      {required bool deleted}) async {
    final r = await sql(
        'INSERT INTO change_log (table_name, entity_uuid, operation) '
        'VALUES (:t, :u, :o)',
        {'t': table, 'u': uuid, 'o': deleted ? 'delete' : 'upsert'});
    return r.lastInsertID.toInt();
  }

  Future<int> maxSeq(SqlExecutor sql) async {
    final r = await sql('SELECT COALESCE(MAX(seq), 0) AS m FROM change_log');
    return r.rows.single.intOf('m');
  }

  /// Записи журнала после [cursor], по возрастанию seq.
  Future<List<({int seq, String table, String uuid})>> after(
      SqlExecutor sql, int cursor, int limit) async {
    final r = await sql(
        'SELECT seq, table_name, entity_uuid FROM change_log '
        'WHERE seq > :c ORDER BY seq LIMIT $limit',
        {'c': cursor});
    return [
      for (final row in r.rows)
        (
          seq: row.intOf('seq'),
          table: row.textOf('table_name'),
          uuid: row.textOf('entity_uuid'),
        ),
    ];
  }
}
