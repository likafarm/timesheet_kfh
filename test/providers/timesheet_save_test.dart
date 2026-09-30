import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:kfh_domain/kfh_domain.dart';
import 'package:kfh_local_db/kfh_local_db.dart';
import 'package:kfx_time_tracking/providers/app_provider.dart';
import 'package:kfx_time_tracking/services/app_database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('смена рабочего дня на больничный снимает место работы', () async {
    final db = LocalDatabase.memory();
    addTearDown(db.close);
    final repos = DriftRepositories(db);
    final app = AppProvider(AppDatabase(db, ':memory:'));
    final emp = await repos.employees.add(
      Employee(
        fullName: 'Иванов Иван',
        position: 'Рабочий',
        hireDate: DateTime(2025, 3, 1),
        baseRate: 1000,
        fieldRate: 1500,
      ),
    );
    final day = DateTime(2026, 9, 3);
    await app.saveTimesheetRecord(
      TimesheetRecord(
        employeeId: emp,
        date: day,
        dayType: 'work',
        days: 1,
        workPlace: 'field',
        notes: 'заметка',
      ),
    );
    await app.saveTimesheetRecord(
      TimesheetRecord(employeeId: emp, date: day, dayType: 'sick', days: 1),
    );
    final saved = (await repos.timesheet.on(emp, day))!;
    expect(saved.dayType, 'sick');
    expect(saved.workPlace, isNull);
    expect(saved.notes, 'заметка');
  });

  group('рабочий день без места или с долей не 1/½ не записывается', () {
    late DriftRepositories repos;
    late AppProvider app;
    late String emp;
    final day = DateTime(2026, 9, 3);

    setUp(() async {
      final db = LocalDatabase.memory();
      addTearDown(db.close);
      repos = DriftRepositories(db);
      app = AppProvider(AppDatabase(db, ':memory:'));
      emp = await repos.employees.add(
        Employee(
          fullName: 'Иванов Иван',
          position: 'Рабочий',
          hireDate: DateTime(2025, 3, 1),
          baseRate: 1000,
          fieldRate: 1500,
        ),
      );
    });

    test('одна запись, групповой ввод и черновик дня', () async {
      final noPlace = TimesheetRecord(employeeId: emp, date: day, days: 1);
      await app.saveTimesheetRecord(noPlace);
      expect(app.takeNotice(), contains('место работы'));
      await app.addTimesheetRecord(noPlace);
      expect(app.takeNotice(), contains('03.09.2026'));
      await app.saveDailyTimesheet([noPlace], day);
      expect(app.takeNotice(), isNotNull);
      expect(await app.saveDayMarks(day, {emp: noPlace}), isFalse);
      expect(app.takeNotice(), isNotNull);
      await app.saveTimesheetRecord(
        TimesheetRecord(
          employeeId: emp,
          date: day,
          days: 0.25,
          workPlace: 'base',
        ),
      );
      expect(app.takeNotice(), contains('1 или ½'));
      expect(await repos.timesheet.on(emp, day), isNull);
    });

    test(
      'групповой ввод: выходной вместо рабочего дня снимает место',
      () async {
        await app.saveDailyTimesheet([
          TimesheetRecord(
            employeeId: emp,
            date: day,
            days: 1,
            workPlace: 'field',
          ),
        ], day);
        await app.saveDailyTimesheet([
          TimesheetRecord(
            employeeId: emp,
            date: day,
            dayType: 'dayoff',
            days: 1,
          ),
        ], day);
        final saved = (await repos.timesheet.on(emp, day))!;
        expect(saved.dayType, 'dayoff');
        expect(saved.workPlace, isNull);
      },
    );
  });
}
