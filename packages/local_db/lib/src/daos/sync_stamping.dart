import 'package:drift/drift.dart';
import 'package:kfh_domain/kfh_domain.dart' show DuplicateEntryException;

import '../database.dart';

/// Строит строку для записи: [now] и [editor] — отметка изменения,
/// [isNew] — запись добавляется (а не меняется).
typedef StampedRow<D> =
    Insertable<D> Function(DateTime now, String editor, bool isNew);

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

  /// Добавляет запись [uuid] или меняет существующую. Удалённую запись
  /// так не вернуть — [StateError]. Повтор уникального значения (название
  /// и т. п.) — [DuplicateEntryException].
  Future<void> saveRow<T extends Table, D>(
    TableInfo<T, D> table,
    String uuid,
    StampedRow<D> build,
  ) async {
    final editor = await db.deviceId();
    await _unique(
      () => transaction(() async {
        final existing = await customSelect(
          'SELECT deleted FROM ${table.actualTableName} WHERE uuid = ?',
          variables: [Variable<String>(uuid)],
          readsFrom: {table},
        ).getSingleOrNull();
        final now = db.nowUtc();
        if (existing == null) {
          await into(table).insert(build(now, editor, true));
          return;
        }
        if (existing.read<bool>('deleted')) {
          throw StateError('Запись удалена: $uuid');
        }
        final row = build(now, editor, false);
        await (update(table)..whereSamePrimaryKey(row)).write(row);
      }),
    );
  }

  /// Нарушение уникального индекса → [DuplicateEntryException]. Текст
  /// ошибки SQLite одинаков на всех платформах (в браузере — внутри
  /// ошибки drift).
  Future<R> _unique<R>(Future<R> Function() action) async {
    try {
      return await action();
    } catch (e) {
      if ('$e'.contains('UNIQUE constraint failed')) {
        throw const DuplicateEntryException('Такая запись уже есть');
      }
      rethrow;
    }
  }

  /// Запись [uuid] есть в таблице (даже удалённая).
  Future<bool> exists(TableInfo table, String uuid) async =>
      await customSelect(
        'SELECT 1 FROM ${table.actualTableName} WHERE uuid = ?',
        variables: [Variable<String>(uuid)],
        readsFrom: {table},
      ).getSingleOrNull() !=
      null;
}
