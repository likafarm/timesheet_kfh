import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/services/app_database.dart';

/// Закрытые месяцы (шаг 3.6): правка в закрытом месяце не записывается,
/// пользователь получает объяснение. Правила — как у сервера (PeriodGuard,
/// тесты — packages/domain/test/period_guard_test.dart).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late LocalDatabase db;
  late AppProvider app;
  late String emp;

  final aug3 = DateTime(2026, 8, 3);
  final sep3 = DateTime(2026, 9, 3);

  TimesheetRecord work(DateTime day) => TimesheetRecord(
    employeeId: emp,
    date: day,
    dayType: 'work',
    days: 1,
    workPlace: 'field',
  );

  setUp(() async {
    db = LocalDatabase.memory();
    app = AppProvider(AppDatabase(db, ':memory:'));
    emp = await DriftRepositories(db).employees.add(
      Employee(
        fullName: 'Иванов Иван',
        position: 'Рабочий',
        hireDate: DateTime(2025, 3, 1),
        baseRate: 1000,
        fieldRate: 1500,
      ),
    );
    await LocalSyncStore(db).saveLockedMonths([(2026, 8)]);
    await app.loadAllData();
  });
  tearDown(() => db.close());

  Future<List<TimesheetRecord>> days() => DriftRepositories(
    db,
  ).timesheet.inPeriod(DateTime(2026, 1, 1), DateTime(2026, 12, 31));

  test('список закрытых месяцев читается из базы', () {
    expect(app.isMonthLocked(2026, 8), isTrue);
    expect(app.isMonthLocked(2026, 9), isFalse);
  });

  test('табель в закрытом месяце не записывается — объяснение', () async {
    await app.saveTimesheetRecord(work(aug3));
    await app.addTimesheetRecord(work(aug3));
    await app.saveDailyTimesheet([work(aug3)], aug3);
    expect(await days(), isEmpty);
    expect(app.takeNotice(), contains('Месяц 08.2026 закрыт'));
    expect(app.takeNotice(), isNull, reason: 'показывается один раз');

    await app.saveTimesheetRecord(work(sep3));
    expect(await days(), hasLength(1));
    expect(app.takeNotice(), isNull);
  });

  test('перенос дня в закрытый месяц и удаление в нём — нельзя', () async {
    await app.saveTimesheetRecord(work(sep3));
    await app.loadTimesheet(DateTime(2026, 9, 1), DateTime(2026, 9, 30));
    final rec = app.timesheetRecords.single;
    await app.updateTimesheetRecord(rec.copyWith(date: aug3));
    expect((await days()).single.date, sep3);
    expect(app.takeNotice(), contains('08.2026'));

    // Открыли месяц на сервере — дальше правки идут.
    await LocalSyncStore(db).saveLockedMonths([]);
    await app.loadLockedMonths();
    await app.saveTimesheetRecord(work(aug3));
    await LocalSyncStore(db).saveLockedMonths([(2026, 8)]);
    await app.loadLockedMonths();
    await app.loadTimesheet(DateTime(2026, 8, 1), DateTime(2026, 8, 31));
    await app.deleteTimesheetRecord(app.timesheetRecords.single.id!);
    expect(await days(), hasLength(2));
    expect(app.takeNotice(), contains('08.2026'));
  });

  test('отчёт: открытый месяц — пересчёт без записи, закрытый — '
      'зафиксированный расчёт', () async {
    final repos = DriftRepositories(db);
    await repos.rates.add(
      EmployeeRate(
        employeeId: emp,
        baseRate: 1000,
        fieldRate: 1500,
        startDate: DateTime(2025, 3, 1),
      ),
    );
    // Август закрыт: день и расчёт пришли с сервера (напрямую в базу).
    await repos.timesheet.add(work(aug3));
    await repos.payroll.save(
      PayrollResult(
        employeeId: emp,
        year: 2026,
        month: 8,
        baseDays: 0,
        fieldDays: 1,
        sickDays: 0,
        vacationDays: 0,
        totalSalary: 777,
      ),
    );
    await app.saveTimesheetRecord(work(sep3));

    await app.loadPayrollReport(2026, 9);
    var report = app.payrollReport!;
    expect(report.locked, isFalse);
    expect(app.payrollResults.single.totalSalary, 1500);
    expect(
      app.startingBalances[emp],
      777,
      reason: 'закрытый август — по зафиксированному расчёту',
    );
    expect(
      await repos.payroll.forMonth(2026, 9),
      isEmpty,
      reason: 'приложение расчёт не сохраняет',
    );

    await app.loadPayrollReport(2026, 8);
    report = app.payrollReport!;
    expect(report.locked, isTrue);
    expect(app.payrollResults.single.totalSalary, 777);
    expect(report.differs, {emp}, reason: 'по табелю вышло бы 1500');
  });

  test('выплаты в закрытом месяце — нельзя', () async {
    await app.addPayment(
      Payment(employeeId: emp, paymentDate: aug3, amount: 500),
    );
    expect(await DriftRepositories(db).payments.list(), isEmpty);
    expect(app.takeNotice(), contains('08.2026'));

    await app.addPayment(
      Payment(employeeId: emp, paymentDate: sep3, amount: 500),
    );
    expect(await DriftRepositories(db).payments.list(), hasLength(1));
  });

  test(
    'ставка, действующая в закрытом месяце, — нельзя (как на сервере)',
    () async {
      final refused = await app.addRate(
        EmployeeRate(
          employeeId: emp,
          baseRate: 1200,
          fieldRate: 1700,
          startDate: DateTime(2026, 7, 1),
        ),
      );
      expect(await DriftRepositories(db).rates.history(emp), isEmpty);
      expect(refused, contains('08.2026'));

      expect(
        await app.addRate(
          EmployeeRate(
            employeeId: emp,
            baseRate: 1200,
            fieldRate: 1700,
            startDate: DateTime(2026, 9, 1),
          ),
        ),
        isNull,
      );
      expect(await DriftRepositories(db).rates.history(emp), hasLength(1));
    },
  );

  test('ставка с начала в закрытом месяце: суммы и удаление — нельзя, '
      'новая ставка с открытого месяца — можно', () async {
    final repos = DriftRepositories(db);
    // Ставка с июля записана до закрытия августа.
    await repos.rates.add(
      EmployeeRate(
        employeeId: emp,
        baseRate: 1000,
        fieldRate: 1500,
        startDate: DateTime(2026, 7, 1),
      ),
    );
    final july = (await repos.rates.history(emp)).single;

    final amount = await app.updateRate(july.copyWith(baseRate: 1100));
    expect(amount, contains('08.2026'));
    expect(amount, contains('добавьте новую ставку'));
    expect(await app.deleteRate(july), contains('08.2026'));
    expect((await repos.rates.history(emp)).single.baseRate, 1000);

    // Новая ставка с сентября закрывает июльскую 31.08 — задеты только
    // открытые дни.
    expect(
      await app.addRate(
        EmployeeRate(
          employeeId: emp,
          baseRate: 1300,
          fieldRate: 1800,
          startDate: DateTime(2026, 9, 1),
        ),
      ),
      isNull,
    );
    final history = await repos.rates.history(emp);
    expect(history.first.endDate, DateTime(2026, 8, 31));
    expect(history.last.baseRate, 1300);
  });

  test('без закрытых месяцев ничего не мешает', () async {
    await LocalSyncStore(db).saveLockedMonths([]);
    await app.loadLockedMonths();
    await app.saveTimesheetRecord(work(aug3));
    expect(await days(), hasLength(1));
    expect(app.takeNotice(), isNull);
  });
}
