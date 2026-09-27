import 'package:kfh_domain/kfh_domain.dart';
import 'package:mysql_client_plus/exception.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

import '../audit.dart';
import '../auth/permissions.dart';
import '../auth/users.dart';
import '../database.dart';
import '../http/responses.dart';
import '../logger.dart';
import '../sql.dart';
import 'change_log.dart';
import 'sync_rows.dart';

/// Итог одного изменения из пачки push.
///
/// - `applied` — записано;
/// - `duplicate` — такая же версия уже есть (повтор отправки) — тоже успех;
/// - `stale` — на сервере версия новее или равная по времени, но другая:
///   побеждает серверная, клиент получит её через pull;
/// - `rejected` — не принято, [code] и [message] объясняют почему. Клиенту
///   нужно вмешательство человека или повторный pull.
class PushResult {
  final int index;
  final String? changeId;
  final String? uuid;
  final String status;
  final String? code;
  final String? message;
  final String? conflictUuid;

  PushResult(this.index, this.changeId, this.uuid, this.status,
      {this.code, this.message, this.conflictUuid});

  Map<String, Object?> toJson() => {
        'change_id': ?changeId,
        'uuid': ?uuid,
        'status': status,
        'code': ?code,
        'message': ?message,
        'conflict_uuid': ?conflictUuid,
      };
}

class PullResult {
  final List<SyncChange> changes;
  final int cursor;
  final bool hasMore;
  final String epoch;

  PullResult(this.changes, this.cursor, this.hasMore, this.epoch);

  Map<String, Object?> toJson() => {
        'epoch': epoch,
        'cursor': cursor,
        'has_more': hasMore,
        'changes': [for (final c in changes) c.toJson()],
      };
}

/// Приём и выдача изменений.
class SyncService {
  static const maxPushChanges = 500;
  static const maxPullLimit = 1000;

  /// Насколько время изменения может опережать часы сервера. Больше —
  /// у клиента сбиты часы: его правка «побеждала» бы все будущие.
  static const maxClockSkew = Duration(minutes: 5);

  final MySqlDatabase db;
  final Logger logger;
  final DateTime Function() _now;

  final _rows = const SyncRows();
  final _log = const ChangeLog();

