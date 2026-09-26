// Доступ к таблицам «как есть» для экрана просмотра базы.
//
// Править можно только бизнес-таблицы: изменение ставит updated_at и
// edited_by, как в DAO, служебные поля синхронизации не меняются.
// Удаление — мягкое. Служебные таблицы (sync_state, pending_changes) —
// только чтение.

import 'package:drift/drift.dart';

import 'database.dart';
import 'schema_info.dart';

/// Колонка таблицы.
class ColumnInfo {
  final String name;

  /// Тип SQLite: `INTEGER`, `REAL`, `TEXT`.
  final String type;
  final bool notNull;

  /// Поле-дата `гггг-мм-дд`.
  final bool isDate;

  /// Служебное поле синхронизации (не правится вручную).
  final bool isSync;

  const ColumnInfo({
    required this.name,
    required this.type,
    required this.notNull,
    required this.isDate,
    required this.isSync,
  });
}

class RawTables {
  final LocalDatabase db;

  RawTables(this.db);

  Future<List<String>> tableNames() async =>
      (await db
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'table' "
                "AND name NOT LIKE 'sqlite_%' ORDER BY name",
              )
              .get())
          .map((r) => r.read<String>('name'))
          .toList();

  /// Можно ли править строки таблицы.
  bool isEditable(String table) => businessTables.contains(table);

  Future<List<ColumnInfo>> columns(String table) async {
    checkIdentifier(table);
    final dates = dateColumnsOf(table);
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return [
      for (final r in rows)
        ColumnInfo(
          name: r.read<String>('name'),
          type: r.read<String>('type').toUpperCase(),
          notNull: r.read<int>('notnull') == 1,
          isDate: dates.contains(r.read<String>('name')),
          isSync: syncColumns.contains(r.read<String>('name')),
        ),
    ];
  }

  /// Строки таблицы в порядке добавления.
  Future<List<Map<String, Object?>>> rows(
    String table, {
    int limit = 100,
  }) async {
    checkIdentifier(table);
    final result = await db
        .customSelect(
          'SELECT * FROM $table ORDER BY rowid LIMIT ?',
          variables: [Variable<int>(limit)],
        )
        .get();
    return result.map((r) => r.data).toList();
  }

  /// Меняет поля строки [uuid]. Служебные поля и неизвестные колонки —
  /// ошибка. Ставит updated_at и edited_by.
  Future<void> updateRow(
    String table,
    String uuid,
    Map<String, Object?> values,
  ) async {
    _checkEditable(table);
    if (values.isEmpty) return;
    final known = {for (final c in await columns(table)) c.name: c};
    for (final MapEntry(:key, :value) in values.entries) {
      final column = known[key];
      if (column == null) {
        throw ArgumentError('В таблице $table нет колонки $key');
      }
      if (column.isSync) {
        throw ArgumentError('Служебное поле $key не правится вручную');
      }
      if (column.notNull && value == null) {
        throw ArgumentError('Поле $key не может быть пустым');
      }
    }
    await _stampedUpdate(
      table,
      uuid,
      values.keys.map((c) => '$c = ?').join(', '),
      [for (final v in values.values) Variable(v)],
    );
  }

  /// Помечает строку удалённой (или возвращает, [deleted] = false).
  /// Настройки хозяйства не удаляются.
  Future<void> setDeleted(String table, String uuid, bool deleted) async {
    _checkEditable(table);
    if (table == 'company_settings') {
      throw ArgumentError('Настройки хозяйства не удаляются');
    }
    await _stampedUpdate(table, uuid, 'deleted = ?', [Variable<bool>(deleted)]);
  }

  Future<void> _stampedUpdate(
    String table,
    String uuid,
    String sets,
    List<Variable> variables,
  ) async {
    final editor = await db.deviceId();
    final count = await db.customUpdate(
      'UPDATE $table SET $sets, updated_at = ?, edited_by = ? WHERE uuid = ?',
      variables: [
        ...variables,
        Variable<DateTime>(db.nowUtc()),
        Variable<String>(editor),
        Variable<String>(uuid),
      ],
      updates: {
        for (final t in db.allTables)
          if (t.actualTableName == table) t,
      },
      updateKind: UpdateKind.update,
    );
    if (count == 0) throw StateError('Строка $uuid в $table не найдена');
  }

  void _checkEditable(String table) {
    if (!isEditable(table)) {
      throw ArgumentError('Таблица $table только для чтения');
    }
  }
}
