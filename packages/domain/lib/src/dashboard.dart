// packages/domain/lib/src/dashboard.dart
//
// Сводка главного экрана (6.8): долг по сотрудникам на сегодня, незакрытые
// прошлые месяцы и напоминания. Чистая функция поверх уже загруженных
// данных — суммы берутся из отчёта месяца (PayrollService.monthReport), своей
// формулы расчёта здесь нет.

import 'models/employee.dart';
import 'models/payment.dart';
import 'models/timesheet_record.dart';
import 'payroll.dart';
import 'payroll_service.dart';
import 'production_calendar.dart';
import 'sync/period_guard.dart';
import 'utils/date_utils.dart';

/// С какого числа напоминать, что прошлый месяц не закрыт (решение
/// владельца 2026-09-29): в первые дни ещё идут выплаты и правки.
const closeReminderDay = 5;

/// Долг хозяйства перед сотрудником на сегодня: остаток на 1-е число +
/// начислено за текущий месяц − выплачено в текущем месяце.
class EmployeeDebt {
  final String employeeId;
  final double opening;
  final double accrued;
  final double paid;

  const EmployeeDebt({
    required this.employeeId,
    required this.opening,
    required this.accrued,
    required this.paid,
  });

  /// Положительный — долг хозяйства, отрицательный — переплата.
  double get balance => opening + accrued - paid;
}

/// Рабочие дни без ставки у сотрудника за месяц — они не оплачиваются.
class UnpaidWorkDays {
  final String employeeId;
  final int year;
  final int month;
  final int days;

  const UnpaidWorkDays(this.employeeId, this.year, this.month, this.days);
}

/// Итог текущего месяца.
class MonthTotals {
  final double accrued;
  final double paid;
  final double baseDays;
  final double fieldDays;

  /// Рабочих дней по производственному календарю.
  final int normDays;

  const MonthTotals({
    required this.accrued,
    required this.paid,
    required this.baseDays,
    required this.fieldDays,
    required this.normDays,
  });
}

class DashboardSummary {
  /// Сегодня (местная полночь).
  final DateTime today;

  /// Долги и переплаты (ненулевые, от полкопейки) — по убыванию суммы.
  final List<EmployeeDebt> debts;

  /// Прошлые месяцы `(год, месяц)` с данными, которые ещё не закрыты, — по
  /// возрастанию.
  final List<(int, int)> openPastMonths;

  /// Пропущенные рабочие дни (по производственному календарю, по вчера):
  /// кто-то в этот день уже работал, но в табеле за день нет ни одной
  /// записи — день, скорее всего, забыли внести. По возрастанию.
  ///
  /// Отдельные пустые клетки не в счёт: табель ведётся выборочно, пустая
  /// клетка обычно значит «не работал» (так на реальных данных).
  final List<DateTime> missingDays;

  /// Неоплачиваемые дни без ставки — прошлый (если открыт) и текущий месяц.
  final List<UnpaidWorkDays> unpaidDays;

  final MonthTotals month;

  /// Все сотрудники (и уволенные) по id — для имён в сводке.
  final Map<String, Employee> employees;

  const DashboardSummary({
    required this.today,
    required this.employees,
    required this.debts,
    required this.openPastMonths,
    required this.missingDays,
    required this.unpaidDays,
    required this.month,
  });

  /// Всего должны сотрудникам (только положительные остатки).
  double get totalDebt =>
      debts.where((d) => d.balance > 0).fold(0.0, (sum, d) => sum + d.balance);

  /// Всего переплачено (положительным числом).
  double get totalOverpaid =>
      debts.where((d) => d.balance < 0).fold(0.0, (sum, d) => sum - d.balance);

  /// Незакрытые прошлые месяцы, о которых пора напомнить: прошлый месяц —
  /// с [closeReminderDay]-го числа, более ранние — всегда.
  List<(int, int)> get monthsToClose {
    final previous = PeriodGuard.monthKey(today.year, today.month) - 1;
    return [
      for (final (y, m) in openPastMonths)
        if (PeriodGuard.monthKey(y, m) < previous ||
            today.day >= closeReminderDay)
          (y, m),
    ];
  }
}

