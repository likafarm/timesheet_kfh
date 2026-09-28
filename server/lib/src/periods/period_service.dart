import 'package:kfh_domain/kfh_domain.dart';

import '../audit.dart';
import '../auth/users.dart';
import '../database.dart';
import '../http/responses.dart';
import '../payroll/payroll_calculator.dart';
import '../sql.dart';
import '../sync/change_log.dart';

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

/// Закрытие и открытие месяцев (бухгалтер и админ).
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

  Future<PeriodLock> lock(User actor, Object? year, Object? month, Object? note,
      {String? requestId, String? deviceId}) async {
    _requireAccountant(actor);
    final (y, m) = _checkMonth(year, month);
    if (note != null && (note is! String || note.length > 500)) {
      throw const ApiException(400, 'validation', 'Примечание — строка до 500 символов');
    }
    await db.transaction((conn) async {
      final sql = conn.execute;
      final existing = await sql(
          'SELECT 1 FROM period_locks WHERE year = :y AND month = :m FOR UPDATE',
          {'y': y, 'm': m});
      if (existing.rows.isNotEmpty) {
        throw const ApiException(409, 'already_locked', 'Месяц уже закрыт');
      }
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

  /// Открытие месяца — с записью в аудит прежнего закрытия. Расчёт этого и
  /// следующих открытых месяцев пересчитывается в той же транзакции:
  /// зафиксированный расчёт снова следует за данными.
  Future<void> unlock(User actor, Object? year, Object? month,
      {String? requestId, String? deviceId}) async {
    _requireAccountant(actor);
    final (y, m) = _checkMonth(year, month);
    await db.transaction((conn) async {
      final sql = conn.execute;
      // Пересчёт пишет журнал изменений — блокировка очереди, как у push.
      if (payroll != null) await const ChangeLog().lock(sql);
      final r = await sql(
          'SELECT locked_by, locked_at, note FROM period_locks '
          'WHERE year = :y AND month = :m FOR UPDATE',
          {'y': y, 'm': m});
      if (r.rows.isEmpty) {
        throw const ApiException.notFound('Месяц не закрыт');
      }
      final row = r.rows.first;
      await sql('DELETE FROM period_locks WHERE year = :y AND month = :m',
          {'y': y, 'm': m});
      await writeAudit(sql,
          action: 'period_unlock',
          userUuid: actor.uuid,
          deviceId: deviceId,
          requestId: requestId,
          entity: 'period_locks',
          oldValue: {
            'year': y,
            'month': m,
            'locked_by': row.textOf('locked_by'),
            'locked_at': parseSqlDateTime(row.textOf('locked_at')).toIso8601String(),
            'note': row.text('note'),
          });
      await payroll?.recalculateOpenMonths(sql,
          fromMonth: PeriodGuard.monthKey(y, m),
          userUuid: actor.uuid,
          deviceId: deviceId,
          requestId: requestId);
    });
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
