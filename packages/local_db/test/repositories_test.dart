import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:test/test.dart';

void main() {
  late LocalDatabase db;
  late DriftRepositories repo;

  setUp(() {
    db = LocalDatabase.memory(clock: () => DateTime.utc(2026, 9, 26, 10));
    repo = DriftRepositories(db);
  });
  tearDown(() => db.close());

  Future<String> addEmployee(String name, {DateTime? dismissal}) =>
      repo.employees.add(
        Employee(
          fullName: name,
          position: 'Рабочий',
          hireDate: DateTime(2025, 3, 1),
          dismissalDate: dismissal,
          baseRate: 1000,
          fieldRate: 1500,
        ),
      );

  TimesheetRecord work(
    String emp,
    DateTime date, {
    String place = 'field',
    double days = 1,
  }) => TimesheetRecord(
    employeeId: emp,
    date: date,
    dayType: 'work',
    days: days,
    workPlace: place,
  );

  group('сотрудники', () {
    test('добавление, чтение, правка, увольнение', () async {
      final id = await addEmployee('Иванов Иван Иванович');
      final e = (await repo.employees.byId(id))!;
      expect(e.id, id);
      expect(e.fullName, 'Иванов Иван Иванович');
      expect(e.hireDate, DateTime(2025, 3, 1));
      expect(e.dismissalDate, isNull);
      expect((e.baseRate, e.fieldRate), (1000, 1500));

      await repo.employees.update(
        e.copyWith(position: 'Тракторист', dismissalDate: DateTime(2026, 9, 1)),
      );
      final updated = (await repo.employees.byId(id))!;
      expect(updated.position, 'Тракторист');
      expect(updated.dismissalDate, DateTime(2026, 9, 1));

      expect(
        await repo.employees.all(activeOn: DateTime(2026, 9, 26)),
        isEmpty,
      );
      expect(await repo.employees.all(), hasLength(1));
    });

    test('удаление скрывает сотрудника', () async {
      final id = await addEmployee('Иванов Иван');
      await repo.employees.delete(id);
      expect(await repo.employees.byId(id), isNull);
      expect(await repo.employees.all(), isEmpty);
    });

    test('правка без id — ошибка', () async {
      expect(
        () => repo.employees.update(
          Employee(
            fullName: 'Без id',
            position: 'Рабочий',
            hireDate: DateTime(2025, 1, 1),
            baseRate: 0,
            fieldRate: 0,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  test('ставки: новая закрывает прежнюю', () async {
    final emp = await addEmployee('Иванов Иван');
    await repo.rates.add(
      EmployeeRate(
        employeeId: emp,
        baseRate: 1000,
        fieldRate: 1500,
        startDate: DateTime(2026, 1, 1),
      ),
    );
    await repo.rates.add(
      EmployeeRate(
        employeeId: emp,
        baseRate: 1100,
        fieldRate: 1600,
        startDate: DateTime(2026, 3, 1),
      ),
    );
    final history = await repo.rates.history(emp);
    expect(history.first.endDate, DateTime(2026, 2, 28));
    expect(history.last.endDate, isNull);
    expect(history.every((r) => r.employeeId == emp), isTrue);
    expect((await repo.rates.at(emp, DateTime(2026, 3, 1)))!.baseRate, 1100);
  });

  group('табель', () {
    test('добавление и чтение, дубль отклоняется', () async {
      final emp = await addEmployee('Иванов Иван');
      final id = await repo.timesheet.add(
        work(emp, DateTime(2026, 9, 1), place: 'base', days: 0.5),
      );
      final r = (await repo.timesheet.on(emp, DateTime(2026, 9, 1)))!;
      expect(r.id, id);
      expect(r.employeeId, emp);
      expect(r.date, DateTime(2026, 9, 1));
      expect((r.dayType, r.days, r.workPlace), ('work', 0.5, 'base'));

      expect(
        () => repo.timesheet.add(work(emp, DateTime(2026, 9, 1))),
        throwsA(isA<DuplicateEntryException>()),
      );
    });

    test('правка и удаление', () async {
      final emp = await addEmployee('Иванов Иван');
      await repo.timesheet.add(work(emp, DateTime(2026, 9, 1)));
      final r = (await repo.timesheet.on(emp, DateTime(2026, 9, 1)))!;

      await repo.timesheet.update(
        r.copyWith(dayType: 'sick', days: 0, notes: 'справка'),
      );
      final changed = (await repo.timesheet.on(emp, DateTime(2026, 9, 1)))!;
      expect((changed.dayType, changed.notes), ('sick', 'справка'));
      expect(changed.createdAt, r.createdAt);

      await repo.timesheet.delete(r.id!);
      expect(await repo.timesheet.on(emp, DateTime(2026, 9, 1)), isNull);
    });
  });

  test('выплаты: поля переживают сохранение', () async {
    final emp = await addEmployee('Иванов Иван');
    final id = await repo.payments.add(
      Payment(
        employeeId: emp,
        paymentDate: DateTime(2026, 9, 5),
        amount: 12345.67,
        paymentType: 'advance',
        periodStart: '2026-09-01',
        periodEnd: '2026-09-30',
        paymentMethod: 'card',
        documentNumber: '№ 7',
        notes: 'аванс',
      ),
    );
    final p = (await repo.payments.list(employeeId: emp)).single;
    expect(p.id, id);
    expect(p.paymentDate, DateTime(2026, 9, 5));
    expect(p.amount, 12345.67);
    expect(
      (p.paymentType, p.periodStart, p.periodEnd, p.paymentMethod),
      ('advance', '2026-09-01', '2026-09-30', 'card'),
    );
    expect((p.documentNumber, p.notes), ('№ 7', 'аванс'));

    await repo.payments.update(p.copyWith(amount: 100));
    expect((await repo.payments.list()).single.amount, 100);
    await repo.payments.delete(id);
    expect(await repo.payments.list(), isEmpty);
  });

  test('расчёты: сохранение заменяет прежний за месяц', () async {
    final emp = await addEmployee('Иванов Иван');
    final calculatedAt = DateTime(2026, 9, 26, 12, 30);
    PayrollResult result(double total) => PayrollResult(
      employeeId: emp,
      year: 2026,
      month: 8,
      baseDays: 2,
      fieldDays: 3.5,
      sickDays: 1,
      vacationDays: 0,
      totalSalary: total,
      baseRateUsed: 1000,
      fieldRateUsed: 1500,
      calculatedAt: calculatedAt,
      skippedWorkDays: 1,
    );
    final first = await repo.payroll.save(result(7250));
    final second = await repo.payroll.save(result(8000));
    expect(second, first);

    final saved = (await repo.payroll.resultFor(emp, 2026, 8))!;
    expect(saved.totalSalary, 8000);
    expect((saved.baseDays, saved.fieldDays, saved.sickDays), (2, 3.5, 1));
    expect(saved.skippedWorkDays, 1);
    expect(saved.calculatedAt, calculatedAt);
    expect(await repo.payroll.forMonth(2026, 8), hasLength(1));
  });

  test('настройки хозяйства: чтение и сохранение', () async {
    final s = await repo.settings.get();
    expect(s.companyName, 'КФХ');
    await repo.settings.save(s.copyWith(companyName: 'КФХ Лика', inn: '123'));
    final saved = await repo.settings.get();
    expect((saved.companyName, saved.inn), ('КФХ Лика', '123'));
  });

  group('PayrollService', () {
    test('расчёт месяца по табелю и ставкам', () async {
      final emp = await addEmployee('Иванов Иван');
      await repo.rates.add(
        EmployeeRate(
          employeeId: emp,
          baseRate: 1000,
          fieldRate: 1500,
          startDate: DateTime(2026, 8, 1),
        ),
      );
      await repo.rates.add(
        EmployeeRate(
          employeeId: emp,
          baseRate: 1200,
          fieldRate: 1800,
          startDate: DateTime(2026, 8, 16),
        ),
      );
      await repo.timesheet.add(work(emp, DateTime(2026, 8, 15), place: 'base'));
      await repo.timesheet.add(work(emp, DateTime(2026, 8, 16), days: 0.5));
      await repo.timesheet.add(work(emp, DateTime(2026, 9, 1)));

      final calc = await repo.payrollService.calculateMonth(emp, 2026, 8);
      expect(calc.employeeId, emp);
      expect(calc.totalSalary, 1000 + 900);
      expect((calc.baseDays, calc.fieldDays), (1, 0.5));
    });

    test('расчёт для неизвестного сотрудника — ошибка', () async {
      expect(
        () => repo.payrollService.calculateMonth('нет-такого', 2026, 8),
        throwsStateError,
      );
    });

    test(
      'входящий остаток: начислено до месяца минус выплачено до 1-го',
      () async {
        final a = await addEmployee('Иванов Иван');
        final b = await addEmployee('Петров Пётр');
        PayrollResult result(String emp, int month, double total) =>
            PayrollResult(
              employeeId: emp,
              year: 2026,
              month: month,
              baseDays: 0,
              fieldDays: 0,
              sickDays: 0,
              vacationDays: 0,
              totalSalary: total,
            );
        await repo.payroll.save(result(a, 7, 10000));
        await repo.payroll.save(result(a, 8, 5000));
        await repo.payroll.save(result(a, 9, 99999)); // текущий — не входит
        await repo.payments.add(
          Payment(
            employeeId: a,
            paymentDate: DateTime(2026, 8, 31),
            amount: 12000,
          ),
        );
        await repo.payments.add(
          Payment(
            employeeId: a,
            paymentDate: DateTime(2026, 9, 1),
            amount: 99999,
          ),
        );
        await repo.payments.add(
          Payment(
            employeeId: b,
            paymentDate: DateTime(2026, 8, 10),
            amount: 500,
          ),
        );

        final balances = await repo.payrollService.startingBalances(
          DateTime(2026, 9, 15),
        );
        expect(balances, {a: 3000, b: -500});
      },
    );
  });
}
