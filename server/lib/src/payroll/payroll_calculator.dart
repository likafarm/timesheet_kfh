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

  /// Были ли выплаты сотруднику в этом месяце.
  final bool paidInMonth;

  /// Входящий остаток на 1-е число месяца.
  final double startingBalance;

  EmployeePayroll(this.employee, this.calculation, this.saved,
      {required this.paidInMonth, required this.startingBalance});

  /// Входит ли сотрудник в расчёт месяца: есть начисления, выплаты или
  /// входящий остаток ([payrollNeeded] из kfh_domain — то же правило, что
  /// в приложении).
  bool get needed => payrollNeeded(
      emptyPayroll: calculation.isEmpty,
      paidInMonth: paidInMonth,
      startingBalance: startingBalance);

  /// Сохранённое совпадает с тем, что должно быть: свежий расчёт — для
  /// нужных, отсутствие расчёта — для выпавших из расчёта.
  bool get upToDate => needed
      ? saved != null && sameAsSaved(calculation, saved!.data)
      : saved == null;

  Map<String, Object?> toJson() => {
        'employee_uuid': employee.uuid,
        'full_name': employee.data['full_name'],
        'calculation': _calculationJson(calculation),
        'saved': saved == null
            ? null
            : {'uuid': saved!.uuid, ...saved!.data, 'updated_at': formatSyncTimestamp(saved!.updatedAt)},
        'starting_balance': startingBalance,
        'needed': needed,
        'up_to_date': upToDate,
      };
}

