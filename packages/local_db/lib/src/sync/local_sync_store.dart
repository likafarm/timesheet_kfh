import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:kfh_domain/kfh_domain.dart';

import '../database.dart';
import '../schema_info.dart';
import 'sync_export_builder.dart';

/// Ключи курсора pull в `sync_state`.
const syncCursorKey = 'sync_cursor';
const syncEpochKey = 'sync_epoch';

/// Место в журнале изменений сервера: номер и эпоха (после восстановления
/// сервера из копии эпоха меняется, и курсор теряет смысл).
class SyncCursor {
  final int seq;
  final String? epoch;

  const SyncCursor(this.seq, this.epoch);

  static const start = SyncCursor(0, null);

  @override
  bool operator ==(Object other) =>
      other is SyncCursor && other.seq == seq && other.epoch == epoch;

  @override
  int get hashCode => Object.hash(seq, epoch);

  @override
  String toString() => 'SyncCursor($seq, $epoch)';
}

/// Неотправленная локальная запись.
///
/// [rawUpdatedAt] — `updated_at` как он записан в базе: отметка «отправлено»
/// ставится, только если запись с тех пор не менялась.
class PendingChange {
  final SyncChange change;
  final String rawUpdatedAt;

  PendingChange(this.change, this.rawUpdatedAt);

  String get table => change.table;
  String get uuid => change.uuid;
}

/// Изменение, которое сервер не принял. Хранится в `pending_changes`, пока
/// запись не изменят снова (или пока её не отправят успешно).
class RejectedChange {
  final String table;
  final String uuid;
  final bool deleted;
  final String code;
  final String message;
  final int attempts;
  final DateTime since;

  RejectedChange({
    required this.table,
    required this.uuid,
    required this.deleted,
    required this.code,
    required this.message,
    required this.attempts,
    required this.since,
  });
}

/// Почему пропала неотправленная локальная правка.
enum LostReason {
  /// На сервере версия новее (или того же времени) — победила она.
  overwritten,

  /// Сервер уже принял другую запись с тем же уникальным ключом (день
  /// табеля, месяц расчёта) — побеждает пришедшая на сервер первой.
  uniqueKey,
}

/// Локальная правка, уступившая серверу, — для журнала конфликтов.
class LostChange {
  final LostReason reason;

  /// Версия записи на этом устройстве, которая пропала.
  final SyncChange local;

  /// Серверная запись, которая победила.
  final SyncChange remote;

  LostChange(this.reason, this.local, this.remote);
}

/// Итог применения пачки изменений с сервера.
class ApplyReport {
  /// Записано в базу.
  int applied = 0;

  /// Пропущено: на устройстве неотправленная правка новее серверной.
  int keptLocal = 0;

  final List<LostChange> lost = [];

  /// Локальная база могла разойтись с сервером (у записи, уступившей по
  /// уникальному ключу, на сервере есть своя версия) — нужен pull с нуля.
  bool needsResync = false;
}

/// Хранилище синхронизации поверх локальной базы: что отправить, отметки
/// об отправке, применение изменений с сервера, курсор.
///
/// Запись не отправлена, если её `updated_at` не совпадает с
/// `remote_updated_at` (версией, известной серверу). Любая локальная правка
/// ставит новый `updated_at` — поэтому очередь не нужно вести в каждом
/// месте записи. Изменения с сервера пишутся с `remote_updated_at =
/// updated_at` и в очередь не попадают.
class LocalSyncStore {
  final LocalDatabase db;

  LocalSyncStore(this.db);

  static const _dirty =
      'remote_updated_at IS NULL OR remote_updated_at <> updated_at';

  // ----------------------------------------------------------- отправка

  /// Неотправленные записи: сначала сотрудники, потом ссылающиеся на них,
  /// внутри таблицы — по времени правки. Отклонённые сервером (и с тех пор
  /// не менявшиеся) — только при [includeRejected].
  Future<List<PendingChange>> pendingChanges({
    int limit = 500,
    bool includeRejected = false,
  }) async {
    final rejected = includeRejected
        ? const <String, String>{}
        : await _rejectedVersions();
    final result = <PendingChange>[];
    for (final table in syncTables) {
      final rows = await db
          .customSelect(
            'SELECT * FROM ${table.name} WHERE $_dirty '
            'ORDER BY updated_at, uuid',
          )
          .get();
      for (final row in rows) {
        final raw = row.data['updated_at'] as String;
        if (rejected[row.data['uuid']] == raw) continue;
        final change = syncChangeFromLocalRow(table, row.data);
        result.add(
          PendingChange(
            SyncChange(
              table: change.table,
              uuid: change.uuid,
              updatedAt: change.updatedAt,
              deleted: change.deleted,
              data: change.data,
              editedBy: change.editedBy,
              changeId: change.uuid,
            ),
            raw,
          ),
        );
        if (result.length >= limit) return result;
      }
    }
    return result;
  }

