import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:kfh_domain/kfh_domain.dart' show DuplicateEntryException;
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:test/test.dart';

/// Часы, которые двигает тест.
class FakeClock {
  DateTime now = DateTime.utc(2026, 9, 26, 10);
  DateTime call() => now;
  void advance([Duration d = const Duration(minutes: 1)]) => now = now.add(d);
}

final _uuidV7 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

const _businessTables = [
  'company_settings',
  'employees',
  'employee_rates',
  'timesheet',
  'payments',
  'sick_leave',
  'vacation',
  'payroll_results',
];

void main() {
  // В тестах баз несколько (память + файл) — это намеренно.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeClock clock;
  late LocalDatabase db;

  setUp(() {
    clock = FakeClock();
    db = LocalDatabase.memory(clock: clock.call);
  });
  tearDown(() => db.close());

  Future<String> addEmployee(
    String name, {
    String hire = '2025-01-01',
    String? dismissal,
  }) => db.employeesDao.insertEmployee(
    EmployeesCompanion(
      fullName: Value(name),
      position: const Value('Рабочий'),
      hireDate: Value(hire),
      dismissalDate: Value(dismissal),
    ),
  );

  TimesheetCompanion day(String emp, String date, {double days = 1}) =>
      TimesheetCompanion(
        employeeUuid: Value(emp),
        date: Value(date),
        dayType: const Value('work'),
        days: Value(days),
        workPlace: const Value('field'),
      );

  PaymentsCompanion payment(String emp, String date, double amount) =>
      PaymentsCompanion(
        employeeUuid: Value(emp),
        paymentDate: Value(date),
        amount: Value(amount),
      );

  PayrollResultsCompanion payroll(String emp, int y, int m, double total) =>
      PayrollResultsCompanion(
        employeeUuid: Value(emp),
        year: Value(y),
        month: Value(m),
        totalSalary: Value(total),
        calculatedAt: const Value('2026-09-01T12:00:00.000'),
      );

  group('схема', () {
    test('во всех бизнес-таблицах есть поля синхронизации', () async {
      for (final table in _businessTables) {
        final columns = await db
            .customSelect('PRAGMA table_info($table)')
            .map((r) => r.read<String>('name'))
            .get();
        expect(
          columns,
          containsAll([
            'uuid',
            'legacy_id',
            'updated_at',
            'deleted',
            'edited_by',
            'remote_updated_at',
          ]),
          reason: table,
        );
      }
    });

    test('есть служебные таблицы синхронизации', () async {
      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r.read<String>('name'))
          .get();
      expect(tables, containsAll(['pending_changes', 'sync_state']));
    });

    test('настройки хозяйства создаются одной строкой', () async {
      final settings = await db.settingsDao.getSettings();
      expect(settings, isNotNull);
      expect(settings!.uuid, companySettingsUuid);
      expect(settings.companyName, 'КФХ');
      expect(await db.select(db.companySettings).get(), hasLength(1));
    });

    test(
      'id устройства создаётся один раз и переживает переоткрытие',
      () async {
        final dir = await Directory.systemTemp.createTemp('kfh_local_db_');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/v2.db');

        final first = LocalDatabase.file(file);
        final id = await first.deviceId();
        await first.close();

        final second = LocalDatabase.file(file);
        expect(await second.deviceId(), id);
        expect(id, matches(_uuidV7));
        await second.close();
      },
    );

    test('updated_at хранится строкой ISO в UTC', () async {
      await addEmployee('Иванов Иван');
      final raw = await db
          .customSelect(
            'SELECT updated_at, typeof(updated_at) AS t FROM employees',
          )
          .getSingle();
      expect(raw.read<String>('t'), 'text');
      expect(raw.read<String>('updated_at'), startsWith('2026-09-26T10:00:00'));
      expect(raw.read<String>('updated_at'), endsWith('Z'));
    });
  });

  group('сотрудники', () {
    test('добавление: uuid v7, отметка времени и устройства', () async {
      final uuid = await addEmployee('Иванов Иван');
      expect(uuid, matches(_uuidV7));
      final row = (await db.employeesDao.employeeByUuid(uuid))!;
      expect(row.updatedAt, clock.now);
      expect(row.editedBy, await db.deviceId());
      expect(row.deleted, isFalse);
    });

    test('список по ФИО и фильтр уволенных на дату', () async {
      await addEmployee('Петров Пётр', dismissal: '2026-09-26');
      await addEmployee('Иванов Иван');
      await addEmployee('Сидоров Сидор', dismissal: '2026-09-27');

      final all = await db.employeesDao.allEmployees();
      expect(all.map((e) => e.fullName), [
        'Иванов Иван',
        'Петров Пётр',
        'Сидоров Сидор',
      ]);

      final active = await db.employeesDao.allEmployees(
        activeOn: DateTime(2026, 9, 26),
      );
      expect(active.map((e) => e.fullName), ['Иванов Иван', 'Сидоров Сидор']);
    });

    test('обновление ставит новое updated_at и не меняет uuid', () async {
      final uuid = await addEmployee('Иванов Иван');
      clock.advance();
      final count = await db.employeesDao.updateEmployee(
        uuid,
        const EmployeesCompanion(
          uuid: Value('чужой'),
          position: Value('Бригадир'),
        ),
      );
      expect(count, 1);
      final row = (await db.employeesDao.employeeByUuid(uuid))!;
      expect(row.position, 'Бригадир');
      expect(row.updatedAt, clock.now);
    });

    test(
      'мягкое удаление скрывает сотрудника, но не трогает его историю',
      () async {
        final uuid = await addEmployee('Иванов Иван');
        await db.timesheetDao.insertRecord(day(uuid, '2026-09-01'));
        await db.paymentsDao.insertPayment(payment(uuid, '2026-09-05', 1000));

        clock.advance();
        expect(await db.employeesDao.softDeleteEmployee(uuid), 1);
        expect(await db.employeesDao.softDeleteEmployee(uuid), 0);

        expect(await db.employeesDao.allEmployees(), isEmpty);
        expect(await db.employeesDao.employeeByUuid(uuid), isNull);
        final deleted = await db.employeesDao.employeeByUuid(
          uuid,
          includeDeleted: true,
        );
        expect(deleted!.deleted, isTrue);
        expect(deleted.updatedAt, clock.now);

        final records = await db.timesheetDao.recordsInPeriod(
          DateTime(2026, 9, 1),
          DateTime(2026, 9, 30),
          employeeUuid: uuid,
        );
        expect(records, hasLength(1));
        expect(
          await db.paymentsDao.paymentsList(employeeUuid: uuid),
          hasLength(1),
        );
      },
    );
  });

  group('ставки', () {
    test(
      'новая ставка закрывает действующую датой «начало − 1 день»',
      () async {
        final emp = await addEmployee('Иванов Иван');
        await db.ratesDao.addRate(
          employeeUuid: emp,
          baseRate: 1000,
          fieldRate: 1500,
          startDate: DateTime(2026, 1, 1),
        );
        await db.ratesDao.addRate(
          employeeUuid: emp,
          baseRate: 1200,
          fieldRate: 1800,
          startDate: DateTime(2026, 3, 1),
        );

        final history = await db.ratesDao.rateHistory(emp);
        expect(history.map((r) => (r.startDate, r.endDate)), [
          ('2026-01-01', '2026-02-28'),
          ('2026-03-01', null),
        ]);

        expect(
          (await db.ratesDao.rateAt(emp, DateTime(2026, 2, 28)))!.baseRate,
          1000,
        );
        expect(
          (await db.ratesDao.rateAt(emp, DateTime(2026, 3, 1)))!.baseRate,
          1200,
        );
        expect(await db.ratesDao.rateAt(emp, DateTime(2025, 12, 31)), isNull);
      },
    );

    test('удалённая ставка не действует', () async {
      final emp = await addEmployee('Иванов Иван');
      final rate = await db.ratesDao.addRate(
        employeeUuid: emp,
        baseRate: 1000,
        fieldRate: 1500,
        startDate: DateTime(2026, 1, 1),
      );
      await db.ratesDao.softDeleteRate(rate);
      expect(await db.ratesDao.rateAt(emp, DateTime(2026, 5, 1)), isNull);
      expect(await db.ratesDao.rateHistory(emp), isEmpty);
    });
  });

  group('табель', () {
    test('вторая запись на ту же дату отклоняется', () async {
      final emp = await addEmployee('Иванов Иван');
      await db.timesheetDao.insertRecord(day(emp, '2026-09-01'));
      expect(
        () => db.timesheetDao.insertRecord(day(emp, '2026-09-01', days: 0.5)),
        throwsA(isA<DuplicateEntryException>()),
      );
    });

    test('после удаления день можно ввести заново', () async {
      final emp = await addEmployee('Иванов Иван');
      final first = await db.timesheetDao.insertRecord(day(emp, '2026-09-01'));
      await db.timesheetDao.softDeleteRecord(first);
      final second = await db.timesheetDao.insertRecord(
        day(emp, '2026-09-01', days: 0.5),
      );
      expect(second, isNot(first));
      final row = await db.timesheetDao.recordOn(emp, DateTime(2026, 9, 1));
      expect(row!.uuid, second);
      expect(row.days, 0.5);
    });

    test('уникальный индекс не пускает дубль в обход DAO', () async {
      final emp = await addEmployee('Иванов Иван');
      await db.timesheetDao.insertRecord(day(emp, '2026-09-01'));
      final duplicate = day(emp, '2026-09-01').copyWith(
        uuid: Value(newUuid()),
        createdAt: const Value('2026-09-01T00:00:00.000'),
        updatedAt: Value(clock.now),
      );
      expect(
        () => db.into(db.timesheet).insert(duplicate),
        throwsA(predicate((e) => '$e'.contains('UNIQUE constraint failed'))),
      );
    });

    test('период включает границы и фильтрует сотрудника', () async {
      final a = await addEmployee('Иванов Иван');
      final b = await addEmployee('Петров Пётр');
      for (final d in [
        '2026-08-31',
        '2026-09-01',
        '2026-09-30',
        '2026-10-01',
      ]) {
        await db.timesheetDao.insertRecord(day(a, d));
      }
      await db.timesheetDao.insertRecord(day(b, '2026-09-15'));

      final september = await db.timesheetDao.recordsInPeriod(
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 30),
      );
      expect(september.map((r) => r.date), [
        '2026-09-30',
        '2026-09-15',
        '2026-09-01',
      ]);

      final onlyA = await db.timesheetDao.recordsInPeriod(
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 30),
        employeeUuid: a,
      );
      expect(onlyA, hasLength(2));
    });

    test('правка не меняет created_at, но меняет updated_at', () async {
      final emp = await addEmployee('Иванов Иван');
      final uuid = await db.timesheetDao.insertRecord(day(emp, '2026-09-01'));
      final before = (await db.timesheetDao.recordOn(
        emp,
        DateTime(2026, 9, 1),
      ))!;

      clock.advance();
      await db.timesheetDao.updateRecord(
        uuid,
        const TimesheetCompanion(
          days: Value(0.5),
          createdAt: Value('2000-01-01T00:00:00.000'),
        ),
      );
      final after = (await db.timesheetDao.recordOn(
        emp,
        DateTime(2026, 9, 1),
      ))!;
      expect(after.days, 0.5);
      expect(after.createdAt, before.createdAt);
      expect(after.updatedAt, clock.now);
    });
  });

  group('выплаты и начисления', () {
    test('выплаты за период и сумма до даты без удалённых', () async {
      final emp = await addEmployee('Иванов Иван');
      await db.paymentsDao.insertPayment(payment(emp, '2026-08-31', 100));
      await db.paymentsDao.insertPayment(payment(emp, '2026-09-01', 200));
      final removed = await db.paymentsDao.insertPayment(
        payment(emp, '2026-08-15', 1000),
      );
      await db.paymentsDao.softDeletePayment(removed);

      final september = await db.paymentsDao.paymentsList(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 30),
      );
      expect(september.map((p) => p.amount), [200]);

      expect(await db.paymentsDao.paidBefore(DateTime(2026, 9, 1)), {emp: 100});
    });

    test('повторное сохранение расчёта обновляет ту же запись', () async {
      final emp = await addEmployee('Иванов Иван');
      final first = await db.payrollDao.saveResult(payroll(emp, 2026, 8, 1000));
      final second = await db.payrollDao.saveResult(
        payroll(emp, 2026, 8, 1500),
      );
      expect(second, first);
      final rows = await db.payrollDao.resultsForMonth(2026, 8);
      expect(rows.single.totalSalary, 1500);
    });

    test('начислено за месяцы строго до указанного', () async {
      final emp = await addEmployee('Иванов Иван');
      await db.payrollDao.saveResult(payroll(emp, 2025, 12, 100));
      await db.payrollDao.saveResult(payroll(emp, 2026, 8, 200));
      await db.payrollDao.saveResult(payroll(emp, 2026, 9, 400));
      expect(await db.payrollDao.accruedBefore(2026, 9), {emp: 300});
      expect(await db.payrollDao.accruedBefore(2026, 1), {emp: 100});
    });
  });

  group('внешние ключи', () {
    test('запись табеля без сотрудника отклоняется', () async {
      expect(
        () => db.timesheetDao.insertRecord(day(newUuid(), '2026-09-01')),
        throwsA(
          predicate((e) => '$e'.contains('FOREIGN KEY constraint failed')),
        ),
      );
    });

    test('в транзакции сотрудник может прийти после своих записей', () async {
      final emp = newUuid();
      await db.transaction(() async {
        await db.timesheetDao.insertRecord(day(emp, '2026-09-01'));
        await db.employeesDao.insertEmployee(
          EmployeesCompanion(
            uuid: Value(emp),
            fullName: const Value('Иванов Иван'),
            position: const Value('Рабочий'),
            hireDate: const Value('2025-01-01'),
          ),
        );
      });
      expect(
        await db.timesheetDao.recordOn(emp, DateTime(2026, 9, 1)),
        isNotNull,
      );
    });
  });

  test('настройки: правка сохраняет единственную строку', () async {
    clock.advance();
    await db.settingsDao.updateSettings(
      const CompanySettingsCompanion(companyName: Value('КФХ «Лика»')),
    );
    final settings = (await db.settingsDao.getSettings())!;
    expect(settings.companyName, 'КФХ «Лика»');
    expect(settings.updatedAt, clock.now);
    expect(await db.select(db.companySettings).get(), hasLength(1));
  });
}