/// Сводка на [today].
///
/// [current] — отчёт текущего месяца; [previous] — отчёт прошлого месяца,
/// если он открыт (null — закрыт: его дни и ставки уже не поправить).
/// [records] — табель прошлого и текущего месяца, [currentPayments] —
/// выплаты текущего месяца, [dataMonths] — месяцы с табелем или выплатами,
/// [lockedMonths] — ключи [PeriodGuard.monthKey] закрытых месяцев.
DashboardSummary buildDashboard({
  required DateTime today,
  required List<Employee> employees,
  required List<TimesheetRecord> records,
  required PayrollMonthReport current,
  PayrollMonthReport? previous,
  required List<Payment> currentPayments,
  required List<(int, int)> dataMonths,
  required Set<int> lockedMonths,
}) {
  final day = calendarDay(today);

  // Долг на сегодня.
  final accrued = {
    for (final r in current.results) r.employeeId: r.totalSalary,
  };
  final paid = <String, double>{};
  for (final p in currentPayments) {
    paid[p.employeeId] = (paid[p.employeeId] ?? 0) + p.amount;
  }
  final debts =
      [
          for (final id in {
            ...current.startingBalances.keys,
            ...accrued.keys,
            ...paid.keys,
          })
            EmployeeDebt(
              employeeId: id,
              opening: current.startingBalances[id] ?? 0,
              accrued: accrued[id] ?? 0,
              paid: paid[id] ?? 0,
            ),
        ]
        ..removeWhere((d) => d.balance.abs() < balanceEpsilon)
        ..sort((a, b) => b.balance.compareTo(a.balance));

  // Незакрытые прошлые месяцы.
  final currentKey = PeriodGuard.monthKey(day.year, day.month);
  final openPast = [
    for (final (y, m) in dataMonths)
      if (PeriodGuard.monthKey(y, m) < currentKey &&
          !lockedMonths.contains(PeriodGuard.monthKey(y, m)))
        (y, m),
  ];

  // Пропущенные дни табеля: рабочие дни по вчера — прошлый месяц, если он
  // открыт и в нём есть данные, и текущий.
  final previousMonth = DateTime(day.year, day.month - 1, 1);
  final hasData = {for (final (y, m) in dataMonths) PeriodGuard.monthKey(y, m)};
  final checkPrevious =
      previous != null &&
      hasData.contains(
        PeriodGuard.monthKey(previousMonth.year, previousMonth.month),
      );
  final filled = {for (final r in records) calendarDay(r.date)};
  final missing = <DateTime>[
    for (
      var d = checkPrevious ? previousMonth : DateTime(day.year, day.month, 1);
      d.isBefore(day);
      d = addCalendarDays(d, 1)
    )
      if (ProductionCalendar.isWorkingDay(d) &&
          !filled.contains(d) &&
          employees.any(
            (e) => !calendarDay(e.hireDate).isAfter(d) && e.isActiveOn(d),
          ))
        d,
  ];

  // Рабочие дни без ставки.
  final unpaid = [
    for (final report in [?previous, current])
      for (final r in report.results)
        if (r.skippedWorkDays > 0)
          UnpaidWorkDays(r.employeeId, r.year, r.month, r.skippedWorkDays),
  ];

  return DashboardSummary(
    today: day,
    employees: {
      for (final e in employees)
        if (e.id != null) e.id!: e,
    },
    debts: debts,
    openPastMonths: openPast,
    missingDays: missing,
    unpaidDays: unpaid,
    month: MonthTotals(
      accrued: accrued.values.fold(0.0, (s, v) => s + v),
      paid: paid.values.fold(0.0, (s, v) => s + v),
      baseDays: current.results.fold(0.0, (s, r) => s + r.baseDays),
      fieldDays: current.results.fold(0.0, (s, r) => s + r.fieldDays),
      normDays: ProductionCalendar.monthNorm(day.year, day.month).workdays,
    ),
  );
}
