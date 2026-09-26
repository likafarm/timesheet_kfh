import 'package:kfh_domain/kfh_domain.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';
import 'package:uuid/uuid.dart';

import '../audit.dart';
import '../auth/users.dart';
import '../database.dart';
import '../http/responses.dart';
import '../sql.dart';
import '../sync/change_log.dart';
import '../sync/sync_rows.dart';

/// Итог расчёта сотрудника: свежий расчёт и то, что сохранено.
class EmployeePayroll {
  final SyncChange employee;
  final PayrollCalculation calculation;

  /// Сохранённый расчёт за месяц (null — не считали).
  final SyncChange? saved;

  EmployeePayroll(this.employee, this.calculation, this.saved);

  /// Сохранённый расчёт совпадает со свежим.
  bool get upToDate => saved != null && sameAsSaved(calculation, saved!.data);

  Map<String, Object?> toJson() => {
        'employee_uuid': employee.uuid,
        'full_name': employee.data['full_name'],
        'calculation': _calculationJson(calculation),
        'saved': saved == null
            ? null
            : {'uuid': saved!.uuid, ...saved!.data, 'updated_at': formatSyncTimestamp(saved!.updatedAt)},
        'up_to_date': upToDate,
      };
}

Map<String, Object?> _calculationJson(PayrollCalculation c) => {
      'base_days': c.baseDays,
      'field_days': c.fieldDays,
      'sick_days': c.sickDays,
      'vacation_days': c.vacationDays,
      'total_salary': c.totalSalary,
      'base_rate_used': c.baseRateUsed,
      'field_rate_used': c.fieldRateUsed,
      'skipped_work_days': c.skippedWorkDays,
    };

/// Поля расчёта, которые сравниваются с сохранённым (без времени и
/// статуса).
bool sameAsSaved(PayrollCalculation c, Map<String, Object?> saved) {
  final fresh = _calculationJson(c);
  return fresh.keys.every((k) => fresh[k] == saved[k]);
}

/// Расчёт ЗП на сервере — тем же кодом, что и в приложении
/// (`calculateMonthlySalary`, `combineBalances` из kfh_domain): загружает
/// живые записи из MySQL и передаёт их в чистые функции.
class PayrollCalculator {
  /// Кто записал расчёт (`edited_by`): у сервера нет id устройства.
  static const editor = 'server';

  final MySqlDatabase db;
  final DateTime Function() _now;
  final _rows = const SyncRows();
  final _log = const ChangeLog();
  static const _uuid = Uuid();

