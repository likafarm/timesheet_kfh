import 'package:drift/drift.dart';

import '../database.dart';

/// Общие операции DAO над бизнес-таблицами со служебными полями
/// синхронизации (`uuid`, `updated_at`, `deleted`, `edited_by`).
mixin SyncStamping on DatabaseAccessor<LocalDatabase> {
  /// Мягкое удаление: `deleted = 1` и отметка изменения.
  /// Возвращает число изменённых строк (0 — записи нет или уже удалена).
  Future<int> softDeleteRow(TableInfo table, String uuid) async {
    final editor = await db.deviceId();
    return customUpdate(
      'UPDATE ${table.actualTableName} '
      'SET deleted = 1, updated_at = ?, edited_by = ? '
      'WHERE uuid = ? AND deleted = 0',
      variables: [
        Variable<DateTime>(db.nowUtc()),
        Variable<String>(editor),
        Variable<String>(uuid),
      ],
      updates: {table},
      updateKind: UpdateKind.update,
    );
  }
}
