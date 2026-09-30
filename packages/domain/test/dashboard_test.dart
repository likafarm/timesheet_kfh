import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

Employee _emp(String id, {DateTime? hired, DateTime? dismissed}) => Employee(
  id: id,
  fullName: id,
  position: '',
  hireDate: hired ?? DateTime(2020, 1, 1),
  dismissalDate: dismissed,
  baseRate: 0,
  fieldRate: 0,
);

PayrollResult _result(
  String id,
  int year,
  int month, {
  double total = 0,
  double base = 0,
  double field = 0,
  int skipped = 0,
}) => PayrollResult(
  employeeId: id,
  year: year,
  month: month,
  baseDays: base,
  fieldDays: field,
  sickDays: 0,
  vacationDays: 0,
  totalSalary: total,
  skippedWorkDays: skipped,
);

PayrollMonthReport _report(
  int year,
  int month, {
  List<PayrollResult> results = const [],
  Map<String, double> balances = const {},
  bool locked = false,
}) => PayrollMonthReport(
  year: year,
  month: month,
  locked: locked,
  results: results,
  startingBalances: balances,
);

TimesheetRecord _day(String id, DateTime d) =>
    TimesheetRecord(employeeId: id, date: d, days: 1, workPlace: 'base');

/// Все рабочие дни с [from] по [to] включительно.
List<DateTime> _workdays(DateTime from, DateTime to) => [
  for (var d = from; !d.isAfter(to); d = addCalendarDays(d, 1))
    if (ProductionCalendar.isWorkingDay(d)) d,
];