  /// Число неотправленных записей (вместе с отклонёнными).
  Future<int> pendingCount() async {
    final union = syncTables
        .map((t) => 'SELECT COUNT(*) AS n FROM ${t.name} WHERE $_dirty')
        .join(' UNION ALL ');
    final row = await db
        .customSelect('SELECT SUM(n) AS total FROM ($union)')
        .getSingle();
    return row.read<int>('total');
  }

  /// Сервер принял запись (или она у него уже была). Если запись успели
  /// снова изменить, она останется неотправленной.
  Future<void> markPushed(PendingChange change) => db.transaction(() async {
    await _setSynced(change);
    await _dropRejection(change.table, change.uuid);
  });

  /// Сервер отклонил запись: она остаётся неотправленной, но повторно не
  /// уходит, пока её не изменят или не вызовут [clearRejections].
  Future<void> markRejected(
    PendingChange change,
    String code,
    String message,
  ) => db.transaction(() async {
    final existing = await _rejectionRow(change.table, change.uuid);
    final attempts = (existing?.read<int>('attempts') ?? 0) + 1;
    final payload = jsonEncode({
      'code': code,
      'updated_at_raw': change.rawUpdatedAt,
      'change': change.change.toJson(),
    });
    if (existing == null) {
      await db.customInsert(
        'INSERT INTO pending_changes (entity_table, entity_uuid, '
        'operation, payload, created_at, attempts, last_error) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable<String>(change.table),
          Variable<String>(change.uuid),
          Variable<String>(change.change.deleted ? 'delete' : 'upsert'),
          Variable<String>(payload),
          Variable<DateTime>(db.nowUtc()),
          Variable<int>(attempts),
          Variable<String>(message),
        ],
        updates: {db.pendingChanges},
      );
    } else {
      await db.customUpdate(
        'UPDATE pending_changes SET operation = ?, payload = ?, '
        'attempts = ?, last_error = ? WHERE id = ?',
        variables: [
          Variable<String>(change.change.deleted ? 'delete' : 'upsert'),
          Variable<String>(payload),
          Variable<int>(attempts),
          Variable<String>(message),
          Variable<int>(existing.read<int>('id')),
        ],
        updates: {db.pendingChanges},
        updateKind: UpdateKind.update,
      );
    }
  });

  /// Отклонённые изменения, которые всё ещё не отправлены (записи с тех пор
  /// не менялись). Устаревшие отметки удаляются.
  Future<List<RejectedChange>> rejectedChanges() async {
    final result = <RejectedChange>[];
    final rows = await db
        .customSelect('SELECT * FROM pending_changes ORDER BY id')
        .get();
    for (final row in rows) {
      final table = row.read<String>('entity_table');
      final uuid = row.read<String>('entity_uuid');
      final payload = _payload(row);
      final current = syncTableByName(table) == null
          ? null
          : await db
                .customSelect(
                  'SELECT updated_at FROM $table WHERE uuid = ? AND ($_dirty)',
                  variables: [Variable<String>(uuid)],
                )
                .getSingleOrNull();
      if (current == null ||
          current.read<String>('updated_at') != payload['updated_at_raw']) {
        await _dropRejection(table, uuid);
        continue;
      }
      result.add(
        RejectedChange(
          table: table,
          uuid: uuid,
          deleted: row.read<String>('operation') == 'delete',
          code: payload['code'] as String? ?? '',
          message: row.readNullable<String>('last_error') ?? '',
          attempts: row.read<int>('attempts'),
          since: row.read<DateTime>('created_at'),
        ),
      );
    }
    return result;
  }

  /// Отправить отклонённые изменения ещё раз (например, после открытия
  /// месяца).
  Future<void> clearRejections() => db.customUpdate(
    'DELETE FROM pending_changes',
    updates: {db.pendingChanges},
    updateKind: UpdateKind.delete,
  );

  /// Отказаться от локальной записи, уступившей серверной по уникальному
  /// ключу: она мягко удаляется и в очередь не попадает. Если у записи есть
  /// версия на сервере, возвращает true — нужен pull с нуля, чтобы её
  /// вернуть.
  Future<bool> discardLocal(PendingChange change) => db.transaction(() async {
    final row = await _row(change.table, change.uuid);
    if (row == null || row['updated_at'] != change.rawUpdatedAt) {
      return false; // запись изменили — пусть уйдёт новой версией
    }
    await _markDeletedSynced(change.table, change.uuid);
    await _dropRejection(change.table, change.uuid);
    return row['remote_updated_at'] != null;
  });

  // ----------------------------------------------------------- приём

  /// Записывает изменения с сервера (last-write-wins):
  /// - запись без неотправленных правок принимает серверную версию;
  /// - неотправленная правка новее серверной остаётся (уйдёт при push);
  /// - неотправленная правка старше (или того же времени) уступает и
  ///   попадает в [ApplyReport.lost];
  /// - живая локальная запись с тем же уникальным ключом, что у пришедшей,
  ///   мягко удаляется без постановки в очередь (серверная пришла раньше).
  Future<ApplyReport> applyRemote(List<SyncChange> changes) =>
      db.transaction(() async {
        final report = ApplyReport();
        for (final change in changes) {
          await _applyOne(change, report);
        }
        return report;
      });

  Future<void> _applyOne(SyncChange change, ApplyReport report) async {
    final table = syncTableByName(change.table);
    if (table == null) {
      throw SyncFormatException('неизвестная таблица: ${change.table}');
    }
    final local = await _row(table.name, change.uuid);
    if (local != null && _isDirty(local)) {
      final mine = syncChangeFromLocalRow(table, local);
      if (mine.updatedAt.isAfter(change.updatedAt)) {
        report.keptLocal++;
        return;
      }
      if (!_same(mine, change)) {
        report.lost.add(LostChange(LostReason.overwritten, mine, change));
      }
    }
    if (!change.deleted) {
      await _freeUniqueKey(table, change, report);
    }
    await _write(table, change, exists: local != null);
    report.applied++;
  }

  Future<void> _freeUniqueKey(
    SyncTable table,
    SyncChange change,
    ApplyReport report,
  ) async {
    final key = uniqueKeys[table.name];
    if (key == null) return;
    final rows = await db
        .customSelect(
          'SELECT * FROM ${table.name} WHERE deleted = 0 AND uuid <> ? AND '
          '${key.map((c) => '$c = ?').join(' AND ')}',
          variables: [
            Variable<String>(change.uuid),
            for (final c in key) Variable(change.data[c]),
          ],
        )
        .get();
    for (final row in rows) {
      final other = row.data;
      if (_isDirty(other)) {
        report.lost.add(
          LostChange(
            LostReason.uniqueKey,
            syncChangeFromLocalRow(table, other),
            change,
          ),
        );
        // Своя версия этой записи на сервере придёт позже или уже пришла
        // (и уступила неотправленной правке) — надёжнее принять всё заново.
        if (other['remote_updated_at'] != null) report.needsResync = true;
      }
      // Для синхронизированной записи сервер пришлёт её удаление (или смену
      // ключа) в этой же выдаче: у сервера тоже не бывает двух живых записей
      // с одним ключом.
      await _markDeletedSynced(table.name, other['uuid'] as String);
    }
  }

  Future<void> _write(
    SyncTable table,
    SyncChange change, {
    required bool exists,
  }) async {
    final values = <String, Variable>{
      for (final c in table.columns) c.name: Variable(change.data[c.name]),
      'updated_at': Variable<DateTime>(change.updatedAt),
      'remote_updated_at': Variable<DateTime>(change.updatedAt),
      'deleted': Variable<bool>(change.deleted),
      'edited_by': Variable<String>(change.editedBy),
    };
    final info = _tableInfo(table.name);
    if (exists) {
      await db.customUpdate(
        'UPDATE ${table.name} SET '
        '${values.keys.map((c) => '$c = ?').join(', ')} WHERE uuid = ?',
        variables: [...values.values, Variable<String>(change.uuid)],
        updates: {info},
        updateKind: UpdateKind.update,
      );
    } else {
      await db.customInsert(
        'INSERT INTO ${table.name} (uuid, ${values.keys.join(', ')}) '
        'VALUES (?, ${List.filled(values.length, '?').join(', ')})',
        variables: [Variable<String>(change.uuid), ...values.values],
        updates: {info},
      );
    }
  }

  // ----------------------------------------------------------- курсор

  Future<SyncCursor> cursor() async {
    final seq = await db.syncStateDao.getValue(syncCursorKey);
    final epoch = await db.syncStateDao.getValue(syncEpochKey);
    return SyncCursor(int.tryParse(seq ?? '') ?? 0, epoch);
  }

  Future<void> saveCursor(SyncCursor cursor) => db.transaction(() async {
    await db.syncStateDao.setValue(syncCursorKey, '${cursor.seq}');
    if (cursor.epoch == null) {
      await db.customUpdate(
        'DELETE FROM sync_state WHERE key = ?',
        variables: [Variable<String>(syncEpochKey)],
        updates: {db.syncState},
        updateKind: UpdateKind.delete,
      );
    } else {
      await db.syncStateDao.setValue(syncEpochKey, cursor.epoch!);
    }
  });

  /// Следующий pull — с начала журнала сервера.
  Future<void> resetCursor() => saveCursor(SyncCursor.start);

  // ----------------------------------------------------------- служебное

  static bool _isDirty(Map<String, Object?> row) =>
      row['remote_updated_at'] == null ||
      row['remote_updated_at'] != row['updated_at'];

  static bool _same(SyncChange a, SyncChange b) =>
      a.deleted == b.deleted &&
      a.data.length == b.data.length &&
      a.data.keys.every((k) => a.data[k] == b.data[k]);

  TableInfo _tableInfo(String name) =>
      db.allTables.firstWhere((t) => t.actualTableName == name);

  Future<Map<String, Object?>?> _row(String table, String uuid) async {
    final row = await db
        .customSelect(
          'SELECT * FROM ${checkIdentifier(table)} WHERE uuid = ?',
          variables: [Variable<String>(uuid)],
        )
        .getSingleOrNull();
    return row?.data;
  }

  Future<void> _setSynced(PendingChange change) => db.customUpdate(
    'UPDATE ${checkIdentifier(change.table)} '
    'SET remote_updated_at = updated_at WHERE uuid = ? AND updated_at = ?',
    variables: [
      Variable<String>(change.uuid),
      Variable<String>(change.rawUpdatedAt),
    ],
    updates: {_tableInfo(change.table)},
    updateKind: UpdateKind.update,
  );

  /// Мягкое удаление без новой версии: `updated_at` прежний, запись
  /// считается синхронизированной.
  Future<void> _markDeletedSynced(String table, String uuid) => db.customUpdate(
    'UPDATE ${checkIdentifier(table)} '
    'SET deleted = 1, remote_updated_at = updated_at WHERE uuid = ?',
    variables: [Variable<String>(uuid)],
    updates: {_tableInfo(table)},
    updateKind: UpdateKind.update,
  );

  Future<QueryRow?> _rejectionRow(String table, String uuid) => db
      .customSelect(
        'SELECT * FROM pending_changes WHERE entity_table = ? '
        'AND entity_uuid = ? ORDER BY id LIMIT 1',
        variables: [Variable<String>(table), Variable<String>(uuid)],
      )
      .getSingleOrNull();

  Future<void> _dropRejection(String table, String uuid) => db.customUpdate(
    'DELETE FROM pending_changes WHERE entity_table = ? AND entity_uuid = ?',
    variables: [Variable<String>(table), Variable<String>(uuid)],
    updates: {db.pendingChanges},
    updateKind: UpdateKind.delete,
  );

  /// uuid → `updated_at` отклонённой версии.
  Future<Map<String, String>> _rejectedVersions() async {
    final rows = await db.customSelect('SELECT * FROM pending_changes').get();
    return {
      for (final row in rows)
        row.read<String>('entity_uuid'):
            _payload(row)['updated_at_raw'] as String? ?? '',
    };
  }

  static Map<String, Object?> _payload(QueryRow row) {
    final raw = row.readNullable<String>('payload');
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }
}
