// Модуль «Резервные копии»: снимок текущей базы и применение плана возврата
// записей (`planRestore` в kfh_domain).
//
// Возврат — обычные правки: запись получает новое `updated_at` и id этого
// устройства, поэтому становится «не отправленной» и уходит на сервер
// синхронизацией, как любая правка человека.

import 'package:drift/drift.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../backup_format.dart';
import '../database.dart';
import '../schema_info.dart';
import 'sync_export_builder.dart';

/// Все записи базы (и удалённые) в виде снимка.
Future<DataSnapshot> readSnapshot(LocalDatabase db) async =>
    DataSnapshot(await readAllSyncRows(db));

/// Применяет план возврата к открытой базе.
class SnapshotRestorer {
  final LocalDatabase db;

  SnapshotRestorer(this.db);

  /// Применяет [edits] одной транзакцией в заданном порядке; возвращает
  /// число изменённых записей.
  ///
  /// Если запись с момента построения плана изменилась (например, пришла
  /// правка с сервера), ничего не записывается — [RestoreException]: план
  /// нужно построить заново.
  Future<int> apply(List<RestoreEdit> edits) async {
    if (edits.isEmpty) return 0;
    await db.transaction(() async {
      final exists = <RestoreEdit, bool>{};
      for (final edit in edits) {
        final table = _table(edit.table);
        final row = await db
            .customSelect(
              'SELECT * FROM ${table.name} WHERE uuid = ?',
              variables: [Variable<String>(edit.uuid)],
            )
            .getSingleOrNull();
        final current = row == null
            ? null
            : syncChangeFromLocalRow(table, row.data);
        if (current?.updatedAt != edit.current?.updatedAt ||
            current?.deleted != edit.current?.deleted) {
          throw const RestoreException(
            'Данные изменились, пока готовился возврат, — откройте '
            'сравнение с копией заново',
          );
        }
        exists[edit] = row != null;
      }

      // Записи с уникальным ключом (день табеля) сначала снимаются: в
      // середине транзакции два живых дня одного сотрудника недопустимы,
      // а возвращаемые записи могут меняться днями между собой.
      for (final edit in edits) {
        if (exists[edit]! && uniqueKeys.containsKey(edit.table)) {
          await db.customUpdate(
            'UPDATE ${edit.table} SET deleted = 1 WHERE uuid = ?',
            variables: [Variable<String>(edit.uuid)],
          );
        }
      }

      final editor = await db.deviceId();
      final now = db.nowUtc();
      for (final edit in edits) {
        await _write(edit, exists: exists[edit]!, now: now, editor: editor);
      }
    });
    return edits.length;
  }

  Future<void> _write(
    RestoreEdit edit, {
    required bool exists,
    required DateTime now,
    required String editor,
  }) async {
    final table = _table(edit.table);
    final values = <String, Variable>{
      for (final c in table.columns) c.name: Variable(edit.data[c.name]),
      'deleted': Variable<bool>(edit.deleted),
      'updated_at': Variable<DateTime>(now),
      'edited_by': Variable<String>(editor),
    };
    final info = {
      for (final t in db.allTables)
        if (t.actualTableName == table.name) t,
    };
    if (exists) {
      await db.customUpdate(
        'UPDATE ${table.name} SET '
        '${values.keys.map((c) => '$c = ?').join(', ')} WHERE uuid = ?',
        variables: [...values.values, Variable<String>(edit.uuid)],
        updates: info,
        updateKind: UpdateKind.update,
      );
    } else {
      await db.customInsert(
        'INSERT INTO ${table.name} (uuid, ${values.keys.join(', ')}) '
        'VALUES (?, ${List.filled(values.length, '?').join(', ')})',
        variables: [Variable<String>(edit.uuid), ...values.values],
        updates: info,
      );
    }
  }

  static SyncTable _table(String name) {
    final table = syncTableByName(name);
    if (table == null || !restorableTables.contains(name)) {
      throw RestoreException('Таблица $name не возвращается из копии');
    }
    return table;
  }
}
