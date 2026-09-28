import 'dart:convert';

import 'package:kfh_domain/kfh_domain.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

import '../audit.dart';
import '../auth/users.dart';
import '../database.dart';
import '../http/responses.dart';
import '../payroll/payroll_calculator.dart';
import '../sql.dart';
import '../sync/change_log.dart';
import 'period_balances.dart';

class PeriodLock {
  final int year;
  final int month;
  final String lockedBy;
  final String? lockedByName;
  final DateTime lockedAt;
  final String? note;

  PeriodLock(this.year, this.month, this.lockedBy, this.lockedByName,
      this.lockedAt, this.note);

  Map<String, Object?> toJson() => {
        'year': year,
        'month': month,
        'locked_by': lockedBy,
        'locked_by_name': lockedByName,
        'locked_at': lockedAt.toIso8601String(),
        'note': note,
      };
}

/// Закрытие месяцев (бухгалтер и админ) и открытие (только админ).
///
/// Приём изменений (push) и расчёт читают `period_locks` с блокировкой
/// FOR SHARE, поэтому закрытие месяца ждёт окончания начатых приёмов:
/// изменение не проскочит в месяц, закрытый посреди его проверки.
class PeriodService {
  final MySqlDatabase db;

  /// Пересчёт открытых месяцев после открытия месяца
  /// ([PayrollCalculator.recalculateOpenMonths]); null — без пересчёта.
  final PayrollCalculator? payroll;
  final DateTime Function() _now;

