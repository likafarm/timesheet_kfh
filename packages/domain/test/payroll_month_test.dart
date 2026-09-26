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
  Future<Map<String, double>> paidBefore(DateTime date) async => {};
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
  Future<Map<String, double>> accruedBefore(int year, int month) async => {};
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
        for (final id in ['работал', 'только выплата', 'только выходные', 'больничный'])
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

  test('правило: нужен при начислениях или выплатах в месяце', () {
    expect(payrollNeeded(emptyPayroll: true, paidInMonth: false), isFalse);
    expect(payrollNeeded(emptyPayroll: true, paidInMonth: true), isTrue);
    expect(payrollNeeded(emptyPayroll: false, paidInMonth: false), isTrue);
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