/// Сохранённый расчёт показывается в отчёте, если в нём есть начисления,
/// сотруднику в месяце что-то выплачено или у него есть входящий остаток
/// (пустые строки могли остаться от расчётов до 2026-09-26).
bool savedPayrollVisible(Map<String, Object?> saved,
        {required bool paidInMonth, required double startingBalance}) =>
    payrollNeeded(
      emptyPayroll: isEmptyPayroll(
        baseDays: saved['base_days'] as double,
        fieldDays: saved['field_days'] as double,
        sickDays: saved['sick_days'] as double,
        vacationDays: saved['vacation_days'] as double,
        totalSalary: saved['total_salary'] as double,
        skippedWorkDays: saved['skipped_work_days'] as int,
      ),
      paidInMonth: paidInMonth,
      startingBalance: startingBalance,
    );

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

  /// Сотрудники, которым в месяце что-то выплачено.
  Future<Set<String>> paidInMonth(SqlExecutor sql, int year, int month) async {
    final r = await sql(
        'SELECT DISTINCT employee_uuid FROM payments WHERE deleted = 0 '
        'AND payment_date BETWEEN :from AND :to',
        {
          'from': formatDateIso(DateTime(year, month, 1)),
          'to': formatDateIso(DateTime(year, month + 1, 0)),
        });
    return {for (final row in r.rows) row.textOf('employee_uuid')};
  }

  /// Свежий расчёт по всем сотрудникам (включая уволенных) рядом с
  /// сохранёнными результатами месяца. В список входят только нужные
  /// ([EmployeePayroll.needed]) и те, у кого остался сохранённый расчёт
  /// (его уберёт пересчёт).
  Future<List<EmployeePayroll>> calculate(SqlExecutor sql, int year, int month) async =>
      (await calculateEveryone(sql, year, month))
          .where((r) => r.needed || r.saved != null)
          .toList();

  /// Свежий расчёт каждого неудалённого сотрудника за месяц — без отбора
  /// (для сверки импорта).
  Future<List<EmployeePayroll>> calculateEveryone(
      SqlExecutor sql, int year, int month) async {
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
    final paid = await paidInMonth(sql, year, month);
    final balances = await startingBalances(sql, year, month);

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
          paidInMonth: paid.contains(e.uuid),
          startingBalance: balances[e.uuid] ?? 0,
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
  /// перезаписываются; расчёт сотрудника, выпавшего из расчёта (нет ни
  /// начислений, ни выплат), удаляется мягко — клиенты получат удаление.
  Future<({int saved, int unchanged, int removed, List<EmployeePayroll> results})> save(
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
      final done = await _writeMonth(sql, year, month,
          auto: false, userUuid: actor.uuid, requestId: requestId);
      return (
        saved: done.saved,
        unchanged: done.unchanged,
        removed: done.removed,
        results: await calculate(sql, year, month),
      );
    });
  }

  /// Пересчитывает и сохраняет открытые месяцы, начиная с [fromMonth]
  /// ([PeriodGuard.monthKey]; null — с самого раннего месяца с данными), по
  /// последний месяц, где есть табель, выплаты или сохранённый расчёт.
  /// Закрытые месяцы не трогаются: их расчёт зафиксирован.
  ///
  /// Месяцы идут по возрастанию: входящий остаток следующего месяца
  /// считается по уже обновлённым расчётам предыдущих. Так сохранённые
  /// расчёты открытых месяцев всегда совпадают со свежим пересчётом, и
  /// остатки по ним верны.
  ///
  /// Вызывающий держит транзакцию и блокировку журнала ([ChangeLog.lock]).
  /// Возвращает число записанных и удалённых расчётов.
  Future<int> recalculateOpenMonths(SqlExecutor sql,
      {int? fromMonth,
      String? userUuid,
      String? deviceId,
      String? requestId}) async {
    final span = await dataMonths(sql);
    if (span == null) return 0;
    final from =
        fromMonth == null || fromMonth < span.first ? span.first : fromMonth;
    final locked = await sql('SELECT year, month FROM period_locks FOR SHARE');
    final lockedKeys = {
      for (final row in locked.rows)
        PeriodGuard.monthKey(row.intOf('year'), row.intOf('month')),
    };
    var written = 0;
    for (var key = from; key <= span.last; key++) {
      if (lockedKeys.contains(key)) continue;
      final done = await _writeMonth(sql, key ~/ 12, key % 12 + 1,
          auto: true,
          userUuid: userUuid,
          deviceId: deviceId,
          requestId: requestId);
      written += done.saved + done.removed;
    }
    return written;
  }

  /// Первый и последний месяц ([PeriodGuard.monthKey]), где есть живой
  /// табель, выплата или сохранённый расчёт; null — данных нет.
  Future<({int first, int last})?> dataMonths(SqlExecutor sql) async {
    final r = await sql('SELECT '
        '(SELECT MIN(date) FROM timesheet WHERE deleted = 0) AS t0, '
        '(SELECT MAX(date) FROM timesheet WHERE deleted = 0) AS t1, '
        '(SELECT MIN(payment_date) FROM payments WHERE deleted = 0) AS p0, '
        '(SELECT MAX(payment_date) FROM payments WHERE deleted = 0) AS p1, '
        '(SELECT MIN(year * 12 + month - 1) FROM payroll_results '
        'WHERE deleted = 0) AS r0, '
        '(SELECT MAX(year * 12 + month - 1) FROM payroll_results '
        'WHERE deleted = 0) AS r1');
    final row = r.rows.single;
    int? day(String column) {
      final v = row.text(column);
      if (v == null) return null;
      final d = parseDateIso(v);
      return PeriodGuard.monthKey(d.year, d.month);
    }

    int? key(String column) => int.tryParse(row.text(column) ?? '');
    final firsts = [day('t0'), day('p0'), key('r0')].whereType<int>();
    final lasts = [day('t1'), day('p1'), key('r1')].whereType<int>();
    if (firsts.isEmpty) return null;
    return (
      first: firsts.reduce((a, b) => a < b ? a : b),
      last: lasts.reduce((a, b) => a > b ? a : b),
    );
  }

  /// Считает месяц и записывает то, что разошлось с сохранённым: новые и
  /// изменившиеся расчёты, мягкое удаление выпавших из расчёта. Каждая
  /// запись — в журнал изменений и аудит ([auto] — автоматический пересчёт
  /// после правки: действия `payroll_auto_save`/`payroll_auto_delete`).
  Future<({int saved, int unchanged, int removed})> _writeMonth(
      SqlExecutor sql, int year, int month,
      {required bool auto,
      String? userUuid,
      String? deviceId,
      String? requestId}) async {
    final table = _t('payroll_results');
    final results = await calculate(sql, year, month);
    var saved = 0, unchanged = 0, removed = 0;
    final now = _now().toUtc();
    // Новая версия всегда позже прежней — даже если часы клиента, записавшего
    // прежнюю, спешили: иначе клиент счёл бы свою версию новее.
    DateTime stamp(SyncChange? old) =>
        old == null || now.isAfter(old.updatedAt)
            ? now
            : old.updatedAt.add(const Duration(microseconds: 1));
    for (final r in results) {
      final old = r.saved;
      if (r.upToDate) {
        unchanged++;
        continue;
      }
      if (!r.needed) {
        // Выпал из расчёта: прежний расчёт — мягко удалить.
        final gone = SyncChange(
            table: table.name,
            uuid: old!.uuid,
            updatedAt: stamp(old),
            deleted: true,
            data: old.data);
        await _rows.update(sql, table, gone, editor);
        await _log.append(sql, table.name, gone.uuid, deleted: true);
        await writeAudit(sql,
            action: auto ? 'payroll_auto_delete' : 'payroll_delete',
            userUuid: userUuid,
            deviceId: deviceId,
            requestId: requestId,
            entity: table.name,
            entityUuid: gone.uuid,
            oldValue: old.data);
        removed++;
        continue;
      }
      final change = SyncChange(
        table: table.name,
        uuid: old?.uuid ?? _uuid.v7(),
        updatedAt: stamp(old),
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
          action: auto ? 'payroll_auto_save' : 'payroll_save',
          userUuid: userUuid,
          deviceId: deviceId,
          requestId: requestId,
          entity: table.name,
          entityUuid: change.uuid,
          oldValue: old?.data,
          newValue: change.data);
      saved++;
    }
    return (saved: saved, unchanged: unchanged, removed: removed);
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

/// С какого месяца ([PeriodGuard.monthKey]) правка записи может изменить
/// расчёты ЗП: табель и выплаты — их месяц (прежний и новый), ставка — месяц
/// начала, расчёт — его месяц, сотрудник — все месяцы (0: удалённый
/// сотрудник выпадает из расчёта). null — на расчёт не влияет (реквизиты,
/// больничные и отпуска: расчёт идёт по табелю). [before] и [after] —
/// данные живой записи до и после правки (null — записи нет или удалена).
int? payrollImpactFrom(
    String table, Map<String, Object?>? before, Map<String, Object?>? after) {
  if (table == 'employees') return 0;
  int? month(Map<String, Object?>? data) {
    if (data == null) return null;
    final column = switch (table) {
      'timesheet' => 'date',
      'payments' => 'payment_date',
      'employee_rates' => 'start_date',
      _ => null,
    };
    if (column != null) {
      final d = parseDateIso(data[column] as String);
      return PeriodGuard.monthKey(d.year, d.month);
    }
    if (table == 'payroll_results') {
      return PeriodGuard.monthKey(data['year'] as int, data['month'] as int);
    }
    return null;
  }

  final keys = [month(before), month(after)].whereType<int>();
  return keys.isEmpty ? null : keys.reduce((a, b) => a < b ? a : b);
}