  PeriodService({required this.db, this.payroll, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  Future<List<PeriodLock>> list() async {
    final r = await db.execute(
        'SELECT l.year, l.month, l.locked_by, u.full_name, l.locked_at, l.note '
        'FROM period_locks l LEFT JOIN users u ON u.uuid = l.locked_by '
        'ORDER BY l.year DESC, l.month DESC');
    return [
      for (final row in r.rows)
        PeriodLock(
          row.intOf('year'),
          row.intOf('month'),
          row.textOf('locked_by'),
          row.text('full_name'),
          parseSqlDateTime(row.textOf('locked_at')),
          row.text('note'),
        ),
    ];
  }

  /// Закрытие месяца (бухгалтер и админ). В той же транзакции до закрытия
  /// расчёт месяца пересчитывается по текущим данным — фиксируется свежий.
  Future<PeriodLock> lock(User actor, Object? year, Object? month, Object? note,
      {String? requestId, String? deviceId}) async {
    _requireAccountant(actor);
    final (y, m) = _checkMonth(year, month);
    if (note != null && (note is! String || note.length > 500)) {
      throw const ApiException(400, 'validation', 'Примечание — строка до 500 символов');
    }
    await db.transaction((conn) async {
      final sql = conn.execute;
      // Пересчёт пишет журнал изменений — блокировка очереди, как у push.
      if (payroll != null) await const ChangeLog().lock(sql);
      final existing = await sql(
          'SELECT 1 FROM period_locks WHERE year = :y AND month = :m FOR UPDATE',
          {'y': y, 'm': m});
      if (existing.rows.isNotEmpty) {
        throw const ApiException(409, 'already_locked', 'Месяц уже закрыт');
      }
      await payroll?.recalculateOpenMonths(sql,
          fromMonth: PeriodGuard.monthKey(y, m),
          userUuid: actor.uuid,
          deviceId: deviceId,
          requestId: requestId);
      await sql(
          'INSERT INTO period_locks (year, month, locked_by, locked_at, note) '
          'VALUES (:y, :m, :u, :now, :note)',
          {
            'y': y,
            'm': m,
            'u': actor.uuid,
            'now': sqlDateTime(_now()),
            'note': note,
          });
      await writeAudit(sql,
          action: 'period_lock',
          userUuid: actor.uuid,
          deviceId: deviceId,
          requestId: requestId,
          entity: 'period_locks',
          newValue: {'year': y, 'month': m, 'note': note});
    });
    return (await list()).firstWhere((l) => l.year == y && l.month == m);
  }

  /// Открытие месяца (только админ, решение владельца 2026-09-28) — с
  /// записью в аудит прежнего закрытия. Перед открытием в
  /// `period_snapshots` сохраняется снимок: остатки, начисления и выплаты
  /// по сохранённым расчётам с этого месяца по последний с данными. Затем
  /// расчёт этого и следующих открытых месяцев пересчитывается — всё в
  /// одной транзакции. Возвращает id снимка.
  Future<int> unlock(User actor, Object? year, Object? month,
      {String? requestId, String? deviceId}) async {
    final (y, m) = _checkUnlock(actor, year, month);
    return db.transaction((conn) async {
      final done = await _unlockIn(conn.execute, actor, y, m,
          requestId: requestId, deviceId: deviceId);
      final r = await conn.execute(
          'INSERT INTO period_snapshots '
          '(year, month, reason, created_at, created_by, lock_info, data) '
          'VALUES (:y, :m, :reason, :now, :u, :lock, :data)',
          {
            'y': y,
            'm': m,
            'reason': 'unlock',
            'now': sqlDateTime(_now()),
            'u': actor.uuid,
            'lock': jsonEncode(done.lock),
            'data': jsonEncode({'months': balanceTableJson(done.before)}),
          });
      return r.lastInsertID.toInt();
    });
  }

  /// Что сделает открытие месяца: те же шаги, что [unlock], в транзакции,
  /// которая откатывается. Возвращает изменения остатков по месяцам
  /// ([balanceChangesJson]) — только у кого что-то станет другим.
  Future<Map<String, Object?>> unlockPreview(
      User actor, Object? year, Object? month) async {
    final (y, m) = _checkUnlock(actor, year, month);
    try {
      await db.transaction<Never>((conn) async {
        final done = await _unlockIn(conn.execute, actor, y, m);
        throw _Preview({
          'year': y,
          'month': m,
          'lock': done.lock,
          'changes': balanceChangesJson(done.before, done.after),
        });
      });
    } on _Preview catch (p) {
      return p.result;
    }
  }

  /// Снимки перед открытием месяцев, новые сверху (без данных).
  Future<List<Map<String, Object?>>> snapshots() async {
    final r = await db.execute(
        'SELECT s.id, s.year, s.month, s.reason, s.created_at, u.full_name, '
        's.lock_info FROM period_snapshots s '
        'LEFT JOIN users u ON u.uuid = s.created_by ORDER BY s.id DESC');
    return [for (final row in r.rows) _snapshotJson(row)];
  }

  /// Снимок целиком; нет — 404.
  Future<Map<String, Object?>> snapshot(Object? id) async {
    final n = id is String ? int.tryParse(id) : null;
    if (n == null) throw const ApiException.notFound('Нет такого снимка');
    final r = await db.execute(
        'SELECT s.id, s.year, s.month, s.reason, s.created_at, u.full_name, '
        's.lock_info, s.data FROM period_snapshots s '
        'LEFT JOIN users u ON u.uuid = s.created_by WHERE s.id = :id',
        {'id': n});
    if (r.rows.isEmpty) throw const ApiException.notFound('Нет такого снимка');
    final row = r.rows.first;
    return {
      ..._snapshotJson(row),
      ...jsonDecode(row.textOf('data')) as Map<String, Object?>,
    };
  }

  Map<String, Object?> _snapshotJson(ResultSetRow row) => {
        'id': row.intOf('id'),
        'year': row.intOf('year'),
        'month': row.intOf('month'),
        'reason': row.textOf('reason'),
        'created_at':
            parseSqlDateTime(row.textOf('created_at')).toIso8601String(),
        'created_by_name': row.text('full_name'),
        'lock': row.text('lock_info') == null
            ? null
            : jsonDecode(row.textOf('lock_info')),
      };

  (int, int) _checkUnlock(User actor, Object? year, Object? month) {
    if (actor.role != Role.admin) {
      throw const ApiException(
          403, 'forbidden', 'Открыть закрытый месяц может только администратор');
    }
    return _checkMonth(year, month);
  }

  /// Шаги открытия внутри транзакции: остатки «до», снятие закрытия с
  /// аудитом, пересчёт, остатки «после».
  Future<({Map<String, Object?> lock, BalanceTable before, BalanceTable after})>
      _unlockIn(SqlExecutor sql, User actor, int y, int m,
          {String? requestId, String? deviceId}) async {
    // Пересчёт пишет журнал изменений — блокировка очереди, как у push.
    await const ChangeLog().lock(sql);
    final r = await sql(
        'SELECT l.locked_by, l.locked_at, l.note, u.full_name '
        'FROM period_locks l LEFT JOIN users u ON u.uuid = l.locked_by '
        'WHERE l.year = :y AND l.month = :m FOR UPDATE',
        {'y': y, 'm': m});
    if (r.rows.isEmpty) {
      throw const ApiException.notFound('Месяц не закрыт');
    }
    final row = r.rows.first;
    final lock = <String, Object?>{
      'year': y,
      'month': m,
      'locked_by': row.textOf('locked_by'),
      'locked_by_name': row.text('full_name'),
      'locked_at': parseSqlDateTime(row.textOf('locked_at')).toIso8601String(),
      'note': row.text('note'),
    };
    final calc = payroll ?? PayrollCalculator(db: db);
    final from = PeriodGuard.monthKey(y, m);
    Future<BalanceTable> table() async {
      final span = await calc.dataMonths(sql);
      final to = span == null || span.last < from ? from : span.last;
      return balanceTable(sql, calc, from, to);
    }

    final before = await table();
    await sql('DELETE FROM period_locks WHERE year = :y AND month = :m',
        {'y': y, 'm': m});
    await writeAudit(sql,
        action: 'period_unlock',
        userUuid: actor.uuid,
        deviceId: deviceId,
        requestId: requestId,
        entity: 'period_locks',
        oldValue: lock);
    await payroll?.recalculateOpenMonths(sql,
        fromMonth: from,
        userUuid: actor.uuid,
        deviceId: deviceId,
        requestId: requestId);
    return (lock: lock, before: before, after: await table());
  }

  static void _requireAccountant(User actor) {
    if (actor.role == Role.operator) {
      throw const ApiException(
          403, 'forbidden', 'Закрывать и открывать месяцы может бухгалтер или админ');
    }
  }

  static (int, int) _checkMonth(Object? year, Object? month) {
    int? parse(Object? v) => v is int ? v : (v is String ? int.tryParse(v) : null);
    final y = parse(year), m = parse(month);
    if (y == null || m == null || y < 1900 || y > 2200 || m < 1 || m > 12) {
      throw const ApiException(400, 'validation', 'Неверный год или месяц');
    }
    return (y, m);
  }
}

/// Результат предпросмотра — выходит из транзакции исключением, чтобы она
/// откатилась.
class _Preview implements Exception {
  final Map<String, Object?> result;
  _Preview(this.result);
}
