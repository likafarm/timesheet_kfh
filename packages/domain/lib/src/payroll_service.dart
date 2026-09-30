import 'models/employee_rate.dart';
import 'models/payroll_result.dart';
import 'models/timesheet_record.dart';
import 'payroll.dart';
import 'repositories.dart';
import 'sync/period_guard.dart';

/// Итог сохранения расчёта за месяц.
class PayrollMonthSave {
  /// Сохранено (записано или обновлено) расчётов.
  final int saved;

  /// Удалено прежних расчётов — сотрудник выпал из расчёта.
  final int removed;

  const PayrollMonthSave(this.saved, this.removed);
}

/// Отчёт по зарплате за месяц (правило 6.1, решение владельца 2026-09-28):
/// открытый месяц — свежий пересчёт по текущим данным, закрытый — расчёт,
/// зафиксированный сервером.
class PayrollMonthReport {
  final int year;
  final int month;

  /// Месяц закрыт: строки — зафиксированный расчёт.
  final bool locked;

  /// Строки отчёта по ФИО: только сотрудники, которым расчёт нужен
  /// ([payrollNeeded]). В открытом месяце — свежий расчёт (id = null).
  final List<PayrollResult> results;

  /// Входящий остаток на 1-е число ([PayrollService.currentBalances]).
  final Map<String, double> startingBalances;

  /// Закрытый месяц: сотрудники, у которых зафиксированный расчёт расходится
  /// с текущими данными (иная сумма или дни, нет расчёта или он лишний).
  /// В открытом месяце всегда пусто.
  final Set<String> differs;

  const PayrollMonthReport({
    required this.year,
    required this.month,
    required this.locked,
    required this.results,
    required this.startingBalances,
    this.differs = const {},
  });
}

/// Расчёт ЗП поверх хранилища: загружает данные из репозиториев
/// и передаёт их в чистые функции из payroll.dart.
class PayrollService {
  final EmployeeRepository employees;
  final RateRepository rates;
  final TimesheetRepository timesheet;
  final PaymentRepository payments;
  final PayrollRepository payroll;

  PayrollService({
    required this.employees,
    required this.rates,
    required this.timesheet,
    required this.payments,
    required this.payroll,
  });

  /// Расчёт за месяц по табелю и истории ставок.
  Future<PayrollCalculation> calculateMonth(
    String employeeId,
    int year,
    int month,
  ) async {
    final employee = await employees.byId(employeeId);
    if (employee == null) throw StateError('Сотрудник не найден');
    final records = await timesheet.inPeriod(
      DateTime(year, month, 1),
      DateTime(year, month + 1, 0),
      employeeId: employeeId,
    );
    return calculateMonthlySalary(
      employeeId: employeeId,
      year: year,
      month: month,
      records: records,
      rates: await rates.history(employeeId),
    );
  }

  /// Сотрудники, которым в месяце что-то выплачено.
  Future<Set<String>> paidInMonth(int year, int month) async => {
        for (final p in await payments.list(
          start: DateTime(year, month, 1),
          end: DateTime(year, month + 1, 0),
        ))
          p.employeeId,
      };

  /// Считает и сохраняет месяц — для всех сотрудников (включая уволенных)
  /// или только для [employeeId]. Сотрудник без начислений, выплат за
  /// месяц и входящего остатка ([payrollNeeded]) в расчёт не входит:
  /// расчёт не сохраняется, а прежний сохранённый удаляется.
  Future<PayrollMonthSave> saveMonth(
    int year,
    int month, {
    String? employeeId,
  }) async {
    final ids = employeeId != null
        ? [employeeId]
        : [
            for (final e in await employees.all())
              if (e.id != null) e.id!,
          ];
    final paid = await paidInMonth(year, month);
    final balances = await startingBalances(DateTime(year, month, 1));
    var saved = 0, removed = 0;
    for (final id in ids) {
      final calc = await calculateMonth(id, year, month);
      if (payrollNeeded(
          emptyPayroll: calc.isEmpty,
          paidInMonth: paid.contains(id),
          startingBalance: balances[id] ?? 0)) {
        await payroll.save(PayrollResult.fromCalculation(calc));
        saved++;
      } else {
        final old = await payroll.resultFor(id, year, month);
        if (old?.id != null) {
          await payroll.delete(old!.id!);
          removed++;
        }
      }
    }
    return PayrollMonthSave(saved, removed);
  }

