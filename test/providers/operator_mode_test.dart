import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/services/app_database.dart';

/// Программа оператора (шаг 4.2): записывается только табель. Сервер
/// проверяет те же права сам (server/lib/src/auth/permissions.dart).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late DriftRepositories repos;
  late AppProvider app;
  late String emp;

  setUp(() async {
    db = LocalDatabase.memory();
    repos = DriftRepositories(db);
    app = AppProvider(AppDatabase(db, ':memory:'), operatorMode: true);
    emp = await repos.employees.add(
      Employee(
        fullName: 'Иванов Иван',
        position: 'Рабочий',
        hireDate: DateTime(2025, 3, 1),
        baseRate: 0,
        fieldRate: 0,
      ),
    );
    await app.loadAllData();
  });
  tearDown(() => db.close());

  test('табель записывается', () async {
    final day = DateTime(2026, 9, 3);
    await app.saveTimesheetRecord(
      TimesheetRecord(
        employeeId: emp,
        date: day,
        dayType: 'work',
        days: 1,
        workPlace: 'field',
      ),
    );
    expect(await repos.timesheet.on(emp, day), isNotNull);
    expect(app.takeNotice(), isNull);
  });

  test('сотрудники, ставки, выплаты, расчёт, настройки — нет', () async {
    final employee = app.employees.single;
    await app.updateEmployee(employee.copyWith(fullName: 'Другой'));
    expect(app.takeNotice(), contains('только табель'));
    await app.addEmployee(employee.copyWith(fullName: 'Новый'));
    await app.addEmployeeRate(
      EmployeeRate(
        employeeId: emp,
        baseRate: 1,
        fieldRate: 1,
        startDate: DateTime(2026, 9, 1),
      ),
    );
    await app.addPayment(
      Payment(employeeId: emp, amount: 100, paymentDate: DateTime(2026, 9, 5)),
    );
    await app.calculatePayrollForMonth(2026, 9);
    await app.updateCompanySettings(
      (await repos.settings.get()).copyWith(companyName: 'Чужое'),
    );

    final employees = await repos.employees.all();
    expect(employees.single.fullName, 'Иванов Иван');
    expect(await repos.rates.history(emp), isEmpty);
    expect(
      await repos.payments.list(),
      isEmpty,
    );
    expect(await repos.payroll.resultFor(emp, 2026, 9), isNull);
    expect((await repos.settings.get()).companyName, isNot('Чужое'));
  });
}