void main() {
  group('долг на сегодня', () {
    test('остаток на 1-е + начислено − выплачено, по убыванию', () {
      final s = buildDashboard(
        today: DateTime(2026, 9, 29),
        employees: [_emp('a'), _emp('b'), _emp('c'), _emp('d')],
        records: const [],
        current: _report(
          2026,
          9,
          results: [_result('a', 2026, 9, total: 10000)],
          balances: {'a': 2000, 'b': 500, 'c': 0.001},
        ),
        currentPayments: [
          Payment(
            employeeId: 'a',
            paymentDate: DateTime(2026, 9, 10),
            amount: 3000,
          ),
          Payment(
            employeeId: 'a',
            paymentDate: DateTime(2026, 9, 20),
            amount: 1000,
          ),
          Payment(
            employeeId: 'd',
            paymentDate: DateTime(2026, 9, 5),
            amount: 700,
          ),
        ],
        dataMonths: const [],
        lockedMonths: const {},
      );
      expect(
        [for (final d in s.debts) (d.employeeId, d.balance)],
        [('a', 8000), ('b', 500), ('d', -700)],
      );
      final a = s.debts.first;
      expect((a.opening, a.accrued, a.paid), (2000, 10000, 4000));
      expect(s.totalDebt, 8500);
      expect(s.totalOverpaid, 700);
      expect(s.month.accrued, 10000);
      expect(s.month.paid, 4700);
    });
  });

  group('закрытие месяцев', () {
    List<(int, int)> toClose(DateTime today, Set<int> locked) => buildDashboard(
      today: today,
      employees: const [],
      records: const [],
      current: _report(today.year, today.month),
      currentPayments: const [],
      dataMonths: const [(2026, 7), (2026, 8), (2026, 9), (2026, 10)],
      lockedMonths: locked,
    ).monthsToClose;

    test('прошлый месяц — только с 5-го числа, более ранние — всегда', () {
      final locked = {PeriodGuard.monthKey(2026, 7)};
      expect(toClose(DateTime(2026, 10, 4), locked), [(2026, 8)]);
      expect(toClose(DateTime(2026, 10, 5), locked), [(2026, 8), (2026, 9)]);
    });

    test('текущий и закрытые не напоминаются', () {
      final s = buildDashboard(
        today: DateTime(2026, 9, 29),
        employees: const [],
        records: const [],
        current: _report(2026, 9),
        currentPayments: const [],
        dataMonths: const [(2026, 7), (2026, 8), (2026, 9)],
        lockedMonths: {PeriodGuard.monthKey(2026, 8)},
      );
      expect(s.openPastMonths, [(2026, 7)]);
    });
  });

  group('пропущенные дни табеля', () {
    DashboardSummary summary({
      required DateTime today,
      required List<Employee> employees,
      List<TimesheetRecord> records = const [],
      bool previousOpen = true,
      List<(int, int)> dataMonths = const [(2026, 9), (2026, 10)],
    }) => buildDashboard(
      today: today,
      employees: employees,
      records: records,
      current: _report(today.year, today.month),
      previous: previousOpen ? _report(today.year, today.month - 1) : null,
      currentPayments: const [],
      dataMonths: dataMonths,
      lockedMonths: const {},
    );

    test('рабочие дни по вчера без единой записи, сегодняшний не в счёт', () {
      final s = summary(
        today: DateTime(2026, 9, 29),
        employees: [_emp('a'), _emp('b')],
        dataMonths: const [(2026, 9)],
        records: [
          // У «b» клетки пустые — это не пропуск: день внесён.
          for (final d in _workdays(
            DateTime(2026, 9, 1),
            DateTime(2026, 9, 24),
          ))
            _day('a', d),
        ],
      );
      // 26–27.09 — выходные, 29-е — сегодня.
      expect(s.missingDays, [DateTime(2026, 9, 25), DateTime(2026, 9, 28)]);
    });

    test('день внесён, если есть любая запись (и не «работа»)', () {
      final s = summary(
        today: DateTime(2026, 9, 29),
        employees: [_emp('a')],
        dataMonths: const [(2026, 9)],
        records: [
          for (final d in _workdays(
            DateTime(2026, 9, 1),
            DateTime(2026, 9, 28),
          ))
            TimesheetRecord(employeeId: 'a', date: d, dayType: 'sick'),
        ],
      );
      expect(s.missingDays, isEmpty);
    });

    test('праздники и переносы — по производственному календарю', () {
      // 2027: 1–8 января — праздники, 9-е и 10-е — выходные.
      final s = summary(
        today: DateTime(2027, 1, 12),
        employees: [_emp('a')],
        previousOpen: false,
      );
      expect(s.missingDays, [DateTime(2027, 1, 11)]);
    });

    test(
      'дни, когда никто не работал (до приёма, с увольнения), — не нужны',
      () {
        final s = summary(
          today: DateTime(2026, 10, 8),
          employees: [
            _emp('new', hired: DateTime(2026, 10, 6)),
            _emp('gone', dismissed: DateTime(2026, 10, 2)),
          ],
          previousOpen: false,
        );
        // 2-го уволен один, принят другой только 6-го: 2.10 никого нет.
        expect([for (final d in s.missingDays) d.day], [1, 6, 7]);
      },
    );

    test('прошлый месяц — только открытый и с данными', () {
      final employees = [_emp('a')];
      final today = DateTime(2026, 10, 2);
      bool hasSeptember(DashboardSummary s) =>
          s.missingDays.any((d) => d.month == 9);
      expect(hasSeptember(summary(today: today, employees: employees)), isTrue);
      expect(
        hasSeptember(
          summary(today: today, employees: employees, previousOpen: false),
        ),
        isFalse,
      );
      expect(
        hasSeptember(
          summary(
            today: today,
            employees: employees,
            dataMonths: const [(2026, 10)],
          ),
        ),
        isFalse,
      );
    });
  });

  test('дни без ставки и итог месяца', () {
    final s = buildDashboard(
      today: DateTime(2026, 10, 15),
      employees: const [],
      records: const [],
      previous: _report(2026, 9, results: [_result('a', 2026, 9, skipped: 2)]),
      current: _report(
        2026,
        10,
        results: [
          _result('a', 2026, 10, total: 5000, base: 3, field: 2),
          _result('b', 2026, 10, total: 1000, base: 1, skipped: 1),
        ],
      ),
      currentPayments: const [],
      dataMonths: const [],
      lockedMonths: const {},
    );
    expect(
      [for (final u in s.unpaidDays) (u.employeeId, u.month, u.days)],
      [('a', 9, 2), ('b', 10, 1)],
    );
    expect((s.month.baseDays, s.month.fieldDays), (4, 2));
    expect(s.month.normDays, ProductionCalendar.monthNorm(2026, 10).workdays);
  });

  test('дни с ошибкой отметки — за всё время, по дате', () {
    final bad1 = TimesheetRecord(
      employeeId: 'a',
      date: DateTime(2026, 9, 3),
      days: 1,
    );
    final bad0 = TimesheetRecord(
      employeeId: 'b',
      date: DateTime(2025, 1, 10),
      days: 0.25,
      workPlace: 'base',
    );
    final s = buildDashboard(
      today: DateTime(2026, 10, 1),
      employees: const [],
      records: const [],
      current: _report(2026, 10),
      currentPayments: const [],
      dataMonths: const [],
      lockedMonths: const {},
      allRecords: [
        bad1,
        _day('a', DateTime(2026, 9, 4)),
        TimesheetRecord(
          employeeId: 'a',
          date: DateTime(2026, 9, 5),
          dayType: 'dayoff',
          days: 1,
          workPlace: 'field',
        ),
        bad0,
      ],
    );
    expect(s.invalidDays, [bad0, bad1]);
  });
}