  /// Отчёт за месяц: открытый — свежий пересчёт, закрытый ([lockedMonths],
  /// ключи [PeriodGuard.monthKey]) — зафиксированный расчёт и отметка
  /// расхождений с текущими данными. Сохранённые расчёты открытых месяцев
  /// ведёт сервер; приложение их не пишет.
  Future<PayrollMonthReport> monthReport(
    int year,
    int month, {
    required Set<int> lockedMonths,
  }) async {
    final data = await _load(DateTime(year, month + 1, 0));
    final balances = await _balances(data, year, month, lockedMonths);
    final paid = await paidInMonth(year, month);
    bool needed(bool empty, String id) => payrollNeeded(
        emptyPayroll: empty,
        paidInMonth: paid.contains(id),
        startingBalance: balances[id] ?? 0);

    final fresh = <String, PayrollCalculation>{
      for (final id in data.employeeIds) id: data.calculate(id, year, month),
    };
    if (!lockedMonths.contains(PeriodGuard.monthKey(year, month))) {
      return PayrollMonthReport(
        year: year,
        month: month,
        locked: false,
        startingBalances: balances,
        results: [
          for (final id in data.employeeIds)
            if (needed(fresh[id]!.isEmpty, id))
              PayrollResult.fromCalculation(fresh[id]!),
        ],
      );
    }

    final saved = {
      for (final r in await payroll.forMonth(year, month)) r.employeeId: r,
    };
    final differs = <String>{};
    for (final id in {...data.employeeIds, ...saved.keys}) {
      final calc = fresh[id];
      final result = saved[id];
      final shouldHave = calc != null && needed(calc.isEmpty, id);
      final shown = result != null && needed(result.isEmpty, id);
      if (shouldHave != shown || (shouldHave && !_sameAsSaved(calc, result!))) {
        differs.add(id);
      }
    }
    final order = {for (final (i, id) in data.employeeIds.indexed) id: i};
    int rank(PayrollResult r) => order[r.employeeId] ?? order.length;
    return PayrollMonthReport(
      year: year,
      month: month,
      locked: true,
      startingBalances: balances,
      results: [
        for (final r in saved.values)
          if (needed(r.isEmpty, r.employeeId)) r,
      ]..sort((a, b) => rank(a).compareTo(rank(b))),
      differs: differs,
    );
  }

  /// Входящий остаток на 1-е число месяца по правилу отчёта: начислено за
  /// прошлые месяцы (закрытые — по зафиксированному расчёту, открытые — по
  /// свежему пересчёту) минус выплачено до 1-го числа. Так остаток не
  /// зависит от того, успел ли сервер пересчитать открытые месяцы.
  Future<Map<String, double>> currentBalances(
    int year,
    int month, {
    required Set<int> lockedMonths,
  }) async => _balances(
    await _load(DateTime(year, month, 0)),
    year,
    month,
    lockedMonths,
  );

  Future<Map<String, double>> _balances(
    _PayrollData data,
    int year,
    int month,
    Set<int> lockedMonths,
  ) async {
    final target = PeriodGuard.monthKey(year, month);
    final accrued = <String, double>{};
    void add(String id, double sum) => accrued[id] = (accrued[id] ?? 0) + sum;

    // Открытые месяцы — пересчёт по табелю (месяц без табеля начислений не
    // даёт).
    for (final (id, key) in data.monthsWithDays) {
      if (key >= target || lockedMonths.contains(key)) continue;
      add(id, data.calculate(id, key ~/ 12, key % 12 + 1).totalSalary);
    }
    // Закрытые — зафиксированный расчёт.
    for (final key in lockedMonths) {
      if (key >= target) continue;
      for (final r in await payroll.forMonth(key ~/ 12, key % 12 + 1)) {
        add(r.employeeId, r.totalSalary);
      }
    }
    return combineBalances(
      accrued: accrued,
      paid: await payments.paidBefore(DateTime(year, month, 1)),
    );
  }

  /// Сотрудники, табель по [end] включительно и ставки — для пересчёта.
  Future<_PayrollData> _load(DateTime end) async {
    final ids = [
      for (final e in await employees.all())
        if (e.id != null) e.id!,
    ];
    return _PayrollData(
      ids,
      await timesheet.inPeriod(DateTime(1900), end),
      {for (final id in ids) id: await rates.history(id)},
    );
  }

  static bool _sameAsSaved(PayrollCalculation c, PayrollResult r) {
    bool same(double a, double b) => (a - b).abs() < 0.001;
    return same(c.baseDays, r.baseDays) &&
        same(c.fieldDays, r.fieldDays) &&
        same(c.sickDays, r.sickDays) &&
        same(c.vacationDays, r.vacationDays) &&
        same(c.totalSalary, r.totalSalary) &&
        c.skippedWorkDays == r.skippedWorkDays;
  }

  /// Входящий остаток на начало месяца [date] по сохранённым расчётам:
  /// начислено за прошлые месяцы минус выплачено до 1-го числа. Так считает
  /// сервер и сверка выгрузки для импорта; для отчёта — [currentBalances].
  Future<Map<String, double>> startingBalances(DateTime date) async =>
      combineBalances(
        accrued: await payroll.accruedBefore(date.year, date.month),
        paid: await payments.paidBefore(DateTime(date.year, date.month, 1)),
      );
}

/// Данные для пересчёта: табель по сотрудникам и месяцам, ставки.
class _PayrollData {
  final List<String> employeeIds;
  final Map<String, List<EmployeeRate>> rates;
  final _days = <(String, int), List<TimesheetRecord>>{};

  _PayrollData(this.employeeIds, List<TimesheetRecord> records, this.rates) {
    final live = employeeIds.toSet();
    for (final r in records) {
      if (!live.contains(r.employeeId)) continue;
      final key = PeriodGuard.monthKey(r.date.year, r.date.month);
      (_days[(r.employeeId, key)] ??= []).add(r);
    }
  }

  /// (сотрудник, месяц) с записями табеля.
  Iterable<(String, int)> get monthsWithDays => _days.keys;

  PayrollCalculation calculate(String id, int year, int month) =>
      calculateMonthlySalary(
        employeeId: id,
        year: year,
        month: month,
        records: _days[(id, PeriodGuard.monthKey(year, month))] ?? const [],
        rates: rates[id] ?? const [],
      );
}
