import 'package:kfh_domain/kfh_domain.dart';
import 'package:test/test.dart';

// Хранилище в памяти — ровно столько, сколько нужно PayrollService.

class _Employees implements EmployeeRepository {
  final List<Employee> list;
  _Employees(this.list);
  @override
  Future<List<Employee>> all({DateTime? activeOn}) async => list;
  @override
  Future<Employee?> byId(String id) async =>
      list.where((e) => e.id == id).firstOrNull;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Rates implements RateRepository {
  final List<EmployeeRate> list;
  _Rates(this.list);
  @override
  Future<List<EmployeeRate>> history(String employeeId) async =>
      list.where((r) => r.employeeId == employeeId).toList();
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Timesheet implements TimesheetRepository {
  final List<TimesheetRecord> list;
  _Timesheet(this.list);
  @override
  Future<List<TimesheetRecord>> inPeriod(DateTime start, DateTime end,
          {String? employeeId}) async =>
      list
          .where((r) =>
              (employeeId == null || r.employeeId == employeeId) &&
              !r.date.isBefore(start) &&
              !r.date.isAfter(end))
          .toList();
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Payments implements PaymentRepository {
  final List<Payment> items;
  _Payments(this.items);
  @override
  Future<List<Payment>> list({String? employeeId, DateTime? start, DateTime? end}) async =>
      items
          .where((p) =>
              (employeeId == null || p.employeeId == employeeId) &&
              (start == null || !p.paymentDate.isBefore(start)) &&
              (end == null || !p.paymentDate.isAfter(end)))
          .toList();
  @override
  Future<Map<String, double>> paidBefore(DateTime date) async {
    final sums = <String, double>{};
    for (final p in items.where((p) => p.paymentDate.isBefore(date))) {
      sums[p.employeeId] = (sums[p.employeeId] ?? 0) + p.amount;
    }
    return sums;
  }
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Payroll implements PayrollRepository {
  final saved = <String, PayrollResult>{};
  final deleted = <String>[];
  var _n = 0;

  @override
  Future<String> save(PayrollResult r) async {
    final old = await resultFor(r.employeeId, r.year, r.month);
    final id = old?.id ?? 'p${++_n}';
    saved[id] = r.copyWith(id: id);
    return id;
  }

  @override
  Future<void> delete(String id) async {
    saved.remove(id);
    deleted.add(id);
  }

  @override
  Future<PayrollResult?> resultFor(String employeeId, int year, int month) async =>
      saved.values
          .where((r) =>
              r.employeeId == employeeId && r.year == year && r.month == month)
          .firstOrNull;

  @override
  Future<List<PayrollResult>> forMonth(int year, int month) async =>
      saved.values.where((r) => r.year == year && r.month == month).toList();

  @override
  Future<Map<String, double>> accruedBefore(int year, int month) async {
    final sums = <String, double>{};
    for (final r in saved.values
        .where((r) => r.year < year || (r.year == year && r.month < month))) {
      sums[r.employeeId] = (sums[r.employeeId] ?? 0) + r.totalSalary;
    }
    return sums;
  }
}

Employee _employee(String id, {DateTime? dismissed}) => Employee(
      id: id,
      fullName: id,
      position: 'Рабочий',
      hireDate: DateTime(2026, 1, 1),
      dismissalDate: dismissed,
      baseRate: 0,
      fieldRate: 0,
    );

void main() {
  late _Payroll payroll;
  late List<TimesheetRecord> days;
  late List<Payment> payments;
  late PayrollService service;

  setUp(() {
    payroll = _Payroll();
    days = [];
    payments = [];
    service = PayrollService(
      employees: _Employees([
        _employee('работал'),
        _employee('только выплата'),
        _employee('только выходные'),
        _employee('без ставки'),
        _employee('больничный'),
        _employee('уволен', dismissed: DateTime(2026, 8, 31)),
      ]),
      rates: _Rates([
        for (final id in ['работал', 'только выплата', 'только выходные', 'больничный', 'уволен'])
          EmployeeRate(
              employeeId: id,
              baseRate: 1000,
              fieldRate: 1500,
              startDate: DateTime(2026, 1, 1)),
      ]),
      timesheet: _Timesheet(days),
      payments: _Payments(payments),
      payroll: payroll,
    );
    days.addAll([
      TimesheetRecord(
          employeeId: 'работал',
          date: DateTime(2026, 9, 1),
          dayType: 'work',
          days: 1,
          workPlace: 'field'),
      TimesheetRecord(
          employeeId: 'только выходные',
          date: DateTime(2026, 9, 6),
          dayType: 'dayoff',
          days: 1),
      TimesheetRecord(
          employeeId: 'без ставки',
          date: DateTime(2026, 9, 2),
          dayType: 'work',
          days: 1,
          workPlace: 'field'),
      TimesheetRecord(
          employeeId: 'больничный',
          date: DateTime(2026, 9, 3),
          dayType: 'sick',
          days: 1),
      // Соседние месяцы в сентябрь не попадают.
      TimesheetRecord(
          employeeId: 'уволен',
          date: DateTime(2026, 8, 31),
          dayType: 'work',
          days: 1,
          workPlace: 'field'),
    ]);
    payments.addAll([
      Payment(employeeId: 'только выплата', paymentDate: DateTime(2026, 9, 30), amount: 500),
      Payment(employeeId: 'уволен', paymentDate: DateTime(2026, 10, 1), amount: 100),
    ]);
  });

  test('правило: нужен при начислениях, выплатах или входящем остатке', () {
    bool needed(bool empty, bool paid, double balance) => payrollNeeded(
        emptyPayroll: empty, paidInMonth: paid, startingBalance: balance);
    expect(needed(true, false, 0), isFalse);
    expect(needed(true, true, 0), isTrue);
    expect(needed(false, false, 0), isTrue);
    expect(needed(true, false, 1500), isTrue, reason: 'долг хозяйства');
    expect(needed(true, false, -200), isTrue, reason: 'переплата');
    expect(needed(true, false, 0.004), isFalse, reason: 'погрешность сложения');
    expect(needed(true, false, 0.01), isTrue, reason: 'копейка — уже остаток');
  });

  test('долг с прошлого месяца оставляет в расчёте и отчёте, погашенный — нет',
      () async {
    // Август: «уволен» работал 31.08 (1500 ₽), ничего не выплачено.
    await service.saveMonth(2026, 8);
    expect(await payroll.resultFor('уволен', 2026, 8), isNotNull);
    // Сентябрь: у него ни дней, ни выплат, но остаток 1500 — он в расчёте.
    await service.saveMonth(2026, 9);
    final september = await payroll.resultFor('уволен', 2026, 9);
    expect(september, isNotNull);
    expect(september!.totalSalary, 0);
    expect((await service.resultsForReport(2026, 9)).map((r) => r.employeeId),
        contains('уволен'));

    // Долг погашен в августе — в сентябре остаток ноль, строка уходит.
    payments.add(Payment(
        employeeId: 'уволен', paymentDate: DateTime(2026, 8, 31), amount: 1500));
    expect((await service.resultsForReport(2026, 9)).map((r) => r.employeeId),
        isNot(contains('уволен')));
    final again = await service.saveMonth(2026, 9, employeeId: 'уволен');
    expect((again.saved, again.removed), (0, 1));
  });

  test('переплата (отрицательный остаток) тоже оставляет в отчёте', () async {
    payments.add(Payment(
        employeeId: 'только выходные', paymentDate: DateTime(2026, 8, 20), amount: 300));
    await service.saveMonth(2026, 9);
    expect(await payroll.resultFor('только выходные', 2026, 9), isNotNull);
  });

  test('saveMonth: пустые не сохраняются; выплата, больничный и дни без '
      'ставки — сохраняются', () async {
    final result = await service.saveMonth(2026, 9);
    expect(result.saved, 4);
    expect(result.removed, 0);
    expect(payroll.saved.values.map((r) => r.employeeId).toSet(),
        {'работал', 'только выплата', 'без ставки', 'больничный'});
    final paidOnly =
        payroll.saved.values.firstWhere((r) => r.employeeId == 'только выплата');
    expect(paidOnly.isEmpty, isTrue, reason: 'начислений нет, но есть выплата');
  });

  test('ставший пустым расчёт удаляется при пересчёте месяца и сотрудника',
      () async {
    await service.saveMonth(2026, 9);
    days.removeWhere((d) => d.employeeId == 'работал');
    final all = await service.saveMonth(2026, 9);
    expect(all.removed, 1);
    expect(await payroll.resultFor('работал', 2026, 9), isNull);

    days.removeWhere((d) => d.employeeId == 'больничный');
    final single = await service.saveMonth(2026, 9, employeeId: 'больничный');
    expect((single.saved, single.removed), (0, 1));
    // Повтор ничего не удаляет.
    expect((await service.saveMonth(2026, 9, employeeId: 'больничный')).removed, 0);
  });

  test('отчёт скрывает пустые строки, оставшиеся от старых расчётов',
      () async {
    // Как в базе до исправления: сохранены нулевые расчёты всех.
    for (final id in ['только выходные', 'уволен', 'только выплата']) {
      await payroll.save(PayrollResult(
          employeeId: id,
          year: 2026,
          month: 9,
          baseDays: 0,
          fieldDays: 0,
          sickDays: 0,
          vacationDays: 0,
          totalSalary: 0));
    }
    await service.saveMonth(2026, 9, employeeId: 'работал');
    final report = await service.resultsForReport(2026, 9);
    expect(report.map((r) => r.employeeId).toSet(), {'работал', 'только выплата'});
  });

  test('выплата 30-го числа — в сентябре, 1-го октября — уже нет', () async {
    expect(await service.paidInMonth(2026, 9), {'только выплата'});
    expect(await service.paidInMonth(2026, 10), {'уволен'});
  });

  group('день увольнения', () {
    final e = _employee('x', dismissed: DateTime(2026, 9, 30));
    test('накануне — работает, в день увольнения — уже нет', () {
      expect(e.isActiveOn(DateTime(2026, 9, 29, 23, 59)), isTrue);
      expect(e.isActiveOn(DateTime(2026, 9, 30, 0, 1)), isFalse);
      expect(e.isActiveOn(DateTime(2026, 9, 30, 23, 59)), isFalse);
    });
    test('время в дате увольнения не влияет', () {
      final withTime = _employee('y', dismissed: DateTime(2026, 9, 30, 15, 0));
      expect(withTime.isActiveOn(DateTime(2026, 9, 30, 9, 0)), isFalse);
      expect(withTime.isActiveOn(DateTime(2026, 9, 29, 23, 0)), isTrue);
    });
  });
}