  SyncService({required this.db, required this.logger, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  // --------------------------------------------------------------- push

  /// Принимает пачку изменений. Неверные изменения отклоняются по одному
  /// (остальные применяются), ответ — итог по каждому в исходном порядке.
  Future<List<PushResult>> push(User user, String deviceId,
      List<Object?> rawChanges, {String? requestId}) async {
    if (rawChanges.length > maxPushChanges) {
      throw ApiException(413, 'too_large',
          'В одной пачке не больше $maxPushChanges изменений');
    }
    final results = List<PushResult?>.filled(rawChanges.length, null);
    final valid = <(int, SyncChange)>[];
    for (var i = 0; i < rawChanges.length; i++) {
      final raw = rawChanges[i];
      try {
        valid.add((i, SyncChange.fromJson(raw)));
      } on SyncFormatException catch (e) {
        results[i] = PushResult(i, _field(raw, 'change_id'), _field(raw, 'uuid'),
            'rejected', code: 'invalid', message: e.message);
      }
    }
    // Сначала сотрудники, потом ссылающиеся на них записи (внешние ключи
    // в MySQL не отложенные); внутри таблицы — в порядке клиента.
    valid.sort((a, b) {
      final byTable =
          syncTableOrder(a.$2.table).compareTo(syncTableOrder(b.$2.table));
      return byTable != 0 ? byTable : a.$1.compareTo(b.$1);
    });

    if (valid.isNotEmpty) {
      await db.transaction((conn) async {
        await _log.lock(conn.execute);
        final guard = PeriodGuard(await _lockedMonths(conn.execute));
        final allowed = writableTables(user.role);
        for (final (index, change) in valid) {
          results[index] = await _applyOne(conn, user, deviceId, index, change,
              guard, allowed, requestId);
        }
      });
    }
    final done = results.cast<PushResult>();
    logger.info('sync push', {
      'request_id': requestId,
      'user': user.uuid,
      'device': deviceId,
      'total': done.length,
      for (final s in const ['applied', 'duplicate', 'stale', 'rejected'])
        s: done.where((r) => r.status == s).length,
    });
    return done;
  }

  Future<PushResult> _applyOne(
    MySQLConnection conn,
    User user,
    String deviceId,
    int index,
    SyncChange change,
    PeriodGuard guard,
    Set<String> allowed,
    String? requestId,
  ) async {
    PushResult result(String status,
            {String? code, String? message, String? conflictUuid}) =>
        PushResult(index, change.changeId, change.uuid, status,
            code: code, message: message, conflictUuid: conflictUuid);

    if (!allowed.contains(change.table)) {
      return result('rejected',
          code: 'forbidden',
          message: 'Роли ${user.role.name} нельзя менять ${change.table}');
    }
    if (change.updatedAt.isAfter(_now().toUtc().add(maxClockSkew))) {
      return result('rejected',
          code: 'clock_skew',
          message: 'Время изменения в будущем — проверьте часы устройства');
    }

    final table = syncTableByName(change.table)!;
    final sql = conn.execute;
    await sql('SAVEPOINT sync_change');
    try {
      final existing = await _rows.read(sql, table, change.uuid, forUpdate: true);
      if (existing != null && !change.updatedAt.isAfter(existing.updatedAt)) {
        await sql('RELEASE SAVEPOINT sync_change');
        final same = change.updatedAt == existing.updatedAt &&
            change.deleted == existing.deleted &&
            _sameData(change.data, existing.data);
        return same ? result('duplicate') : result('stale');
      }
      final locked = guard.violation(change.table, existing?.data,
          existing?.deleted ?? false, change.data, change.deleted);
      if (locked != null) {
        await sql('RELEASE SAVEPOINT sync_change');
        final (year, month) = locked;
        return result('rejected',
            code: 'period_locked',
            message: PeriodLockedException(year, month).message);
      }

      if (existing == null) {
        await _rows.insert(sql, table, change, deviceId);
      } else {
        await _rows.update(sql, table, change, deviceId);
      }
      await _log.append(sql, change.table, change.uuid, deleted: change.deleted);
      await writeAudit(sql,
          action: existing == null
              ? 'sync_insert'
              : change.deleted && !existing.deleted
                  ? 'sync_delete'
                  : 'sync_update',
          userUuid: user.uuid,
          deviceId: deviceId,
          requestId: requestId,
          entity: change.table,
          entityUuid: change.uuid,
          oldValue: existing == null ? null : _auditValue(existing),
          newValue: _auditValue(change));
      await sql('RELEASE SAVEPOINT sync_change');
      return result('applied');
    } on MySQLServerException catch (e) {
      await sql('ROLLBACK TO SAVEPOINT sync_change');
      final rejected = await _explain(sql, table, change, e);
      if (rejected == null) rethrow;
      return result('rejected',
          code: rejected.$1, message: rejected.$2, conflictUuid: rejected.$3);
    }
  }

  /// Ошибка MySQL, которая значит «эта запись не подходит» (а не «сломался
  /// сервер»): (код, сообщение, uuid мешающей записи).
  Future<(String, String, String?)?> _explain(SqlExecutor sql, SyncTable table,
      SyncChange change, MySQLServerException e) async {
    switch (e.errorCode) {
      case 1062: // ER_DUP_ENTRY: живая запись с тем же ключом
        return ('unique_conflict',
            'Такая запись уже есть (другая запись того же сотрудника за тот же '
                'день или месяц)',
            await _conflictingUuid(sql, table, change));
      case 1452: // ER_NO_REFERENCED_ROW_2
        return ('unknown_employee',
            'Нет сотрудника ${change.data['employee_uuid']} — сначала '
                'должен прийти он',
            null);
      case 3819: // ER_CHECK_CONSTRAINT_VIOLATED
      case 1406: // ER_DATA_TOO_LONG
      case 1264: // ER_WARN_DATA_OUT_OF_RANGE
        return ('invalid', 'Значение не подходит: ${e.message}', null);
    }
    return null;
  }

  Future<String?> _conflictingUuid(
      SqlExecutor sql, SyncTable table, SyncChange change) async {
    final (String where, Map<String, dynamic> params) = switch (table.name) {
      'timesheet' => (
          'employee_uuid = :e AND date = :d',
          {'e': change.data['employee_uuid'], 'd': change.data['date']}
        ),
      'payroll_results' => (
          'employee_uuid = :e AND year = :y AND month = :m',
          {
            'e': change.data['employee_uuid'],
            'y': change.data['year'],
            'm': change.data['month'],
          }
        ),
      _ => ('', <String, dynamic>{}),
    };
    if (where.isEmpty) return null;
    final r = await sql(
        'SELECT uuid FROM ${table.name} WHERE $where AND deleted = 0 '
        'AND uuid <> :self',
        {...params, 'self': change.uuid});
    return r.rows.isEmpty ? null : r.rows.first.textOf('uuid');
  }

  Future<Set<int>> _lockedMonths(SqlExecutor sql) async {
    // FOR SHARE: закрыть месяц посреди приёма пачки нельзя — закрытие
    // подождёт конца транзакции.
    final r = await sql('SELECT year, month FROM period_locks FOR SHARE');
    return {
      for (final row in r.rows)
        PeriodGuard.monthKey(row.intOf('year'), row.intOf('month')),
    };
  }

  static bool _sameData(Map<String, Object?> a, Map<String, Object?> b) =>
      a.length == b.length && a.keys.every((k) => a[k] == b[k]);

  static Map<String, Object?> _auditValue(SyncChange c) => {
        'updated_at': formatSyncTimestamp(c.updatedAt),
        'deleted': c.deleted,
        ...c.data,
      };

  static String? _field(Object? raw, String name) {
    if (raw is! Map) return null;
    final value = raw[name];
    return value is String && value.length <= 64 ? value : null;
  }

  // --------------------------------------------------------------- pull

  /// Изменения после [cursor] (номера `change_log`). Одна запись, менявшаяся
  /// несколько раз, приходит один раз — в текущем виде. Удалённые записи
  /// тоже приходят (с `deleted: true`).
  ///
  /// [epoch] — эпоха, которую клиент получил вместе со своим курсором;
  /// другая эпоха или курсор дальше конца журнала — 409 `resync_required`:
  /// база сервера восстановлена из копии, нужна синхронизация с нуля.
  Future<PullResult> pull(User user,
      {required int cursor, String? epoch, int limit = 500}) async {
    if (cursor < 0) {
      throw const ApiException.badRequest('cursor не может быть отрицательным');
    }
    final n = limit.clamp(1, maxPullLimit);
    final readable = readableTables(user.role);
    return db.transaction((conn) async {
      final sql = conn.execute;
      final current = await _log.epoch(sql);
      if (cursor > 0 &&
          (epoch != current || cursor > await _log.maxSeq(sql))) {
        throw const ApiException(409, 'resync_required',
            'Данные сервера восстановлены из копии — нужна полная '
            'синхронизация');
      }
      final entries = await _log.after(sql, cursor, n);
      final nextCursor = entries.isEmpty ? cursor : entries.last.seq;

      // Последний seq каждой записи — порядок выдачи внутри таблицы.
      final lastSeq = <(String, String), int>{};
      for (final e in entries) {
        if (readable.contains(e.table)) lastSeq[(e.table, e.uuid)] = e.seq;
      }
      final changes = <(int, int, SyncChange)>[];
      for (final table in syncTables) {
        final uuids = [
          for (final key in lastSeq.keys)
            if (key.$1 == table.name) key.$2,
        ];
        final hidden = hiddenColumns(user.role, table.name);
        for (final row in await _rows.readMany(sql, table, uuids)) {
          changes.add((
            syncTableOrder(table.name),
            lastSeq[(table.name, row.uuid)]!,
            hidden.isEmpty ? row : _hide(row, hidden),
          ));
        }
      }
      changes.sort((a, b) =>
          a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
      return PullResult([for (final c in changes) c.$3], nextCursor,
          entries.length == n, current);
    });
  }

  static SyncChange _hide(SyncChange row, Set<String> hidden) => SyncChange(
        table: row.table,
        uuid: row.uuid,
        updatedAt: row.updatedAt,
        deleted: row.deleted,
        editedBy: row.editedBy,
        data: {
          for (final e in row.data.entries)
            e.key: hidden.contains(e.key) ? 0.0 : e.value,
        },
      );
}