  PayrollCalculator({required this.db, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static SyncTable _t(String name) => syncTableByName(name)!;

  /// Свежий расчёт по всем сотрудникам (как «Рассчитать всех» в
  /// приложении — включая уволенных) и сохранённые результаты месяца.
  Future<List<EmployeePayroll>> calculate(SqlExecutor sql, int year, int month) async {
    _checkMonth(year, month);
    final first = DateTime(year, month, 1), last = DateTime(year, month + 1, 0);
    final employees = await _rows.live(sql, _t('employees'),
        orderBy: 'full_name, uuid');
    final days = await _rows.live(sql, _t('timesheet'),
        where: 'date BETWEEN :from AND :to',
        params: {'from': formatDateIso(first), 'to': formatDateIso(last)});
    final rates = await _rows.live(sql, _t('employee_rates'));
    final saved = await _rows.live(sql, _t('payroll_results'),
        where: 'year = :y AND month = :m', params: {'y': year, 'm': month});

    final daysBy = <String, List<TimesheetRecord>>{};
    for (final d in days) {
      (daysBy[d.data['employee_uuid'] as String] ??= []).add(_record(d));
    }
    final ratesBy = <String, List<EmployeeRate>>{};
    for (final r in rates) {
      (ratesBy[r.data['employee_uuid'] as String] ??= []).add(_rate(r));
    }
    final savedBy = {for (final s in saved) s.data['employee_uuid'] as String: s};

    return [
      for (final e in employees)
        EmployeePayroll(
          e,
          calculateMonthlySalary(
            employeeId: e.uuid,
            year: year,
            month: month,
            records: daysBy[e.uuid] ?? const [],
            rates: ratesBy[e.uuid] ?? const [],
          ),
          savedBy[e.uuid],
        ),
    ];
  }

  /// Входящий остаток на 1-е число месяца: начислено за прошлые месяцы −
  /// выплачено до 1-го числа (по сохранённым расчётам, как в приложении).
  Future<Map<String, double>> startingBalances(
      SqlExecutor sql, int year, int month) async {
    _checkMonth(year, month);
    final accrued = await sql(
        'SELECT employee_uuid, SUM(total_salary) AS total FROM payroll_results '
        'WHERE deleted = 0 AND (year < :y OR (year = :y AND month < :m)) '
        'GROUP BY employee_uuid',
        {'y': year, 'm': month});
    final paid = await sql(
        'SELECT employee_uuid, SUM(amount) AS total FROM payments '
        'WHERE deleted = 0 AND payment_date < :d GROUP BY employee_uuid',
        {'d': formatDateIso(DateTime(year, month, 1))});
    Map<String, double> sums(Iterable<ResultSetRow> rows) => {
          for (final row in rows)
            row.textOf('employee_uuid'): double.parse(row.textOf('total')),
        };
    return combineBalances(accrued: sums(accrued.rows), paid: sums(paid.rows));
  }

  /// Считает и сохраняет расчёт месяца. Закрытый месяц — 409
  /// `period_locked`. Совпадающие с сохранёнными расчёты не
  /// перезаписываются. Возвращает (сохранено, без изменений).
  Future<({int saved, int unchanged, List<EmployeePayroll> results})> save(
      User actor, int year, int month, {String? requestId}) {
    _checkMonth(year, month);
    return db.transaction((conn) async {
      final sql = conn.execute;
      // Очередь записи журнала изменений — как у push.
      await _log.lock(sql);
      final locked = await sql(
          'SELECT 1 FROM period_locks WHERE year = :y AND month = :m FOR SHARE',
          {'y': year, 'm': month});
      if (locked.rows.isNotEmpty) {
        throw ApiException(409, 'period_locked',
            'Месяц ${month.toString().padLeft(2, '0')}.$year закрыт — '
            'пересчёт запрещён');
      }
      final table = _t('payroll_results');
      final results = await calculate(sql, year, month);
      var saved = 0, unchanged = 0;
      final now = _now().toUtc();
      for (final r in results) {
        final old = r.saved;
        if (old != null && r.upToDate) {
          unchanged++;
          continue;
        }
        final change = SyncChange(
          table: table.name,
          uuid: old?.uuid ?? _uuid.v7(),
          updatedAt: now,
          deleted: false,
          data: {
            'legacy_id': old?.data['legacy_id'],
            'employee_uuid': r.employee.uuid,
            'year': year,
            'month': month,
            ..._calculationJson(r.calculation),
            'calculated_at': formatSyncTimestamp(now),
            'status': 'calculated',
          },
        );
        if (old == null) {
          await _rows.insert(sql, table, change, editor);
        } else {
          await _rows.update(sql, table, change, editor);
        }
        await _log.append(sql, table.name, change.uuid, deleted: false);
        await writeAudit(sql,
            action: 'payroll_save',
            userUuid: actor.uuid,
            requestId: requestId,
            entity: table.name,
            entityUuid: change.uuid,
            oldValue: old?.data,
            newValue: change.data);
        saved++;
      }
      return (
        saved: saved,
        unchanged: unchanged,
        results: await calculate(sql, year, month),
      );
    });
  }

  static void _checkMonth(int year, int month) {
    if (year < 1900 || year > 2200 || month < 1 || month > 12) {
      throw const ApiException.badRequest('Неверный год или месяц');
    }
  }

  static TimesheetRecord _record(SyncChange d) => TimesheetRecord(
        id: d.uuid,
        employeeId: d.data['employee_uuid'] as String,
        date: parseDateIso(d.data['date'] as String),
        dayType: d.data['day_type'] as String,
        days: d.data['days'] as double,
        workPlace: d.data['work_place'] as String?,
        notes: d.data['notes'] as String?,
      );

  static EmployeeRate _rate(SyncChange r) => EmployeeRate(
        id: r.uuid,
        employeeId: r.data['employee_uuid'] as String,
        baseRate: r.data['base_rate'] as double,
        fieldRate: r.data['field_rate'] as double,
        startDate: parseDateIso(r.data['start_date'] as String),
        endDate: parseDateIsoOrNull(r.data['end_date'] as String?),
      );
}
