import 'package:kfh_domain/kfh_domain.dart';
import 'package:mysql_client_plus/exception.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

import '../audit.dart';
import '../auth/permissions.dart';
import '../auth/users.dart';
import '../database.dart';
import '../finance/category_groups.dart';
import '../http/responses.dart';
import '../logger.dart';
import '../payroll/payroll_calculator.dart';
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

  /// Пересчёт расчётов ЗП открытых месяцев после принятых правок — в той же
  /// транзакции ([PayrollCalculator.recalculateOpenMonths]). null — без
  /// пересчёта (тесты самой синхронизации).
  final PayrollCalculator? payroll;
  final DateTime Function() _now;

  final _rows = const SyncRows();
  final _log = const ChangeLog();
  final CategoryGroups _groups;

  SyncService(
      {required this.db,
      required this.logger,
      this.payroll,
      DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _groups = CategoryGroups(now: now);

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

    var recalculated = 0;
    if (valid.isNotEmpty) {
      await db.transaction((conn) async {
        await _log.lock(conn.execute);
        final guard = PeriodGuard(await _lockedMonths(conn.execute));
        final allowed = writableTables(user.role);
        int? impactFrom;
        void impact(int? month) {
          if (month != null && (impactFrom == null || month < impactFrom!)) {
            impactFrom = month;
          }
        }

        for (final (index, change) in valid) {
          results[index] = await _applyOne(conn, user, deviceId, index, change,
              guard, allowed, requestId, impact);
        }
        final calculator = payroll;
        if (calculator != null && impactFrom != null) {
          recalculated = await calculator.recalculateOpenMonths(conn.execute,
              fromMonth: impactFrom,
              userUuid: user.uuid,
              deviceId: deviceId,
              requestId: requestId);
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
      'payroll_recalculated': recalculated,
    });
    return done;
  }

  Future<PushResult> _applyOne(
    MySQLConnection conn,
    User user,
    String deviceId,
    int index,
    SyncChange incoming,
    PeriodGuard guard,
    Set<String> allowed,
    String? requestId,
    void Function(int? month) impact,
  ) async {
    var change = incoming;
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
            _sameData(table, change.data, existing.data);
        return same ? result('duplicate') : result('stale');
      }
      final forbidden = _operatorProblem(user, change, existing);
      if (forbidden != null) {
        await sql('RELEASE SAVEPOINT sync_change');
        return result('rejected', code: 'forbidden', message: forbidden);
      }
      final problem = change.table == 'timesheet' && !change.deleted
          ? timesheetRowProblem(change.data)
          : null;
      if (problem != null) {
        await sql('RELEASE SAVEPOINT sync_change');
        return result('rejected',
            code: 'invalid_mark',
            message: 'Табель за ${_humanDay(change.data['date'])}: $problem. '
                'Исправьте отметку этого дня');
      }
      final financeProblem =
          change.deleted ? null : financeRowProblem(change.table, change.data);
      if (financeProblem != null) {
        await sql('RELEASE SAVEPOINT sync_change');
        return result('rejected', code: 'invalid', message: financeProblem);
      }
      if (change.table == 'fin_categories' && !change.deleted) {
        final grouped = await _categoryGroup(sql, user, deviceId, change,
            requestId: requestId);
        if (grouped == null) {
          await sql('RELEASE SAVEPOINT sync_change');
          return result('rejected',
              code: 'invalid',
              message: 'Группа статьи другого вида (доход/расход) или '
                  'удалена');
        }
        change = grouped;
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
      impact(payrollImpactFrom(change.table,
          existing == null || existing.deleted ? null : existing.data,
          change.deleted ? null : change.data));
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

  /// Оператор в финансах (0.11.0): свои операции (только доходы и
  /// расходы) и новые контрагенты; null — можно.
  static String? _operatorProblem(
      User user, SyncChange change, SyncChange? existing) {
    if (user.role != Role.operator) return null;
    switch (change.table) {
      case 'fin_operations':
        return operatorOperationProblem(
          userUuid: user.uuid,
          exists: existing != null,
          existingCreatedBy: existing?.data['created_by'] as String?,
          type: change.data['type'] as String? ?? '',
          createdBy: change.data['created_by'] as String?,
        );
      case 'counterparties':
        return existing == null
            ? null
            : 'Оператор только заводит новых контрагентов — исправляют '
                'бухгалтер и администратор';
    }
    return null;
  }

  /// Ошибка MySQL, которая значит «эта запись не подходит» (а не «сломался
  /// сервер»): (код, сообщение, uuid мешающей записи).
  Future<(String, String, String?)?> _explain(SqlExecutor sql, SyncTable table,
      SyncChange change, MySQLServerException e) async {
    switch (e.errorCode) {
      case 1062: // ER_DUP_ENTRY: живая запись с тем же ключом
        return ('unique_conflict',
            switch (table.name) {
              'timesheet' || 'payroll_results' =>
                'Такая запись уже есть (другая запись того же сотрудника за '
                    'тот же день или месяц)',
              _ => 'Такая запись уже есть (то же название)',
            },
            await _conflictingUuid(sql, table, change));
      case 1452: // ER_NO_REFERENCED_ROW_2
        return table.hasEmployee && !table.name.startsWith('fin_')
            ? (
                'unknown_employee',
                'Нет сотрудника ${change.data['employee_uuid']} — сначала '
                    'должен прийти он',
                null
              )
            : (
                'unknown_reference',
                'Нет связанной записи (кошелька, статьи, займа или '
                    'сотрудника) — сначала должна прийти она',
                null
              );
      case 3819: // ER_CHECK_CONSTRAINT_VIOLATED
      case 1406: // ER_DATA_TOO_LONG
      case 1264: // ER_WARN_DATA_OUT_OF_RANGE
        return ('invalid', 'Значение не подходит: ${e.message}', null);
    }
    return null;
  }

  Future<String?> _conflictingUuid(
      SqlExecutor sql, SyncTable table, SyncChange change) async {
    if (table.unique.isEmpty) return null;
    final where = [for (final c in table.unique) '$c = :$c'].join(' AND ');
    final r = await sql(
        'SELECT uuid FROM ${table.name} WHERE $where AND deleted = 0 '
        'AND uuid <> :self',
        {
          for (final c in table.unique) c: change.data[c],
          'self': change.uuid,
        });
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

  /// Те же данные. Колонку, которой не знает программа-отправитель
  /// ([SyncColumn.since]: пришла пустой), не сравниваем — её заполнил сервер.
  static bool _sameData(
          SyncTable table, Map<String, Object?> a, Map<String, Object?> b) =>
      a.length == b.length &&
      a.keys.every((k) =>
          a[k] == b[k] || (a[k] == null && table.column(k)?.since != null));

  /// Статья с группой: без ссылки (программа 1.18) — группа по виду и
  /// названию (нет — заводится); со ссылкой — группа того же вида. null —
  /// группа не подходит.
  Future<SyncChange?> _categoryGroup(
      SqlExecutor sql, User user, String deviceId, SyncChange change,
      {String? requestId}) async {
    final type = change.data['type'] as String;
    final groupUuid = change.data['group_uuid'] as String?;
    if (groupUuid != null) {
      return await _groups.typeOf(sql, groupUuid) == type ? change : null;
    }
    final group = await _groups.groupFor(
        sql, type, change.data['group_name'] as String,
        userUuid: user.uuid, deviceId: deviceId, requestId: requestId);
    return SyncChange(
      table: change.table,
      uuid: change.uuid,
      updatedAt: change.updatedAt,
      deleted: change.deleted,
      editedBy: change.editedBy,
      changeId: change.changeId,
      data: {...change.data, 'group_uuid': group},
    );
  }

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
  ///
  /// [tables] — только эти таблицы (из доступных роли); null — таблицы
  /// до финансов ([legacySyncTableNames]): так спрашивают программы до
  /// 1.18, другие таблицы они не знают. Новые программы присылают список.
  Future<PullResult> pull(User user,
      {required int cursor,
      String? epoch,
      int limit = 500,
      Set<String>? tables}) async {
    if (cursor < 0) {
      throw const ApiException.badRequest('cursor не может быть отрицательным');
    }
    final unknown = tables?.where((t) => syncTableByName(t) == null);
    if (unknown != null && unknown.isNotEmpty) {
      throw ApiException.badRequest('Неизвестные таблицы: ${unknown.join(', ')}');
    }
    final n = limit.clamp(1, maxPullLimit);
    final asked = tables ?? legacySyncTableNames;
    final readable = readableTables(user.role).intersection(asked);
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
        // Колонки, которых программа не знает (спросила без их таблицы).
        final unknown = unknownColumnsFor(table, asked);
        for (final row in await _rows.readMany(sql, table, uuids)) {
          if (!rowVisible(user, row)) continue;
          var out = hidden.isEmpty ? row : _hide(table, row, hidden);
          if (unknown.isNotEmpty) out = _without(out, unknown);
          changes.add((
            syncTableOrder(table.name),
            lastSeq[(table.name, row.uuid)]!,
            out,
          ));
        }
      }
      changes.sort((a, b) =>
          a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
      return PullResult([for (final c in changes) c.$3], nextCursor,
          entries.length == n, current);
    });
  }

  static SyncChange _without(SyncChange row, Set<String> columns) =>
      SyncChange(
        table: row.table,
        uuid: row.uuid,
        updatedAt: row.updatedAt,
        deleted: row.deleted,
        editedBy: row.editedBy,
        data: {
          for (final e in row.data.entries)
            if (!columns.contains(e.key)) e.key: e.value,
        },
      );

  /// Скрытое поле: пустое, если может быть пустым, иначе ноль.
  static Object? _hidden(SyncTable table, String column) {
    final c = table.column(column);
    if (c == null || c.nullable) return null;
    return c.type == SyncType.integer ? 0 : 0.0;
  }

  static SyncChange _hide(SyncTable table, SyncChange row, Set<String> hidden) =>
      SyncChange(
        table: row.table,
        uuid: row.uuid,
        updatedAt: row.updatedAt,
        deleted: row.deleted,
        editedBy: row.editedBy,
        data: {
          for (final e in row.data.entries)
            e.key: hidden.contains(e.key) ? _hidden(table, e.key) : e.value,
        },
      );
}

/// День ISO `гггг-мм-дд` → `дд.мм.гггг` для сообщений.
String _humanDay(Object? iso) =>
    iso is String ? iso.split('-').reversed.join('.') : '$iso';
